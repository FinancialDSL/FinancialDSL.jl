
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

function eachcashflow(p::CashflowPricer, scenario::Scenario) :: Vector{Cashflow}

    if isempty(p.output_index_to_cashflow_type)
        return Vector{Cashflow}()
    else

        cashflows = Vector{Cashflow}(undef, length(p.output_index_to_cashflow_type))

        x = price_input_vector(p, scenario)
        result = p.pricing_function(x)

        i = 1
        for (index, cftype) in p.output_index_to_cashflow_type
            val = result[index]
            cf = Cashflow(cftype.event, cftype.maturity, val, p.currency)
            cashflows[i] = cf
            i += 1
        end
    end

    return cashflows
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
