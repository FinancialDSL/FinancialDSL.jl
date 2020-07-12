
const OP_BIN_SCALAR_SUM = OptimizingIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)
const OP_BIN_SCALAR_SUB = OptimizingIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)
const OP_BIN_SCALAR_MUL = OptimizingIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)
const OP_BIN_SCALAR_DIV = OptimizingIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)
const OP_BIN_SCALAR_MIN = OptimizingIR.Op(min, pure=true, commutative=true)
const OP_BIN_SCALAR_MAX = OptimizingIR.Op(max, pure=true, commutative=true)
const OP_BIN_SCALAR_POW = OptimizingIR.Op(^, pure=true)

const OP_UNARY_SCALAR_SUB = OptimizingIR.Op(-, pure=true)
const OP_UNARY_SCALAR_EXP = OptimizingIR.Op(exp, pure=true)
const OP_UNARY_SCALAR_LOG = OptimizingIR.Op(log, pure=true)
const OP_UNARY_SCALAR_SQRT = OptimizingIR.Op(sqrt, pure=true)

const OP_GETINDEX = OptimizingIR.Op(Base.getindex, pure=true)

#
# Black-Scholes Model
#

const OP_BLACK_FORMULA_CALL = OptimizingIR.Op(BS.bscall, pure=true)
const OP_BLACK_FORMULA_PUT = OptimizingIR.Op(BS.bsput, pure=true)

#
# Binomial Daily Model
#

CRR_volatility_match_up_factor(σ, Δt) = exp(σ * sqrt(Δt))
const OP_CRR_VOLATILITY_MATCH_UP_FACTOR = OptimizingIR.Op(CRR_volatility_match_up_factor, pure=true)

underlying_price(s, n, i, ln_u, ln_d) = s * exp((i-1)*ln_u + (n-i)*ln_d)
const OP_BINOMIAL_UNDERLYING_PRICE_AT = OptimizingIR.Op(underlying_price, pure=true)

function risk_neutral_pricing_step(riskfree_discount_factor, risk_neutral_probability, next_step_price_up, next_step_price_down)
    df = riskfree_discount_factor
    q = risk_neutral_probability
    f_up = next_step_price_up
    f_down = next_step_price_down
    return df * ( q * f_up + (1-q) * f_down )
end
const OP_BINOMIAL_RISK_NEUTRAL_PRICING_STEP = OptimizingIR.Op(risk_neutral_pricing_step, pure=true)

function risk_neutral_probability(d, ert, u)
    @assert d <= ert <= u "No-arbitrage condition was not satisfied: d = $d, ert = $ert, u = $u."
    return ( ert - d ) / ( u - d )
end
const OP_BINOMIAL_RISK_NEUTRAL_PROBABILITY = OptimizingIR.Op(risk_neutral_probability, pure=true)
