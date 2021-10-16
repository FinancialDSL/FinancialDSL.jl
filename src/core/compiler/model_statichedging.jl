
#
# Static Hedging
#

function initial_state(ctx::CompilerContext{M}) where {M<:StaticHedgingModel}
    return get_pricing_date(ctx)
end

function get_riskfree_curve_symbol(m::StaticHedgingModel, kind::String, rf::CashRiskFactor) :: Symbol
    @assert haskey(m.riskfree_curve_map, kind) "Pricing Model doesn't know about a riskfree curve of type $kind. These are the available types of riskfree curves: $(collect(keys(m.riskfree_curve_map)))."
    riskfree_curve_map = m.riskfree_curve_map[kind]
    sym = risk_factor_symbol(rf)
    @assert haskey(riskfree_curve_map, sym) "Riskfree curve mapping is missing for $sym in this pricing model. These are the available items: $(collect(keys(riskfree_curve_map)))."
    return riskfree_curve_map[sym]
end

function is_riskfree_discountfactor(model::StaticHedgingModel, kind::String, rf::DiscountFactor) :: Bool
    @assert haskey(model.riskfree_curve_map, kind) "Pricing Model doesn't know about a riskfree curve of type $kind. These are the available types of riskfree curves: $(collect(keys(model.riskfree_curve_map)))."
    riskfree_curve_map = model.riskfree_curve_map[kind]
    sym = market_data_symbol(rf)

    for curve_sym in values(riskfree_curve_map)
        if curve_sym == sym
            return true
        end
    end

    return false
end

# in StaticHedging, all risk factors are observed at the pricing_date
function lower!(ctx::CompilerContext{M}, rf::RiskFactor, at::Date) :: OptimizingIR.ImmutableValue where {M<:StaticHedgingModel}
    assert_at_initial_state(ctx, at)
    return add_input_riskfactor!(ctx, rf)
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
    return lower!(ctx, o.o, resolve_compile_time_value(ctx, o.at, at))
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
    carry_type = get_carry_type(ctx.attr)

    if (
        carry_type == CARRY_TYPE_NONE # there's no carry curve
        || (carry_type == CARRY_TYPE_CURVE && !has_carry_curve(ctx.attr, underlying) ) # there's a carry curve, but not for the current underlying
        || unit.carryless # the unit contract was declared caryless
        )

        # caryless cashflows are discounted using only the riskfree curve
        discount_factor_process = lower!(ctx, riskfree_discount_factor, at)

    elseif carry_type == CARRY_TYPE_CURVE
        carry_discount_factor_observable = DiscountFactor(get_carry_curve_symbol(ctx.attr, underlying), mat)
        riskfree_discount_factor_process = lower!(ctx, riskfree_discount_factor, at)
        carry_discount_factor_process = lower!(ctx, carry_discount_factor_observable, at)
        discount_factor_process = add_instruction!(ctx, OP_BIN_SCALAR_MUL, riskfree_discount_factor_process, carry_discount_factor_process)

    #elseif carry_type == "curve_lookup"
    #    error("carry_type $carry_type not implemented")
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
