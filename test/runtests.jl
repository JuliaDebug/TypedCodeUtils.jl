using TypedCodeUtils
using Test

import TypedCodeUtils: reflect, filter, lookthrough,
                       DefaultConsumer, Reflection, Callsite,
                       identify_invoke, identify_call,
                       process_invoke, process_call

# Test simple reflection
f(x, y) = x + y

@test reflect(f, Tuple{Int, Int}) !== nothing
@test reflect(f, Tuple{Int, Number}) !== nothing # this probably doesn't do the right thing
                                                 # it will give us **a** method instance. 
@generated g(x, y) = :(x + y)
@test reflect(g, Tuple{Int, Int}) !== nothing
@test reflect(g, Tuple{Int, Number}) === nothing

# Cthulhu's inner loop
function cthulhu(ref::Reflection)

    invokes = filter((c)->lookthrough(identify_invoke,      c), ref.CI.code)
    calls   = filter((c)->lookthrough(identify_call,        c), ref.CI.code)

    invokes = map((arg) -> process_invoke(DefaultConsumer(), ref, arg...), invokes)
    calls   = map((arg) -> process_call(  DefaultConsumer(), ref, arg...), calls)
    
    callsites = append!(invokes, calls)
    @show callsites
    sort!(callsites, by=(c)->c.id)
    return callsites
end

params = TypedCodeUtils.current_params()
ref = reflect(f, Tuple{Int, Int}, params=params)
calls = cthulhu(ref)
nextrefs = collect(reflect(c) for c in calls if TypedCodeUtils.canreflect(c))

function h(x)
    if x >= 2
        return x ^ 2
    else
        return x + 2
    end
end

params = TypedCodeUtils.current_params()
ref = reflect(h, Tuple{Int}, params=params)
calls = cthulhu(ref)
nextrefs = collect(reflect(c) for c in calls if TypedCodeUtils.canreflect(c))

if VERSION >= v"1.1.0-DEV.215" && Base.JLOptions().check_bounds == 0 
Base.@propagate_inbounds function f(x)
    @boundscheck error()
end
g(x) = @inbounds f(x)

params = TypedCodeUtils.current_params()
ref = reflect(g, Tuple{Vector{Float64}}, params=params)
@show ref.CI.code
calls = cthulhu(ref)
@test !isempty(calls)

TypedCodeUtils.preprocess!(DefaultConsumer(), ref, true)
calls = cthulhu(ref)
@test isempty(calls)

end




