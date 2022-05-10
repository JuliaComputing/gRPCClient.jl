const GRPC_STATIC_HEADERS = Ref{Ptr{Nothing}}(C_NULL)

const StatusCode = (
    OK                  = (code=0,  message="Success"),
    CANCELLED           = (code=1,  message="The operation was cancelled"),
    UNKNOWN             = (code=2,  message="Unknown error"),
    INVALID_ARGUMENT    = (code=3,  message="Client specified an invalid argument"),
    DEADLINE_EXCEEDED   = (code=4,  message="Deadline expired before the operation could complete"),
    NOT_FOUND           = (code=5,  message="Requested entity was not found"),
    ALREADY_EXISTS      = (code=6,  message="Entity already exists"),
    PERMISSION_DENIED   = (code=7,  message="No permission to execute the specified operation"),
    RESOURCE_EXHAUSTED  = (code=8,  message="Resource exhausted"),
    FAILED_PRECONDITION = (code=9,  message="Operation was rejected because the system is not in a state required for the operation's execution"),
    ABORTED             = (code=10, message="Operation was aborted"),
    OUT_OF_RANGE        = (code=11, message="Operation was attempted past the valid range"),
    UNIMPLEMENTED       = (code=12, message="Operation is not implemented or is not supported/enabled in this service"),
    INTERNAL            = (code=13, message="Internal error"),
    UNAVAILABLE         = (code=14, message="The service is currently unavailable"),
    DATA_LOSS           = (code=15, message="Unrecoverable data loss or corruption"),
    UNAUTHENTICATED     = (code=16, message="The request does not have valid authentication credentials for the operation")
)

grpc_status_info(code) = StatusCode[code+1]
grpc_status_message(code) = (grpc_status_info(code)).message
grpc_status_code_str(code) = string(propertynames(StatusCode)[code+1])

#=
const SEND_BUFFER_SZ = 1024 * 1024
function buffer_send_data(input::Channel{T}) where T <: ProtoType
    data = nothing
    if isready(input)
        iob = IOBuffer()
        while isready(input) && (iob.size < SEND_BUFFER_SZ)
            write(iob, to_delimited_message_bytes(take!(input)))
            yield()
        end
        data = take!(iob)
    elseif isopen(input)
        data = UInt8[]
    end
    data
end
=#

function send_data(easy::Curl.Easy, input::Channel{T}, max_send_message_length::Int) where T <: ProtoType
    while true
        yield()
        data = isready(input) ? to_delimited_message_bytes(take!(input), max_send_message_length) : isopen(input) ? UInt8[] : nothing
        easy.input === nothing && break
        easy.input = data
        Curl.curl_easy_pause(easy.handle, Curl.CURLPAUSE_CONT)
        wait(easy.ready)
        easy.input === nothing && break
        easy.ready = Threads.Event()
    end
end

function grpc_timeout_header_val(timeout::Real)
    if round(Int, timeout) == timeout
        timeout_secs = round(Int64, timeout)
        return "$(timeout_secs)S"
    end
    timeout *= 1000
    if round(Int, timeout) == timeout
        timeout_millisecs = round(Int64, timeout)
        return "$(timeout_millisecs)m"
    end
    timeout *= 1000
    if round(Int, timeout) == timeout
        timeout_microsecs = round(Int64, timeout)
        return "$(timeout_microsecs)u"
    end
    timeout *= 1000
    timeout_nanosecs = round(Int64, timeout)
    return "$(timeout_nanosecs)n"
end

function grpc_headers(; timeout::Real=Inf)
    headers = C_NULL
    headers = LibCURL.curl_slist_append(headers, "User-Agent: $(Curl.USER_AGENT)")
    headers = LibCURL.curl_slist_append(headers, "Content-Type: application/grpc+proto")
    headers = LibCURL.curl_slist_append(headers, "Content-Length:")
    headers = LibCURL.curl_slist_append(headers, "te: trailers")
    if timeout !== Inf
        headers = LibCURL.curl_slist_append(headers, "grpc-timeout: $(grpc_timeout_header_val(timeout))")
    end
    headers
