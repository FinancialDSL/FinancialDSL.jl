
module Currencies

include("types.jl")
include("currency.jl")
include("algebra.jl")

# Syntax Sugar for a few common Currencies

const BRL = Currency(:BRL)
const USD = Currency(:USD)
const EUR = Currency(:EUR)
const JPY = Currency(:JPY)
const CHF = Currency(:CHF)
const GBP = Currency(:GBP)

end # module Currencies
