
@testset "ContractAttributes" begin
    a1 = FinancialDSL.Core.ContractAttributes()
    a2 = FinancialDSL.Core.ContractAttributes()

    @test a1 == a2
    @test hash(a1) == hash(a2)

    a1["hey"] = "you"
    @test a1["hey"] == "you"
    a1["maturity"] = Date(2018, 2, 1)
    a1["spread"] = 10.2

    @test a1 != a2
    @test a2 != a1
    @test hash(a1) != hash(a2)

    a2["hey"] = "you"
    @test a1 != a2
    @test a2 != a1

    a2["maturity"] = Date(2018, 2, 1)
    a2["spread"] = 10.2

    @test a1 == a2
    @test a2 == a1
    @test hash(a1) == hash(a2)

    attributes = FinancialDSL.Core.ContractAttributes("price_serie" => Dict("serie_name" => "DI1Q18"))
end

@testset "equality para RiskFactors" begin
    @test FinancialDSL.Core.SpotCurrency(USD) == FinancialDSL.Core.SpotCurrency(USD)
    @test hash(FinancialDSL.Core.SpotCurrency(USD)) == hash(FinancialDSL.Core.SpotCurrency(USD))
    @test FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)) == FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))
    @test hash(FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))) == hash(FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)))
    v = [ FinancialDSL.Core.SpotCurrency(USD), FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)) ]
    @test FinancialDSL.Core.SpotCurrency(USD) ∈ v
    @test FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)) ∈ v
    @test FinancialDSL.Core.SpotCurrency(BRL) ∉ v
    @test FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 3)) ∉ v
    @test FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2)) ∉ v
end

@testset "Builtin contracts" begin
    @test FinancialDSL.Core.Amount(2.0BRL) == FinancialDSL.Core.Amount(2.0, BRL)
    @test FinancialDSL.Core.Amount(1.0BRL) == FinancialDSL.Core.Unit(BRL)
    @test FinancialDSL.Core.Amount(1.0, BRL) == FinancialDSL.Core.Unit(BRL)
    @test FinancialDSL.Core.Amount(0.0BRL) == FinancialDSL.Core.Worthless()
    @test FinancialDSL.Core.Amount(0.0, BRL) == FinancialDSL.Core.Worthless()
end

