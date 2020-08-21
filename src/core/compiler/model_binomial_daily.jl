
abstract type AbstractBinomialModelState end

struct StateVariables
    s::OptimizingIR.ImmutableVariable
    u::OptimizingIR.ImmutableVariable
    d::OptimizingIR.ImmutableVariable
    ln_u::OptimizingIR.ImmutableVariable
    ln_d::OptimizingIR.ImmutableVariable
end

struct BinomialModelState{T<:InterestRates.DailyDatesRange} <: AbstractBinomialModelState
    dates_range::T
    current_time_step::Int # starts at n = 1
    current_state_of_nature::Int # starts at i = 1, 1 <= i <= n
    state_variables::StateVariables
end

struct BinomialModelInitialState <: AbstractBinomialModelState
end

function initial_state(ctx::CompilerContext{B}) where {B<:BinomialModelDaily}
    return BinomialModelInitialState()
end

"Returns tuple var_u, var_d, var_ln_u, var_ln_d"
function volatility_match(ctx::CompilerContext{B}, dates_range::InterestRates.DailyDatesRange, state::BinomialModelInitialState) where {B<:BinomialModelDaily}
    pricing_model = get_pricing_model(ctx)
    σ = lower!(ctx, Volatility(pricing_model.underlying), state)
    Δt = lower!(ctx, Konst(InterestRates.yearfractionvalue(dates_range)), state)
    u_value = add_instruction!(ctx, OP_CRR_VOLATILITY_MATCH_UP_FACTOR, σ, Δt) # u = exp(σ*sqrt(Δt))
    d_value = add_instruction!(ctx, OP_BIN_SCALAR_DIV, lower!(ctx, Konst(1.0), state), u_value) # d = 1 / u
    ln_u_value = add_instruction!(ctx, OP_UNARY_SCALAR_LOG, u_value) # ln(u)
    ln_d_value = add_instruction!(ctx, OP_UNARY_SCALAR_SUB, ln_u_value) # ln(d) = -ln(u)
    return bind_local_immutable_variable!(ctx, :u, u_value), bind_local_immutable_variable!(ctx, :d, d_value), bind_local_immutable_variable!(ctx, :ln_u, ln_u_value), bind_local_immutable_variable!(ctx, :ln_d, ln_d_value)
end

function lower!(ctx::CompilerContext{B}, c::WhenAt, initial_state::BinomialModelInitialState) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}
    return lower_binomial_tree_algorithm!(ctx, c, initial_state)
end

function lower!(ctx::CompilerContext{B}, c::Anytime, initial_state::BinomialModelInitialState) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}
    return lower_binomial_tree_algorithm!(ctx, c, initial_state)
end

@inline function lower_binomial_tree_algorithm!(ctx::CompilerContext{B}, c::C, initial_state::BinomialModelInitialState) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily, C<:Union{WhenAt,Anytime}}
    startdate = get_pricing_date(ctx)
    enddate = C <: WhenAt ? c.maturity : c.expiry
    model = get_pricing_model(ctx)
    dates_range = InterestRates.DailyDatesRange(startdate, enddate, model.numeraire_daycount_convention)
    number_of_steps = length(dates_range)

    # initial underlying price
    var_s = bind_local_immutable_variable!(ctx, :s, lower!(ctx, Unit(model.underlying), initial_state))

    # up and down underlying price factors
    var_u, var_d, var_ln_u, var_ln_d = volatility_match(ctx, dates_range, initial_state)

    state_variables = StateVariables(var_s, var_u, var_d, var_ln_u, var_ln_d)

    # evaluate contract on maturity for all states
    # at maturity, there are n states of nature
    # where n is the number of steps in the dates_range
    opt_prices_at_maturity = [ lower!(ctx, c.c, BinomialModelState(dates_range, number_of_steps, i, state_variables)) for i in 1:number_of_steps ]

    current_state_prices = opt_prices_at_maturity
    for time_step in (number_of_steps-1):-1:1
        next_state_prices = current_state_prices
        current_state_prices = Vector{OptimizingIR.ImmutableValue}(undef, time_step) # could be optimized to avoid allocations

        q = lower_risk_neutral_probability!(ctx, dates_range, time_step, state_variables)
        df = lower_numeraire_discountfactor_forward!(ctx, dates_range, time_step)

        # for each state of nature
        for i in 1:time_step
            current_state = BinomialModelState(dates_range, time_step, i, state_variables)
            current_state_prices[i] = lower_current_state_price!(ctx, c, current_state, df, q, next_state_prices[i+1], next_state_prices[i])
        end
    end

    return current_state_prices[1]
end

