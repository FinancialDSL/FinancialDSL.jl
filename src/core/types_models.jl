
"""
    PricingModel{C<:Currencies.Currency}

Represents a Pricing Model for a `Contract`.

# Provides

* `get_functional_currency(model) :: Currencies.Currency`

"""
abstract type PricingModel{C<:Currencies.Currency} end

@inline function get_functional_currency(m::PricingModel{C}) :: C where {C<:Currencies.Currency}
    return C()
end

"""
    StaticHedgingModel

Standard discounted cashflow model. Used to price instruments that can be hedged with a static strategy.
"""
struct StaticHedgingModel{C} <: PricingModel{C}
    functional_currency::C
    riskfree_curve_map::Dict{String, Dict{Symbol, Symbol}} # "onshore" -> [ :BRL -> :PRE ]
end

"""
    FutureValueModel

Wrapps a `StaticHedgingModel` and changes its behavior
to disable the discounted cashflow rule,
preserving any projection to future values.

Used to project cashflows.
"""
struct FutureValueModel{C} <: PricingModel{C}
    underlying_model::StaticHedgingModel{C}
end

# docstrings generated by docs.jl
struct BlackScholesModel{C} <: PricingModel{C}
    static_model::StaticHedgingModel{C}
end

struct BinomialModelDaily{C, U<:CashRiskFactor, T<:InterestRates.DayCountConvention} <: PricingModel{C}
    static_model::StaticHedgingModel{C}
    underlying::U # CashRiskFactor -> Stock or SpotCurrency
    numeraire_daycount_convention::T # the numeraire is static_model.functional_currency
end
