
# BlackScholesModel

function initial_state(ctx::CompilerContext{B}) where {B<:BlackScholesModel}
    get_pricing_date(ctx)
end

# An EuropeanOption is recognized as a Call
# when the `Both` contract has a `Unit{Stock} leg.
function is_european_call_option(c::EuropeanOption)
    both_contract = c.c.c1::Both
    return (isa(both_contract.c1, Unit{Stock}) || isa(both_contract.c2, Unit{Stock})) && (isa(both_contract.c1, Give) || isa(both_contract.c2, Give))
end

# An EuropeanOption is recognized as a Put
# when the `Both` contract has a Give(Unit{Stock}) leg.
function is_european_put_option(c::EuropeanOption)
    both_contract = c.c.c1::Both

    if !(isa(both_contract.c1, Give) || isa(both_contract.c2, Give))
        return false
    end

    give_contract = isa(both_contract.c1, Give) ? both_contract.c1 : both_contract.c2
    @assert isa(give_contract, Give)
    return isa(give_contract.c, Unit{Stock})
end

is_european_call_option(c::Contract) = false
is_european_put_option(c::Contract) = false

struct EuropeanOptionLegs
    call_or_put::Symbol
    stock::Unit{Stock}
    strike::Contract
end

function EuropeanOptionLegs(c::EuropeanOption)
    both_contract = c.c.c1::Both

    if is_european_call_option(c)
        call_or_put = :call
        if isa(both_contract.c1, Unit{Stock})
            return EuropeanOptionLegs(call_or_put, both_contract.c1, both_contract.c2.c)
        else
            return EuropeanOptionLegs(call_or_put, both_contract.c2, both_contract.c1.c)
        end
    elseif is_european_put_option(c)
        call_or_put = :put
        if isa(both_contract.c1, Give)
            return EuropeanOptionLegs(call_or_put, both_contract.c1.c, both_contract.c2)
        else
            return EuropeanOptionLegs(call_or_put, both_contract.c2.c, both_contract.c1)
        end
    end

    error("Contract was not recognized as an European Option: $c.")
end

function is_european_option(c::EuropeanOption)
    return is_european_call_option(c) || is_european_put_option(c)
end

is_european_option(c::Contract) = false
check_is_european_option(c::EuropeanOption) = @assert is_european_option(c) "Contract is not an European Option: $c."

# WhenAt -> Either{Both, Worthless}
# Call: Both -> Unit{Stock}, Give(c)
# Put:  Both -> c, Give(Unit{Stock})
function lower!(ctx::CompilerContext{B}, c::EuropeanOption, at::Date) :: OptimizingIR.ImmutableValue where {B<:BlackScholesModel}

    check_is_european_option(c)
    assert_at_initial_state(ctx, at)

    maturity = c.maturity
    legs = EuropeanOptionLegs(c)
    underlying_stock_observable = legs.stock.o

    yf_to_maturity = yearfraction(ctx, maturity)
    arg_years_to_maturity = lower!(ctx, Konst(yf_to_maturity), at)
    arg_stock = lower!(clone_context_with_model(ctx, ctx.model.static_model), WhenAt(maturity, legs.stock), at)
    arg_strike = lower!(clone_context_with_model(ctx, ctx.model.static_model), WhenAt(maturity, legs.strike), at)
    arg_vol = lower!(ctx, Volatility(underlying_stock_observable), at)

    op_bs = legs.call_or_put == :call ? OP_BLACK_FORMULA_CALL : OP_BLACK_FORMULA_PUT
    return add_instruction!(ctx, op_bs, arg_stock, arg_strike, arg_years_to_maturity, arg_vol)
end

function yearfraction(ctx::CompilerContext{B}, maturity::Date) where {B<:BlackScholesModel}
    # TODO : maybe look at the convention of the riskfree curve of the functional currency...
    if get_functional_currency(ctx.model) == Currencies.BRL
        return InterestRates.yearfractionvalue(InterestRates.BDays252(CAL_BRL), get_pricing_date(ctx), maturity)
    else
        error("Functional currency $(get_functional_currency(ctx.model)) not supported by `Compiler.yearfraction`.")
    end
end

function lower!(ctx::CompilerContext{B}, v::Volatility, at::Date) :: OptimizingIR.ImmutableValue where {B<:BlackScholesModel}
    assert_at_initial_state(ctx, at)
    return add_input_riskfactor!(ctx, v)
end
