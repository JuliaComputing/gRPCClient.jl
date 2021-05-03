module GrpcerrorsClients
using gRPCClient

include("grpcerrors.jl")
using .grpcerrors

import Base: show

# begin service: grpcerrors.GRPCErrors

export GRPCErrorsBlockingClient, GRPCErrorsClient

struct GRPCErrorsBlockingClient
    controller::gRPCController
    channel::gRPCChannel
    stub::GRPCErrorsBlockingStub

    function GRPCErrorsBlockingClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = GRPCErrorsBlockingStub(channel)
        new(controller, channel, stub)
    end
end

struct GRPCErrorsClient
    controller::gRPCController
    channel::gRPCChannel
    stub::GRPCErrorsStub

    function GRPCErrorsClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = GRPCErrorsStub(channel)
        new(controller, channel, stub)
    end
end

show(io::IO, client::GRPCErrorsBlockingClient) = print(io, "GRPCErrorsBlockingClient(", client.channel.baseurl, ")")
show(io::IO, client::GRPCErrorsClient) = print(io, "GRPCErrorsClient(", client.channel.baseurl, ")")

import .grpcerrors: SimpleRPC
"""
    SimpleRPC

- input: grpcerrors.Data
- output: grpcerrors.Data
"""
SimpleRPC(client::GRPCErrorsBlockingClient, inp::grpcerrors.Data) = SimpleRPC(client.stub, client.controller, inp)
SimpleRPC(client::GRPCErrorsClient, inp::grpcerrors.Data, done::Function) = SimpleRPC(client.stub, client.controller, inp, done)

import .grpcerrors: StreamResponse
"""
    StreamResponse

- input: grpcerrors.Data
- output: Channel{grpcerrors.Data}
"""
StreamResponse(client::GRPCErrorsBlockingClient, inp::grpcerrors.Data) = StreamResponse(client.stub, client.controller, inp)
StreamResponse(client::GRPCErrorsClient, inp::grpcerrors.Data, done::Function) = StreamResponse(client.stub, client.controller, inp, done)

import .grpcerrors: StreamRequest
"""
    StreamRequest

- input: Channel{grpcerrors.Data}
- output: grpcerrors.Data
"""
StreamRequest(client::GRPCErrorsBlockingClient, inp::Channel{grpcerrors.Data}) = StreamRequest(client.stub, client.controller, inp)
StreamRequest(client::GRPCErrorsClient, inp::Channel{grpcerrors.Data}, done::Function) = StreamRequest(client.stub, client.controller, inp, done)

import .grpcerrors: StreamRequestResponse
"""
    StreamRequestResponse

- input: Channel{grpcerrors.Data}
- output: Channel{grpcerrors.Data}
"""
StreamRequestResponse(client::GRPCErrorsBlockingClient, inp::Channel{grpcerrors.Data}) = StreamRequestResponse(client.stub, client.controller, inp)
StreamRequestResponse(client::GRPCErrorsClient, inp::Channel{grpcerrors.Data}, done::Function) = StreamRequestResponse(client.stub, client.controller, inp, done)

# end service: grpcerrors.GRPCErrors

end # module GrpcerrorsClients
