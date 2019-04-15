module TypedCodeUtils

using Base.Meta
import Core: Compiler
using .Compiler: widenconst, argextype

"""
    Consumer

Downstream packages can change the the behaviour of `process_call` and `process_invoke`,
by overloading them for a different `Consumer`.

"""
abstract type Consumer end
struct DefaultConsumer <: Consumer end

##
# Reflection
##

"""
    Reflection

# Fields:
  - `CI`: CodeInfo
  - `mi`: MethodInfo
  - `slottypes`:
  - `sptypes`:
  - `world`:
"""
struct Reflection
    CI
    mi
    slottypes
    sptypes
    world
end

include("reflection.jl")

##
# Callsite processing
##
abstract type CallInfo end

struct Callsite
    id
    callinfo::CallInfo
end

canreflect(c::Callsite) = canreflect(c.callinfo)
reflect(c::Callsite; optimize=true, params=current_params()) = reflect(c.callinfo, optimize=optimize, params=params)

include("process.jl")

##
# Utils
##

filter(f, code) = ((id, c) for (id, c) in enumerate(code) if f(c))

"""
    lookthrough(f, c)

Checks if `c isa Expr` and inspects the right hand side of assignments.
"""
function lookthrough(f, c)
    if c isa Expr
        # look through assignment
        if identify_assignment(c)
            return lookthrough(f, c.args[2])
        end
        return f(c)
    end
    return false
end

##
# Identify
##

identify_assignment(c::Expr) = c.head === :(=)
identify_invoke(c::Expr) = c.head === :invoke
identify_call(c::Expr) = c.head === :call
identify_foreigncall(c::Expr) = c.head === :foreigncall

end # module
