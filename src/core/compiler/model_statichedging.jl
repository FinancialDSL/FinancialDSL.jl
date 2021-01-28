
#
# Static Hedging
#

function initial_state(ctx::CompilerContext{M}) where {M<:StaticHedgingModel}
    return get_pricing_date(ctx)
end

function get_riskfree_curve_symbol(m::StaticHedgingModel, kind::String, rf::CashRiskFactor) :: Symbol
    @assert haskey(m.riskfree_curve_map, kind) "Pricing Model doesn't know about a carry curve of type $kind. These are the available types of carry curves: $(collect(keys(m.riskfree_curve_map)))."
    riskfree_curve_map = m.riskfree_curve_map[kind]
    sym = risk_factor_symbol(rf)
    @assert haskey(riskfree_curve_map, sym) "Risk factor $sym not available in this pricing model. These are the available items: $(collect(keys(riskfree_curve_map)))."
    return riskfree_curve_map[sym]
end

# in StaticHedging, all risk factors are observed at the pricing_date
function lower!(ctx::CompilerContext{M}, rf::RiskFactor, at::Date) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)
    return add_input_riskfactor!(ctx, rf)
end

function lower!(ctx::CompilerContext{M}, fwd::DiscountFactorForward, at::Date) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)

    if get_pricing_date(ctx) == fwd.start_date
        # when at start date, a DiscountFactorForward can be simplified to a DiscountFactor
        return lower!(ctx, DiscountFactor(fwd.sym, fwd.end_date), at)
    else
        arg1 = lower!(ctx, DiscountFactor(fwd.sym, fwd.end_date), at)
        arg2 = lower!(ctx, DiscountFactor(fwd.sym, fwd.start_date), at)

        # arg1 / arg2
        return add_instruction!(ctx, OP_BIN_SCALAR_DIV, arg1, arg2)
    end
end

# simplifies innner DiscountFactorForward
function lower!(ctx::CompilerContext{M}, rf::FixedNonCashRiskFactor{DiscountFactorForward}, at::Date) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)
    fwd = rf.rf
    if get_pricing_date(ctx) == fwd.start_date
        # when at start date, a DiscountFactorForward can be simplified to a DiscountFactor
        return lower!(ctx, FixedNonCashRiskFactor(DiscountFactor(fwd.sym, fwd.end_date), rf.val), at)
    else
        arg1 = lower!(ctx, FixedNonCashRiskFactor(DiscountFactor(fwd.sym, fwd.end_date), rf.val), at)
        arg2 = lower!(ctx, FixedNonCashRiskFactor(DiscountFactor(fwd.sym, fwd.start_date), 1.0), at)

        # arg1 / arg2
        return add_instruction!(ctx, OP_BIN_SCALAR_DIV, arg1, arg2)
    end
end

function lower!(ctx::CompilerContext{StaticHedgingModel{C}}, c::Unit{SpotCurrency{C}}, at::Date) :: OptimizingIR.ImmutableValue where {C<:Currencies.Currency}
    assert_at_initial_state(ctx, at)
    # same currency
    return lower!(ctx, Konst(1.0), at)
end

function lower!(ctx::CompilerContext{StaticHedgingModel{C1}}, c::Unit{SpotCurrency{C2}}, at::Date) :: OptimizingIR.ImmutableValue where {C1<:Currencies.Currency, C2<:Currencies.Currency}
    assert_at_initial_state(ctx, at)
    return lower!(ctx, c.o, at)
end

function lower!(ctx::CompilerContext{M}, c::Unit{Stock}, at::Date) where {M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)
    return lower!(ctx, c.o, at)
end

function lower!(ctx::CompilerContext{M}, o::ObservableAt, at::Date) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
    @assert o.at <= at "Observable date was fixed to ($(o.at)), and can't be valued after date ($(at))"
    return lower!(ctx, o.o, o.at)
end

# Present Value for a Unit
function lower!(ctx::CompilerContext{M}, c::WhenAt{U}, at::Date) :: OptimizingIR.ImmutableValue where {U<:Unit, M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)
    pricing_date = get_pricing_date(ctx)

    unit = c.c
    underlying = unit.o
    mat = c.maturity

    if pricing_date > mat
        # ignore old cashflows
        return lower!(ctx, Worthless(), at)
    elseif pricing_date == mat
        # returns the underlying asset value if at maturity
        return lower!(ctx, c.c, at)
    end

    riskfree_discount_factor = DiscountFactor(get_riskfree_curve_symbol(ctx.model, ctx.attr["riskfree_curves"], underlying), mat)

    carry_type = ctx.attr["carry_type"]

    if (
        carry_type == "none" # there's no carry curve
        || (carry_type == "curve" && !has_carry_curve(ctx.attr, underlying) ) # there's a carry curve, but not for the current underlying
        || unit.carryless # the unit contract was declared caryless
        )

        # caryless cashflows are discounted using only the riskfree curve
        discount_factor_process = lower!(ctx, riskfree_discount_factor, at)

    elseif carry_type == "curve"
        carry_discount_factor_observable = DiscountFactor(get_carry_curve_symbol(ctx.attr, underlying), mat)
        riskfree_discount_factor_process = lower!(ctx, riskfree_discount_factor, at)
        carry_discount_factor_process = lower!(ctx, carry_discount_factor_observable, at)
        discount_factor_process = add_instruction!(ctx, OP_BIN_SCALAR_MUL, riskfree_discount_factor_process, carry_discount_factor_process)

    elseif carry_type == "curve_lookup"
        error("carry_type $carry_type not implemented")
        #contract_id = get(attr, :extern_contract_id, missing)
        #counterpart_id = get(attr, :extern_counterpart_id, missing)

    else
        error("Attribute carry_type='$carry_type' not supported.")
    end

    unit_process = lower!(ctx, unit, at)

    # unit_process * discount_factor_process
    return add_instruction!(ctx, OP_BIN_SCALAR_MUL, unit_process, discount_factor_process)
end

# TODO: is this a general rule, or only applies to StaticHedgingModel / FutureValueModel ?
function lower!(ctx::CompilerContext{M}, c::WhenAt{Scale}, state) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
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
