# TypedCodeUtils

This package performs operations on Julia's typed IR. 

## Example: Your own Cthulhu.jl

```julia
using TypedCodeUtils
import TypedCodeUtils: reflect, filter, lookthrough,
                       DefaultConsumer, Reflection, Callsite,
                       identify_invoke, identify_call,
                       process_invoke, process_call

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
```

