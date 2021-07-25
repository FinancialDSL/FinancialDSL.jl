
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
            target_pricer_type <: AbstractCashflowPricer ? Dict{OptimizingIR.ImmutableVariable, CashflowType}() : nothing
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

function compile_pricer(
        model::PricingModel,
        provider::MarketData.AbstractMarketDataProvider,
        attributes::ContractAttributes,
        pricing_date::Date,
        contract::Contract,
        target_pricer_type::Type{T}
        ;
        compiler::Symbol=:interpreter) where {T<:Union{AbstractPricer, AbstractCashflowPricer}}

    compiler_result = compile_pricing_program(model, provider, attributes, pricing_date, contract, target_pricer_type)
    return create_pricer(compiler_result, compiler=compiler)
end

function _compile_pricing_function(
            program::OptimizingIR.CompiledBasicBlock,
            compiler::Symbol;
            memory_buffer::Union{Nothing, Vector{Any}}=nothing,
            input_values_buffer::Union{Nothing, Vector{Any}}=nothing,
            auto_resize_buffers::Bool=true
        )

    if compiler === :interpreter

        if memory_buffer === nothing
            memory_buffer = Vector{Any}()
        end

        if input_values_buffer === nothing
            input_values_buffer = Vector{Any}()
        end

        return OptimizingIR.BasicBlockInterpreter(program, memory_buffer, input_values_buffer, auto_resize_buffers=auto_resize_buffers)

    elseif compiler === :native
        return OptimizingIR.compile(OptimizingIR.Native, program)
    else
        error("Unknown compiler type: $compiler")
    end
end

function create_pricer(
            compiler_result::CompilerResult{OptimizingIR.CompiledBasicBlock, P};
            compiler::Symbol=:interpreter,
            memory_buffer::Union{Nothing, Vector{Any}}=nothing,
            input_values_buffer::Union{Nothing, Vector{Any}}=nothing,
            auto_resize_buffers::Bool=true
        ) where {P<:AbstractPricer}

    f = _compile_pricing_function(compiler_result.program, compiler, memory_buffer=memory_buffer, input_values_buffer=input_values_buffer, auto_resize_buffers=auto_resize_buffers)

    @assert length(compiler_result.program.outputs) == 1 "pricing function should have exactly one output"

    return Pricer(
            f,
            compiler_result.input_riskfactors,
            compiler_result.currency
        )
end

function create_pricer(
            compiler_result::CompilerResult{OptimizingIR.CompiledBasicBlock, P};
            compiler::Symbol=:interpreter,
            memory_buffer::Union{Nothing, Vector{Any}}=nothing,
            input_values_buffer::Union{Nothing, Vector{Any}}=nothing,
            auto_resize_buffers::Bool=true
        ) where {P<:AbstractCashflowPricer}

    f = _compile_pricing_function(compiler_result.program, compiler, memory_buffer=memory_buffer, input_values_buffer=input_values_buffer, auto_resize_buffers=auto_resize_buffers)

    @assert length(compiler_result.program.outputs) >= 1 "pricing function should have at least one output."

    return CashflowPricer(
        f,
        compiler_result.input_riskfactors,
        compiler_result.currency,
        compiler_result.price_output_index,
        compiler_result.output_index_to_cashflow_type
    )
end

function compile_pricing_program(
            model::PricingModel,
            provider::MarketData.AbstractMarketDataProvider,
            attributes::ContractAttributes,
            pricing_date::Date,
            contract::Contract,
            target_pricer_type::Type{T}
        ) where {T<:Union{AbstractPricer, AbstractCashflowPricer}}

    ctx = CompilerContext(model, provider, attributes, pricing_date, OptimizingIR.ImmutableVariable(:risk_factors_values), target_pricer_type)
    price_value = lower!(ctx, contract)
    bind_output!(ctx, :price, price_value)

    return CompilerResult(ctx)
end

function CompilerResult(ctx::CompilerContext{M, D, IR, P}) where {M, D, IR<:OptimizingIR.BasicBlock, P<:AbstractPricer}
    # identifies the index of the return value with the pricing result for the contract
    price_output_index = OptimizingIR.indexof(ctx.program.outputs, OptimizingIR.ImmutableVariable(:price))

    # an AbstractPricer has a single return value with the price of the contract
    output_index_to_cashflow_type = nothing

    return CompilerResult(
            OptimizingIR.CompiledBasicBlock(ctx.program),
            ctx.input_riskfactors,
            get_functional_currency(ctx.model),
            ctx.target_pricer_type,
            price_output_index,
            output_index_to_cashflow_type
        )
end

function CompilerResult(ctx::CompilerContext{M, D, IR, P}) where {M, D, IR<:OptimizingIR.BasicBlock, P<:AbstractCashflowPricer}
    # identifies the index of the return value with the pricing result for the contract
    price_output_index = OptimizingIR.indexof(ctx.program.outputs, OptimizingIR.ImmutableVariable(:price))

    # an AbstractCashflowPricer has a return value for each cashflow
    @assert ctx.output_var_to_cashflowtype !== nothing
    output_index_to_cashflow_type = Dict{Int, CashflowType}()
    for (output_variable, cftype) in ctx.output_var_to_cashflowtype
        output_index_to_cashflow_type[OptimizingIR.indexof(ctx.program.outputs, output_variable)] = cftype
    end

    # outputs: pricing result + one result for each cashflow
    @assert length(output_index_to_cashflow_type) + 1 == length(ctx.program.outputs) "Some output value was not considered in the pricing routine."

    return CompilerResult(
            OptimizingIR.CompiledBasicBlock(ctx.program),
            ctx.input_riskfactors,
            get_functional_currency(ctx.model),
            ctx.target_pricer_type,
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