@testset "Observables Albebra" begin
    @testset "Konst eager algebra" begin
        k = FinancialDSL.Core.Konst(2.0)
        @test !iszero(k)
        @test !FinancialDSL.Core.iszerokonst(k)
        @test -k == FinancialDSL.Core.Konst(-2.0)
        @test -(-k) == k
        @test k^2 == FinancialDSL.Core.Konst(4.0)
        @test (1 + k)^(2) == FinancialDSL.Core.Konst((1+2.0)^2)
        @test 3^k == FinancialDSL.Core.Konst(9.0)

        kk = FinancialDSL.Core.Konst(3.0)
        @test k * kk == FinancialDSL.Core.Konst(6.0)
        @test k + kk == FinancialDSL.Core.Konst(5.0)
        @test k / kk == FinancialDSL.Core.Konst(2.0 / 3.0)
        @test kk - k == FinancialDSL.Core.Konst(1.0)

        @test FinancialDSL.Core.Konst(1) * 2.0 == FinancialDSL.Core.Konst(2.0)

        @test kk + kk * kk == FinancialDSL.Core.Konst(12.0)
        @test 2kk == FinancialDSL.Core.Konst(6.0)

        z = FinancialDSL.Core.Konst(0.0)
        @test iszero(z)
        @test FinancialDSL.Core.iszerokonst(z)
        z = FinancialDSL.Core.Konst(0)
        @test iszero(z)
        @test FinancialDSL.Core.iszerokonst(z)
        @test !FinancialDSL.Core.iszerokonst(FinancialDSL.Core.SpotCurrency(BRL))
    end

    @testset "Special functions" begin
        @test round(FinancialDSL.Core.Konst(2.2)) == FinancialDSL.Core.Konst(2.0)
        @test round(FinancialDSL.Core.Konst(2.23); digits=1) == FinancialDSL.Core.Konst(2.2)

        @test trunc(FinancialDSL.Core.Konst(2.8)) == FinancialDSL.Core.Konst(2.0)
        @test trunc(FinancialDSL.Core.Konst(2.83); digits=1) == FinancialDSL.Core.Konst(2.8)
    end

    @testset "Konst +, *, - obs optim" begin
        obs = FinancialDSL.Core.SpotCurrency(BRL)
        k1 = FinancialDSL.Core.Konst(2.0)
        k2 = FinancialDSL.Core.Konst(3.0)

        @testset "*" begin
            expected_result = FinancialDSL.Core.LiftObs2(*, FinancialDSL.Core.Konst(6.0), obs)
            @test k1 * (k2 * obs) == expected_result
            @test k1 * (obs * k2) == expected_result
            @test (k1 * obs) * k2 == expected_result
            @test (obs * k1) * k2 == expected_result
            @test k1 * k2 * obs == expected_result
            @test k1 * obs * k2 == expected_result
            @test obs * k1 * k2 == expected_result
        end

        @testset "+" begin
            expected_result = FinancialDSL.Core.LiftObs2(+, FinancialDSL.Core.Konst(5.0), obs)
            @test k1 + (k2 + obs) == expected_result
            @test k1 + (obs + k2) == expected_result
            @test (k1 + obs) + k2 == expected_result
            @test (obs + k1) + k2 == expected_result
            @test k1 + k2 + obs == expected_result
            @test k1 + obs + k2 == expected_result
            @test obs + k1 + k2 == expected_result
        end

        @testset "-" begin
            @test k1 - (k2 + obs) == (k1 - k2) + (-obs)
            @test k1 - (obs + k2) == (k1 - k2) + (-obs)
            @test k1 - (k2 - obs) == (k1 - k2) + obs
            @test k1 - (obs - k2) == (k1 + k2) + (-obs)
            @test (k1 - obs) + k2 == (k1 + k2) + (-obs)
            @test (k1 + obs) - k2 == (k1 - k2) + obs
            @test (obs - k1) + k2 == (k2 - k1) + obs
            @test (obs + k1) - k2 == (k1 - k2) + obs
            @test k2 + (k1 - obs) == (k1 + k2) + (-obs)
        end

        # mixing lifting and binary operators
        @test min(1.0, obs) == FinancialDSL.Core.LiftObs2(min, FinancialDSL.Core.Konst(1.0), obs)
        @test min(obs, 1.0) == FinancialDSL.Core.LiftObs2(min, obs, FinancialDSL.Core.Konst(1.0))
        @test max(1.0 + obs, obs) == FinancialDSL.Core.LiftObs2(max, FinancialDSL.Core.LiftObs2(+, FinancialDSL.Core.Konst(1.0), obs), obs)

        # Konst optimization does not apply to these cases
        @test k1 + k2 * obs == FinancialDSL.Core.LiftObs2(+, k1, FinancialDSL.Core.LiftObs2(*, k2, obs))
        @test k1 * k2 + obs == FinancialDSL.Core.LiftObs2(+, FinancialDSL.Core.Konst(6.0), obs)
        @test k1 * obs + k2 == FinancialDSL.Core.LiftObs2(+, FinancialDSL.Core.LiftObs2(*, k1, obs), k2)
        @test obs * k1 + k2 == FinancialDSL.Core.LiftObs2(+, FinancialDSL.Core.LiftObs2(*, obs, k1), k2)
    end

    @testset "exp and log" begin
        obs = FinancialDSL.Core.SpotCurrency(BRL)
        @test log(obs) == FinancialDSL.Core.LiftObs(log, obs)
        @test exp(obs) == FinancialDSL.Core.LiftObs(exp, obs)
        @test log(exp(obs)) == obs
        @test exp(log(obs)) == obs
    end
end

function scenario_map_function(rf::FinancialDSL.Core.SpotCurrency, val::FinancialDSL.Currencies.Cash)
    return val * 1.05
end

