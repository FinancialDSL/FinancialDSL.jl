
@inline function decode_compiler_type(compiler::Symbol)
    if compiler == :interpreter
        return OptimizingIR.BasicBlockInterpreter
    elseif compiler == :native
        return OptimizingIR.Native
    else
        error("Invalid compiler option: $compiler")
    end
end

function compile(
        model::PricingModel,
        provider::MarketData.AbstractMarketDataProvider,
        attributes::ContractAttributes,
        pricing_date::Date,
        contract::Contract,
        target_pricer_type::Type{T}
        ;
        compiler::Symbol=:interpreter) :: AbstractPricer where {T<:Union{AbstractPricer, AbstractCashflowPricer}}

    ctx = CompilerContext(model, provider, attributes, pricing_date, OptimizingIR.ImmutableVariable(:risk_factors_values), target_pricer_type)

    price_value = lower!(ctx, contract)
    bind_output!(ctx, :price, price_value)
    f = OptimizingIR.compile(decode_compiler_type(compiler), ctx.program)

    return new_pricer(ctx, f)
end

# an AbstractPricer has a single return value with the price of the contract
@inline function new_pricer(ctx::CompilerContext{P, M, IR, AbstractPricer}, f) where {P,M,IR}

    @assert length(ctx.program.outputs) == 1 "pricing function should have exactly one output"

    return Pricer(
            f,
            ctx.input_riskfactors,
            get_functional_currency(ctx.model)
        )
end

# an AbstractCashflowPricer has a return value for each cashflow
@inline function new_pricer(ctx::CompilerContext{P,M,IR,AbstractCashflowPricer}, f) where {P,M,IR}

    @assert length(ctx.program.outputs) >= 1 "pricing function should have at least one output."

    # identifies the index of the return value with the pricing result for the contract
    price_output_index = OptimizingIR.indexof(ctx.program.outputs, OptimizingIR.ImmutableVariable(:price))

    # identifies indexes for the return values with each cashflow pricing result
    output_index_to_cashflow_type = Dict{Int, CashflowType}()
    for (output_variable, cftype) in ctx.output_var_to_cashflowtype
        output_index_to_cashflow_type[OptimizingIR.indexof(ctx.program.outputs, output_variable)] = cftype
    end

    # outputs: pricing result + one result for each cashflow
    @assert length(output_index_to_cashflow_type) + 1 == length(ctx.program.outputs) "Some output value was not considered in the pricing routine."

    return CashflowPricer(
            f,
            ctx.input_riskfactors,
            get_functional_currency(ctx.model),
            price_output_index,
            output_index_to_cashflow_type
        )
end

#
# Register inputs and outputs
#

function add_input_riskfactor!(ctx::CompilerContext, rf::RiskFactor) :: OptimizingIR.ImmutableValue
    rf_index = OptimizingIR.addentry!(ctx.input_riskfactors, rf)
    return OptimizingIR.addinstruction!(ctx.program, OptimizingIR.call(OP_GETINDEX, ctx.input_riskfactors_variable, OptimizingIR.constant(rf_index)))
end

function bind_local_immutable_variable!(ctx::CompilerContext, var_sym::Symbol, var_value::OptimizingIR.ImmutableValue) :: OptimizingIR.ImmutableVariable
    var = OptimizingIR.ImmutableVariable(var_sym)
    OptimizingIR.assign!(ctx.program, var, var_value)
    return var
end

function bind_output!(ctx::CompilerContext, var_sym::Symbol, var_value::OptimizingIR.ImmutableValue)
    var = OptimizingIR.ImmutableVariable(var_sym)
    bind_output!(ctx, var, var_value)
    nothing
end

function bind_output!(ctx::CompilerContext, var::OptimizingIR.ImmutableVariable, var_value::OptimizingIR.ImmutableValue)
    OptimizingIR.addoutput!(ctx.program, var)
    OptimizingIR.assign!(ctx.program, var, var_value)
    nothing
end

@inline function add_instruction!(ctx::CompilerContext, op::OptimizingIR.Op, arg...) :: OptimizingIR.ImmutableValue
    return OptimizingIR.addinstruction!(ctx.program, OptimizingIR.call(op, arg...))
end

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
