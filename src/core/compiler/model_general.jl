
#
# Entry Point
#
lower!(ctx::CompilerContext, c::Contract) = lower!(ctx, c, initial_state(ctx))

#
# State (at)
#

@inline is_initial_state(ctx, state) = initial_state(ctx) == state
@inline assert_at_initial_state(ctx, state) = @assert is_initial_state(ctx, state) "Model not at initial state. Expected initial state = $(initial_state(ctx)), current state = $state."

#
# Observables
#

function lower!(ctx::CompilerContext, o::Konst, state) :: OptimizingIR.ImmutableValue
    return OptimizingIR.constant(o.val)
end

function resolve_op(::Type{LiftObs{F, R}}) :: OptimizingIR.Op where {F<:Function, R<:Number}
    if F == typeof(-)
        return OP_UNARY_SCALAR_SUB
    elseif F == typeof(exp)
        return OP_UNARY_SCALAR_EXP
    elseif F == typeof(log)
        return OP_UNARY_SCALAR_LOG
    elseif F == typeof(sqrt)
        return OP_UNARY_SCALAR_SQRT
    else
        error("function $F not supported by `resolve_op`.")
    end
end

function resolve_op(::Type{LiftObs2{F, R}}) :: OptimizingIR.Op where {F<:Function, R<:Number}
    if F == typeof(+)
        return OP_BIN_SCALAR_SUM
    elseif F == typeof(-)
        return OP_BIN_SCALAR_SUB
    elseif F == typeof(*)
        return OP_BIN_SCALAR_MUL
    elseif F == typeof(/)
        return OP_BIN_SCALAR_DIV
    elseif F == typeof(^)
        return OP_BIN_SCALAR_POW
    elseif F == typeof(min)
        return OP_BIN_SCALAR_MIN
    elseif F == typeof(max)
        return OP_BIN_SCALAR_MAX
    else
        error("function $F not supported by `resolve_op`.")
    end
end

@generated function lower!(ctx::CompilerContext, lo::LiftObs, state) :: OptimizingIR.ImmutableValue

    op = resolve_op(lo)

    return quote
        arg = lower!(ctx, lo.o, state)
        return add_instruction!(ctx, $op, arg)
    end
end

@generated function lower!(ctx::CompilerContext, lo2::LiftObs2, state) :: OptimizingIR.ImmutableValue

    op = resolve_op(lo2)

    return quote
        arg1 = lower!(ctx, lo2.o1, state)
        arg2 = lower!(ctx, lo2.o2, state)
        return add_instruction!(ctx, $op, arg1, arg2)
    end
end

# HistoricalValue degenerates to Konst
function lower!(ctx::CompilerContext, o::HistoricalValue, state) :: OptimizingIR.ImmutableValue
    assert_at_initial_state(ctx, state)
    provider = get_market_data_provider(ctx)
    pricing_date = get_pricing_date(ctx)
    val = MarketData.get_value(provider, Symbol(o.serie_name), pricing_date, pricing_date; locf=o.locf)::Float64
    return lower!(ctx, Konst(val), pricing_date)
end

function lower!(ctx::CompilerContext, o::BufferedObservable, state) :: OptimizingIR.ImmutableValue
    key = (o, state)
    # BufferedObservable is stored in ctx.buffer
    if !haskey(ctx.observables_buffer, key)
        ctx.observables_buffer[key] = lower!(ctx, o.o, state)
    end

    return ctx.observables_buffer[key]
end

#
# Contracts
#

