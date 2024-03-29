module gRPCClient

using LibCURL
using Downloads
using ProtoBuf

import Downloads: Curl
import ProtoBuf: call_method
import Base: close

export gRPCController, gRPCChannel, gRPCException, gRPCServiceCallException, gRPCMessageTooLargeException, gRPCStatus, gRPCCheck, StatusCode

abstract type gRPCException <: Exception end

include("limitio.jl")
include("curl.jl")
include("grpc.jl")
include("generate.jl")

function __init__()
    GRPC_STATIC_HEADERS[] = grpc_headers()
end

end # module
