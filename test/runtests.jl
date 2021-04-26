
import FinancialDSL
using Test, Dates
import InterestRates, BusinessDays

ts_start = Dates.now()

@testset "BS" begin
    include("test_BS.jl")
end

import FinancialDSL.Currencies.BRL
import FinancialDSL.Currencies.USD
import FinancialDSL.Currencies.EUR
import FinancialDSL.Currencies.GBP
import FinancialDSL.Currencies.JPY

@testset "Currencies" begin
    include("test_currencies.jl")
end

@testset "Core" begin
    include("test_core.jl")
end

@info("Tests completed in $(Dates.now() - ts_start)")
