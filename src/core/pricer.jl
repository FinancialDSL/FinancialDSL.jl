
function compile_pricer(provider::MarketData.AbstractMarketDataProvider, pricing_date::Date, model::PricingModel, c::Contract, attr::ContractAttributes; compiler::Symbol=:interpreter)
    Compiler.compile(model, provider, attr, pricing_date, c, AbstractPricer, compiler=compiler)
end

function compile_cashflow_pricer(provider::MarketData.AbstractMarketDataProvider, pricing_date::Date, model::PricingModel, c::Contract, attr::ContractAttributes; compiler::Symbol=:interpreter)
	Compiler.compile(model, provider, attr, pricing_date, c, AbstractCashflowPricer, compiler=compiler)
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
	eachcashflow(p::AbstractCashflowPricer, scenario::Scenario) -> itr

Returns an iterator for the cashflow of the contract.
"""
function eachcashflow end
