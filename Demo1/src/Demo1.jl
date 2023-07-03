module Demo1

export callsum1, callsum2, callsum3

callsum1(a) = sum(a)

callsum2(a::Vector{Int}) = sum(a)

callsum3(a::String) = sum(a)

end # module Demo1
