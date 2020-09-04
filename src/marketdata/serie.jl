
"""
# Interface

* `get_name(s::AbstractSerie) :: Symbol`

* `get_value(h::AbstractSerie{D, T}, date::D; locf::Bool=false) :: Union{Missing, T}`

* `get_serie_currency(serie) :: Union{Missing, Currency}`

# Default Implementation

* `get_serie_currency(serie::AbstractSerie) = missing`

# Provided Methods

* `has_value(s::AbstractSerie{D, T}, date::D; locf::Bool=false) :: Bool = !ismissing(get_value(s, date, locf=locf))`
"""
abstract type AbstractSerie{D, T} end

@inline date_type(::AbstractSerie{D, T}) where {D, T} = D
@inline value_type(::AbstractSerie{D, T}) where {D, T} = T

get_name(::AbstractSerie) = error("Not implemented")

"""
    get_value(::AbstractSerie, date; locf::Bool=false)

Returns `missing` if value is not available.

* `locf`: last observation carried forward. If `true`, repeats last observation if it exists.
"""
get_value(::AbstractSerie, date; locf::Bool=false) = error("Not implemented")

# Default implementation.
get_serie_currency(serie::AbstractSerie) = missing

# Provided Methods
has_value(s::AbstractSerie, date; locf::Bool=false) = !ismissing(get_value(s, date; locf=locf))
