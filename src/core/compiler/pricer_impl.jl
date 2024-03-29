
#
# Execution machinery
#

function price_input_vector(program::AbstractPricer, scenario::Scenario) :: Vector{Float64}
    return price_input_vector(program.input_riskfactors, scenario, program.currency)
end

# A NonCashRiskFactor has no Currency information, therefore we don't need to apply `exch`
function parse_risk_factor_value(scenario::Scenario, risk_factor::NonCashRiskFactor, ::TO_CURRENCY) :: Float64 where {TO_CURRENCY<:Currencies.Currency}
    return scenario[risk_factor]
end

function parse_risk_factor_value(scenario::Scenario, risk_factor::SpotCurrency{FROM_CURRENCY}, to::TO_CURRENCY) :: Float64 where {FROM_CURRENCY<:Currencies.Currency, TO_CURRENCY<:Currencies.Currency}
    exch(scenario, FROM_CURRENCY(), to)
end

function parse_risk_factor_value(scenario::Scenario, risk_factor::CashRiskFactor, to::Currencies.Currency) :: Float64
    exch(scenario, scenario[risk_factor], to)
end

function price_input_vector(
        input_symbols::OptimizingIR.LookupTable{RiskFactor},
        scenario::Scenario,
        functional_currency::Currencies.Currency) :: Vector{Float64}

    if isempty(input_symbols)
        # there are no risk factors
        return Vector{Float64}()
    end

    input_vector = zeros(Float64, length(input_symbols))

    for risk_factor in input_symbols
        if !isa(risk_factor, SpotCurrency)
            # For currencies, `exch` checks wether currency prices are available.
            # For any other risk factor, the Scenario must provide values for Risk Factors.
            # See `parse_risk_factor_value`.
            @assert haskey(scenario, risk_factor) "Scenario has no value for Risk Factor $risk_factor."
        end

        @inbounds input_vector[ OptimizingIR.indexof(input_symbols, risk_factor) ] = parse_risk_factor_value(scenario, risk_factor, functional_currency)
    end

    return input_vector
end

# converts `program.pricing_function`
# to something that accepts a vector as input
# so that ForwardDiff can do its thing
# Regarding `invokelatest`, see https://felipenoris.github.io/OptimizingIR.jl/dev/#World-Age-Problem-1
function price_closure(program::Pricer) :: Function
    if isa(program.pricing_function, Function)
        x -> Base.invokelatest(program.pricing_function, x)
    else
        x -> program.pricing_function(x)
    end
end

# Regarding `invokelatest`, see https://felipenoris.github.io/OptimizingIR.jl/dev/#World-Age-Problem-1
function price_closure(program::CashflowPricer) :: Function
    # the CashflowPricer returns the contract price along with
    # the prices for each cashflow.

    if isempty(program.output_index_to_cashflow_type)
        # there are no events for this contract
        if isa(program.pricing_function, Function)
            return x -> Base.invokelatest(program.pricing_function, x)
        else
            return x -> program.pricing_function(x)
        end
    else
        if isa(program.pricing_function, Function)
            return x -> Base.invokelatest(program.pricing_function, x)[program.price_output_index]
        else
            return x -> program.pricing_function(x)[program.price_output_index]
        end
    end
end

function price(program::AbstractPricer, scenario::Scenario) :: Number
    x = price_input_vector(program, scenario)
    f = price_closure(program)
    return f(x)
end

function foreachcashflow(f::Function, p::CashflowPricer, scenario::Scenario)
    if !isempty(p.output_index_to_cashflow_type)
        x = price_input_vector(p, scenario)
        result = p.pricing_function(x)

        for (index, cftype) in p.output_index_to_cashflow_type
            val = result[index]
            cf = Cashflow(cftype.event, cftype.maturity, val, p.currency)
            f(cf)
        end
    end
end

function exposures(::DeltaNormalExposuresMethod, program::AbstractPricer, scenario::Scenario) :: ExposureResult
    result = ExposureResult()
    first_order_exposures!(result, program, scenario)
    return result
end

function exposures(::DeltaGammaApproxExposuresMethod, program::AbstractPricer, scenario::Scenario) :: ExposureResult
    result = ExposureResult()
    first_order_exposures!(result, program, scenario)
    second_order_exposures!(result, program, scenario)
    return result
end

function first_order_exposures!(result::ExposureResult, program::AbstractPricer, scenario::Scenario)

    x = price_input_vector(program, scenario)

    if isempty(x)
        return result
    end

    f_grad = args -> ForwardDiff.gradient(price_closure(program), args)
    exposures_vector = x .* f_grad(x)

    # sanity check
    _risk_factors = riskfactors(program)
    @assert length(exposures_vector) == length(_risk_factors) "Size of exposures vector ($(length(exposures_vector))) should equal the size of inputs vector ($(length(_risk_factors)))."

    for i in 1:length(exposures_vector)
        # consider as zero exposure values below eps(1_000_000_000_000.0)
        if abs(exposures_vector[i]) > 0.0001220703125
            @inbounds result[_risk_factors[i]] = exposures_vector[i]
        end
    end

    nothing
end

"""
Returns second order exposures approximation as:

``\\frac{1}{2} \\frac{ \\partial^2 P }{ \\partial S^2 } S^2``

where `P` is the pricing function,
and `S` is a Risk Factor.
"""
function second_order_exposures!(result::ExposureResult, program::AbstractPricer, scenario::Scenario)

    x = price_input_vector(program, scenario)

    if isempty(x)
        return result
    end

    f_hessian = args -> ForwardDiff.hessian(price_closure(program), args)
    exposures_vector = 0.5 * (LinearAlgebra.diag(f_hessian(x)) .* (x.^2))

    # sanity check
    _risk_factors = riskfactors(program)
    @assert length(exposures_vector) == length(_risk_factors) "Size of exposures vector ($(length(exposures_vector))) should equal the size of inputs vector ($(length(_risk_factors)))."

    for i in 1:length(exposures_vector)
        # consider as zero exposure values below eps(1_000_000_000_000.0)
        if abs(exposures_vector[i]) > 0.0001220703125
            @inbounds result[SecondOrderRiskFactor(_risk_factors[i])] = exposures_vector[i]
        end
    end

    nothing
end