@inline function lower_current_state_price!(ctx::CompilerContext, c::WhenAt, current_state::BinomialModelState, df, q, next_state_price_up, next_state_price_down)
    # european-style
    return add_instruction!(ctx, OP_BINOMIAL_RISK_NEUTRAL_PRICING_STEP, df, q, next_state_price_up, next_state_price_down)
end

@inline function lower_current_state_price!(ctx::CompilerContext, c::Anytime, current_state::BinomialModelState, df, q, next_state_price_up, next_state_price_down)
    # american-style
    early_exercise_value = lower!(ctx, c.c, current_state)
    hold_value = add_instruction!(ctx, OP_BINOMIAL_RISK_NEUTRAL_PRICING_STEP, df, q, next_state_price_up, next_state_price_down)
    return add_instruction!(ctx, OP_BIN_SCALAR_MAX, hold_value, early_exercise_value)
end

@inline function lower_numeraire_discountfactor_forward!(ctx::CompilerContext{B}, dates_range::InterestRates.DailyDatesRange, current_time_step::Integer) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}
    model = get_pricing_model(ctx)

    fwd_start_date = dates_range[current_time_step]
    fwd_end_date = dates_range[current_time_step + 1]

    numeraire_carry_symbol = get_riskfree_curve_symbol(model.static_model, ctx.attr["riskfree_curves"], SpotCurrency(model.static_model.functional_currency))
    df_numeraire_carry = DiscountFactorForward(numeraire_carry_symbol, fwd_start_date, fwd_end_date)
    return lower!(clone_context_with_model(ctx, model.static_model), df_numeraire_carry, get_pricing_date(ctx))
end

@inline function lower_risk_neutral_probability!(ctx::CompilerContext{B}, dates_range::InterestRates.DailyDatesRange, current_time_step::Integer, state_variables::StateVariables) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}

    model = get_pricing_model(ctx)

    fwd_start_date = dates_range[current_time_step]
    fwd_end_date = dates_range[current_time_step + 1]

    numeraire_carry_symbol = get_riskfree_curve_symbol(model.static_model, ctx.attr["riskfree_curves"], SpotCurrency(model.static_model.functional_currency))

    # For Stocks, the carry is the dividend yield
    underlying_carry_symbol = get_riskfree_curve_symbol(model.static_model, ctx.attr["riskfree_curves"], model.underlying)

    # exp(r-q)Δt = df_underlying_carry / df_numeraire_carry
    df_underlying_carry = DiscountFactorForward(underlying_carry_symbol, fwd_start_date, fwd_end_date)
    df_numeraire_carry = DiscountFactorForward(numeraire_carry_symbol, fwd_start_date, fwd_end_date)
    ert = lower!(clone_context_with_model(ctx, model.static_model), df_underlying_carry / df_numeraire_carry, get_pricing_date(ctx))

    d = state_variables.d
    u = state_variables.u

    return add_instruction!(ctx, OP_BINOMIAL_RISK_NEUTRAL_PROBABILITY, d, ert, u)
end

function lower!(ctx::CompilerContext{B}, c::Unit{Stock}, state::BinomialModelState) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}
    model = get_pricing_model(ctx)
    @assert c.o == model.underlying "Expected $(model.underlying) as underlying. Got. $(c.o)."
    s = state.state_variables.s
    ln_u = state.state_variables.ln_u
    ln_d = state.state_variables.ln_d
    n = lower!(ctx, Konst(state.current_time_step), state)
    i = lower!(ctx, Konst(state.current_state_of_nature), state)
    return add_instruction!(ctx, OP_BINOMIAL_UNDERLYING_PRICE_AT, s, n, i, ln_u, ln_d)
end

function lower!(ctx::CompilerContext{B}, v::Volatility, ::BinomialModelInitialState) :: OptimizingIR.ImmutableValue where {B<:BinomialModelDaily}
    return add_input_riskfactor!(ctx, v)
end

function lower!(ctx::CompilerContext{B}, unit::Unit{Stock}, ::BinomialModelInitialState) where {B<:BinomialModelDaily}
    # gets the stock price at the pricing_date, using the StaticHedgingModel
    model = get_pricing_model(ctx)
    pricing_date = get_pricing_date(ctx)
    static_context = clone_context_with_model(ctx, model.static_model)
    return lower!(static_context, unit, pricing_date)
end

function lower!(ctx::CompilerContext{BinomialModelDaily{C,P,U,T}}, c::Unit{SpotCurrency{C}}, s::AbstractBinomialModelState) :: OptimizingIR.ImmutableValue where {C<:Currencies.Currency, P, U, T}
    # Same currency -> no exch.
    # Acquisition at state `s`, possibly a future date.
    return lower!(ctx, Konst(1.0), s)
end
