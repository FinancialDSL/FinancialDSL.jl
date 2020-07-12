
call = FinancialDSL.Core.european_call(:PETR4, 20.0BRL, Date(2020, 5, 2))
put = FinancialDSL.Core.european_put(:PETR4, 20.0BRL, Date(2020, 5, 2))

@testset "BS Model internal API" begin

    not_an_option = FinancialDSL.Core.Unit(FinancialDSL.Core.Stock(:PETR4))

    @test FinancialDSL.Core.Compiler.is_european_call_option(call)
    @test !FinancialDSL.Core.Compiler.is_european_call_option(put)
    @test !FinancialDSL.Core.Compiler.is_european_put_option(call)
    @test FinancialDSL.Core.Compiler.is_european_put_option(put)
    @test !FinancialDSL.Core.Compiler.is_european_call_option(FinancialDSL.Core.Unit(FinancialDSL.Core.Stock(:PETR4)))
    @test !FinancialDSL.Core.Compiler.is_european_put_option(FinancialDSL.Core.Unit(FinancialDSL.Core.Stock(:PETR4)))

    @test FinancialDSL.Core.Compiler.is_european_option(call)
    @test FinancialDSL.Core.Compiler.is_european_option(put)
    @test !FinancialDSL.Core.Compiler.is_european_option(not_an_option)

    @test FinancialDSL.Core.Compiler.EuropeanOptionLegs(call) == FinancialDSL.Core.Compiler.EuropeanOptionLegs(:call, FinancialDSL.Core.Unit(FinancialDSL.Core.Stock(:PETR4)), FinancialDSL.Core.Scale(FinancialDSL.Core.Konst(20.0), FinancialDSL.Core.Unit(FinancialDSL.Core.SpotCurrency(FinancialDSL.Currencies.BRL))))
    @test FinancialDSL.Core.Compiler.EuropeanOptionLegs(put) == FinancialDSL.Core.Compiler.EuropeanOptionLegs(:put, FinancialDSL.Core.Unit(FinancialDSL.Core.Stock(:PETR4)), FinancialDSL.Core.Scale(FinancialDSL.Core.Konst(20.0), FinancialDSL.Core.Unit(FinancialDSL.Core.SpotCurrency(FinancialDSL.Currencies.BRL))))
end

@testset "Pricing European Option" begin

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD, :PETR4 => Symbol("PETR4 DIVIDEND YIELD") ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, FinancialDSL.MarketData.EmptyMarketDataProvider(), currency_to_curves_map)
    black_scholes_model = FinancialDSL.Core.BlackScholesModel(static_model)
    attr = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 2))] = 0.95
    scenario_fixed[FinancialDSL.Core.Stock(:PETR4)] = 25.0BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 2))] = 0.8
    scenario_fixed[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))] = 0.3

    call_pricer = FinancialDSL.Core.compile_pricer(pricing_date, black_scholes_model, call, attr)
    put_pricer = FinancialDSL.Core.compile_pricer(pricing_date, black_scholes_model, put, attr)

    # pricing
    call_p = FinancialDSL.Core.price(call_pricer, scenario_fixed)
    put_p = FinancialDSL.Core.price(put_pricer, scenario_fixed)

    t = BusinessDays.bdayscount(:Brazil, pricing_date, Date(2020, 5, 2)) / 252
    s = 25.0 * 0.95
    k = 20.0 * 0.8
    σ = 0.3

    @test call_p ≈ FinancialDSL.BS.bscall(s, k, t, σ)
    @test put_p ≈ FinancialDSL.BS.bsput(s, k, t, σ)

    native_call_pricer = FinancialDSL.Core.compile_pricer(pricing_date, black_scholes_model, call, attr, compiler=:native)
    native_put_pricer = FinancialDSL.Core.compile_pricer(pricing_date, black_scholes_model, put, attr, compiler=:native)
    @test call_p ≈ FinancialDSL.Core.price(native_call_pricer, scenario_fixed)
    @test put_p ≈ FinancialDSL.Core.price(native_put_pricer, scenario_fixed)

    # exposures
    call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), call_pricer, scenario_fixed)
    put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), put_pricer, scenario_fixed)

    native_call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_call_pricer, scenario_fixed)
    native_put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_put_pricer, scenario_fixed)

    # delta
    delta_fwd_diff = call_exposures[FinancialDSL.Core.Stock(:PETR4)]
    delta_bs = 25.0 * 0.95 * FinancialDSL.BS.delta(FinancialDSL.BS.EuropeanCall(), s, k, t, σ)
    @test delta_fwd_diff ≈ delta_bs
    @test delta_fwd_diff ≈ native_call_exposures[FinancialDSL.Core.Stock(:PETR4)]

    # vega
    vega_fwd_diff = call_exposures[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))]
    vega_bs = σ * FinancialDSL.BS.vega(s, k, t, σ)
    @test vega_fwd_diff ≈ vega_bs
    @test vega_fwd_diff ≈ native_call_exposures[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))]

    # gamma
    gamma_fwd_diff = call_exposures[FinancialDSL.Core.SecondOrderRiskFactor(FinancialDSL.Core.Stock(:PETR4))]
    gamma_bs = 0.5 * FinancialDSL.BS.gamma(s, k, t, σ) * s^2
    @test gamma_fwd_diff ≈ gamma_bs
end

@testset "BS European Call" begin
    k = 0.88
    maturity = Date(2025, 10, 28)
    ticker = :UNDERLYING_STOCK
    pricing_date = Date(2020, 3, 6)
    qty = 339_824

    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :UNDERLYING_STOCK => Symbol("UNDERLYING_STOCK DIVIDEND YIELD") ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, FinancialDSL.MarketData.EmptyMarketDataProvider(), currency_to_curves_map)
    black_scholes_model = FinancialDSL.Core.BlackScholesModel(static_model)
    attr = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")

    contract = FinancialDSL.Core.european_call(ticker, k*BRL, maturity)

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("UNDERLYING_STOCK DIVIDEND YIELD"), maturity)] = 1.0
    scenario_fixed[FinancialDSL.Core.Stock(:UNDERLYING_STOCK)] = 2.14BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, maturity)] = 0.7088448249661002
    scenario_fixed[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:UNDERLYING_STOCK))] = 1.01393597487

    pricer = FinancialDSL.Core.compile_pricer(pricing_date, black_scholes_model, contract, attr)
    p = FinancialDSL.Core.price(pricer, scenario_fixed)
    ex = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), pricer, scenario_fixed)

    @test p ≈ 1.89492553836
    @test qty * p ≈ 643941.1761486751
    @test qty * ex[FinancialDSL.Core.Stock(:UNDERLYING_STOCK)] ≈ 695852.3823994318
    @test qty * ex[FinancialDSL.Core.SecondOrderRiskFactor(FinancialDSL.Core.Stock(:UNDERLYING_STOCK))] ≈ 13844.789831796134
    @test qty * ex[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:UNDERLYING_STOCK))] ≈ 160294.74401978508
    @test qty * ex[FinancialDSL.Core.DiscountFactor(:PRE, Date(2025, 10, 28))] ≈ -51911.20625075656

    # TODO fix volatility exposure
    @test (qty * ex[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:UNDERLYING_STOCK))] / 1.01393597487) == 158091.58368242823
end
