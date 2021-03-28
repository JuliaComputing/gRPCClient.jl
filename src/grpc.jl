"""
    struct gRPCStatus
        success::Bool
        message::String
    end

`gRPCStatus` represents the status of a request. It has the following fields:

- `success`: whether the request was completed successfully.
- `message`: any error message if request was not successful
"""
struct gRPCStatus
    success::Bool
    message::String
end

"""
    struct gRPCException
        message::String
    end

Every gRPC request returns the result and a future representing the status
of the gRPC request. Use the `gRPCCheck` method on the status future to check
the request status and throw a `gRPCException` if it is not successful.

A `gRPCException` has the following members:

- `message`: any error message if request was not successful
"""
struct gRPCException <: Exception
    message::String
end

"""
    gRPCCheck(status; throw_error::Bool=true)

Check the response of a gRPC request and raise a `gRPCException` if it has
failed. If `throw_error` is set to false, returns `true` or `false` indicating
success instead.
"""
gRPCCheck(status; throw_error::Bool=true) = gRPCCheck(fetch(status); throw_error=throw_error)
function gRPCCheck(status::gRPCStatus; throw_error::Bool=true)
    if throw_error
        status.success || throw(gRPCException(status.message))
    else
        status.success
    end
end

"""
    gRPCController(;
        [ maxage::Int = 0, ]
        [ keepalive::Int64 = 60, ]
        [ request_timeout::Real = Inf, ]
        [ connect_timeout::Real = 0, ]
        [ verbose::Bool = false, ]
    )

Contains settings to control the behavior of gRPC requests.
- `maxage`: maximum age (seconds) of a connection beyond which it will not
   be reused (default 180 seconds, same as setting this to 0).
- `keepalive`: interval (seconds) in which to send TCP keepalive messages on
   the connection (default 60 seconds).
- `request_timeout`: request timeout (seconds)
- `connect_timeout`: connect timeout (seconds) (default is 300 seconds, same
   as setting this to 0)
- `verbose`: whether to print out verbose communication logs (default false)
"""
struct gRPCController <: ProtoRpcController
    maxage::Clong
    keepalive::Clong
    request_timeout::Real
    connect_timeout::Real
    verbose::Bool

    function gRPCController(;
            maxage::Integer = 0,
            keepalive::Integer = 60,
            request_timeout::Real = Inf,
            connect_timeout::Real = 0,
            verbose::Bool = false
        )
        new(maxage, keepalive, request_timeout, connect_timeout, verbose)
    end
end

"""
    gRPCChannel(baseurl)

`gRPCChannel` represents a connection to a specific service endpoint
(service `baseurl`) of a gRPC server.

A channel also usually has a single network connection backing it and
multiple streams of requests can flow through it at any time. The number
of streams that can be multiplexed is negotiated between the client and
the server.
"""
struct gRPCChannel <: ProtoRpcChannel
    downloader::Downloader
    baseurl::String

    function gRPCChannel(baseurl::String)
        downloader = Downloader(; grace=Inf)
        Curl.init!(downloader.multi)
        Curl.setopt(downloader.multi, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX)
        endswith(baseurl, '/') && (baseurl = baseurl[1:end-1])
        new(downloader, baseurl)
    end
end

function to_delimited_message_bytes(msg)
    iob = IOBuffer()
    write(iob, UInt8(0))                # compression
    write(iob, hton(UInt32(0)))         # message length (placeholder)
    data_len = writeproto(iob, msg)     # message bytes
    seek(iob, 1)                        # seek out the message length placeholder
    write(iob, hton(UInt32(data_len)))  # fill the message length
    take!(iob)
end

function call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, request::T) where T <: ProtoType
    inputchannel = Channel{T}(1)
    put!(inputchannel, request)
    close(inputchannel)
    call_method(channel, service, method, controller, inputchannel)
end
call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, input::Channel{T}) where T <: ProtoType = call_method(channel, service, method, controller, input, get_response_type(method))
function call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, input::Channel{T1}, ::Type{Channel{T2}}) where {T1 <: ProtoType, T2 <: ProtoType}
    call_method(channel, service, method, controller, input, Channel{T2}())
end
function call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, input::Channel{T1}, ::Type{T2}) where {T1 <: ProtoType, T2 <: ProtoType}
    outchannel, status_future = call_method(channel, service, method, controller, input, Channel{T2}())
    try
        take!(outchannel), status_future
    catch
        nothing, status_future
    end
end
function call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, input::Channel{T1}, outchannel::Channel{T2}) where {T1 <: ProtoType, T2 <: ProtoType}
    url = string(channel.baseurl, "/", service.name, "/", method.name)
    status_future = @async grpc_request(channel.downloader, url, input, outchannel;
        maxage = controller.maxage,
        keepalive = controller.keepalive,
        request_timeout = controller.request_timeout,
        connect_timeout = controller.connect_timeout,
        verbose = controller.verbose,
    )
    outchannel, status_future
end
