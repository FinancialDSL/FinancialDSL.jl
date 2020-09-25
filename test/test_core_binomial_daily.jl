
@testset "Pricing European Option" begin
    pricing_date = Date(2020, 5, 14)
    call = FinancialDSL.Core.european_call(:PETR4, 20.0BRL, Date(2020, 5, 19))
    put = FinancialDSL.Core.european_put(:PETR4, 20.0BRL, Date(2020, 5, 19))

    @testset "internal DailyDatesRange" begin
        dd = InterestRates.DailyDatesRange(pricing_date, call.maturity, InterestRates.BDays252(FinancialDSL.CAL_BRL))
        @test length(dd) == 4
        dd[1] == Date(2020, 5, 14)
        dd[2] == Date(2020, 5, 15)
        dd[3] == Date(2020, 5, 18)
        dd[4] == Date(2020, 5, 19)
        @test dd[end] == call.maturity
        @test InterestRates.yearfractionvalue(dd) ≈ 1/252
    end

    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD, :PETR4 => Symbol("PETR4 DIVIDEND YIELD") ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    binomial_daily_model = FinancialDSL.Core.BinomialModelDaily(static_model, FinancialDSL.Core.Stock(:PETR4), InterestRates.BDays252(BusinessDays.BRSettlement()))
    attr = FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

#=
PETR4 (underlying price)    N/A 20
PRE 15/05/2020  0,9
PRE 18/05/2020  0,8
PRE 19/05/2020  0,7
underlying carry    15/05/2020  0,95
underlying carry    18/05/2020  0,93
underlying carry    19/05/2020  0,91
underlying volatility   N/A 200%
=#

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.Stock(:PETR4)] = 20.0BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 15))] = 0.9
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 18))] = 0.8
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 19))] = 0.7
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 15))] = 0.95
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 18))] = 0.93
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 19))] = 0.91
    scenario_fixed[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))] = 2.00 # 200%

    call_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, call, attr)
    put_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, put, attr)

    # pricing
    call_p = FinancialDSL.Core.price(call_pricer, scenario_fixed)
    @test call_p ≈ 4.312249551607606
    put_p = FinancialDSL.Core.price(put_pricer, scenario_fixed)
    @test put_p ≈ 0.11224955160760348

    native_call_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, call, attr, compiler=:native)
    native_put_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, put, attr, compiler=:native)
    @test call_p ≈ FinancialDSL.Core.price(native_call_pricer, scenario_fixed)
    @test put_p ≈ FinancialDSL.Core.price(native_put_pricer, scenario_fixed)

    # exposures
    call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), call_pricer, scenario_fixed)
    put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), put_pricer, scenario_fixed)

    #println("European Call Exposures")
    #for (k, v) in call_exposures
    #    println()
    #    println("$k => $v")
    #    println()
    #end

    native_call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_call_pricer, scenario_fixed)
    native_put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_put_pricer, scenario_fixed)

    #println("european native_call_exposures = $native_call_exposures")
end

@testset "Pricing American Option" begin
    pricing_date = Date(2020, 5, 14)
    call = FinancialDSL.Core.american_call(:PETR4, 20.0BRL, Date(2020, 5, 19))
    put = FinancialDSL.Core.american_put(:PETR4, 20.0BRL, Date(2020, 5, 19))

    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD, :PETR4 => Symbol("PETR4 DIVIDEND YIELD") ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    binomial_daily_model = FinancialDSL.Core.BinomialModelDaily(static_model, FinancialDSL.Core.Stock(:PETR4), InterestRates.BDays252(BusinessDays.BRSettlement()))
    attr = FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

#=
PETR4 (underlying price)    N/A 20
PRE 15/05/2020  0,9
PRE 18/05/2020  0,8
PRE 19/05/2020  0,7
underlying carry    15/05/2020  0,95
underlying carry    18/05/2020  0,93
underlying carry    19/05/2020  0,91
underlying volatility   N/A 200%
=#

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.Stock(:PETR4)] = 20.0BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 15))] = 0.9
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 18))] = 0.8
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 19))] = 0.7
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 15))] = 0.95
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 18))] = 0.93
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 19))] = 0.91
    scenario_fixed[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))] = 2.00 # 200%

    call_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, call, attr)
    put_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, put, attr)

    # pricing
    call_p = FinancialDSL.Core.price(call_pricer, scenario_fixed)
    @test call_p ≈ 4.312249551607606
    put_p = FinancialDSL.Core.price(put_pricer, scenario_fixed)
    @test put_p ≈ 0.6732693664447074

    native_call_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, call, attr, compiler=:native)
    native_put_pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, put, attr, compiler=:native)
    @test call_p ≈ FinancialDSL.Core.price(native_call_pricer, scenario_fixed)
    @test put_p ≈ FinancialDSL.Core.price(native_put_pricer, scenario_fixed)

    # exposures
    call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), call_pricer, scenario_fixed)
    put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), put_pricer, scenario_fixed)

    #println("american call_exposures = $call_exposures")

    native_call_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_call_pricer, scenario_fixed)
    native_put_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), native_put_pricer, scenario_fixed)

    #println("american native_call_exposures = $native_call_exposures")
end

@testset "Pricing ZCB" begin
    pricing_date = Date(2020, 5, 14)
    zcb = FinancialDSL.Core.WhenAt(Date(2020, 5, 19), FinancialDSL.Core.Amount(1000.0BRL))

    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD, :PETR4 => Symbol("PETR4 DIVIDEND YIELD") ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    binomial_daily_model = FinancialDSL.Core.BinomialModelDaily(static_model, FinancialDSL.Core.Stock(:PETR4), InterestRates.BDays252(BusinessDays.BRSettlement()))
    attr = FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.Stock(:PETR4)] = 20.0BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 15))] = 0.9
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 18))] = 0.8
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 19))] = 0.7
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 15))] = 0.95
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 18))] = 0.93
    scenario_fixed[FinancialDSL.Core.DiscountFactor(Symbol("PETR4 DIVIDEND YIELD"), Date(2020, 5, 19))] = 0.91
    scenario_fixed[FinancialDSL.Core.Volatility(FinancialDSL.Core.Stock(:PETR4))] = 2.00 # 200%

    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, binomial_daily_model, zcb, attr)
    p = FinancialDSL.Core.price(pricer, scenario_fixed)
    @test p ≈ 1000.0 * 0.7

    zcb_exposures = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaGammaApproxExposuresMethod(), pricer, scenario_fixed)
    @test length(zcb_exposures) == 1
    @test zcb_exposures[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 5, 19))] ≈ 1000.0 * 0.7
end
