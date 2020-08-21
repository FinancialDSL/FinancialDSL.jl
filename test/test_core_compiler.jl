
@testset "LookupTable" begin
    table = FinancialDSL.Core.Compiler.OptimizingIR.LookupTable{FinancialDSL.Core.RiskFactor}()
    rf1 = FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 2, 1))
    @test rf1 ∉ table
    i = FinancialDSL.Core.Compiler.OptimizingIR.addentry!(table, rf1)
    @test rf1 ∈ table
    @test table[i] == rf1

    for rf in table
        @test rf == rf1
    end

    rf2 = FinancialDSL.Core.SpotCurrency(USD)
    @test rf2 ∉ table
    i = FinancialDSL.Core.Compiler.OptimizingIR.addentry!(table, rf2)
    @test rf2 ∈ table
    @test table[i] == rf2
    @test rf1 ∈ table

    for rf in table
        @test rf == rf1 || rf == rf2
    end

    let
        filtered_risk_factors = filter( x -> FinancialDSL.Core.risk_factor_symbol(x) == :USD, table)
        @test filtered_risk_factors[1] == FinancialDSL.Core.SpotCurrency(USD)
        @test length(filtered_risk_factors) == 1
        @test isa(filtered_risk_factors, AbstractVector)
    end
end

@testset "dag" begin

    pricing_date = Date(2018, 5, 29)
    currency_to_curves_map = Dict( "onshore" => Dict( :BRL => :PRE, :USD => :cpUSD ))
    static_model = FinancialDSL.Core.StaticHedgingModel(BRL, FinancialDSL.MarketData.EmptyMarketDataProvider(), currency_to_curves_map)
    attr = FinancialDSL.Core.ContractAttributes("riskfree_curves" => "onshore", "carry_type" => "none")

    scenario = FinancialDSL.Core.FixedScenario()
    scenario[FinancialDSL.Core.SpotCurrency(USD)] = 3.0BRL
    scenario[FinancialDSL.Core.DiscountFactor(:PRE, Date(2019, 1, 2))] = 0.7
    scenario[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 2, 1))] = 0.8

    let
        contract = FinancialDSL.Core.Both(
            FinancialDSL.Core.Both(FinancialDSL.Core.Amount(10.0, BRL), FinancialDSL.Core.Amount(10.0, BRL)),
            FinancialDSL.Core.Amount(10.0, USD))

        pricer = FinancialDSL.Core.compile_pricer(pricing_date, static_model, contract, attr)
        println("Printing pricer for contract")
        println(contract)
        println(pricer)
        p = FinancialDSL.Core.price(pricer, scenario)
        @test p ≈ 10.0 + 10.0 + 10.0*3.0
        @test FinancialDSL.Core.get_functional_currency(pricer) == BRL

        ex = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario)
        @test ex[FinancialDSL.Core.SpotCurrency(USD)] ≈ 10.0*3.0
    end

    let
        contract = FinancialDSL.Core.WhenAt(Date(2019, 2, 1), FinancialDSL.Core.Amount(10.0, USD))

        pricer = FinancialDSL.Core.compile_pricer(pricing_date, static_model, contract, attr)
        p = FinancialDSL.Core.price(pricer, scenario)
        @test p ≈ 10.0 * 3.0 * 0.8

        ex = FinancialDSL.Core.exposures(FinancialDSL.Core.DeltaNormalExposuresMethod(), pricer, scenario)
        @test ex[FinancialDSL.Core.SpotCurrency(USD)] ≈ 10.0 * 3.0 * 0.8
        @test ex[FinancialDSL.Core.DiscountFactor(:cpUSD, Date(2019, 2, 1))] ≈ 10.0 * 3.0 * 0.8
    end
end
