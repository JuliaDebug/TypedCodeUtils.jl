if VERSION >= v"1.1.0-DEV.215"
function dce!(ci, mi)
    argtypes = Core.Compiler.matching_cache_argtypes(mi, nothing)[1]
    ir = Compiler.inflate_ir(ci, sptypes_from_meth_instance(mi),
                             argtypes)
    compact = Core.Compiler.IncrementalCompact(ir, true)
    # Just run through the iterator without any processing
    Core.Compiler.foreach(x -> nothing, compact)
    ir = Core.Compiler.finish(compact)
    
    Core.Compiler.replace_code_newstyle!(ci, ir, length(argtypes)-1)
end
else
function dce!(ci, mi)
end
end

function preprocess!(::Consumer, ref::Reflection, optimize)
    if optimize
        # if the optimizer hasn't run, the IR hasn't been converted
        # to SSA form yet and dce is not legal
        dce!(ref.CI, ref.mi)
    end
end