function scenario_map_function(rf::FinancialDSL.Core.DiscountFactor, val::Number)
    # 10% increase on BRL discount factor
    if FinancialDSL.Core.market_data_symbol(rf) === :PRE
        return identity(val)
    else
        return val * 1.1
    end
end

@testset "Scenarios" begin

    @testset "FixedScenario" begin
        scenario = FinancialDSL.Core.FixedScenario()
        scenario[FinancialDSL.Core.SpotCurrency(BRL)] = 1.0BRL
        scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7
        @test_throws ErrorException scenario[FinancialDSL.Core.SpotCurrency(USD)] = 10
        @test_throws ErrorException scenario[FinancialDSL.Core.SpotCurrency(USD)] = 10.0
        @test haskey(scenario, FinancialDSL.Core.SpotCurrency(BRL))
        @test haskey(scenario, FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)))
        @test scenario[FinancialDSL.Core.SpotCurrency(BRL)] == 1.0BRL
        @test scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] == 0.7
        scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2))] = 1
        @test scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2))] == 1.0
        @test isa(scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2))], Float64)
    end

    @testset "DebugScenario" begin
        scenario = FinancialDSL.Core.FixedScenario()
        scenario[FinancialDSL.Core.SpotCurrency(BRL)] = 1.0BRL
        scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7

        debug = FinancialDSL.Core.DebugScenario(scenario)
        @test haskey(debug, FinancialDSL.Core.SpotCurrency(BRL))
        @test debug[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] == 0.7
        @test length(debug.record) == 1
        @test debug.record[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] == 0.7
    end

    @testset "ScenarioMap" begin
        scenario = FinancialDSL.Core.FixedScenario()
        scenario[FinancialDSL.Core.SpotCurrency(BRL)] = 1.0BRL
        scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7
        scenario[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] = 0.8

        scenario_map = FinancialDSL.Core.ScenarioMap(scenario_map_function, scenario)
        @test scenario_map[FinancialDSL.Core.SpotCurrency(BRL)] ≈ 1.0 * 1.05 * BRL
        @test scenario_map[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] ≈ 0.7
        @test scenario_map[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] ≈ 0.8 * 1.1
    end
end

@testset "Compiler" begin
    include("test_core_compiler.jl")
end

