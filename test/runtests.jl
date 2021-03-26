using gRPCClient
using Random
using Test

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

server_endpoint = isempty(ARGS) ? "https://$(strip(read(`hostname -f`, String))):10000/" : ARGS[1]
@info("server endpoint: $server_endpoint")

@testset "gRPCClient" begin
    test_generate()
    include("test_routeclient.jl")
    @info("testing routeclinet...")
    test_clients(server_endpoint)
end