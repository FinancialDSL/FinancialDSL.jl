
@testset "Algebra and Properties" begin
    @test USD == FinancialDSL.Currencies.Currency(:USD)
    @test FinancialDSL.Currencies.currency_symbol(FinancialDSL.Currencies.Currency(:X)) === :X
    @test 1BRL == FinancialDSL.Currencies.Cash{FinancialDSL.Currencies.Currency{:BRL}, Int}(1)
    @test 10.2BRL > 10BRL
    @test 1BRL + 20.5BRL == 21.5BRL
    @test 100BRL * 0.5BRL == 50BRL
    @test 100BRL / 10BRL == 10
    @test 100BRL / 10 == 10BRL
    @test isapprox(10.334BRL, 10.334BRL)
    @test FinancialDSL.Currencies.cashcurrency(10.0BRL) == BRL
    @test FinancialDSL.Currencies.cashvalue(10.0BRL) == 10.0
end

@testset "exch" begin
    provider = FinancialDSL.Core.FixedScenario()
    provider[USD] = 3.5BRL
    provider[EUR] = 4.0BRL

    usd_price = FinancialDSL.Currencies.cashvalue(provider[USD])
    @test usd_price == 3.5

    eur_price = FinancialDSL.Currencies.cashvalue(provider[EUR])
    @test eur_price == 4.0

    @test FinancialDSL.Currencies.cashcurrency(provider[EUR]) == BRL

    @test FinancialDSL.Core.exch(provider, BRL, BRL) == 1.0
    @test FinancialDSL.Core.exch(provider, EUR, EUR) == 1.0
    @test FinancialDSL.Core.exch(provider, FinancialDSL.Currencies.Currency(:X), FinancialDSL.Currencies.Currency(:X)) == 1.0
    @test FinancialDSL.Core.exchcash(provider, BRL, BRL) == 1.0BRL
    @test FinancialDSL.Core.exchcash(provider, EUR, EUR) == 1.0EUR

    @test FinancialDSL.Core.exch(provider, BRL, USD) == 1.0 / usd_price
    @test FinancialDSL.Core.exch(provider, BRL, EUR) == 1.0 / eur_price
    @test FinancialDSL.Core.exchcash(provider, BRL, EUR) == (1.0 / eur_price)*EUR

    @test FinancialDSL.Core.exch(provider, USD, BRL) == usd_price
    @test FinancialDSL.Core.exch(provider, EUR, BRL) == eur_price
    @test FinancialDSL.Core.exchcash(provider, EUR, BRL) == eur_price*BRL

    @test FinancialDSL.Core.exch(provider, EUR, USD) == eur_price / usd_price
    @test FinancialDSL.Core.exchcash(provider, EUR, USD) == (eur_price / usd_price)*USD
end
