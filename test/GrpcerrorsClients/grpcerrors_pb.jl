# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct Data <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Data(; kwargs...)
        obj = new(meta(Data), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct Data
const __meta_Data = Ref{ProtoMeta}()
function meta(::Type{Data})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Data)
            __meta_Data[] = target = ProtoMeta(Data)
            allflds = Pair{Symbol,Union{Type,String}}[:mode => Int32, :param => Int32]
            meta(target, Data, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Data[]
    end
end
function Base.getproperty(obj::Data, name::Symbol)
    if name === :mode
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :param
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

# service methods for GRPCErrors
const _GRPCErrors_methods = MethodDescriptor[
        MethodDescriptor("SimpleRPC", 1, Data, Data),
        MethodDescriptor("StreamResponse", 2, Data, Channel{Data}),
        MethodDescriptor("StreamRequest", 3, Channel{Data}, Data),
        MethodDescriptor("StreamRequestResponse", 4, Channel{Data}, Channel{Data})
    ] # const _GRPCErrors_methods
const _GRPCErrors_desc = ServiceDescriptor("grpcerrors.GRPCErrors", 1, _GRPCErrors_methods)

GRPCErrors(impl::Module) = ProtoService(_GRPCErrors_desc, impl)

mutable struct GRPCErrorsStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    GRPCErrorsStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_GRPCErrors_desc, channel))
end # mutable struct GRPCErrorsStub

mutable struct GRPCErrorsBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    GRPCErrorsBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_GRPCErrors_desc, channel))
end # mutable struct GRPCErrorsBlockingStub

SimpleRPC(stub::GRPCErrorsStub, controller::ProtoRpcController, inp::Data, done::Function) = call_method(stub.impl, _GRPCErrors_methods[1], controller, inp, done)
SimpleRPC(stub::GRPCErrorsBlockingStub, controller::ProtoRpcController, inp::Data) = call_method(stub.impl, _GRPCErrors_methods[1], controller, inp)

StreamResponse(stub::GRPCErrorsStub, controller::ProtoRpcController, inp::Data, done::Function) = call_method(stub.impl, _GRPCErrors_methods[2], controller, inp, done)
StreamResponse(stub::GRPCErrorsBlockingStub, controller::ProtoRpcController, inp::Data) = call_method(stub.impl, _GRPCErrors_methods[2], controller, inp)

StreamRequest(stub::GRPCErrorsStub, controller::ProtoRpcController, inp::Channel{Data}, done::Function) = call_method(stub.impl, _GRPCErrors_methods[3], controller, inp, done)
StreamRequest(stub::GRPCErrorsBlockingStub, controller::ProtoRpcController, inp::Channel{Data}) = call_method(stub.impl, _GRPCErrors_methods[3], controller, inp)

StreamRequestResponse(stub::GRPCErrorsStub, controller::ProtoRpcController, inp::Channel{Data}, done::Function) = call_method(stub.impl, _GRPCErrors_methods[4], controller, inp, done)
StreamRequestResponse(stub::GRPCErrorsBlockingStub, controller::ProtoRpcController, inp::Channel{Data}) = call_method(stub.impl, _GRPCErrors_methods[4], controller, inp)

export Data, GRPCErrors, GRPCErrorsStub, GRPCErrorsBlockingStub, SimpleRPC, StreamResponse, StreamRequest, StreamRequestResponse
