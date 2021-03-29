using gRPCClient
using Downloads
using Random
using Sockets
using Test

const SERVER_RELEASE = "https://github.com/JuliaComputing/gRPCClient.jl/releases/download/testserver_v0.1/"
function server_binary()
    arch = (Sys.ARCH === :x86_64) ? "amd64" : "386"
    filename = Sys.islinux() ? "runserver_linux_$(arch)" :
                Sys.iswindows() ? "runserver_windows_$(arch).exe" :
                Sys.isapple() ? "runserver_darwin_$(arch)" :
                error("no server binary available for this platform")
    source = string(SERVER_RELEASE, filename)
    destination = joinpath(@__DIR__, filename)
    isfile(destination) || Downloads.download(source, destination)
    ((filemode(destination) & 0o777) == 0o777) || chmod(destination, 0o777)

    destination
end

function start_server()
    serverbin = server_binary()
    cert_file = joinpath(@__DIR__, "certgen", "server.pem")
    key_file = joinpath(@__DIR__, "certgen", "server.key")
    @assert isfile(cert_file) && isfile(key_file)

    @info("starting test server", serverbin, cert_file, key_file)
    serverproc = run(`$serverbin --tls=true --cert_file=$cert_file --key_file=$key_file`; wait=false)

    listening = timedwait(120.0; pollint=5.0) do 
        try
            sock = connect(ip"127.0.0.1", 10000)
            close(sock)
            true
        catch
            false
        end
    end

    if listening !== :ok
        @warn("test server did not start, stopping server")
        kill(serverproc)
        error("test server did not start")
    end

    serverproc
end

function test_generate()
    @testset "codegen" begin
        dir = joinpath(@__DIR__, "RouteGuideClients")
        gRPCClient.generate(joinpath(dir, "route_guide.proto"); outdir=dir)
        @test isfile(joinpath(dir, "route_guide_pb.jl"))
        @test isfile(joinpath(dir, "routeguide.jl"))
        @test isfile(joinpath(dir, "RouteGuideClients.jl"))
    end
end

# e.g.: SSL_CERT_FILE=/path/to/gRPCClient/test/certgen/ca.crt julia runtests.jl https://hostname:10000/
if isempty(get(ENV, "SSL_CERT_FILE", ""))
    ENV["SSL_CERT_FILE"] = joinpath(@__DIR__, "certgen", "ca.crt")
end

# switch off host verification for tests
if isempty(get(ENV, "JULIA_NO_VERIFY_HOSTS", ""))
    ENV["JULIA_NO_VERIFY_HOSTS"] = "**"
end

server_endpoint = isempty(ARGS) ? "https://localhost:10000/" : ARGS[1]
@info("server endpoint: $server_endpoint")

@testset "gRPCClient" begin
    test_generate()
    include("test_routeclient.jl")

    serverproc = start_server()

    @info("testing routeclinet...")
    test_clients(server_endpoint)

    kill(serverproc)
    @info("stopped test server")
end
