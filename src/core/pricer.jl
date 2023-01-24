
function compile_pricer(
            provider::MarketData.AbstractMarketDataProvider,
            pricing_date::Date,
            model::PricingModel,
            c::Contract,
            attr::ContractAttributes;
            compiler::Symbol=:interpreter
        )

    Compiler.compile_pricer(model, provider, attr, pricing_date, c, AbstractPricer, compiler=compiler)
end

function compile_cashflow_pricer(
            provider::MarketData.AbstractMarketDataProvider,
            pricing_date::Date,
            model::PricingModel,
            c::Contract,
            attr::ContractAttributes;
            compiler::Symbol=:interpreter
        )

	Compiler.compile_pricer(model, provider, attr, pricing_date, c, AbstractCashflowPricer, compiler=compiler)
end

function compile_pricing_program(
            provider::MarketData.AbstractMarketDataProvider,
            pricing_date::Date,
            model::PricingModel,
            c::Contract,
            attr::ContractAttributes;
        )

    Compiler.compile_pricing_program(model, provider, attr, pricing_date, c, AbstractPricer)
end

function compile_cashflow_pricing_program(
            provider::MarketData.AbstractMarketDataProvider,
            pricing_date::Date,
            model::PricingModel,
            c::Contract,
            attr::ContractAttributes;
        )

    Compiler.compile_pricing_program(model, provider, attr, pricing_date, c, AbstractCashflowPricer)
end

function create_pricer(
        compiler_result;
        compiler::Symbol=:interpreter,
        memory_buffer::Union{Nothing, Vector{Any}}=nothing,
        input_values_buffer::Union{Nothing, Vector{Any}}=nothing,
        auto_resize_buffers::Bool=true
    )

    return Compiler.create_pricer(compiler_result, compiler=compiler, memory_buffer=memory_buffer, input_values_buffer=input_values_buffer, auto_resize_buffers=auto_resize_buffers)
end

"""
    price(p::AbstractPricer, scenario::Scenario) :: Real

Returns the price for the contract.
"""
function price end

"""
    exposures(method::AbstractExposuresMethod, p::AbstractPricer, scenario::Scenario) :: ExposureResult

Risk factors mapping.
"""
function exposures end

"""
    riskfactors(pricer::AbstractPricer) -> itr

Returns an iterator for the risk factors of the contract.
"""
function riskfactors end

"""
	foreachcashflow(f::Function, p::AbstractCashflowPricer, scenario::Scenario)

Applies `f` to each `cashflow :: FinancialDSL.Core.Cashflow` given by pricer `p` under `scenario`.

# Example

```julia
FinancialDSL.Core.foreachcashflow(p, scenario) do cashflow
    @assert isa(cashflow, FinancialDSL.Core.Cashflow)
end
```
"""
function foreachcashflow end

"""
    collect_cashflows(p::AbstractCashflowPricer, scenario::Scenario) :: Vector{Cashflow}

Returns all cashflows given by pricer `p` under `scenario` as a vector with eltype `Cashflow`.
"""
function collect_cashflows(p::AbstractCashflowPricer, scenario::Scenario) :: Vector{Cashflow}
    result = Vector{Cashflow}()
    foreachcashflow(p, scenario) do cashflow
        push!(result, cashflow)
    end
    return result
end
