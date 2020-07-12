
function _gen_bs_docstring()
    call = WhenAt(
            Date(2020, 5, 2),
            Either(
                    Both(
                            Unit(Stock(:PETR4)),
                            Give(Scale(Konst(20.0), Unit(SpotCurrency(Currencies.BRL))))
                        ),
                    Worthless()
                )
        )

    put = WhenAt(
            Date(2020, 5, 2),
            Either(
                    Both(
                            Scale(Konst(20.0), Unit(SpotCurrency(Currencies.BRL))),
                            Give(Unit(Stock(:PETR4)))
                        ),
                    Worthless()
                )
        )

    return """
    BlackScholesModel

Pricing model for european call or put.

# Constructor:

```
BlackScholesModel(
    functional_currency::Currency,
    provider::MarketData.AbstractMarketDataProvider,
    underlying::Stock
)
```

# European Call contract example

```
$call
```

For a Call contract, the leg from the `Both` contract
which is different from `Unit{Stock}`
is recognized as the option *strike*.

# European Put contract example

```
$put
```

For a Put contract, the leg from the `Both` contract
which is not a `Give`
is recognized as the option *strike*.

# *strike* valuation

The *strike* will be priced using the `StaticHedgingModel`
with the same functional currency as the `BlackScholesModel`.
"""
end

@doc _gen_bs_docstring() BlackScholesModel
