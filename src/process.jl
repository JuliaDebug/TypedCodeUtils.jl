canreflect(::CallInfo) = false
isambiguous(::CallInfo) = false
reflect(::CallInfo; optimize=true, params=current_params()) = nothing

# Call could be resolved to a singular MI
struct MICallInfo <: CallInfo
    mi::MethodInstance
    rt
end
canreflect(::MICallInfo) = true
reflect(mi::MICallInfo; optimize=true, params=current_params()) =
    reflect(mi.mi, optimize=optimize, params=params)

struct BuiltinCallInfo <: CallInfo
    types
    rt
end

struct MultiCallInfo <: CallInfo
    sig
    rt
    callinfos::Vector{CallInfo}
end
isambiguous(::MultiCallInfo) = true
Base.collect(mci::MultiCallInfo) = mci.callinfos

struct GeneratedCallInfo <: CallInfo
    sig
    rt
end

struct FailedCallInfo <: CallInfo
    sig
    rt
end

function process_invoke(::Consumer, ref::Reflection, id, c)
    @assert c.head === :invoke
    rt = ref.CI.ssavaluetypes[id]
    return Callsite(id, MICallInfo(c.args[1], rt))
end

function process_call(::Consumer, ref::Reflection, id, c)
    @assert c.head === :call

    rt = ref.CI.ssavaluetypes[id]
    sig = map(arg -> widenconst(argextype(arg, ref.CI, ref.sptypes, ref.slottypes)), c.args)

    # Look through _apply
    ok = true
    while sig[1] === typeof(Core._apply)
        new_sig = Any[types[2]]
        for t in sig[3:end]
            if !(t <: Tuple) || t isa Union
                ok = false
                break
            end
            append!(new_sig, t.parameters)
        end
        ok || break
        sig = new_sig
    end
    if !ok
        # when does this happen?
        @error "Failed to look through _apply" id c ref
        return nothing
    end
                
    # Filter out builtin functions and intrinsic function
    if sig[1] <: Core.Builtin || sig[1] <: Core.IntrinsicFunction
        return id, BuiltinCallInfo(sig, rt)
    end
    return id, callinfo(sig, rt, ref)
end

function callinfo(sig, rt, ref)
    methds = Base._methods_by_ftype(sig, -1, ref.world)
    (methds === false || length(methds) < 1) && return FailedCallInfo(sig, rt)
    callinfos = CallInfo[]
    for x in methds
        atypes = x[1]
        sparams = x[2]
        meth = x[3]
        if isdefined(meth, :generator) && !Base.may_invoke_generator(meth, atypes, sparams)
            push!(callinfos, GeneratedCallInfo(sig, rt))
        else
            mi = code_for_method(meth, atypes, sparams, ref.world)
            if mi === nothing
                push!(callinfos, FailedCallInfo(sig, rt)) 
            end
            push!(callinfos, MICallInfo(mi, rt)) 
        end
    end
    
    @assert length(callinfos) != 0
    length(callinfos) == 1 && return first(callinfos)
    return MultiCallInfo(sig, rt, callinfos)
end