@testset "Pricing and Exposures" begin

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    @test FinancialDSL.Core.is_riskfree_discountfactor(static_model, "onshore", FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)))
    @test !FinancialDSL.Core.is_riskfree_discountfactor(static_model, "onshore", FinancialDSL.Core.DiscountFactor(:OTHER_CURVE, Date(2019, 1, 2)))
    @test_throws AssertionError FinancialDSL.Core.is_riskfree_discountfactor(static_model, "offshore", FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)))

    o = FinancialDSL.Core.Konst(10.2)
    lo = FinancialDSL.Core.LiftObs(string, o)
    @test typeof(lo) == FinancialDSL.Core.LiftObs{typeof(string), String}

    o1 = FinancialDSL.Core.Konst(10)
    o2 = FinancialDSL.Core.Konst(20.0)
    lo = FinancialDSL.Core.LiftObs2(+, o1, o2)
    @test typeof(lo) == FinancialDSL.Core.LiftObs2{typeof(+), Float64}

    # Scenarios
    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.SpotCurrency(USD)] = 2.9BRL # dolar spot price
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7 # BRL discount factor
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] = 0.9 # USD discount factor
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2))] = 0.5
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2020, 1, 2))] = 0.8
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:spOnshoreAA, Date(2019, 1, 2))] = 0.99 # credit risk spread discount factor

    let
        other_scenario_fixed = FinancialDSL.Core.FixedScenario()
        other_scenario_fixed[FinancialDSL.Core.SpotCurrency(USD)] = 5.0BRL
        composite_scenario = FinancialDSL.Core.CompositeScenario([other_scenario_fixed, scenario_fixed])

        @test haskey(composite_scenario, FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2)))
        @test composite_scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 1, 2))] == 0.5
        @test composite_scenario[FinancialDSL.Core.SpotCurrency(USD)] == 5.0BRL
    end

    @testset "dolar spot" begin
        c_dol_spot = FinancialDSL.Core.Amount(10.0USD)
        pricer_dol_spot = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_dol_spot, FinancialDSL.Core.ContractAttributes())
        @test FinancialDSL.Core.price(pricer_dol_spot, scenario_fixed) == 2.9 * 10.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_dol_spot, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.9 * 10.0

        # spot position on USD with credit risk, should make no difference
        pricer_dol_spot_spAA = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_dol_spot, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "curve"))
        @test FinancialDSL.Core.price(pricer_dol_spot_spAA, scenario_fixed) == 2.9 * 10.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_dol_spot_spAA, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.9 * 10.0
    end

    @testset "FX zero-coupon" begin
        c_zcb_usd = FinancialDSL.Core.ZCB(Date(2019, 1, 2), 10.0USD)
        pricer_zcb_usd = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_zcb_usd, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none"))
        @test length(FinancialDSL.Core.riskfactors(pricer_zcb_usd)) == 2
        @test in(FinancialDSL.Core.SpotCurrency(USD), FinancialDSL.Core.riskfactors(pricer_zcb_usd))
        @test in(FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2)), FinancialDSL.Core.riskfactors(pricer_zcb_usd))
        @test FinancialDSL.Core.price(pricer_zcb_usd, scenario_fixed) ≈ 10.0 * 2.9 * 0.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_zcb_usd, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] ≈ 10.0 * 2.9 * 0.9
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] ≈ 10.0 * 2.9 * 0.9
    end

    @testset "FX zero-coupon with credit risk" begin
        c_zcb_usd = FinancialDSL.Core.ZCB(Date(2019, 1, 2), 10.0USD)
        pricer_zcb_usd_spAA = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_zcb_usd, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "curve", "carry_curves" => Dict("USD" => "spOnshoreAA")))
        @test length(FinancialDSL.Core.riskfactors(pricer_zcb_usd_spAA)) == 3
        @test in(FinancialDSL.Core.SpotCurrency(USD), FinancialDSL.Core.riskfactors(pricer_zcb_usd_spAA))
        @test in(FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2)), FinancialDSL.Core.riskfactors(pricer_zcb_usd_spAA))
        @test FinancialDSL.Core.price(pricer_zcb_usd_spAA, scenario_fixed) ≈ 10.0 * 2.9 * 0.9 * 0.99
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_zcb_usd_spAA, scenario_fixed)
        @test length(exposures_result) == 3
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] ≈ 10.0 * 2.9 * 0.9 * 0.99
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] ≈ 10.0 * 2.9 * 0.9 * 0.99
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:spOnshoreAA, Date(2019, 1, 2))] ≈ 10.0 * 2.9 * 0.9 * 0.99
    end

    @testset "BRL zero-coupon" begin
        c_zcb_pre = FinancialDSL.Core.ZCB(Date(2019, 1, 2), 1000.0BRL)
        pricer_zcb_pre = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_zcb_pre, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none"))
        @test length(FinancialDSL.Core.riskfactors(pricer_zcb_pre)) == 1
        @test FinancialDSL.Core.riskfactors(pricer_zcb_pre)[1] == FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))
        @test FinancialDSL.Core.price(pricer_zcb_pre, scenario_fixed) ≈ 1000.0 * 0.7
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_zcb_pre, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] ≈ 1000.0 * 0.7
    end

    @testset "BRL zero-coupon with credit risk" begin
        c_zcb_pre = FinancialDSL.Core.ZCB(Date(2019, 1, 2), 1000.0BRL)
        pricer_zcb_pre = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_zcb_pre, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "curve", "carry_curves" => Dict("BRL" => "spOnshoreAA")))
        @test length(FinancialDSL.Core.riskfactors(pricer_zcb_pre)) == 2
        @test FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2)) ∈ FinancialDSL.Core.riskfactors(pricer_zcb_pre)
        @test FinancialDSL.Core.price(pricer_zcb_pre, scenario_fixed) ≈ 1000.0 * 0.7 * 0.99
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_zcb_pre, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] ≈ 1000.0 * 0.7 * 0.99
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:spOnshoreAA, Date(2019, 1, 2))] ≈ 1000.0 * 0.7 * 0.99
    end

    @testset "spot position on functional currency" begin
        c_brl_spot = FinancialDSL.Core.Amount(1BRL)
        pricer_brl_spot = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_brl_spot, FinancialDSL.Core.ContractAttributes())
        @test FinancialDSL.Core.price(pricer_brl_spot, scenario_fixed) == 1.0
    end

    @testset "USD FWD without carry" begin
        c_future_usd = FinancialDSL.Core.Forward(Date(2019, 1, 2), 1USD, 2.9 * 0.9 / 0.7 * BRL)
        pricer_future_usd = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_future_usd, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none"))
        @test FinancialDSL.Core.price(pricer_future_usd, scenario_fixed) ≈ 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer_future_usd, scenario_fixed)
        @test length(exposures_result) == 3
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] ≈ 2.9 * 0.9
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] ≈ 2.9 * 0.9
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] ≈ - (2.9 * 0.9 / 0.7 * 0.7)
    end

    @testset "When{When}" begin
        c_when_when = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.ZCB(Date(2020, 1, 2), 1USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, c_when_when, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none"))
        @test FinancialDSL.Core.price(pricer, scenario_fixed) ≈ 2.9 * 0.8
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] ≈ 2.9 * 0.8
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2020, 1, 2))] ≈ 2.9 * 0.8
    end

    @testset "FutureValueModel" begin
        fvmodel = FinancialDSL.Core.FutureValueModel(static_model)

        c_zcb_brl = FinancialDSL.Core.ZCB(Date(2020, 1, 2), 10.0BRL)
        pricer_zcb_brl = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, fvmodel, c_zcb_brl, FinancialDSL.Core.ContractAttributes())
        @test FinancialDSL.Core.price(pricer_zcb_brl, scenario_fixed) == 10.0

        c_zcb_usd = FinancialDSL.Core.ZCB(Date(2020, 1, 2), 20.0USD)
        pricer_zcb_usd = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, fvmodel, c_zcb_usd, FinancialDSL.Core.ContractAttributes())
        @test FinancialDSL.Core.price(pricer_zcb_usd, scenario_fixed) ≈ 20.0 * 2.9
    end
