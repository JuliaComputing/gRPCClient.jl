# gRPCClient.jl

A Julia gRPC Client.

### Generating gRPC Service Client

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

julia> Base.show(io::IO, location::RouteGuideClients.Point) = print(io, string("[", location.latitude, ", ", location.longitude, "]"))

julia> Base.show(io::IO, feature::RouteGuideClients.Feature) = print(io, string(feature.name, " - ", feature.location))

julia> client = RouteGuideBlockingClient("https://server:10000/");

julia> point = RouteGuideClients.Point(; latitude=409146138, longitude=-746188906); # API request parameter

julia> feature, status_future = RouteGuideClients.GetFeature(client, point);

julia> gRPCCheck(status_future) # check status of request
true

julia> feature # this is the API return value
Berkshire Valley Management Area Trail, Jefferson, NJ, USA - [409146138, -746188906]
```
