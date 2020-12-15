
"""
    get_horizon(c::Contract) :: Union{Missing, Date}

Returns the furthest date of choice or maturity for a given contract.

Horizon is not defined for spot positions. In this case,
this function returns `missing`.
"""
get_horizon(c::Contract) :: Union{Missing, Date} = error("Not implemented.")
get_horizon(::Union{Worthless, Unit}) :: Union{Missing, Date} = missing
get_horizon(c::Union{Give, Scale}) :: Union{Missing, Date} = get_horizon(c.c)
get_horizon(c::FixedIncomeEvent) :: Date = get_horizon(c.c)

function get_horizon(c::FixedIncomeContract) :: Union{Missing, Date}
    if isempty(c.events)
        return missing
    else
        result = get_horizon(c.events[1])
        if length(c.events) > 1
            for i in 2:length(c.events)
                result = max(result, get_horizon(c.events[i]))
            end
        end

        return result
    end
end

function get_horizon(c::SwapContract) :: Union{Missing, Date}
    return max(get_horizon(c.asset), get_horizon(c.liability))
end

function get_horizon(c::Union{Both, Either}) :: Union{Missing, Date}
    h1 = get_horizon(c.c1)
    h2 = get_horizon(c.c2)
    if !ismissing(h1) && !ismissing(h2)
        return max(h1, h2)
    elseif ismissing(h1) && !ismissing(h2)
        return h2
    elseif !ismissing(h1) && ismissing(h2)
        return h1
    elseif ismissing(h1) && ismissing(h2)
        return missing
    else
        error("Unexpected state.")
    end
end

function get_horizon(c::WhenAt) :: Date
    inner_horizon = get_horizon(c.c)
    if ismissing(inner_horizon)
        return c.maturity
    else
        return max(c.maturity, inner_horizon)
    end
end

"""
    is_expired(c::Contract, pricing_date::Date) :: Union{Missing, Bool}

Returns wether this contract has expired.

# Possible Results

* before contract horizon: `false`

* at contract horizon: `false`

* after contract horizon: `true`

* horizon is not defined for this contract: `false`, meaning it never expires.

See also: [`is_expired_or_expires_today`](@ref).
"""
function is_expired(c::Contract, pricing_date::Date) :: Bool
    h = get_horizon(c)
    if ismissing(h)
        return false
    else
        return pricing_date > h
    end
end

"""
    is_expired_or_expires_today(c::Contract, pricing_date::Date) :: Union{Missing, Bool}

Similar to [`is_expired`](@ref), but with different behavior in the case
the contract expires today.

# Possible Results

* before contract horizon: `false`

* at contract horizon: `true`

* after contract horizon: `true`

* horizon is not defined for this contract: `false`, meaning it never expires.
"""
function is_expired_or_expires_today(c::Contract, pricing_date::Date) :: Bool
    h = get_horizon(c)
    if ismissing(h)
        return false
    else
        return pricing_date >= h
    end
end
