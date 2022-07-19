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
    grpc_status::Int
    message::String
    exception::Union{Nothing,Exception}
end

gRPCStatus(success::Bool, grpc_status::Int, message::AbstractString) = gRPCStatus(success, grpc_status, string(message), nothing)
function gRPCStatus(status_future)
    try
        return fetch(status_future)
    catch ex
        task_exception = isa(ex, TaskFailedException) ? ex.task.exception : ex
        while isa(task_exception, TaskFailedException)
            task_exception = task_exception.task.exception
        end
        return gRPCStatus(false, StatusCode.INTERNAL.code, string(task_exception), task_exception)
    end
end

"""
    struct gRPCServiceCallException
        message::String
    end

A `gRPCServiceCallException` is thrown if a gRPC request is not successful.
It has the following members:

- `message`: any error message if request was not successful
"""
struct gRPCServiceCallException <: gRPCException
    grpc_status::Int
    message::String
end

Base.show(io::IO, m::gRPCServiceCallException) = print(io, "gRPCServiceCallException: $(m.grpc_status), $(m.message)")

"""
    gRPCCheck(status; throw_error::Bool=true)

Every gRPC request returns the result and a future representing the status
of the gRPC request. Check the response of a gRPC request and raise a
`gRPCException` if it has failed. If `throw_error` is set to false, this
returns `true` or `false` indicating success instead.
"""
gRPCCheck(status_future; throw_error::Bool=true) = gRPCCheck(gRPCStatus(status_future); throw_error=throw_error)
function gRPCCheck(status::gRPCStatus; throw_error::Bool=true)
    if throw_error && !status.success
        if status.exception === nothing
            throw(gRPCServiceCallException(status.grpc_status, status.message))
        else
            throw(status.exception)
        end
    end
    status.success
end

"""
    gRPCController(;
        [ maxage::Int = 0, ]
        [ keepalive::Int64 = 60, ]
        [ negotiation::Symbol = :http2_prior_knowledge, ]
        [ revocation::Bool = true, ]
        [ request_timeout::Real = Inf, ]
        [ connect_timeout::Real = 0, ]
        [ max_message_length = DEFAULT_MAX_MESSAGE_LENGTH, ]
        [ max_recv_message_length = 0, ]
        [ max_send_message_length = 0, ]
        [ verbose::Bool = false, ]
    )

Contains settings to control the behavior of gRPC requests.
- `maxage`: maximum age (seconds) of a connection beyond which it will not
   be reused (default 180 seconds, same as setting this to 0).
- `keepalive`: interval (seconds) in which to send TCP keepalive messages on
   the connection (default 60 seconds).
- `negotiation`: how to negotiate HTTP2, can be one of `:http2_prior_knowledge`
   (no negotiation, the default), `:http2_tls` (http2 upgrade but only over
   tls), or `:http2` (http2 upgrade)
- `revocation`: whether to check for certificate recovation (default is true)
- `request_timeout`: request timeout (seconds)
- `connect_timeout`: connect timeout (seconds) (default is 300 seconds, same
   as setting this to 0)
- `max_message_length`: maximum message length (default is 4MB)
- `max_recv_message_length`: maximum message length to receive (default is
   `max_message_length`, same as setting this to 0)
- `max_send_message_length`: maximum message length to send (default is
   `max_message_length`, same as setting this to 0)
- `enable_shared_locks`: whether to enable locks for using gRPCClient across
    tasks/threads concurrently (experimental, default is false)
- `verbose`: whether to print out verbose communication logs (default false)
"""
struct gRPCController <: ProtoRpcController
    maxage::Clong
    keepalive::Clong
    negotiation::Symbol
    revocation::Bool
    request_timeout::Real
    connect_timeout::Real
    max_recv_message_length::Int
    max_send_message_length::Int
    enable_shared_locks::Bool
    verbose::Bool

    function gRPCController(;
            maxage::Integer = 0,
            keepalive::Integer = 60,
            negotiation::Symbol = :http2_prior_knowledge,
            revocation::Bool = true,
            request_timeout::Real = Inf,
            connect_timeout::Real = 0,
            max_message_length::Integer = DEFAULT_MAX_MESSAGE_LENGTH,
            max_recv_message_length::Integer = 0,
            max_send_message_length::Integer = 0,
            enable_shared_locks::Bool = false,
            verbose::Bool = false
        )
        if maxage < 0 || keepalive < 0 || request_timeout < 0 || connect_timeout < 0 || 
            max_message_length < 0 || max_recv_message_length < 0 || max_send_message_length < 0
            throw(ArgumentError("Invalid gRPCController parameter"))
        end
        (max_recv_message_length == 0) && (max_recv_message_length = max_message_length)
        (max_send_message_length == 0) && (max_send_message_length = max_message_length)
        new(maxage,
            keepalive,
            negotiation,
            revocation,
            request_timeout,
            connect_timeout,
            max_recv_message_length,
            max_send_message_length,
            enable_shared_locks,
            verbose,
        )
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
    curlshare::CurlShare

    function gRPCChannel(baseurl::String)
        downloader = Downloader(; grace=Inf)
        Curl.init!(downloader.multi)
        Curl.setopt(downloader.multi, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX)
        endswith(baseurl, '/') && (baseurl = baseurl[1:end-1])
        new(downloader, baseurl, CurlShare())
    end
end

function close(channel::gRPCChannel)
    close(channel.curlshare)
    nothing
end

function to_delimited_message_bytes(msg, max_message_length::Int)
    iob = IOBuffer()
    limitiob = LimitIO(iob, max_message_length)
    write(limitiob, UInt8(0))                   # compression
    write(limitiob, hton(UInt32(0)))            # message length (placeholder)
    data_len = writeproto(limitiob, msg)        # message bytes

    seek(iob, 1)                                # seek out the message length placeholder
    write(iob, hton(UInt32(data_len)))          # fill the message length
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
        return (take!(outchannel), status_future)
    catch ex
        gRPCCheck(status_future)    # check for core issue
        if isa(ex, InvalidStateException)
            throw(gRPCServiceCallException("Server closed connection without any response"))
        else
            rethrow()               # throw this error if there's no other issue
        end
    end
end
function call_method(channel::gRPCChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::gRPCController, input::Channel{T1}, outchannel::Channel{T2}) where {T1 <: ProtoType, T2 <: ProtoType}
    url = string(channel.baseurl, "/", service.name, "/", method.name)
    shptr = controller.enable_shared_locks ? channel.curlshare.shptr : nothing
    status_future = @async grpc_request(shptr, channel.downloader, url, input, outchannel;
        maxage = controller.maxage,
        keepalive = controller.keepalive,
        negotiation = controller.negotiation,
        revocation = controller.revocation,
        request_timeout = controller.request_timeout,
        connect_timeout = controller.connect_timeout,
        max_recv_message_length = controller.max_recv_message_length,
        max_send_message_length = controller.max_send_message_length,
        verbose = controller.verbose,
    )
    outchannel, status_future
end
