# limits number of bytes written to an io stream (originally from https://github.com/JuliaDebug/Debugger.jl/blob/master/src/limitio.jl)
# useful to detect messages that would go over limit when converted to bytes.
mutable struct LimitIO{IO_t <: IO} <: IO
    io::IO_t
    maxbytes::Int
    n::Int # max bytes to write
end
LimitIO(io::IO, maxbytes) = LimitIO(io, maxbytes, 0)

function Base.write(io::LimitIO, v::UInt8)
    io.n > io.maxbytes && throw(gRPCMessageTooLargeException(io.maxbytes, io.n))
    nincr = write(io.io, v)
    io.n += nincr
    nincr
end

"""
Default maximum gRPC message size
"""
const DEFAULT_MAX_MESSAGE_LENGTH = 1024*1024*4

"""
    struct gRPCMessageTooLargeException
        limit::Int
        encountered::Int
    end

A `gRPMessageTooLargeException` exception is thrown when a message is
encountered that has a size greater than the limit configured.
Specifically, `max_recv_message_length` while receiving  and
`max_send_message_length` while sending.

A `gRPMessageTooLargeException` has the following members:

- `limit`: the limit value that was exceeded
- `encountered`: the amount of data that was actually received
    or sent before this error was triggered. Note that this may
    not correspond to the full size of the data, as error may be
    thrown before actually materializing the complete data.
"""
struct gRPCMessageTooLargeException <: gRPCException
    limit::Int
    encountered::Int
end

Base.show(io::IO, m::gRPCMessageTooLargeException) = print(io, "gRPMessageTooLargeException($(m.limit), $(m.encountered)) - Encountered message size $(m.encountered) > max configured $(m.limit)")