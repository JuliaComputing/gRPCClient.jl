using gRPCClient
using Random
using Test
using Profile

include("RouteGuideClients/RouteGuideClients.jl")
using .RouteGuideClients

Base.show(io::IO, location::RouteGuideClients.Point) = print(io, string("[", location.latitude, ", ", location.longitude, "]"))
Base.show(io::IO, feature::RouteGuideClients.Feature) = print(io, string(feature.name, " - ", feature.location))
Base.show(io::IO, summary::RouteGuideClients.RouteSummary) = print(io, string(summary.point_count, " points, ", summary.feature_count, " features, distance=", summary.distance, ", elapsed_time=", summary.elapsed_time))
Base.show(io::IO, note::RouteGuideClients.RouteNote) = print(io, string(note.message, " ", note.location))

function randomPoint()
    latitude = (abs(rand(Int) % 180) - 90) * 1e7
    longitude = (abs(rand(Int) % 360) - 180) * 1e7
    RouteGuideClients.Point(; latitude=latitude, longitude=longitude)
end

# single request, single response
function test_get_feature(client::RouteGuideBlockingClient)
    # existing feature
    point = RouteGuideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteGuideClients.GetFeature(client, point)
    gRPCCheck(status_future)
    @test isa(feature, RouteGuideClients.Feature)
    @debug("existing feature", feature)

    # missing feature
    point = RouteGuideClients.Point(; latitude=0, longitude=0)
    feature, status_future = RouteGuideClients.GetFeature(client, point)
    gRPCCheck(status_future)
    @test isa(feature, RouteGuideClients.Feature)
    @debug("missing feature", feature)
end

# single request, streaming response
function test_list_features(client::RouteGuideBlockingClient)
    @debug("listing features in an area")
    rect = RouteGuideClients.Rectangle(; lo=RouteGuideClients.Point(; latitude=400000000, longitude=-750000000), hi=RouteGuideClients.Point(; latitude=420000000, longitude=-730000000))
    features, status_future = RouteGuideClients.ListFeatures(client, rect)
    while isopen(features) || isready(features)
        try
            feature = take!(features)
            @debug(feature)
        catch ex
            (!isa(ex, InvalidStateException) || !fetch(status_future).success) && rethrow(ex)
        end
    end
    gRPCCheck(status_future)
    @test isa(features, Channel{RouteGuideClients.Feature})
    @test !isopen(features)
end

# streaming request, single response
function test_record_route(client::RouteGuideBlockingClient)
    @sync begin
        point_count = abs(rand(Int) % 100) + 2
        @debug("recording a route", point_count)
        points_channel = Channel{RouteGuideClients.Point}(1)
        @async begin
            for idx in 1:point_count
                put!(points_channel, randomPoint())
            end
            close(points_channel)
        end
        route_summary, status_future = RouteGuideClients.RecordRoute(client, points_channel)
        gRPCCheck(status_future)
        @test isa(route_summary, RouteGuideClients.RouteSummary)
        @test !isopen(points_channel)
        @debug("route summary: $route_summary")
    end
end

# streaming request, streaming response
function test_route_chat(client::RouteGuideBlockingClient)
    @sync begin
        notes = RouteGuideClients.RouteNote[
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=1), message="First message"),
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=2), message="Second message"),
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=3), message="Third message"),
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=1), message="Fourth message"),
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=2), message="Fifth message"),
            RouteGuideClients.RouteNote(;location=RouteGuideClients.Point(;latitude=0, longitude=3), message="Sixth message"),
        ]
        @debug("route chat")
        in_channel = Channel{RouteGuideClients.RouteNote}(1)
        @async begin
            for note in notes
                put!(in_channel, note)
            end
            close(in_channel)
        end
        out_channel, status_future = RouteGuideClients.RouteChat(client, in_channel)
        nreceived = 0
        for note in out_channel
            nreceived += 1
            @debug("received note $note")
        end
        gRPCCheck(status_future)
        @test nreceived > 0
        @test isa(out_channel, Channel{RouteGuideClients.RouteNote})
        @test !isopen(out_channel)
        @test !isopen(in_channel)
    end
end

function test_exception()
    client = RouteGuideBlockingClient("https://localhost:30000"; verbose=false)
    point = RouteGuideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteGuideClients.GetFeature(client, point)
    @test_throws gRPCException gRPCCheck(status_future)
    @test !gRPCCheck(status_future; throw_error=false)
end

function test_async_get_feature(client::RouteGuideClient)
    # existing feature
    point = RouteGuideClients.Point(; latitude=409146138, longitude=-746188906)
    results = Channel{Any}(1)
    RouteGuideClients.GetFeature(client, point, result->put!(results, result))
    feature, status_future = take!(results)
    gRPCCheck(status_future)
    @test isa(feature, RouteGuideClients.Feature)
    @debug("existing feature", feature)    
end

function test_async_client(server_endpoint::String)
    client = RouteGuideClient(server_endpoint; verbose=false)
    @testset "GetFeature" begin
        test_async_get_feature(client)
    end
end

function test_blocking_client(server_endpoint::String)
    client = RouteGuideBlockingClient(server_endpoint; verbose=false)
    @testset "GetFeature" begin
        test_get_feature(client)
    end
    @testset "ListFeatures" begin
        test_list_features(client)
    end
    @testset "RecordRoute" begin
        test_record_route(client)
    end
    @testset "RouteChat" begin
        test_route_chat(client)
    end
    @testset "ErrorHandling" begin
        test_exception()
    end
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

function test_clients(server_endpoint::String)
    test_blocking_client(server_endpoint)
    test_async_client(server_endpoint)
end

if length(ARGS) == 1
    @testset "gRPCClient" begin
        test_generate()
        test_clients(ARGS[1])
    end
else
    error("Usage: julia runtests.jl [server_endpoint]")
end
