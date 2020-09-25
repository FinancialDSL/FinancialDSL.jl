
#
# FutureValueModel
#

function initial_state(ctx::CompilerContext{F}) where {F<:FutureValueModel}
    return get_pricing_date(ctx)
end

function lower!(ctx::CompilerContext{F}, rf::RiskFactor, state) :: OptimizingIR.ImmutableValue where {F<:FutureValueModel}
    # in StaticHedging, all risk factors are valued in the pricing date
    assert_at_initial_state(ctx, state)
    return add_input_riskfactor!(ctx, rf)
end

function lower!(ctx::CompilerContext{FutureValueModel{C}}, c::Unit{SpotCurrency{C}}, at::Date) :: OptimizingIR.ImmutableValue where {C<:Currencies.Currency}
    assert_at_initial_state(ctx, at)
    # same currency
    return lower!(ctx, Konst(1.0), at)
end

function lower!(ctx::CompilerContext{FutureValueModel{C1}}, c::Unit{SpotCurrency{C2}}, at::Date) :: OptimizingIR.ImmutableValue where {C1<:Currencies.Currency, C2<:Currencies.Currency}
    assert_at_initial_state(ctx, at)
    return lower!(ctx, c.o, at)
end

function lower!(ctx::CompilerContext{F}, o::ObservableAt, at::Date) :: OptimizingIR.ImmutableValue where {F<:FutureValueModel}
    @assert o.at <= at "Observable date was fixed to ($(o.at)), and can't be valued after date ($(at))"
    return lower!(ctx, o.o, o.at)
end

function lower!(ctx::CompilerContext{F}, c::WhenAt{U}, at::Date) :: OptimizingIR.ImmutableValue where {U<:Unit, F<:FutureValueModel}
    assert_at_initial_state(ctx, at)
    if get_pricing_date(ctx) > c.maturity
        # ignore old cashflows
        return lower!(ctx, Worthless(), at)
    end

    # disable discounted cashflow rule for FutureValueModel
    unit = c.c
    return lower!(ctx, unit, at)
end

# TODO: is this a general rule, or only applies to StaticHedgingModel / FutureValueModel ?
function lower!(ctx::CompilerContext{F}, c::WhenAt{Scale}, state) :: OptimizingIR.ImmutableValue where {F<:FutureValueModel}
    assert_at_initial_state(ctx, state)
    pricing_date = get_pricing_date(ctx)

    mat = c.maturity
    scale_contract = c.c
    scale_observable = scale_contract.s
    scale_inner_contract = scale_contract.c

    if pricing_date > mat
        # ignore old cashflows
        return lower!(ctx, Worthless(), state)
    elseif pricing_date == mat
        # returns the underlying asset value if at maturity
        return lower!(ctx, c.c, state)
    end

    # obtains the observable value at the acquisition date
    arg1 = lower!(ctx, scale_observable, mat) # TODO: this should be a problem if we wanted to apply this as a general rule
    arg2 = lower!(ctx, WhenAt(mat, scale_inner_contract), state)

    # arg1 * arg2
    return add_instruction!(ctx, OP_BIN_SCALAR_MUL, arg1, arg2)
end
