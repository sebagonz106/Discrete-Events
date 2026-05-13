"""
    RandomGenerators

Inverse transform methods for random variable generation.
"""

module RandomGenerators

export uniform_int, uniform_dict, exponential_lambda, exponential_mean

"""
    uniform_int(a::Int64, b::Int64)::Int64
    
Generate uniform random integer in [a, b].
"""
function uniform_int(a::Int64, b::Int64)::Int64
    floor(Int64, a + rand() * (b - a + 1))
end

"""
    uniform_int(a::Real, b::Real)::Int64

Wrapper that accepts float bounds. The integer range used is
`ceil(min(a,b))`..`floor(max(a,b))`; if no integer lies in that
interval, returns the nearest integer to the midpoint.
"""
function uniform_int(a::Real, b::Real)::Int64
    lo = Int(ceil(min(a, b)))
    hi = Int(floor(max(a, b)))
    if lo <= hi
        return uniform_int(lo, hi)
    end
    return Int(round((a + b) / 2))
end

"""
    uniform_dict(dict::Dict)::Float64

Generate uniform random float in [0, cumulative_sum).
Useful for non-normalized probability distributions.
"""
function uniform_dict(dict::Dict)::Float64
    cumsum = 0.0

    for (_, prob) in collect(dict)
        cumsum += prob
    end

    return rand() * cumsum
end

"""
    exponential_lambda(lambda::Float64)::Int64
    
Generate exponential random variable with rate lambda, return as days (Int64).
"""
function exponential_lambda(lambda::Float64)::Int64
    u = rand()
    floor(Int64, -(1.0 / lambda) * log(u))
end

"""
    exponential_mean(mean::Float64)::Int64
    
Generate exponential random variable with mean, return as days (Int64).
"""
function exponential_mean(mean::Float64)::Int64
    u = rand()
    floor(Int64, -mean * log(u))
end

end # module
