
function CompilerContext(
            model::PricingModel,
            provider::MarketData.AbstractMarketDataProvider,
            attr::ContractAttributes,
            pricing_date::Date,
            input_riskfactors_variable::OptimizingIR.ImmutableVariable,
            target_pricer_type::DataType
        ) :: CompilerContext

    ctx = CompilerContext(
            model,
            provider,
            attr,
            pricing_date,
            OptimizingIR.BasicBlock(),
            ObservablesBuffer(),
            input_riskfactors_variable,
            OptimizingIR.LookupTable{RiskFactor}(),
            target_pricer_type,
            Dict{OptimizingIR.ImmutableVariable, CashflowType}()
        )

    # creates the pricing function argument for the vector of risk factor values
    OptimizingIR.addinput!(ctx.program, ctx.input_riskfactors_variable)

    return ctx
end

function clone_context_with_model(ctx::CompilerContext, new_model::PricingModel)
    return CompilerContext(
            new_model,
            ctx.provider,
            ctx.attr,
            ctx.pricing_date,
            ctx.program,
            ctx.observables_buffer,
            ctx.input_riskfactors_variable,
            ctx.input_riskfactors,
            ctx.target_pricer_type,
            ctx.output_var_to_cashflowtype
        )
end

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
