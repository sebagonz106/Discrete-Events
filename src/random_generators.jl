"""
    RandomGenerators

Inverse transform methods for random variable generation.
"""

module RandomGenerators

export uniformInt, uniformDict, exponential

"""
    uniformInt(a::Int64, b::Int64)::Int64
    
Generate uniform random integer in [a, b).
"""
function uniformInt(a::Int64, b::Int64)::Int64
    floor(Int64, a + rand() * (b - a))
end

"""
    uniformDict(dict::Dict)::Float64

Generate uniform random float in [0, cumulative_sum).
Useful for non-normalized probability distributions.
"""
function uniformDict(dict::Dict)::Float64
    cumsum = 0.0

    for (_, prob) in collect(dict)
        cumsum += prob
    end

    return rand() * cumsum
end

"""
    exponential(lambda::Float64)::Int64
    
Generate exponential random variable with rate lambda, return as days (Int64).
"""
function exponential(lambda::Float64)::Int64
    u = rand()
    floor(Int64, -(1.0 / lambda) * log(u))
end

end # module
