module Demo2

export typed_filter, typed_replace

using Base: uniontypes

function infer(@nospecialize(tt),
               world = Base.get_world_counter(),
               interp = Core.Compiler.NativeInterpreter(world))
    mms = Core.Compiler._methods_by_ftype(tt, -1, world)
    length(mms) === 1 || return nothing

    mm = first(mms)::Core.MethodMatch
    linfo = Core.Compiler.specialize_method(mm.method, mm.spec_types, mm.sparams)
    result = Core.Compiler.InferenceResult(linfo)
    frame = Core.Compiler.InferenceState(result, #=cached=#:global, interp)

    Core.Compiler.typeinf(interp, frame)

    return result
end

function typed_filter(f, a::Array{T,N}) where {T,N}
    if @generated
        ft = f
        et = T
        isa(et, Union) || return :(filter(f, a))
        ets = uniontypes(et)

        filtered = []
        for et in ets
            tt = Tuple{ft,et}
            result = infer(tt)
            if isa(result, Core.Compiler.InferenceResult)
                result = result.result
                isa(result, Core.Const) && result.val === false && continue
            end
            push!(filtered, et)
        end
        et′ = Union{filtered...}

        return quote
            j = 1
            b = Vector{$(et′)}(undef, length(a))
            isempty(b) && return b
            fallback = first(b)
            for ai in a
                c = f(ai)
                @inbounds b[j] = (c ? ai : fallback)::$(et′)
                j = ifelse(c, j+1, j)
            end
            resize!(b, j-1)
            sizehint!(b, length(b))
            b
        end
    else
        filter(f, a)
    end
end

function typed_filter(pred, s::AbstractSet)
    if @generated
        ft = pred
        et = eltype(s)
        isa(et, Union) || return :(filter(pred, s))
        ets = uniontypes(et)

        filtered = []
        for et in ets
            tt = Tuple{ft,et}
            result = infer(tt)
            if isa(result, Core.Compiler.InferenceResult)
                result = result.result
                isa(result, Core.Const) && result.val === false && continue
            end
            push!(filtered, et)
        end
        et′ = Union{filtered...}

        return :(Base.mapfilter(pred, push!, s, Set{$(et′)}()))
    else
        return filter(pred, s)
    end
end

function typed_replace(new::Base.Callable, A; count = nothing)
    if @generated
        count === Nothing || return :(replace(new, A; count))
        fallback = :(replace(new, A; count = typemax(Int)))

        ft = new
        et = eltype(A)
        isa(et, Union) || return fallback
        ets = uniontypes(et)

        replaced = []
        for et in ets
            tt = Tuple{ft,et}
            result = infer(tt)
            isa(result, Core.Compiler.InferenceResult) || return fallback # unsuccessful inference
            push!(replaced, Core.Compiler.widenconst(result.result))
        end
        et′ = Union{replaced...}

        return :(Base._replace!(new, Base._similar_or_copy(A, $(et′)), A, Base.check_count(typemax(Int))))
    else
        if isnothing(count)
            count = typemax(Int)
        end
        return replace(new, A; count)
    end
end

end # module Demo2
