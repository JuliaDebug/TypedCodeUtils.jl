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
    callsites = Callsite[]

    invokes      = filter((c)->lookthrough(identify_invoke,      c), ref.CI.code)
    calls        = filter((c)->lookthrough(identify_call,        c), ref.CI.code)

    invokes = map((arg) -> process_invoke(DefaultConsumer(), ref, arg...), invokes)
    append!(callsites, invokes)
    calls = map((arg) -> process_call(DefaultConsumer(), ref, arg...), calls)
    append!(callsites, calls)

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

