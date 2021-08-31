module RouteClientTest

using gRPCClient
using Downloads
using Random
using Sockets
using Test
using Base.Threads

const SERVER_RELEASE = "https://github.com/JuliaComputing/gRPCClient.jl/releases/download/testserver_v0.2/"
function server_binary()
    arch = (Sys.ARCH === :x86_64) ? "amd64" : "386"
    filename = Sys.islinux() ? "routeguide_linux_$(arch)" :
                Sys.iswindows() ? "routeguide_windows_$(arch).exe" :
                Sys.isapple() ? "routeguide_darwin_$(arch)" :
                error("no server binary available for this platform")
    source = string(SERVER_RELEASE, filename)
    destination = joinpath(@__DIR__, filename)
    isfile(destination) || Downloads.download(source, destination)
    ((filemode(destination) & 0o777) == 0o777) || chmod(destination, 0o777)

    destination
end

function start_server()
    serverbin = server_binary()

    @info("starting test server", serverbin)
    serverproc = run(`$serverbin`; wait=false)

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
        dir = joinpath(@__DIR__, "RouteguideClients")
        gRPCClient.generate(joinpath(dir, "route_guide.proto"); outdir=dir)
        @test isfile(joinpath(dir, "route_guide_pb.jl"))
        @test isfile(joinpath(dir, "routeguide.jl"))
        @test isfile(joinpath(dir, "RouteguideClients.jl"))
    end
end

function test_timeout_header_values()
    @testset "timeout header" begin
        @test "100S" == gRPCClient.grpc_timeout_header_val(100)
        @test "100010m" == gRPCClient.grpc_timeout_header_val(100.01)
        @test "100000100u" == gRPCClient.grpc_timeout_header_val(100.0001)
        @test "100000010000n" == gRPCClient.grpc_timeout_header_val(100.00001)
    end
end

# switch off host verification for tests
if isempty(get(ENV, "JULIA_NO_VERIFY_HOSTS", ""))
    ENV["JULIA_NO_VERIFY_HOSTS"] = "**"
end

server_endpoint = isempty(ARGS) ? "http://localhost:10000/" : ARGS[1]
@info("server endpoint: $server_endpoint")

@testset "RouteGuide" begin
    if !Sys.iswindows()
        test_generate()
    else
        @info("skipping code generation on Windows to avoid needing batch file execution permissions")
    end
    
    test_timeout_header_values()

    include("test_routeclient.jl")
    serverproc = start_server()

    @debug("testing routeclinet...")
    test_clients(server_endpoint)

    @debug("testing async safety...")
    test_task_safety(server_endpoint)

    if Threads.nthreads() > 1
        @debug("testing multithreaded clients...", threadcount=Threads.nthreads())
        test_threaded_clients(server_endpoint)
    end

    kill(serverproc)
    @info("stopped test server")
end

end # module RouteClientTest
