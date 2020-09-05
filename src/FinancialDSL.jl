
"DSL for Financial Contracts."
module FinancialDSL

import BusinessDays
import InterestRates
import ForwardDiff
import OptimizingIR
import Distributions
import Roots

const CAL_BRL = BusinessDays.Brazil()
BusinessDays.initcache(CAL_BRL)

include("BS.jl")
include("currencies/currencies.jl")
include("marketdata.jl")
include("core/core.jl")

end # module
