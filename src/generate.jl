const package_regex = r"package\s(\S*)[\s]*;.*"
const service_regex = r"service\s(\S*)[\s]*{.*"

function write_header(io, package, service)
    print(io, """module $(service)Clients
    using gRPCClient

    include("$(package).jl")
    using .$(package)

    import Base: show
    """)
end

function write_trailer(io, package, service)
    print(io, """

    end # module $(service)Clients
    """)
end

function write_service(io, package, service, methods)
    print(io, """
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

function detect_service(proto::String)
    package = ""
    service = ""

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
            end
        end
    end
    package, service
end

function generate(proto::String; outdir::String=pwd())
    if !isfile(proto)
        throw(ArgumentError("No such file - $proto"))
    end
    proto = abspath(proto)

    @info("Generating gRPC client", proto, outdir)

    # determine the package name and service name
    package, service = detect_service(proto)
    protodir = dirname(proto)
    @info("Detected", package, service)

    # generate protobuf service
    mkpath(outdir)
    ProtoBuf.protoc(`-I=$protodir --julia_out=$outdir $proto`)

    # include the generated code and detect service method names
    generated_module = joinpath(outdir, "$(package).jl")
    Main.eval(:(include($generated_module)))
    methods = Base.eval(Base.eval(Main, Symbol(package)), Symbol(string("_", service, "_methods")))

    # generate the gRPC client code
    open(joinpath(outdir, "$(service)Clients.jl"), "w") do grpcservice
        write_header(grpcservice, package, service)
        write_service(grpcservice, package, service, methods)
        write_trailer(grpcservice, package, service)
    end

    @info("Generated", outdir)
end