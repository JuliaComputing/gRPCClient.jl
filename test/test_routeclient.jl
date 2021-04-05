include("RouteguideClients/RouteguideClients.jl")
using .RouteguideClients

Base.show(io::IO, location::RouteguideClients.Point) = print(io, string("[", location.latitude, ", ", location.longitude, "]"))
Base.show(io::IO, feature::RouteguideClients.Feature) = print(io, string(feature.name, " - ", feature.location))
Base.show(io::IO, summary::RouteguideClients.RouteSummary) = print(io, string(summary.point_count, " points, ", summary.feature_count, " features, distance=", summary.distance, ", elapsed_time=", summary.elapsed_time))
Base.show(io::IO, note::RouteguideClients.RouteNote) = print(io, string(note.message, " ", note.location))

function randomPoint()
    latitude = (abs(rand(Int) % 180) - 90) * 1e7
    longitude = (abs(rand(Int) % 360) - 180) * 1e7
    RouteguideClients.Point(; latitude=latitude, longitude=longitude)
end

# single request, single response
function test_get_feature(client::RouteGuideBlockingClient)
    # existing feature
    point = RouteguideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteguideClients.GetFeature(client, point)
    gRPCCheck(status_future)
    @test isa(feature, RouteguideClients.Feature)
    @debug("existing feature", feature)

    # missing feature
    point = RouteguideClients.Point(; latitude=0, longitude=0)
    feature, status_future = RouteguideClients.GetFeature(client, point)
    gRPCCheck(status_future)
    @test isa(feature, RouteguideClients.Feature)
    @debug("missing feature", feature)
end

# single request, streaming response
function test_list_features(client::RouteGuideBlockingClient)
    @debug("listing features in an area")
    rect = RouteguideClients.Rectangle(; lo=RouteguideClients.Point(; latitude=400000000, longitude=-750000000), hi=RouteguideClients.Point(; latitude=420000000, longitude=-730000000))
    features, status_future = RouteguideClients.ListFeatures(client, rect)
    while isopen(features) || isready(features)
        try
            feature = take!(features)
            @debug(feature)
        catch ex
            (!isa(ex, InvalidStateException) || !fetch(status_future).success) && rethrow(ex)
        end
    end
    gRPCCheck(status_future)
    @test isa(features, Channel{RouteguideClients.Feature})
    @test !isopen(features)
end

# streaming request, single response
function test_record_route(client::RouteGuideBlockingClient)
    @sync begin
        point_count = abs(rand(Int) % 100) + 2
        @debug("recording a route", point_count)
        points_channel = Channel{RouteguideClients.Point}(1)
        @async begin
            for idx in 1:point_count
                put!(points_channel, randomPoint())
            end
            close(points_channel)
        end
        route_summary, status_future = RouteguideClients.RecordRoute(client, points_channel)
        gRPCCheck(status_future)
        @test isa(route_summary, RouteguideClients.RouteSummary)
        @test !isopen(points_channel)
        @debug("route summary: $route_summary")
    end
end

# streaming request, streaming response
function test_route_chat(client::RouteGuideBlockingClient)
    @sync begin
        notes = RouteguideClients.RouteNote[
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=1), message="First message"),
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=2), message="Second message"),
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=3), message="Third message"),
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=1), message="Fourth message"),
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=2), message="Fifth message"),
            RouteguideClients.RouteNote(;location=RouteguideClients.Point(;latitude=0, longitude=3), message="Sixth message"),
        ]
        @debug("route chat")
        in_channel = Channel{RouteguideClients.RouteNote}(1)
        @async begin
            for note in notes
                put!(in_channel, note)
            end
            close(in_channel)
        end
        out_channel, status_future = RouteguideClients.RouteChat(client, in_channel)
        nreceived = 0
        for note in out_channel
            nreceived += 1
            @debug("received note $note")
        end
        gRPCCheck(status_future)
        @test nreceived > 0
        @test isa(out_channel, Channel{RouteguideClients.RouteNote})
        @test !isopen(out_channel)
        @test !isopen(in_channel)
    end
end

function test_exception()
    client = RouteGuideBlockingClient("https://localhost:30000"; verbose=false)
    point = RouteguideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteguideClients.GetFeature(client, point)
    @test_throws gRPCServiceCallException gRPCCheck(status_future)
    @test !gRPCCheck(status_future; throw_error=false)

    @test_throws ArgumentError RouteGuideBlockingClient("https://localhost:30000"; maxage=-1)
end

function test_message_length_limit(server_endpoint)
    # test send message length limit
    client = RouteGuideBlockingClient(server_endpoint; max_message_length=1, verbose=false)
    point = RouteguideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteguideClients.GetFeature(client, point)
    @test_throws gRPCMessageTooLargeException gRPCCheck(status_future)
    @test !gRPCCheck(status_future; throw_error=false)

    # test recv message length limit
    client = RouteGuideBlockingClient(server_endpoint; max_recv_message_length=1, verbose=false)
    point = RouteguideClients.Point(; latitude=409146138, longitude=-746188906)
    feature, status_future = RouteguideClients.GetFeature(client, point)
    @test_throws gRPCMessageTooLargeException gRPCCheck(status_future)
    @test !gRPCCheck(status_future; throw_error=false)

    iob = IOBuffer()
    show(iob, gRPCMessageTooLargeException(1, 2))
    @test String(take!(iob)) == "gRPMessageTooLargeException(1, 2) - Encountered message size 2 > max configured 1"
    show(iob, gRPCServiceCallException("test error"))
    @test String(take!(iob)) == "gRPCServiceCallException - test error"
end

function test_async_get_feature(client::RouteGuideClient)
    # existing feature
    point = RouteguideClients.Point(; latitude=409146138, longitude=-746188906)
    results = Channel{Any}(1)
    RouteguideClients.GetFeature(client, point, result->put!(results, result))
    feature, status_future = take!(results)
    gRPCCheck(status_future)
    @test isa(feature, RouteguideClients.Feature)
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
    @testset "request response" begin
        test_get_feature(client)
    end
    @testset "streaming recv" begin
        test_list_features(client)
    end
    @testset "streaming send" begin
        test_record_route(client)
    end
    @testset "streaming send recv" begin
        test_route_chat(client)
    end
    @testset "error handling" begin
        test_exception()
    end
    @testset "message length limits" begin
        test_message_length_limit(server_endpoint)
    end
end

function test_clients(server_endpoint::String)
    @info("testing blocking client")
    test_blocking_client(server_endpoint)
    @info("testing async client")
    test_async_client(server_endpoint)
end