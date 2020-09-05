
module MarketData

import ..Currencies

"""
# Interface

* `MarketData.get_value(provider, serie_id, at; locf::Bool=false) :: Union{Missing, T}`

* `MarketData.get_serie_currency(provider, serie_id) :: Union{Nothing, Currecies.Currency}`

* `MarketData.has_serie(provider, serie_id) :: Bool`

# Provided methods

* `MarketData.has_value(provider, serie_id, at) :: Bool`

* `MarketData.get_cash(provider, serie_id, at) :: Currencies.Cash`

* `MarketData.assert_has_serie(provider, serie_id)`
"""
abstract type AbstractMarketDataProvider end

"""
    get_value(provider, serie_id, at; locf::Bool=false) :: Union{Missing, T}

Returns a value for `serie_id` at state (or date) `at`.

`locf` means: last observation carried forward. Use `locf=true` to repeat the latest observation prior to `at`.

This method should error if `provider` does not know about `serie_id`. Use [`MarketData.assert_has_serie`](@ref) for that.
"""
function get_value end

"""
    get_serie_currency(provider, serie_id) :: Union{Nothing, Currecies.Currency}

Returns the currency in which `serie_id` is expressed. Returns `nothing` if `serie_id` is not based on a currency.

This method should error if `provider` does not know about `serie_id`. Use [`MarketData.assert_has_serie`](@ref) for that.
"""
function get_serie_currency end
function has_serie end
has_value(provider::AbstractMarketDataProvider, serie_id, at) = !ismissing(get_value(provider, serie_id, at))

function get_cash(provider::AbstractMarketDataProvider, serie_id, at) :: Currencies.Cash

    currency = get_serie_currency(provider, serie_id)
    if currenty == nothing
        error("Serie $serie_id has no currency")
    end

    return get_value(provider, serie_id, at) * currency
end

"""
    assert_has_serie(provider::AbstractMarketDataProvider, serie_id)

Throws `AssertionError` if `has_serie(provider, serie_id)` returns `false`.
"""
function assert_has_serie(provider::AbstractMarketDataProvider, serie_id)
    @assert has_serie(provider, serie_id) "Provider does not know about serie $serie_id"
    nothing
end

"A Market Data provided that has no data. Useful when calculation does not depend on Market Data."
struct EmptyMarketDataProvider <: AbstractMarketDataProvider
end

get_value(::EmptyMarketDataProvider, serie_id, at; locf::Bool=false) = error("EmptyMarketDataProvider has no series")
get_serie_currency(::EmptyMarketDataProvider, serie_id) = error("EmptyMarketDataProvider has no series")
has_serie(::EmptyMarketDataProvider, serie_id) = false

end