end

@testset "Functional Currency FixedScenario" begin
    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model_usd = FinancialDSL.Core.StaticHedgingModel(USD, currency_to_curves_map)
    static_model_brl = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.SpotCurrency(USD)] = 2.9BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] = 0.9

    attr_onshore_carry_none = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")

    @testset "USD spot position with BRL as functional currency" begin
        c = FinancialDSL.Core.Amount(1.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.9
    end

    @testset "USD spot position with BRL as functional currency with Scale" begin
        c = FinancialDSL.Core.Amount(2.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0 * 2.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.0 * 2.9
    end

    @testset "USD Spot Worthless with BRL as functional currency" begin
        c = FinancialDSL.Core.Amount(0.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "USD spot position with USD as functional currency" begin
        c = FinancialDSL.Core.Amount(1.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 1.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result) # there are no exposures given that USD is the functional currency
    end

    @testset "USD spot position with USD as functional currency with Scale" begin
        c = FinancialDSL.Core.Amount(2.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result) # there are no exposures given that USD is the functional currency
    end

    @testset "USD Spot Worthless with USD as functional currency" begin
        c = FinancialDSL.Core.Amount(0.0USD)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result) # there are no exposures given that USD is the functional currency
    end

    @testset "zero-coupon USD with BRL as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(1.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.9 * 0.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.9 * 0.9
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] == 2.9 * 0.9
    end

    @testset "zero-coupon USD with BRL as functional currency with Scale" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(2.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0 * 2.9 * 0.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.0 * 2.9 * 0.9
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] == 2.0 * 2.9 * 0.9
    end

    @testset "zero-coupon USD Worthless with BRL as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(0.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "zero-coupon USD at maturity" begin
        c = FinancialDSL.Core.WhenAt(pricing_date, FinancialDSL.Core.Amount(1.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.9
    end

    @testset "zero-coupon USD at maturity with Scale" begin
        c = FinancialDSL.Core.WhenAt(pricing_date, FinancialDSL.Core.Amount(2.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0 * 2.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(USD)] == 2.0 * 2.9
    end

    @testset "zero-coupon USD Worthless at maturity" begin
        c = FinancialDSL.Core.WhenAt(pricing_date, FinancialDSL.Core.Amount(0.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "zero-coupon USD after maturity" begin
        c = FinancialDSL.Core.WhenAt(pricing_date - Dates.Day(1), FinancialDSL.Core.Amount(1.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "zero-coupon USD after maturity with Scale" begin
        c = FinancialDSL.Core.WhenAt(pricing_date - Dates.Day(1), FinancialDSL.Core.Amount(2.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "zero-coupon USD Worthless after maturity" begin
        c = FinancialDSL.Core.WhenAt(pricing_date - Dates.Day(1), FinancialDSL.Core.Amount(0.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "zero-coupon USD with USD as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(1.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] == 0.9 # functional currency is USD, so we get exposures only to cpUSD
    end

    @testset "zero-coupon USD with USD as functional currency with Scale" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(2.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0 * 0.9
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 1, 2))] == 2.0 * 0.9 # functional currency is USD, so we get exposures only to cpUSD
    end

    @testset "zero-coupon USD Worthless with USD as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(0.0USD))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "BRL Spot with BRL as functional currency" begin
        c = FinancialDSL.Core.Amount(1.0BRL)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 1.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "BRL Spot with BRL as functional currency with Scale" begin
        c = FinancialDSL.Core.Amount(2.0BRL)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 2.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "BRL Spot Worthless with BRL as functional currency" begin
        c = FinancialDSL.Core.Amount(0.0BRL)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.0
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test isempty(exposures_result)
    end

    @testset "BRL Spot with USD as functional currency" begin
        c = FinancialDSL.Core.Amount(1.0BRL)
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 1.0 / 2.9 # 1 BRL cotado em USD
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.SpotCurrency(BRL)] == 1.0 / 2.9
    end

    @testset "zero-coupon BRL with BRL as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(1.0BRL))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == 0.7
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 1
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] == 0.7
    end

    @testset "zero-coupon BRL with USD as functional currency" begin
        c = FinancialDSL.Core.WhenAt(Date(2019, 1, 2), FinancialDSL.Core.Amount(1.0BRL))
        pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_usd, c, attr_onshore_carry_none)
        p = FinancialDSL.Core.price(pricer, scenario_fixed)
        @test p == (1.0 / 2.9) * 0.7
        exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
        @test length(exposures_result) == 2
        @test exposures_result[FinancialDSL.Core.SpotCurrency(BRL)] == (1.0 / 2.9) * 0.7
        @test exposures_result[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] == (1.0 / 2.9) * 0.7
    end
end # @testset "Functional Currency FixedScenario"

@testset "FixedCashRiskFactor, FixedNonCashRiskFactor" begin
    pricing_date = Date(2018, 5, 29)
    rf_pre = FinancialDSL.Core.DiscountFactor(:PRE, Date(2020, 12, 1))
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE ))
    static_model_brl = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[rf_pre] = 0.7
    attr_onshore_carry_none = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")

    rf_fixed = FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactor(:BASIS, Date(2020, 12, 1)), 1.0)
    c = FinancialDSL.Core.Scale(rf_fixed, FinancialDSL.Core.WhenAt(Date(2020, 12, 1), FinancialDSL.Core.Amount(1.0BRL)))

    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c, attr_onshore_carry_none)
    p = FinancialDSL.Core.price(pricer, scenario_fixed)
    @test p ≈ 0.7

    exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
    #println(exposures_result)

    @test exposures_result[rf_pre] ≈ 0.7
    @test exposures_result[rf_fixed] ≈ 0.7

    # generates two DiscountFactor exposures
    rf_fixed_fwd = FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactorForward(:BASIS, Date(2019,12,1), Date(2020, 12, 1)), 1.0)
    c_fwd = FinancialDSL.Core.Scale(rf_fixed_fwd, FinancialDSL.Core.WhenAt(Date(2020, 12, 1), FinancialDSL.Core.Amount(1.0BRL)))
    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c_fwd, attr_onshore_carry_none)
    exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
    #println(exposures_result)
    @test length(exposures_result) == 3
    @test haskey(exposures_result, FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactor(:BASIS, Date(2019,12,1)), 1.0))
    @test haskey(exposures_result, FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactor(:BASIS, Date(2020,12,1)), 1.0))

    # generate one DiscountFactor exposure (first is dropped
    # because forward start date == pricing_date)
    rf_fixed_fwd2 = FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactorForward(:BASIS, pricing_date, Date(2020, 12, 1)), 1.0)
    c_fwd = FinancialDSL.Core.Scale(rf_fixed_fwd2, FinancialDSL.Core.WhenAt(Date(2020, 12, 1), FinancialDSL.Core.Amount(1.0BRL)))
    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model_brl, c_fwd, attr_onshore_carry_none)
    exposures_result = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario_fixed)
    #println(exposures_result)
    @test length(exposures_result) == 2
    @test !haskey(exposures_result, FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactor(:BASIS, pricing_date), 1.0))
    @test haskey(exposures_result, FinancialDSL.Core.FixedNonCashRiskFactor(FinancialDSL.Core.DiscountFactor(:BASIS, Date(2020,12,1)), 1.0))

