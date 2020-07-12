
"""
# Interface

* `get_name(s::AbstractSerie) :: Symbol`

* `has_value(s::AbstractSerie{D, T}, date::D) :: Bool`

* `get_value(h::AbstractSerie{D, T}, date::D; strict::Bool=true) :: T`

* `find_index(serie, date) :: Integer`

* `Base.getindex(s::AbstractSerie{D, T}, index) :: T`

* `get_serie_currency(serie) :: Union{Missing, Currency}`
"""
abstract type AbstractSerie{D, T} end

@inline date_type(::AbstractSerie{D, T}) where {D, T} = D
@inline value_type(::AbstractSerie{D, T}) where {D, T} = T

get_name(::AbstractSerie) = error("Not implemented")
has_value(::AbstractSerie, date) = error("Not implemented")
get_value(::AbstractSerie, date) = error("Not implemented")
find_index(::AbstractSerie, date) = error("Not implemented")

# Standard implementation. Should be implemented for each AbstractSerie.
get_serie_currency(serie::AbstractSerie) = missing
