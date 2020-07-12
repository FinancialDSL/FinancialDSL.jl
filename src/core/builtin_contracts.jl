
function Amount(amount::Currencies.Cash)
    currency = Currencies.cashcurrency(amount)
    val = Currencies.cashvalue(amount)
    return Amount(val, currency)
end

function Amount(value::Number, currency::Currencies.Currency)
    if value == 0
        return Worthless()
    elseif value == 1
        return Unit(currency)
    else
        return Amount(Konst(value), currency)
    end
end

function Amount(obs::Observable, currency::Currencies.Currency)
    currency_unit = Unit(currency)
    return Scale(obs, currency_unit)
end

Unit(c::Currencies.Currency; carryless::Bool=false) = Unit(SpotCurrency(c), carryless=carryless)

ZCB(mat::Date, amount::Currencies.Cash) = Currencies.cashvalue(amount) == 0 ? Worthless() : WhenAt(mat, Amount(amount))

Forward(mat::Date, amount::Currencies.Cash, strike::Currencies.Cash) = WhenAt(mat, Both(Amount(amount), Give(Amount(strike))))

const EuropeanOption = WhenAt{Either{Both, Worthless}}

function european_call(stock_ticker::Symbol, k::Currencies.Cash, maturity::Date)
    WhenAt(
        maturity,
        Either(
                Both(
                        Unit(Stock(stock_ticker)),
                        Give(Amount(k))
                    ),
                Worthless()
            )
    )
end

function european_put(stock_ticker::Symbol, k::Currencies.Cash, maturity::Date)
    WhenAt(
        maturity,
        Either(
                Both(
                        Amount(k),
                        Give(Unit(Stock(stock_ticker)))
                    ),
                Worthless()
            )
    )
end

function american_call(stock_ticker::Symbol, k::Currencies.Cash, maturity::Date)
    Anytime(
        maturity,
        Either(
                Both(
                        Unit(Stock(stock_ticker)),
                        Give(Amount(k))
                    ),
                Worthless()
            )
    )
end

function american_put(stock_ticker::Symbol, k::Currencies.Cash, maturity::Date)
    Anytime(
        maturity,
        Either(
                Both(
                        Amount(k),
                        Give(Unit(Stock(stock_ticker)))
                    ),
                Worthless()
            )
    )
end
