###
# Reflection tooling
##

if VERSION >= v"1.2.0-DEV.249"
    sptypes_from_meth_instance(mi) = Core.Compiler.sptypes_from_meth_instance(mi)
else
    sptypes_from_meth_instance(mi) = Core.Compiler.spvals_from_meth_instance(mi)
end

if VERSION < v"1.2.0-DEV.573"
    code_for_method(method, metharg, methsp, world, force=false) = Core.Compiler.code_for_method(method, metharg, methsp, world, force)
else
    code_for_method(method, metharg, methsp, world, force=false) = Core.Compiler.specialize_method(method, metharg, methsp, force)
end

function do_typeinf_slottypes(mi::Core.Compiler.MethodInstance, run_optimizer::Bool, params::Core.Compiler.Params)
    ccall(:jl_typeinf_begin, Cvoid, ())
    result = Core.Compiler.InferenceResult(mi)
    frame = Core.Compiler.InferenceState(result, false, params)
    frame === nothing && return (nothing, Any)
    if Compiler.typeinf(frame) && run_optimizer
        opt = Compiler.OptimizationState(frame)
        Compiler.optimize(opt, result.result)
        opt.src.inferred = true
    end
    ccall(:jl_typeinf_end, Cvoid, ())
    frame.inferred || return (nothing, Any)
    return (frame.src, result.result, frame.slottypes)
end

if :trace_inference_limits in fieldnames(Core.Compiler.Params)
    current_params() = Core.Compiler.CustomParams(ccall(:jl_get_world_counter, UInt, ()); trace_inference_limits=true)
else
    current_params() = Core.Compiler.Params(ccall(:jl_get_world_counter, UInt, ()))
end

function reflect(F, TT; optimize=true, params=current_params())
    sig = Tuple{typeof(F), TT.parameters...}
    reflect(sig; optimize=true, params=params)
end

function reflect(sig; optimize=true, params=current_params())
    methds = Base._methods_by_ftype(sig, 1, params.world)
    (methds === false || length(methds) < 1) && return nothing
    x = methds[1]
    meth = x[3]
    if isdefined(meth, :generator) && !isdispatchtuple(Tuple{sig.parameters[2:end]...})
        return nothing
    end
    mi = code_for_method(meth, sig, x[2], params.world)
    reflect(mi, optimize=optimize, params=params)
end

function reflect(mi::Core.Compiler.MethodInstance; optimize=true, params=current_params())
    sptypes = sptypes_from_meth_instance(mi)
    (CI, rt, slottypes) = do_typeinf_slottypes(mi, optimize, params)

    ref = Reflection(CI, mi, slottypes, sptypes, params.world)
end
     