function lower!(ctx::CompilerContext, ::Worthless, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    return lower!(ctx, Konst(0.0), state)
end

function lower!(ctx::CompilerContext, c::Scale, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    arg1 = lower!(ctx, c.s, state)
    arg2 = lower!(ctx, c.c, state)

    # arg1 * arg2
    return add_instruction!(ctx, OP_BIN_SCALAR_MUL, arg1, arg2)
end

function lower!(ctx::CompilerContext, c::Give, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    arg = lower!(ctx, c.c, state)

    # -arg
    return add_instruction!(ctx, OP_UNARY_SCALAR_SUB, arg)
end

function lower!(ctx::CompilerContext, c::Both, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    arg1 = lower!(ctx, c.c1, state)
    arg2 = lower!(ctx, c.c2, state)

    # arg1 + arg2
    return add_instruction!(ctx, OP_BIN_SCALAR_SUM, arg1, arg2)
end

function lower!(ctx::CompilerContext, c::Either, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    arg1 = lower!(ctx, c.c1, state)
    arg2 = lower!(ctx, c.c2, state)

    # max(arg1, arg2)
    return add_instruction!(ctx, OP_BIN_SCALAR_MAX, arg1, arg2)
end

function lower!(ctx::CompilerContext, c::WhenAt{Both}, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    mat = c.maturity
    c1 = c.c.c1
    c2 = c.c.c2
    arg1 = lower!(ctx, WhenAt(mat, c1), state)
    arg2 = lower!(ctx, WhenAt(mat, c2), state)

    # arg1 + arg2
    return add_instruction!(ctx, OP_BIN_SCALAR_SUM, arg1, arg2)
end

function lower!(ctx::CompilerContext, c::WhenAt{Give}, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    mat = c.maturity
    arg = lower!(ctx, WhenAt(mat, c.c.c), state)

    # -arg
    return add_instruction!(ctx, OP_UNARY_SCALAR_SUB, arg)
end

function lower!(ctx::CompilerContext, c::WhenAt{Worthless}, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    return lower!(ctx, c.c, state)
end

# Postpone a payment makes no difference.
# TODO: this could be a more general rule ( WhenAt{C} where C<:Contract )
function lower!(ctx::CompilerContext, c::WhenAt{WhenAt{U}}, state) :: OptimizingIR.ImmutableValue where {U<:Unit}
    #assert_at_initial_state(ctx, state)
    @assert c.maturity <= c.c.maturity
    return lower!(ctx, c.c, state)
end

# Postpone a payment makes no difference.
# TODO: this could be a more general rule ( WhenAt{C} where C<:Contract )
function lower!(ctx::CompilerContext, c::WhenAt{C}, state) :: OptimizingIR.ImmutableValue where {C<:AbstractFixedIncomeContract}
    @assert c.maturity <= get_horizon(c.c)
    return lower!(ctx, c.c, state)
end

#
# FixedIncomeContract
#

@generated function lower!(ctx::CompilerContext, c::FixedIncomeEvent, state) :: OptimizingIR.ImmutableValue

    if is_cashflow_pricer(ctx)

        # when ctx is asked to create an AbstractCashflowPricer
        # we project cashflows based on the valuation of contracts of type `FixedIncomeEvent`,
        # which are components of contract of type `FixedIncomeContract`.
        #
        # For each cashflow, the following code block
        # creates a unique output variable representing the pricing results.
        # To retrieve cashflow values, a `CashflowType` is created in `ctx.output_var_to_cashflowtype`
        # with the event type and maturity date.

        return quote
            basic_block = ctx.program
            new_sym = OptimizingIR.generate_unique_variable_symbol(basic_block)
            var = OptimizingIR.ImmutableVariable(new_sym)
            cashflow_price_value = lower!(ctx, c.c, state)
            bind_output!(ctx, var, cashflow_price_value)
            ctx.output_var_to_cashflowtype[var] = CashflowType(event_symbol(c), get_horizon(c)) # horizon = c.c.maturity
            return cashflow_price_value
        end
    else
        return quote
            #assert_at_initial_state(ctx, state)
            return lower!(ctx, c.c, state)
        end
    end
end

function lower!(ctx::CompilerContext, contract::FixedIncomeContract, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)

    return mapfoldl(
        event -> lower!(ctx, event, state), # map
        (arg1, arg2) -> add_instruction!(ctx, OP_BIN_SCALAR_SUM, arg1, arg2), # reduce
        contract.events, # itr
        init = lower!(ctx, Worthless(), state) # in case itr is empty
    )
end

function lower!(ctx::CompilerContext, c::SwapContract, state) :: OptimizingIR.ImmutableValue
    #assert_at_initial_state(ctx, state)
    arg1 = lower!(ctx, c.asset, state)
    arg2 = lower!(ctx, Give(c.liability), state)

    # arg1 + arg2
    return add_instruction!(ctx, OP_BIN_SCALAR_SUM, arg1, arg2)
end
