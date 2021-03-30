# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct Point <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Point(; kwargs...)
        obj = new(meta(Point), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct Point
const __meta_Point = Ref{ProtoMeta}()
function meta(::Type{Point})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Point)
            __meta_Point[] = target = ProtoMeta(Point)
            allflds = Pair{Symbol,Union{Type,String}}[:latitude => Int32, :longitude => Int32]
            meta(target, Point, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Point[]
    end
end
function Base.getproperty(obj::Point, name::Symbol)
    if name === :latitude
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :longitude
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

mutable struct Rectangle <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Rectangle(; kwargs...)
        obj = new(meta(Rectangle), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct Rectangle
const __meta_Rectangle = Ref{ProtoMeta}()
function meta(::Type{Rectangle})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Rectangle)
            __meta_Rectangle[] = target = ProtoMeta(Rectangle)
            allflds = Pair{Symbol,Union{Type,String}}[:lo => Point, :hi => Point]
            meta(target, Rectangle, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Rectangle[]
    end
end
function Base.getproperty(obj::Rectangle, name::Symbol)
    if name === :lo
        return (obj.__protobuf_jl_internal_values[name])::Point
    elseif name === :hi
        return (obj.__protobuf_jl_internal_values[name])::Point
    else
        getfield(obj, name)
    end
end

mutable struct Feature <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Feature(; kwargs...)
        obj = new(meta(Feature), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct Feature
const __meta_Feature = Ref{ProtoMeta}()
function meta(::Type{Feature})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Feature)
            __meta_Feature[] = target = ProtoMeta(Feature)
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :location => Point]
            meta(target, Feature, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Feature[]
    end
end
function Base.getproperty(obj::Feature, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :location
        return (obj.__protobuf_jl_internal_values[name])::Point
    else
        getfield(obj, name)
    end
end

mutable struct RouteNote <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function RouteNote(; kwargs...)
        obj = new(meta(RouteNote), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct RouteNote
const __meta_RouteNote = Ref{ProtoMeta}()
function meta(::Type{RouteNote})
    ProtoBuf.metalock() do
        if !isassigned(__meta_RouteNote)
            __meta_RouteNote[] = target = ProtoMeta(RouteNote)
            allflds = Pair{Symbol,Union{Type,String}}[:location => Point, :message => AbstractString]
            meta(target, RouteNote, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_RouteNote[]
    end
end
function Base.getproperty(obj::RouteNote, name::Symbol)
    if name === :location
        return (obj.__protobuf_jl_internal_values[name])::Point
    elseif name === :message
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct RouteSummary <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function RouteSummary(; kwargs...)
        obj = new(meta(RouteSummary), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct RouteSummary
const __meta_RouteSummary = Ref{ProtoMeta}()
function meta(::Type{RouteSummary})
    ProtoBuf.metalock() do
        if !isassigned(__meta_RouteSummary)
            __meta_RouteSummary[] = target = ProtoMeta(RouteSummary)
            allflds = Pair{Symbol,Union{Type,String}}[:point_count => Int32, :feature_count => Int32, :distance => Int32, :elapsed_time => Int32]
            meta(target, RouteSummary, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_RouteSummary[]
    end
end
function Base.getproperty(obj::RouteSummary, name::Symbol)
    if name === :point_count
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :feature_count
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :distance
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :elapsed_time
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

# service methods for RouteGuide
const _RouteGuide_methods = MethodDescriptor[
        MethodDescriptor("GetFeature", 1, routeguide.Point, routeguide.Feature),
        MethodDescriptor("ListFeatures", 2, routeguide.Rectangle, Channel{routeguide.Feature}),
        MethodDescriptor("RecordRoute", 3, Channel{routeguide.Point}, routeguide.RouteSummary),
        MethodDescriptor("RouteChat", 4, Channel{routeguide.RouteNote}, Channel{routeguide.RouteNote})
    ] # const _RouteGuide_methods
const _RouteGuide_desc = ServiceDescriptor("routeguide.RouteGuide", 1, _RouteGuide_methods)

RouteGuide(impl::Module) = ProtoService(_RouteGuide_desc, impl)

mutable struct RouteGuideStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    RouteGuideStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_RouteGuide_desc, channel))
end # mutable struct RouteGuideStub

mutable struct RouteGuideBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    RouteGuideBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_RouteGuide_desc, channel))
end # mutable struct RouteGuideBlockingStub

GetFeature(stub::RouteGuideStub, controller::ProtoRpcController, inp::routeguide.Point, done::Function) = call_method(stub.impl, _RouteGuide_methods[1], controller, inp, done)
GetFeature(stub::RouteGuideBlockingStub, controller::ProtoRpcController, inp::routeguide.Point) = call_method(stub.impl, _RouteGuide_methods[1], controller, inp)

ListFeatures(stub::RouteGuideStub, controller::ProtoRpcController, inp::routeguide.Rectangle, done::Function) = call_method(stub.impl, _RouteGuide_methods[2], controller, inp, done)
ListFeatures(stub::RouteGuideBlockingStub, controller::ProtoRpcController, inp::routeguide.Rectangle) = call_method(stub.impl, _RouteGuide_methods[2], controller, inp)

RecordRoute(stub::RouteGuideStub, controller::ProtoRpcController, inp::Channel{routeguide.Point}, done::Function) = call_method(stub.impl, _RouteGuide_methods[3], controller, inp, done)
RecordRoute(stub::RouteGuideBlockingStub, controller::ProtoRpcController, inp::Channel{routeguide.Point}) = call_method(stub.impl, _RouteGuide_methods[3], controller, inp)

RouteChat(stub::RouteGuideStub, controller::ProtoRpcController, inp::Channel{routeguide.RouteNote}, done::Function) = call_method(stub.impl, _RouteGuide_methods[4], controller, inp, done)
RouteChat(stub::RouteGuideBlockingStub, controller::ProtoRpcController, inp::Channel{routeguide.RouteNote}) = call_method(stub.impl, _RouteGuide_methods[4], controller, inp)

export Point, Rectangle, Feature, RouteNote, RouteSummary, RouteGuide, RouteGuideStub, RouteGuideBlockingStub, GetFeature, ListFeatures, RecordRoute, RouteChat
