module RouteGuideClients
using gRPCClient

include("routeguide.jl")
using .routeguide

import Base: show
export RouteGuideBlockingClient, RouteGuideClient

struct RouteGuideBlockingClient
    controller::gRPCController
    channel::gRPCChannel
    stub::RouteGuideBlockingStub

    function RouteGuideBlockingClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = RouteGuideBlockingStub(channel)
        new(controller, channel, stub)
    end
end

struct RouteGuideClient
    controller::gRPCController
    channel::gRPCChannel
    stub::RouteGuideStub

    function RouteGuideClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = RouteGuideStub(channel)
        new(controller, channel, stub)
    end
end

show(io::IO, client::RouteGuideBlockingClient) = print(io, "RouteGuideBlockingClient(", client.channel.baseurl, ")")
show(io::IO, client::RouteGuideClient) = print(io, "RouteGuideClient(", client.channel.baseurl, ")")

import .routeguide: GetFeature
"""
    GetFeature

- input: routeguide.Point
- output: routeguide.Feature
"""
GetFeature(client::RouteGuideBlockingClient, inp::routeguide.Point) = GetFeature(client.stub, client.controller, inp)
GetFeature(client::RouteGuideClient, inp::routeguide.Point, done::Function) = GetFeature(client.stub, client.controller, inp, done)

import .routeguide: ListFeatures
"""
    ListFeatures

- input: routeguide.Rectangle
- output: Channel{routeguide.Feature}
"""
ListFeatures(client::RouteGuideBlockingClient, inp::routeguide.Rectangle) = ListFeatures(client.stub, client.controller, inp)
ListFeatures(client::RouteGuideClient, inp::routeguide.Rectangle, done::Function) = ListFeatures(client.stub, client.controller, inp, done)

import .routeguide: RecordRoute
"""
    RecordRoute

- input: Channel{routeguide.Point}
- output: routeguide.RouteSummary
"""
RecordRoute(client::RouteGuideBlockingClient, inp::Channel{routeguide.Point}) = RecordRoute(client.stub, client.controller, inp)
RecordRoute(client::RouteGuideClient, inp::Channel{routeguide.Point}, done::Function) = RecordRoute(client.stub, client.controller, inp, done)

import .routeguide: RouteChat
"""
    RouteChat

- input: Channel{routeguide.RouteNote}
- output: Channel{routeguide.RouteNote}
"""
RouteChat(client::RouteGuideBlockingClient, inp::Channel{routeguide.RouteNote}) = RouteChat(client.stub, client.controller, inp)
RouteChat(client::RouteGuideClient, inp::Channel{routeguide.RouteNote}, done::Function) = RouteChat(client.stub, client.controller, inp, done)

end # module RouteGuideClients
