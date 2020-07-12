
"""
# Interface

* `MarketData.get_serie(provider, s::Symbol) :: AbstractSerie`

* `MarketData.has_serie(provider, serie_name) :: Bool`

* `MarketData.get_cash(provider, serie_name, observation_date) :: Currencies.Cash`

# Provided functions

* `MarketData.get_value(provider, serie_name, observation_date)`
"""
abstract type AbstractMarketDataProvider end

has_serie(::AbstractMarketDataProvider, s::Symbol) = error("Not implemented")
get_serie(::AbstractMarketDataProvider, s::Symbol) = error("Not implemented")

# Standard implementation
function get_value(provider::AbstractMarketDataProvider, serie_name, observation_date)
    @assert has_serie(provider, serie_name) "Can't provide serie $serie_name."
    return get_value(get_serie(provider, serie_name), observation_date)
end

function get_cash(provider::AbstractMarketDataProvider, serie_name, observation_date::Date) :: Currencies.Cash
    serie = get_serie(provider, serie_name)
    serie_currency = get_serie_currency(serie)
    @assert !ismissing(serie_currency) "serie $(get_name(serie)) has no currency."
    return get_value(serie, observation_date) * serie_currency
end

# spot prices are scalar numbers. Its historical series is represented by a vector of dates and a vector of real numbers.
function get_spot_value(provider::AbstractMarketDataProvider, serie_name::Union{AbstractString, Symbol}, observation_date::Date) :: Real
    get_value(provider, serie_name, observation_date)
end

function get_curve(provider::AbstractMarketDataProvider, curve_sym::Symbol, observation_date::Date) :: InterestRates.AbstractIRCurve
    get_value(provider, curve_sym, observation_date)
end

function has_serie(provider::AbstractMarketDataProvider, ::Currencies.Currency{C}) :: Bool where {C}
    return has_serie(provider, C)
end

function get_serie(provider::AbstractMarketDataProvider, ::Currencies.Currency{C}) :: AbstractSerie where {C}
    return get_serie(provider, C)
end

function get_spot_value(provider::AbstractMarketDataProvider, ::Currencies.Currency{C}, observation_date::Date) :: Float64 where {C}
    return get_spot_value(provider, C, observation_date)
end