end

function grpc_request_header(request_timeout::Real)
    if request_timeout == Inf
        GRPC_STATIC_HEADERS[]
    else
        grpc_headers(; timeout=request_timeout)
    end
end

function easy_handle(maxage::Clong, keepalive::Clong, negotiation::Symbol, revocation::Bool, request_timeout::Real)
    easy = Curl.Easy()
    http_version = (negotiation === :http2) ? CURL_HTTP_VERSION_2_0 :
                   (negotiation === :http2_tls) ? CURL_HTTP_VERSION_2TLS :
                   (negotiation === :http2_prior_knowledge) ? CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE :
                   throw(ArgumentError("unsupported HTTP2 negotiation mode $negotiation"))
    Curl.setopt(easy, CURLOPT_HTTP_VERSION, http_version)
    Curl.setopt(easy, CURLOPT_PIPEWAIT, Clong(1))
    Curl.setopt(easy, CURLOPT_POST, Clong(1))
    Curl.setopt(easy, CURLOPT_HTTPHEADER, grpc_request_header(request_timeout))
    if !revocation
        Curl.setopt(easy, CURLOPT_SSL_OPTIONS, CURLSSLOPT_NO_REVOKE)
    end
    if maxage > 0
        Curl.setopt(easy, CURLOPT_MAXAGE_CONN, maxage)
    end
    if keepalive > 0
        Curl.setopt(easy, CURLOPT_TCP_KEEPALIVE, Clong(1))
        Curl.setopt(easy, CURLOPT_TCP_KEEPINTVL, keepalive);
        Curl.setopt(easy, CURLOPT_TCP_KEEPIDLE, keepalive);
    end
    easy
end

function recv_data(easy::Curl.Easy, output::Channel{T}, max_recv_message_length::Int) where T <: ProtoType
    iob = PipeBuffer()
    waiting_for_header = true
    msgsize = 0
    compressed = UInt8(0)
    datalen = UInt32(0)
    need_more = true
    for buf in easy.output
        write(iob, buf)
        need_more = false
        while !need_more
            if waiting_for_header
                if bytesavailable(iob) >= 5
                    compressed = read(iob, UInt8)       # compression
                    datalen = ntoh(read(iob, UInt32))   # message length

                    if datalen > max_recv_message_length
                        throw(gRPCMessageTooLargeException(max_recv_message_length, datalen))
                    end

                    waiting_for_header = false
                else
                    need_more = true
                end
            end

            if !waiting_for_header
                if bytesavailable(iob) >= datalen
                    msgbytes = IOBuffer(view(iob.data, iob.ptr:(iob.ptr+datalen-1)))
                    put!(output, readproto(msgbytes, T()))  # decode message bytes
                    iob.ptr += datalen
                    waiting_for_header = true
                else
                    need_more = true
                end
            end
        end
    end
    close(output)
end

function set_low_speed_limits(easy::Curl.Easy, low_speed_limit, low_speed_time)
    low_speed_limit >= 0 || 
        throw(ArgumentError("`low_speed_limit` must be non-negative, got $(low_speed_limit)."))
    low_speed_time >= 0 || 
        throw(ArgumentError("`low_speed_time` must be non-negative, got $(low_speed_time)."))
    
    _max = typemax(Clong) ÷ 1000
    low_speed_limit = low_speed_limit <= _max ? round(Clong, low_speed_limit) : _max
    low_speed_time = low_speed_time <= _max ? round(Clong, low_speed_time) : _max
    
    Curl.setopt(easy, CURLOPT_LOW_SPEED_LIMIT, low_speed_limit)    
    Curl.setopt(easy, CURLOPT_LOW_SPEED_TIME, low_speed_time)
    return nothing    
end 

