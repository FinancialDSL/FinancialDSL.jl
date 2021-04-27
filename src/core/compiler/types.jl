
struct Pricer <: AbstractPricer
    pricing_function::Union{Function, OptimizingIR.BasicBlockInterpreter}
    input_riskfactors::OptimizingIR.LookupTable{RiskFactor}
    currency::Currencies.Currency
end

struct CashflowType
    event::Symbol
    maturity::Date
end

struct CashflowPricer <: AbstractCashflowPricer
    pricing_function::Union{Function, OptimizingIR.BasicBlockInterpreter}
    input_riskfactors::OptimizingIR.LookupTable{RiskFactor}
    currency::Currencies.Currency
    price_output_index::Int # In the resulting tuple from the pricing function, identifies the index of the pricing information
    output_index_to_cashflow_type::Dict{Int, CashflowType} # Key: index in the resulting tuple from the pricing function for the cashflow
end

riskfactors(p::Pricer) = p.input_riskfactors
riskfactors(p::CashflowPricer) = p.input_riskfactors

get_functional_currency(p::Pricer) = p.currency
get_functional_currency(p::CashflowPricer) = p.currency

# maps (observable, state) -> variable
# where state is the state of nature of the pricing routine
# (state argument in lower! method)
const ObservablesBuffer = Dict{Tuple{BufferedObservable, Any}, OptimizingIR.ImmutableValue}

struct CompilerContext{M<:PricingModel, D<:MarketData.AbstractMarketDataProvider, IR<:OptimizingIR.Program, P<:Union{AbstractPricer, AbstractCashflowPricer}}
    model::M
    provider::D
    attr::ContractAttributes
    pricing_date::Date
    program::IR
    observables_buffer::ObservablesBuffer
    input_riskfactors_variable::OptimizingIR.ImmutableVariable # identifies the index of the argument for the pricing function which is a Vector of Risk Factor values
    input_riskfactors::OptimizingIR.LookupTable{RiskFactor}    # identifies the risk factor for each index of input_riskfactors_variable
    target_pricer_type::Type{P}
    output_var_to_cashflowtype::Union{Nothing, Dict{OptimizingIR.ImmutableVariable, CashflowType}}
end

get_market_data_provider(ctx::CompilerContext) = ctx.provider
get_pricing_model(ctx::CompilerContext) = ctx.model
get_pricing_date(ctx::CompilerContext) = ctx.pricing_date

@generated function get_target_pricer_type(::Type{CompilerContext{M,D,IR,P}}) where {M,D,IR,P}
    @assert P<:Union{AbstractPricer, AbstractCashflowPricer}
    P
end

"""
Returns `true` if `CompilerContext` was asked to create an `AbstractCashflowPricer`.
"""
@generated function is_cashflow_pricer(::Type{T}) :: Bool where {T<:CompilerContext}
    return get_target_pricer_type(T) == AbstractCashflowPricer
end

"""
Returns the initial state of nature for the current pricing model.

The entry point for contract compilation is
`lower!(ctx, contract)`, which is implemented as:

```julia
lower!(ctx::CompilerContext, c::Contract) = lower!(ctx, c, initial_state(ctx))
```

`Observables` are always valued in a given state by `lower!(ctx, obs, state)`,
therefore there's no need to implement `lower!` for observables with no `state` argument.
"""
initial_state(ctx::CompilerContext) = error("`initial_state` must be implemented for each `PricingModel`.")
