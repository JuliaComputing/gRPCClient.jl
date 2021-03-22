const GRPC_STATIC_HEADERS = Ref{Ptr{Nothing}}(C_NULL)

function send_data(easy::Curl.Easy, input::Channel{T}) where T <: ProtoType
    while true
        data = isready(input) ? to_delimited_message_bytes(take!(input)) : isopen(input) ? UInt8[] : nothing
        easy.input === nothing && break
        easy.input = data
        Curl.curl_easy_pause(easy.handle, Curl.CURLPAUSE_CONT)
        wait(easy.ready)
        easy.input === nothing && break
        easy.ready = Threads.Event()
    end
end

function grpc_headers()
    headers = C_NULL
    headers = LibCURL.curl_slist_append(headers, "User-Agent: $(Curl.USER_AGENT)")
    headers = LibCURL.curl_slist_append(headers, "Content-Type: application/grpc+proto")
    headers = LibCURL.curl_slist_append(headers, "Content-Length:")
    headers
end

function easy_handle(maxage, keepalive, verify_peer)
    easy = Curl.Easy()
    Curl.setopt(easy, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0)
    Curl.setopt(easy, CURLOPT_PIPEWAIT, Clong(1))
    Curl.setopt(easy, CURLOPT_POST, Clong(1))
    Curl.setopt(easy, CURLOPT_HTTPHEADER, GRPC_STATIC_HEADERS[])
    Curl.set_ssl_verify(easy, verify_peer)
    if maxage > 0
        Curl.setopt(easy, CURLOPT_MAXAGE_CONN, Clong(maxage))
    end
    if keepalive > 0
        Curl.setopt(easy, CURLOPT_TCP_KEEPALIVE, Clong(1))
        Curl.setopt(easy, CURLOPT_TCP_KEEPINTVL, Clong(keepalive));
        Curl.setopt(easy, CURLOPT_TCP_KEEPIDLE, Clong(keepalive));
    end
    easy
end

function recv_data(easy::Curl.Easy, output::Channel{T}) where T <: ProtoType
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

function set_connect_timeout(easy::Curl.Easy, timeout::Real)
    timeout >= 0 ||
        throw(ArgumentError("timeout must be positive, got $timeout"))
    if timeout ≤ typemax(Clong) ÷ 1000
        timeout_ms = round(Clong, timeout * 1000)
        Curl.setopt(easy, CURLOPT_CONNECTTIMEOUT_MS, timeout_ms)
    else
        timeout = timeout ≤ typemax(Clong) ? round(Clong, timeout) : Clong(0)
        Curl.setopt(easy, CURLOPT_CONNECTTIMEOUT, timeout)
    end
end

function grpc_request(downloader::Downloader, url::String, input::Channel{T1}, output::Channel{T2};
        maxage::Int64 = typemax(Int64),
        keepalive::Int64 = 60,
        request_timeout::Real = Inf,
        connect_timeout::Real = 0,
        verify_peer::Bool = true,
        verbose::Bool = false)::gRPCStatus where {T1 <: ProtoType, T2 <: ProtoType}
    Curl.with_handle(easy_handle(maxage, keepalive, verify_peer)) do easy
        # setup the request
        Curl.set_url(easy, url)
        Curl.set_timeout(easy, request_timeout)
        set_connect_timeout(easy, connect_timeout)
        Curl.set_verbose(easy, verbose)
        Curl.add_upload_callbacks(easy)
        Downloads.set_ca_roots(downloader, easy)

        # do the request
        Curl.add_handle(downloader.multi, easy)

        try
            # do send recv data
            Base.Experimental.@sync begin
                @async recv_data(easy, output)
                @async send_data(easy, input)
            end
        finally # ensure handle is removed
            Curl.remove_handle(downloader.multi, easy)
        end

        (easy.code == CURLE_OK) ? gRPCStatus(true, "") : gRPCStatus(false, Curl.get_curl_errstr(easy))
    end
end