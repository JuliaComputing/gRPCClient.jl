# gRPCClient.jl

A Julia gRPC Client.

GitHub Actions : [![Build Status](https://github.com/JuliaComputing/gRPCClient.jl/workflows/CI/badge.svg)](https://github.com/JuliaComputing/gRPCClient.jl/actions?query=workflow%3ACI+branch%3Amaster)

[![Coverage Status](https://coveralls.io/repos/JuliaComputing/gRPCClient.jl/badge.svg?branch=master)](https://coveralls.io/r/JuliaComputing/gRPCClient.jl?branch=master)
[![codecov.io](http://codecov.io/github/JuliaComputing/gRPCClient.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaComputing/gRPCClient.jl?branch=master)


## Generating gRPC Service Client

gRPC services are declared in `.proto` files. Use `gRPCClient.generate` to generate client code from specification files.

```julia
julia> using gRPCClient

julia> gRPCClient.generate("route_guide.proto")
┌ Info: Generating gRPC client
│   proto = "RouteGuideClients/route_guide.proto"
└   outdir = "RouteGuideClients"
┌ Info: Detected
│   package = "routeguide"
└   service = "RouteGuide"
┌ Info: Generated
└   outdir = "RouteGuideClients"
```

The generated code can either be published as a package or included and used as a module.

```julia
julia> using gRPCClient

julia> include("RouteGuideClients/RouteGuideClients.jl");

julia> using .RouteGuideClients

julia> import .RouteGuideClients: Point, Feature, GetFeature

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

## Internals

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
    [ request_timeout::Real = Inf, ]
    [ connect_timeout::Real = 0, ]
    [ verbose::Bool = false, ]
)
```

- `maxage`: maximum age (seconds) of a connection beyond which it will not
   be reused (default 180 seconds, same as setting this to 0).
- `keepalive`: interval (seconds) in which to send TCP keepalive messages on
   the connection (default 60 seconds).
- `request_timeout`: request timeout (seconds)
- `connect_timeout`: connect timeout (seconds) (default is 300 seconds, same
   as setting this to 0)
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
- `message`: any error message if request was not successful

### `gRPCException`

Every gRPC request returns the result and a future representing the status
of the gRPC request. Use the `gRPCCheck` method on the status future to check
the request status and throw a `gRPCException` if it is not successful.

A `gRPCException` has a member named `message` that may contain an error
message if request was not successful.

### `gRPCCheck`

```julia
gRPCCheck(status; throw_error::Bool=true)
```

Method to check the response of a gRPC request and raise a `gRPCException`
if it has failed. If `throw_error` is set to false, returns `true` or `false`
indicating success instead.
