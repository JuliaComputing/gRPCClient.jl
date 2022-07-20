include("GrpcerrorsClients/GrpcerrorsClients.jl")
using .GrpcerrorsClients

# GrpcerrorsClients.Data mode values:
# 1: throw an error after seconds provided in `param`
# 2: no error, just wait until seconds provided in `param`, respond with SimulationParams
Base.show(io::IO, data::GrpcerrorsClients.Data) = print(io, string("[", data.mode, ", ", data.param, "]"))

# single request, single response
function test_simplerpc(client::GRPCErrorsBlockingClient)
    data = GrpcerrorsClients.Data(; mode=1, param=0)
    try
        _, status_future = GrpcerrorsClients.SimpleRPC(client, data)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == "simulated error mode 1"
        @test ex.grpc_status == StatusCode.UNKNOWN.code
    end

    data = GrpcerrorsClients.Data(; mode=2, param=5)
    try
        _, status_future = GrpcerrorsClients.SimpleRPC(client, data)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == StatusCode.DEADLINE_EXCEEDED.message
        @test ex.grpc_status == StatusCode.DEADLINE_EXCEEDED.code
    end
end

# single request, stream response
function test_stream_response(client::GRPCErrorsBlockingClient)
    data = GrpcerrorsClients.Data(; mode=1, param=0)
    try
        _, status_future = GrpcerrorsClients.StreamResponse(client, data)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == "simulated error mode 1"
        @test ex.grpc_status == StatusCode.UNKNOWN.code
    end

    data = GrpcerrorsClients.Data(; mode=2, param=25)
    try
        _, status_future = GrpcerrorsClients.StreamResponse(client, data)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == StatusCode.DEADLINE_EXCEEDED.message
        @test ex.grpc_status == StatusCode.DEADLINE_EXCEEDED.code
    end
end

# stream request, single response
function test_stream_request(client::GRPCErrorsBlockingClient)
    try
        data = GrpcerrorsClients.Data(; mode=1, param=0)
        in = Channel{GrpcerrorsClients.Data}(1)
        @async begin
            put!(in, data)
            close(in)
        end
        _, status_future = GrpcerrorsClients.StreamRequest(client, in)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == "simulated error mode 1"
        @test ex.grpc_status == StatusCode.UNKNOWN.code
    end

    try
        data = GrpcerrorsClients.Data(; mode=2, param=5)
        in = Channel{GrpcerrorsClients.Data}(1)
        @async begin
            put!(in, data)
            close(in)
        end
        _, status_future = GrpcerrorsClients.StreamRequest(client, in)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == StatusCode.DEADLINE_EXCEEDED.message
        @test ex.grpc_status == StatusCode.DEADLINE_EXCEEDED.code
    end
end

# stream request, stream response
function test_stream_request_response(client::GRPCErrorsBlockingClient)
    try
        data = GrpcerrorsClients.Data(; mode=1, param=0)
        in = Channel{GrpcerrorsClients.Data}(1)
        @async begin
            put!(in, data)
            close(in)
        end
        _, status_future = GrpcerrorsClients.StreamRequestResponse(client, in)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == "simulated error mode 1"
        @test ex.grpc_status == StatusCode.UNKNOWN.code
    end

    try
        data = GrpcerrorsClients.Data(; mode=2, param=5)
        in = Channel{GrpcerrorsClients.Data}(1)
        @async begin
            put!(in, data)
            close(in)
        end
        _, status_future = GrpcerrorsClients.StreamRequestResponse(client, in)
        gRPCCheck(status_future)
        error("error not caught")
    catch ex
        @test isa(ex, gRPCServiceCallException)
        @test ex.message == StatusCode.DEADLINE_EXCEEDED.message
        @test ex.grpc_status == StatusCode.DEADLINE_EXCEEDED.code
    end
end

function test_blocking_client(server_endpoint::String)
    client = GRPCErrorsBlockingClient(server_endpoint; verbose=false, request_timeout=3)
    @testset "request response" begin
        test_simplerpc(client)
    end
    @testset "streaming recv" begin
        test_stream_response(client)
    end
    @testset "streaming send" begin
        test_stream_request(client)
    end
    @testset "streaming send recv" begin
        test_stream_request_response(client)
    end
end

function test_connect_timeout()
    timeout_server_endpoint = "http://10.255.255.1/" # a non routable IP
    timeout_secs = 5
    client = GRPCErrorsBlockingClient(timeout_server_endpoint; verbose=false, connect_timeout=timeout_secs)
    @testset "connect timeout" begin
        data = GrpcerrorsClients.Data(; mode=1, param=0)
        t1 = time()
        try
            _, status_future = GrpcerrorsClients.SimpleRPC(client, data)
            gRPCCheck(status_future)
            error("error not caught")
        catch ex
            t2 = time()
            @test isa(ex, gRPCServiceCallException)
            @test ex.message == StatusCode.DEADLINE_EXCEEDED.message
            @test ex.grpc_status == StatusCode.DEADLINE_EXCEEDED.code
            @test (timeout_secs - 1) <= (t2 - t1) <= (timeout_secs + 1)
        end
    end
end

function test_clients(server_endpoint::String)
    @info("testing blocking client")
    test_blocking_client(server_endpoint)
end