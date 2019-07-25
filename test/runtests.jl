using TypedCodeUtils
using Test

import TypedCodeUtils: reflect, filter, lookthrough,
                       DefaultConsumer, Reflection,
                       identify_invoke, identify_call,
                       process_invoke, process_call

# Test simple reflection
f(x, y) = x + y

@test !isempty(reflect(f, Tuple{Int, Int}))
@test !isempty(reflect(f, Tuple{Int, Number}))
@generated g(x, y) = :(x + y)
@test !isempty(reflect(g, Tuple{Int, Int}))
if VERSION >= v"1.2.0-rc1"
    @test !isempty(reflect(g, Tuple{Int, Number}))
else
    @test isempty(reflect(g, Tuple{Int, Number}))
end

# Cthulhu's inner loop
function cthulhu(ref::Reflection)

    invokes = filter((c)->lookthrough(identify_invoke,      c), ref.CI.code)
    calls   = filter((c)->lookthrough(identify_call,        c), ref.CI.code)

    invokes = map((arg) -> process_invoke(DefaultConsumer(), ref, arg...), invokes)
    calls   = map((arg) -> process_call(  DefaultConsumer(), ref, arg...), calls)

    callsites = append!(invokes, calls)
    sort!(callsites, by=(c)->first(c))
    return callsites
end

params = TypedCodeUtils.current_params()
ref = reflect(f, Tuple{Int, Int}, params=params)
@test length(ref) == 1
calls = cthulhu(first(ref))
nextrefs = collect(first(reflect(c)) for c in calls if TypedCodeUtils.canreflect(c[2]))

function h(x)
    if x >= 2
        return x ^ 2
    else
        return x + 2
    end
end

params = TypedCodeUtils.current_params()
ref = reflect(h, Tuple{Int}, params=params)
@test length(ref) == 1
calls = cthulhu(first(ref))
nextrefs = collect(first(reflect(c)) for c in calls if TypedCodeUtils.canreflect(c[2]))

if VERSION >= v"1.1.0-DEV.215" && Base.JLOptions().check_bounds == 0 
Base.@propagate_inbounds function f(x)
    @boundscheck error()
end
g(x) = @inbounds f(x)

params = TypedCodeUtils.current_params()
ref = reflect(g, Tuple{Vector{Float64}}, params=params)
@test length(ref) == 1
ref = first(ref)
@show ref.CI.code
calls = cthulhu(ref)
@test !isempty(calls)

TypedCodeUtils.preprocess!(DefaultConsumer(), ref, true)
calls = cthulhu(ref)
@test isempty(calls)

end




