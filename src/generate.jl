const package_regex = r"package\s(\S*)[\s]*;.*"
const service_regex = r"service\s(\S*)[\s]*.*"

function write_header(io, generated_module, package, client_module_name)
    print(io, """module $(client_module_name)
    using gRPCClient

    include("$(generated_module).jl")
    using .$(package)

    import Base: show
    """)
end

function write_trailer(io, client_module_name)
    print(io, """

    end # module $(client_module_name)
    """)
end

function write_service(io, package, service, methods)
    print(io, """

    # begin service: $(package).$(service)

    export $(service)BlockingClient, $(service)Client

    struct $(service)BlockingClient
        controller::gRPCController
        channel::gRPCChannel
        stub::$(service)BlockingStub

        function $(service)BlockingClient(api_base_url::String; kwargs...)
            controller = gRPCController(; kwargs...)
            channel = gRPCChannel(api_base_url)
            stub = $(service)BlockingStub(channel)
            new(controller, channel, stub)
        end
    end

    struct $(service)Client
        controller::gRPCController
        channel::gRPCChannel
        stub::$(service)Stub

        function $(service)Client(api_base_url::String; kwargs...)
            controller = gRPCController(; kwargs...)
            channel = gRPCChannel(api_base_url)
            stub = $(service)Stub(channel)
            new(controller, channel, stub)
        end
    end

    show(io::IO, client::$(service)BlockingClient) = print(io, "$(service)BlockingClient(", client.channel.baseurl, ")")
    show(io::IO, client::$(service)Client) = print(io, "$(service)Client(", client.channel.baseurl, ")")
    """)

    for method in methods
        write_service_method(io, package, service, method)
    end

    print(io, """

    # end service: $(package).$(service)
    """)
end

typename(ch::Type{T}) where {T <: Channel} = string("Channel{", typename(eltype(ch)), "}")
typename(T) = last(split(string(T), '.'; limit=2))

function write_service_method(io, package, service, method)
    method_name = method.name
    input_type = typename(method.input_type)
    output_type = typename(method.output_type)

    print(io, """

    import .$(package): $(method_name)
    \"\"\"
        $(method_name)
    
    - input: $input_type
    - output: $output_type
    \"\"\"
    $(method_name)(client::$(service)BlockingClient, inp::$(input_type)) = $(method_name)(client.stub, client.controller, inp)
    $(method_name)(client::$(service)Client, inp::$(input_type), done::Function) = $(method_name)(client.stub, client.controller, inp, done)
    """)
end

function detect_services(proto::String)
    package = ""
    services = String[]

    for line in readlines(proto)
        line = strip(line)
        if startswith(line, "package")
            regexmatches = match(package_regex, line)
            if (regexmatches !== nothing) && (length(regexmatches.captures) == 1)
                package = string(first(regexmatches.captures))
            end
        elseif startswith(line, "service")
            regexmatches = match(service_regex, line)
            if (regexmatches !== nothing) && (length(regexmatches.captures) == 1)
                service = string(first(regexmatches.captures))
                push!(services, service)
            end
        end
    end
    package, services
end

function get_generated_method_table(s::String)
    T = Main
    for t in split(s, ".")
        T = Base.eval(T, Symbol(t))
    end
    T
end

# Defining a local protoc to avoid issues with ProtoBuf.protoc,
# wherein it was using the form `protoc_jll.protoc() do .. end`
# which is now deprecated and is causing errors in code generation.
function grpc_protoc(args=``; protoc_path=ProtoBuf.protoc_jll.protoc())
    plugin_dir = abspath(joinpath(dirname(pathof(ProtoBuf)), "..", "plugin"))
    plugin = joinpath(plugin_dir, Sys.iswindows() ? "protoc-gen-julia_win.bat" : "protoc-gen-julia")

    ENV′ = copy(ENV)
    ENV′["PATH"] = string(plugin_dir, Sys.iswindows() ? ";" : ":", ENV′["PATH"])
    ENV′["JULIA"] = joinpath(Sys.BINDIR, Base.julia_exename())
    # protobuf plugin uses COVERAGE env var to pass coverage flag to julia
    # we do not want to pass unintended values that sometimes CI environments set
    # we also do not intend to trigger coverage in the plugin while running CI in this package
    ENV′["COVERAGE"] = ""
    run(setenv(`$protoc_path --plugin=protoc-gen-julia=$plugin $args`, ENV′))
end

"""
    generate(proto::String; outdir::String=pwd())

Generate a gRPC client from protobuf specification file.

- `proto`: Path to the protobuf specification to used.
- `outdir`: Directory to write generated code into, created if not present
    already. Existing files if any will be overwtitten.
"""
function generate(proto::String; outdir::String=pwd(), includes::Vector{String}=String[], protoc_path=ProtoBuf.protoc_jll.protoc())
    if !isfile(proto)
        throw(ArgumentError("No such file - $proto"))
    end
    proto = abspath(proto)

    @info("Generating gRPC client", proto, outdir)

    # determine the package name and service name
    package, services = detect_services(proto)
    protodir = dirname(proto)
    includeflag = `-I=$protodir`
    for inc in includes
        includeflag = `$includeflag -I=$inc`
    end
    @info("Detected", package, services, includes)

    # generate protobuf services
    mkpath(outdir)
    bindir = Sys.BINDIR
    pathenv = string(ENV["PATH"], Sys.iswindows() ? ";" : ":", bindir)
    withenv("PATH"=>pathenv) do
        grpc_protoc(`$includeflag --julia_out=$outdir $proto`; protoc_path=protoc_path)
    end

    # include the generated code and detect service method names
    generated_module = first(split(package, '.'; limit=2))
    generated_module_file = joinpath(outdir, string(generated_module, ".jl"))
    Main.eval(:(include($generated_module_file)))

    # generate the gRPC client code
    client_module_name = string(titlecase(generated_module; strict=false), "Clients")
    open(joinpath(outdir, "$(client_module_name).jl"), "w") do grpcservice
        write_header(grpcservice, generated_module, package, client_module_name)
        for service in services
            methods = get_generated_method_table(string(package, "._", service, "_methods"))
            write_service(grpcservice, package, service, methods)
        end
        write_trailer(grpcservice, client_module_name)
    end

    @info("Generated", outdir)
end
