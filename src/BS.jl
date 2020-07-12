
module BS

using ..Distributions
import ..Roots

#
# types
#

struct D₁Parts{T}
    numerator::T
    denominator::T
end

abstract type BSOption end

"European call option."
struct EuropeanCall <: BSOption end

"European put option."
struct EuropeanPut <: BSOption end

@inline N(x) = cdf(Normal(), x)

@inline D₁Parts(s, k, t, σ) = D₁Parts(log(s/k) + (σ^2/2)*t, σ*sqrt(t))

@inline d₁(parts::D₁Parts) = parts.numerator / parts.denominator
@inline d₂(parts::D₁Parts) = d₁(parts) - parts.denominator

@inline d₁(s, k, t, σ) = d₁(D₁Parts(s, k, t, σ))
@inline d₂(s, k, t, σ) = d₂(D₁Parts(s, k, t, σ))

@inline function bscall(s, k, t, σ)
    parts = D₁Parts(s, k, t, σ)
    return s*N(d₁(parts)) - k*N(d₂(parts))
end

@inline function bsput(s, k, t, σ)
    parts = D₁Parts(s, k, t, σ)
    return k*N(-d₂(parts)) - s*N(-d₁(parts))
end

@inline price(::EuropeanCall, s, k, t, σ) = bscall(s, k, t, σ)
@inline price(::EuropeanPut, s, k, t, σ) = bsput(s, k, t, σ)

function impvol(opt::BSOption, observed_price, s, k, t, interval::Tuple=infer_impvol_interval(opt, observed_price, s, k, t))
    f(σ) = observed_price - price(opt, s, k, t, σ)
    return Roots.find_zero(f, interval, Roots.Bisection())
end

function infer_impvol_interval(opt::BSOption, observed_price, s, k, t)
    # most instruments have volatility values below 100%
    min_vol = 0.0
    max_vol = 1.0
    if observed_price <= price(opt, s, k, t, max_vol)
        return (min_vol, max_vol)
    end

    # will increment max_vol 10x until we reach a final interval
    while true
        min_vol = max_vol
        max_vol = min_vol * 10
        if observed_price <= price(opt, s, k, t, max_vol)
            return (min_vol, max_vol)
        end
    end
end

#
# Greeks
#

@inline delta(::EuropeanCall, s, k, t, σ) = N(d₁(s, k, t, σ))
@inline delta(::EuropeanPut, s, k, t, σ) = N(d₁(s, k, t, σ)) - 1

@inline function theta(::EuropeanCall, s, k, t, r, σ)
    parts = D₁Parts(s, k, t, σ)
    return -(s * pdf(Normal(), d₁(parts)) * σ) / ( 2*sqrt(t) ) - r*k*N(d₂(parts))
end

@inline function theta(::EuropeanPut, s, k, t, r, σ)
    parts = D₁Parts(s, k, t, σ)
    return -(s * pdf(Normal(), d₁(parts)) * σ) / ( 2*sqrt(t) ) + r*k*N(-d₂(parts))
end

@inline function gamma(s, k, t, σ)
    parts = D₁Parts(s, k, t, σ)
    return pdf(Normal(), d₁(parts)) / (s * parts.denominator)
end
@inline gamma(::BSOption, s, k, t, σ) = gamma(s, k, t, σ)


@inline vega(s, k, t, σ) = s*sqrt(t)*pdf(Normal(), d₁(s, k, t, σ))
@inline vega(::BSOption, s, k, t, σ) = vega(s, k, t, σ)

@inline rho(::EuropeanCall, s, k, t, σ) = k*t*N(d₂(s, k, t, σ))
@inline rho(::EuropeanPut, s, k, t, σ) = -k*t*N(-d₂(s, k, t, σ))

end # module
