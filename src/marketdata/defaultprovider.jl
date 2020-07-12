
struct DefaultMarketDataProvider <: AbstractMarketDataProvider
    data::Dict{Symbol, AbstractSerie}
end

DefaultMarketDataProvider() = DefaultMarketDataProvider(Dict{Symbol, AbstractSerie}())

Base.setindex!(provider::DefaultMarketDataProvider, val, key::Symbol) = setindex!(provider.data, val, key)
Base.getindex(provider::DefaultMarketDataProvider, key::Symbol) = getindex(provider.data, key)
Base.haskey(provider::DefaultMarketDataProvider, key::Symbol) = haskey(provider.data, key)

has_serie(provider::DefaultMarketDataProvider, key::Symbol) = haskey(provider, key)
get_serie(provider::DefaultMarketDataProvider, key::Symbol) = provider[key]

"A Market Data provided that has no data. Useful when calculation does not depend on Market Data."
struct EmptyMarketDataProvider <: AbstractMarketDataProvider
end

Base.getindex(::EmptyMarketDataProvider, key::Symbol) = error("Not supported.")
has_serie(::EmptyMarketDataProvider, key::Symbol) = false
get_serie(::EmptyMarketDataProvider, key::Symbol) = error("Not supported.")
