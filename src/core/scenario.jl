
#
# Scenario
#

@generated function Base.setindex!(s::Scenario, val::Number, sc::CashRiskFactor)
    if val <: Currencies.Cash
        return quote
            error("setindex!($s, $val, $sc) not implemented.")
        end
    else
        return quote
            error("The value for a `Core.CashRiskFactor` must be a `Currencies.Cash`.")
        end
    end
end

function Base.haskey(scenario::Scenario, c::Currencies.Currency) :: Bool
    return haskey(scenario, SpotCurrency(c))
end

function Base.getindex(scenario::Scenario, c::Currencies.Currency) :: Currencies.Cash
    return scenario[SpotCurrency(c)]
end

function Base.setindex!(scenario::Scenario, val::Currencies.Cash, c::Currencies.Currency)
    Base.setindex!(scenario, val, SpotCurrency(c))
    nothing
end

for T in (:FixedCashRiskFactor, :FixedNonCashRiskFactor), S in (:FixedScenario, :ActualScenario)
    @eval begin
        Base.haskey(scenario::$S, rf::$T) = true
        Base.getindex(scenario::$S, rf::$T) = rf.val
    end
end

#
# FixedScenario
#

function Base.setindex!(s::FixedScenario, val::Currencies.Cash, rf::CashRiskFactor)
    s.cash_risk_factors[rf] = val
    nothing
end

function Base.haskey(s::FixedScenario, rf::CashRiskFactor) :: Bool
    return haskey(s.cash_risk_factors, rf)
end

function Base.getindex(s::FixedScenario, rf::CashRiskFactor) :: Currencies.Cash
    return s.cash_risk_factors[rf]
end

function Base.setindex!(s::FixedScenario, val::Float64, rf::NonCashRiskFactor)
    s.non_cash_risk_factors[rf] = val
    nothing
end

# risk factor values are currently stored as Float64
Base.setindex!(s::FixedScenario, val::Number, rf::NonCashRiskFactor) = s[rf] = Float64(val)

function Base.haskey(s::FixedScenario, rf::NonCashRiskFactor) :: Bool
    return haskey(s.non_cash_risk_factors, rf)
end

function Base.getindex(s::FixedScenario, rf::NonCashRiskFactor) :: Float64
    return s.non_cash_risk_factors[rf]
end

Base.length(scenario::FixedScenario) = length(scenario.cash_risk_factors) + length(scenario.non_cash_risk_factors)
Base.isempty(scenario::FixedScenario) = length(scenario) == 0

#
# ActualScenario
#

@inline function Base.haskey(act::ActualScenario, rf::RiskFactor)
    result = MarketData.has_serie(act.provider, market_data_symbol(rf))
    if !result
        @warn("Provider doesn't have time series for $(market_data_symbol(rf))")
    end
    return result
end

@inline function Base.getindex(scenario::ActualScenario, ::SpotCurrency{C}) :: Currencies.Cash where {C<:Currencies.Currency}
    return MarketData.get_cash(scenario.provider, C(), scenario.date)
end

@inline function Base.getindex(scenario::ActualScenario, rf::DiscountFactor) :: Float64
    @assert scenario.date <= rf.maturity "Why get value a DiscountFactor value for a past date? Scenario date $(scenario.date); DiscountFactor maturity: $(rf.maturity)."
    sym = market_data_symbol(rf)
    curve = MarketData.get_curve(scenario.provider, sym, scenario.date)
    return InterestRates.discountfactor(curve, rf.maturity)
end

@inline function  Base.getindex(scenario::ActualScenario, rf::Stock) :: Currencies.Cash
    sym = rf.ticker
    value = MarketData.get_cash(scenario.provider, sym, scenario.date)
    return value
end

#
# CompositeScenario
#

@inline function Base.haskey(composite::CompositeScenario, rf::RiskFactor)
    for scenario in composite.scenarios
        if haskey(scenario, rf)
            return true
        end
    end

    return false
end

@inline function Base.getindex(composite::CompositeScenario, rf::RiskFactor) :: Float64
    for scenario in composite.scenarios
        if haskey(scenario, rf)
            return scenario[rf]
        end
    end
    error("Scenario has no value for risk factor $rf.")
end

@inline function Base.getindex(composite::CompositeScenario, sc::SpotCurrency) :: Currencies.Cash
    for scenario in composite.scenarios
        if haskey(scenario, sc)
            return scenario[sc]
        end
    end
    error("Scenario has no value for risk factor $rf.")
end

function Base.length(composite::CompositeScenario)
    l = 0

    for scenario in composite.scenarios
        l += length(scenario)
    end

    return l
end

function Base.isempty(composite::CompositeScenario)
    for scenario in composite.scenarios
        if !isempty(scenario)
            return false
        end
    end

    return true
end

#
# DebugScenario
#

Base.haskey(s::DebugScenario, key::RiskFactor) = haskey(s.scenario, key)

function Base.getindex(s::DebugScenario, key::RiskFactor)
    # tracks which risk factors are used
    item = getindex(s.scenario, key)
    s.record[key] = item
    return item
end

#
# ScenarioMap
#

Base.haskey(s::ScenarioMap, rf::RiskFactor) = haskey(s.scenario, rf)
Base.getindex(s::ScenarioMap, rf::RiskFactor) = s.f(rf, s.scenario[rf])
