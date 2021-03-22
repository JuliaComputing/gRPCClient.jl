module gRPCClient

using LibCURL
using Downloads
using ProtoBuf

import Downloads: Curl
import ProtoBuf: call_method

export gRPCController, gRPCChannel, gRPCException, gRPCStatus, gRPCCheck

include("curl.jl")
include("grpc.jl")

function __init__()
    GRPC_STATIC_HEADERS[] = grpc_headers()
end

end # module