end

@testset "Cashflow projection" begin

    @testset "Both Contract" begin
        c = FinancialDSL.Core.Both(
            FinancialDSL.Core.WhenAt(Date(2019, 8, 2), FinancialDSL.Core.Unit(BRL)),
            FinancialDSL.Core.WhenAt(Date(2019, 8, 1), FinancialDSL.Core.Unit(BRL)))

        @test !FinancialDSL.Core.is_expired(c, Date(2019, 7, 2))
        @test FinancialDSL.Core.is_expired(c, Date(2019, 8, 3))
        @test FinancialDSL.Core.is_expired_or_expires_today(c, Date(2019, 8, 2))
    end

    @testset "FixedIncomeContract" begin
        c = FinancialDSL.Core.FixedIncomeContract()
        @test ismissing(FinancialDSL.Core.get_horizon(c))
        @test !FinancialDSL.Core.is_expired(c, Dates.today())
        @test !FinancialDSL.Core.is_expired_or_expires_today(c, Dates.today())

        push!(c, FinancialDSL.Core.Events.Amort(Date(2019, 2, 1), 2.0, BRL))
        @test FinancialDSL.Core.get_horizon(c) == Date(2019, 2, 1)
    end

    @testset "expires_at_maturity" begin
        c = FinancialDSL.Core.WhenAt(
                Date(2020, 2, 1),
                FinancialDSL.Core.Both(
                        FinancialDSL.Core.WhenAt(Date(2021, 2, 1), FinancialDSL.Core.Amount(1.0USD)),
                        FinancialDSL.Core.Give(FinancialDSL.Core.Amount(5.5BRL))
                    )
            )

        @test FinancialDSL.Core.get_horizon(c) == Date(2021, 2, 1)

        c = FinancialDSL.Core.WhenAt(
                Date(2020, 2, 1),
                FinancialDSL.Core.Both(
                        FinancialDSL.Core.WhenAt(Date(2021, 2, 1), FinancialDSL.Core.Amount(1.0USD)),
                        FinancialDSL.Core.Give(FinancialDSL.Core.Amount(5.5BRL))
                    ),
                expires_at_maturity=true
            )

        @test FinancialDSL.Core.get_horizon(c) == Date(2020, 2, 1)
    end
