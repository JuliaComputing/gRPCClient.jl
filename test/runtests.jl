using Test

include("runtests_routeguide.jl")
include("runtests_errors.jl")

@testset "gRPCClient" begin
    @testset "RouteGuide" begin
        RouteClientTest.runtests()
    end
    @testset "Server Errors" begin
        ErrorTest.runtests()
    end    
end
