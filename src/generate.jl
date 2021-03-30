const package_regex = r"package\s(\S*)[\s]*;.*"
const service_regex = r"service\s(\S*)[\s]*{.*"

function write_header(io, package, client_module_name)
    print(io, """module $(client_module_name)
    using gRPCClient

    include("$(package).jl")
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
        elseif startswith(strip(line), "service")
            regexmatches = match(service_regex, line)
            if (regexmatches !== nothing) && (length(regexmatches.captures) == 1)
                service = string(first(regexmatches.captures))
                push!(services, service)
            end
        end
    end
    package, services
end

"""
    generate(proto::String; outdir::String=pwd())

Generate a gRPC client from protobuf specification file.

- `proto`: Path to the protobuf specification to used.
- `outdir`: Directory to write generated code into, created if not present
    already. Existing files if any will be overwtitten.
"""
function generate(proto::String; outdir::String=pwd())
    if !isfile(proto)
        throw(ArgumentError("No such file - $proto"))
    end
    proto = abspath(proto)

    @info("Generating gRPC client", proto, outdir)

    # determine the package name and service name
    package, services = detect_services(proto)
    protodir = dirname(proto)
    @info("Detected", package, services)

    # generate protobuf services
    mkpath(outdir)
    bindir = Sys.BINDIR
    pathenv = string(ENV["PATH"], Sys.iswindows() ? ";" : ":", bindir)
    withenv("PATH"=>pathenv) do
        ProtoBuf.protoc(`-I=$protodir --julia_out=$outdir $proto`)
    end

    # include the generated code and detect service method names
    generated_module = joinpath(outdir, "$(package).jl")
    Main.eval(:(include($generated_module)))

    # generate the gRPC client code
    client_module_name = string(titlecase(package), "Clients")
    open(joinpath(outdir, "$(client_module_name).jl"), "w") do grpcservice
        write_header(grpcservice, package, client_module_name)
        for service in services
            methods = Base.eval(Base.eval(Main, Symbol(package)), Symbol(string("_", service, "_methods")))
            write_service(grpcservice, package, service, methods)
        end
        write_trailer(grpcservice, client_module_name)
    end

    @info("Generated", outdir)
end