end

@testset "FixedIncome" begin
    c = FinancialDSL.Core.FixedIncomeEvent(:AMORT, FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(1.0BRL)))
    @test FinancialDSL.Core.event_symbol(c) === :AMORT
    @test c.c == FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(1.0BRL))
    @test c == FinancialDSL.Core.FixedIncomeEvent(:AMORT, Date(2019, 2, 1), 1.0, BRL)

    c2 = FinancialDSL.Core.FixedIncomeEvent(:INTEREST, FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(0.5BRL)))
    contract = FinancialDSL.Core.FixedIncomeContract([c, c2])

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    attr = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, contract, attr)

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 2, 1))] = 0.9
    @test FinancialDSL.Core.price(pricer, scenario_fixed) == 1.5*0.9
end

@testset "Swap" begin
    c = FinancialDSL.Core.FixedIncomeEvent(:AMORT, FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(1.0BRL)))
    c2 = FinancialDSL.Core.FixedIncomeEvent(:INTEREST, FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(0.5BRL)))
    swap_leg = FinancialDSL.Core.FixedIncomeContract([c, c2])
    swap = FinancialDSL.Core.SwapContract(swap_leg, swap_leg)

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    attr = FinancialDSL.Core.ContractAttributes(:riskfree_curves => "onshore", :carry_type => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    pricer = FinancialDSL.Core.compile_pricer(empty_provider, pricing_date, static_model, swap, attr)

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 2, 1))] = 0.9
    @test FinancialDSL.Core.price(pricer, scenario_fixed) == 0.0
    @test FinancialDSL.Core.get_horizon(swap) == Date(2019, 2, 1)
