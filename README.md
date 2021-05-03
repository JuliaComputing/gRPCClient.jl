# gRPCClient.jl

A Julia gRPC Client.

[![Build Status](https://github.com/JuliaComputing/gRPCClient.jl/workflows/CI/badge.svg)](https://github.com/JuliaComputing/gRPCClient.jl/actions?query=workflow%3ACI+branch%3Amain)
[![codecov.io](http://codecov.io/github/JuliaComputing/gRPCClient.jl/coverage.svg?branch=main)](http://codecov.io/github/JuliaComputing/gRPCClient.jl?branch=main)


## Generating gRPC Service Client

gRPC services are declared in `.proto` files. Use `gRPCClient.generate` to generate client code from specification files.

gRPC code generation uses `protoc` and the `ProtoBuf.jl` package. To be able to generate gRPC client code, `ProtoBuf` package must be installed along with `gRPCClient`.

The `protoc` file must have service generation turned on for at least one of C++, python or Java, e.g. one of:

```
option cc_generic_services = true;
option py_generic_services = true;
option java_generic_services = true;
```

The Julia code generated can be improper if the `package` name declared in the proto specification has `.`. Set a suitable `package` name without `.`.

```julia
julia> using Pkg

julia> Pkg.add("ProtoBuf")
...
  Installed ProtoBuf ──── v0.11.0
Downloading artifact: protoc
...
julia> Pkg.add("gRPCClient")
...
julia> # or Pkg.develop(PackageSpec(url="https://github.com/JuliaComputing/gRPCClient.jl"))

julia> using gRPCClient

julia> gRPCClient.generate("route_guide.proto")
┌ Info: Generating gRPC client
│   proto = "RouteguideClients/route_guide.proto"
└   outdir = "RouteguideClients"
┌ Info: Detected
│   package = "routeguide"
└   service = "RouteGuide"
┌ Info: Generated
└   outdir = "RouteguideClients"
```

The generated code can either be published as a package or included and used as a module.

```julia
julia> using gRPCClient

julia> include("RouteguideClients/RouteguideClients.jl");

julia> using .RouteguideClients

julia> import .RouteguideClients: Point, Feature, GetFeature

julia> Base.show(io::IO, location::Point) =
    print(io, string("[", location.latitude, ", ", location.longitude, "]"))

julia> Base.show(io::IO, feature::Feature) =
    print(io, string(feature.name, " - ", feature.location))

julia> client = RouteGuideBlockingClient("https://server:10000/");

julia> point = Point(; latitude=409146138, longitude=-746188906); # request param

julia> feature, status_future = GetFeature(client, point);

julia> gRPCCheck(status_future) # check status of request
true

julia> feature # this is the API return value
Berkshire Valley Management Area Trail, Jefferson, NJ, USA - [409146138, -746188906]
```

The generated module is named after the package declared in the proto file.
And for each service, a pair of clients are generated in the form of
`<service_name>Client` and `<service_name>BlockingClient`.

The service methods generated for `<service_name>Client` are identical to the
ones generated for `<service_name>BlockingClient`, except that they spawn off
the actual call into a task and accept a callback method that is invoked with
the results. The `<service_name>BlockingClient` may however be more intuitive
to use.

Each service method returns (or calls back with, in the case of non-blocking
clients) two values:
- The result, which can be a Julia struct or a `Channel` for streaming output.
- And, the gRPC status.

The `gRPCCheck` method checks the status for success or failure. Note that for
methods with streams as input or output, the gRPC status will not be ready
until the method completes. So the status check and stream use must be done
in separate tasks. E.g.:

```julia
@sync begin
   in_channel = Channel{RouteguideClients.RouteNote}(1)
   @async begin
      # send inputs
      for input in inputs
         put!(in_channel, input)
      end
      close(in_channel)
   end
   out_channel, status_future = RouteguideClients.RouteChat(client, in_channel)
   @async begin
      # consume outputs
      for output in out_channel
         # use output
      end
   end
   @async begin
      gRPCCheck(status_future)
   end
end
```

## APIs and Implementation Details

The generated gRPC client (`RouteGuideBlockingClient` in the example above)
uses a gRPC controller and channel behind the scenes to communicate with
the server.

### `gRPCController`

A `gRPCController` contains settings to control the behavior of gRPC requests.
Each gRPC client holds an instance of the controller created using keyword
arguments passed to its constructor.

```julia
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
```

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
- `verbose`: whether to print out verbose communication logs (default false)

### `gRPCChannel`

```julia
gRPCChannel(baseurl::String)
```

`gRPCChannel` represents a connection to a specific service endpoint
(service `baseurl`) of a gRPC server.

A channel also usually has a single network connection backing it and
multiple streams of requests can flow through it at any time. The number
of streams that can be multiplexed is negotiated between the client and
the server.

### `gRPCStatus`

`gRPCStatus` represents the status of a request. It has the following fields:

- `success`: whether the request was completed successfully.
- `grpc_status`: the grpc status code returned
- `message`: any error message if request was not successful

### `gRPCCheck`

```julia
gRPCCheck(status; throw_error::Bool=true)
```

Method to check the response of a gRPC request and raise a `gRPCException`
if it has failed. If `throw_error` is set to false, returns `true` or `false`
indicating success instead.

### `gRPCException`

Every gRPC request returns the result and a future representing the status
of the gRPC request. Use the `gRPCCheck` method on the status future to check
the request status and throw a `gRPCException` if it is not successful.

The abstract `gRPCException` type has the following concrete implementations:

- `gRPCMessageTooLargeException`
- `gRPCServiceCallException`

### `gRPCMessageTooLargeException`

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

### `gRPCServiceCallException`

A `gRPCServiceCallException` is thrown if a gRPC request is not successful.
It has the following members:

- `grpc_status`: grpc status code for this request
- `message`: any error message if request was not successful

## Credits

This package was originally developed at [Julia Computing](https://juliacomputing.com)
