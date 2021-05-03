using Test

@testset "gRPCClient" begin
    include("runtests_routeguide.jl")
    include("runtests_errors.jl")
end