function set_connect_timeout(easy::Curl.Easy, timeout::Real)
    timeout >= 0 ||
        throw(ArgumentError("timeout must be positive, got $timeout"))
    if timeout ≤ typemax(Clong) ÷ 1000
        timeout_ms = round(Clong, timeout * 1000)
        Curl.setopt(easy, CURLOPT_CONNECTTIMEOUT_MS, timeout_ms)
    else
        Curl.setopt(easy, CURLOPT_CONNECTTIMEOUT, Clong(0))
    end
end

function grpc_request(downloader::Downloader, url::String, input::Channel{T1}, output::Channel{T2};
        maxage::Clong = typemax(Clong),
        keepalive::Clong = 60,
        negotiation::Symbol = :http2_prior_knowledge,
        revocation::Bool = true,
        request_timeout::Real = Inf,
        connect_timeout::Real = 0,
        max_recv_message_length::Int = DEFAULT_MAX_RECV_MESSAGE_LENGTH,
        max_send_message_length::Int = DEFAULT_MAX_SEND_MESSAGE_LENGTH,
        verbose::Bool = false,
        low_speed_limit::Int = 0,
        low_speed_time::Int = 0)::gRPCStatus where {T1 <: ProtoType, T2 <: ProtoType}
    Curl.with_handle(easy_handle(maxage, keepalive, negotiation, revocation, request_timeout)) do easy
        # setup the request
        Curl.set_url(easy, url)
        Curl.set_timeout(easy, request_timeout)
        set_connect_timeout(easy, connect_timeout)
        set_low_speed_limits(easy, low_speed_limit, low_speed_time)
        Curl.set_verbose(easy, verbose)
        Curl.add_upload_callbacks(easy)
        Downloads.set_ca_roots(downloader, easy)

        # do the request
        Curl.add_handle(downloader.multi, easy)

        function cleanup()
            Curl.remove_handle(downloader.multi, easy)
            # though remove_handle sets easy.handle to C_NULL, it does not close output and progress channels
            # we need to close them here to unblock anything waiting on them
            close(easy.output)
            close(easy.progress)
            close(output)
            close(input)
            nothing
        end

        # do send recv data
        if VERSION < v"1.5"
            cleaned_up = false
            exception = nothing
            cleanup_once = (ex)->begin
                if !cleaned_up
                    cleaned_up = true
                    exception = ex
                    cleanup()
                end
            end

            @sync begin
                @async try
                    recv_data(easy, output, max_recv_message_length)
                catch ex
                    cleanup_once(ex)
                end
                @async try
                    send_data(easy, input, max_send_message_length)
                catch ex
                    cleanup_once(ex)
                end
            end

            if exception !== nothing
                throw(exception)
            end
        else
            try
                Base.Experimental.@sync begin
                    @async recv_data(easy, output, max_recv_message_length)
                    @async send_data(easy, input, max_send_message_length)
                end
            finally # ensure handle is removed
                cleanup()
            end
        end

        @debug("response headers", easy.res_hdrs)

        # parse the grpc headers
        grpc_status = StatusCode.OK.code
        grpc_message = ""
        for hdr in easy.res_hdrs
            if startswith(hdr, "grpc-status")
                grpc_status = parse(Int, strip(last(split(hdr, ':'; limit=2))))
            elseif startswith(hdr, "grpc-message")
                grpc_message = string(strip(last(split(hdr, ':'; limit=2))))
            end
        end
        if (easy.code == CURLE_OPERATION_TIMEDOUT) && (grpc_status == StatusCode.OK.code)
            grpc_status = StatusCode.DEADLINE_EXCEEDED.code
        end
        if (grpc_status != StatusCode.OK.code) && isempty(grpc_message)
            grpc_message = grpc_status_message(grpc_status)
        end

        if ((easy.code == CURLE_OK) && (grpc_status == StatusCode.OK.code))
            gRPCStatus(true, grpc_status, "")
        else
            gRPCStatus(false, grpc_status, isempty(grpc_message) ? Curl.get_curl_errstr(easy) : grpc_message)
        end
    end
end
