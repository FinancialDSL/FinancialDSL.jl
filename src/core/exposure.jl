
struct ExposureResult
    val::Dict{RiskFactor, Float64}

    function ExposureResult()
        return new(Dict{RiskFactor, Float64}())
    end
end

Base.:(==)(ex1::ExposureResult, ex2::ExposureResult) = ex1.val == ex2.val
Base.hash(ex::ExposureResult) = hash(length(ex.val))

#
# ExposureResult API
#

function ExposureResult(d::Dict{RiskFactor, Float64})
    # creates a copy insted of reusing the instance
    result = ExposureResult()

    for (k, v) in d
        result[k] = v
    end

    return result
end

function Base.getindex(r::ExposureResult, k::RiskFactor) :: Float64
    return r.val[k]
end

function Base.haskey(r::ExposureResult, k::RiskFactor) :: Bool
    return haskey(r.val, k)
end

function Base.setindex!(r::ExposureResult, v::Float64, k::RiskFactor)
    r.val[k] = v
    nothing
end

function Base.setindex!(r::ExposureResult, v::Integer, k::RiskFactor)
    r.val[k] = Float64(v)
    nothing
end

Base.length(r::ExposureResult) = length(r.val)
Base.isempty(r::ExposureResult) = isempty(r.val)
Base.keys(r::ExposureResult) = keys(r.val)
Base.values(r::ExposureResult) = values(r.val)
Base.iterate(r::ExposureResult) = iterate(r.val)
Base.iterate(r::ExposureResult, state) = iterate(r.val, state)
Base.delete!(r::ExposureResult, k::RiskFactor) = delete!(r.val, k)
Base.get(r::ExposureResult, k::RiskFactor, default::Float64) = get(r.val, k, default)

function Base.:*(s::Real, expo::ExposureResult) :: ExposureResult
    result = ExposureResult()

    if s ≈ 0.0
        return result
    end

    for (k, v) in expo
        result[k] = s * v
    end

    return result
end

function Base.:*(expo::ExposureResult, s::Real) :: ExposureResult
    return s * expo
end

function Base.:+(ex1::ExposureResult, ex2::ExposureResult) :: ExposureResult
    result = ExposureResult()

    for (k, v) in ex1
        # copies ex1 to result
        result[k] = v
    end

    for (k, v) in ex2
        # increment result by ex2
        result[k] = v + get(result, k, 0.0)
    end

    _clean_zero_exposures!(result)
    return result
end

function _clean_zero_exposures!(expo::ExposureResult)
    for (k, v) in expo
        if v ≈ 0.0
            delete!(expo, k)
        end
    end

    nothing
end