end

@testset "Repeated risk-factors" begin
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()
    dt_analise = Date(2018, 5, 1)
    c = FinancialDSL.Core.Both(FinancialDSL.Core.ZCB(Date(2030, 2, 1), 800USD), FinancialDSL.Core.ZCB(Date(2040, 2, 1), 1000USD))
    pricer = FinancialDSL.Core.compile_pricer(empty_provider, dt_analise, model, c, FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none"))

    scenario_fixed = FinancialDSL.Core.FixedScenario()
    scenario_fixed[FinancialDSL.Core.SpotCurrency(USD)] = 3.5BRL
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2030, 2, 1))] = 0.7
    scenario_fixed[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2040, 2, 1))] = 0.4
    @test FinancialDSL.Core.price(pricer, scenario_fixed) == 3.5 * 800 * 0.7 + 3.5 * 1000 * 0.4
end

@testset "project cashflows" begin
    c = FinancialDSL.Core.FixedIncomeEvent(:AMORT, FinancialDSL.Core.WhenAt(Date(2020, 2, 1), FinancialDSL.Core.Amount(10.0BRL)))
    c2 = FinancialDSL.Core.FixedIncomeEvent(:INTEREST, FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(5.0BRL)))
    contract = FinancialDSL.Core.FixedIncomeContract([c, c2])

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, currency_to_curves_map)
    fv_model = FinancialDSL.Core.FutureValueModel(static_model)
    attr = FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none")
    empty_provider = FinancialDSL.MarketData.EmptyMarketDataProvider()

    empty_scenario = FinancialDSL.Core.FixedScenario()
    pricer = FinancialDSL.Core.compile_cashflow_pricer(empty_provider, pricing_date, fv_model, contract, attr)
    @test FinancialDSL.Core.get_functional_currency(pricer) == BRL
    for cf in FinancialDSL.Core.eachcashflow(pricer, empty_scenario)
        if cf.event === :AMORT
            @test cf.maturity == Date(2020, 2, 1)
            @test cf.value == 10.0
            @test cf.currency == BRL
        elseif cf.event === :INTEREST
            @test cf.maturity == Date(2019, 2, 1)
            @test cf.value == 5.0
            @test cf.currency == BRL
        else
            @test false
        end
    end

    @test FinancialDSL.Core.price(pricer, empty_scenario) ≈ 15.0
    @test isempty(FinancialDSL.Core.riskfactors(pricer))
    @test isempty(FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, empty_scenario))
end

@testset "Black-Scholes" begin
    include("test_core_black_scholes.jl")
end

@testset "Binomial Daily" begin
    include("test_core_binomial_daily.jl")
end
