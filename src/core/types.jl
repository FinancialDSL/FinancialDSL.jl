
"""
A Dictionary to store contract attributes.
"""
struct ContractAttributes
    attributes::Dict{String, Any}
end

#
# Observables
#

"""
Represents a time-varying quantity of type {T}.
So, its value is indexed by a date or datetime.
"""
abstract type Observable{T} end

#=
"""
The value of `CurrentDate()` at date `dt` is just `dt`.
"""
struct CurrentDate <: Observable{Date} end
=#

"""
    PricingDate <: Observable{Date}

Represents the pricing date
"""
struct PricingDate <: Observable{Date} end

"""
    AdjustedDate{D<:Observable{Date}} <: Observable{Date}

Adjusts to last business day if `date` is not a bday
following `calendar` holiday calendar.

# Fields

* `date`

* `calendar`
"""
struct AdjustedDate{D<:Observable{Date}} <: Observable{Date}
    reference_date::D
    calendar::BusinessDays.HolidayCalendar
end

"""
The value of `Konst(x)` is always `x` at any date.
"""
struct Konst{T} <: Observable{T}
    val::T
end

struct ObservableAt{D<:Observable{Date},T} <: Observable{T}
    at::D
    o::Observable{T}
end

"""
    at(date, observable)

Fixes observation date of `observable`
at `date`.

`date` might be a `Date` or `Observable{Date}`.
"""
at(date::Date, k::Konst) = k
at(date::Date, o::Observable) = ObservableAt(Konst(date), o)

function at(d::D, o::Observable) where {D<:Observable{Date}}
    return ObservableAt(d, o)
end

function at(date::Date, oat::ObservableAt)
    @assert date == oat.at
    return oat
end

"""
MarketData historical series value observed at
date infered by `at` observable,
asof `PricingDate`.
"""
struct HistoricalValue{D<:Observable{Date}} <: Observable{Float64}
    serie_name::String
    locf::Bool
    at::D
end

"""
First order risk factor.
"""
abstract type RiskFactor <: Observable{Float64} end

"""
Second order risk factor.

See [`DeltaGammaApproxExposuresMethod`](@ref).
"""
struct SecondOrderRiskFactor{T<:RiskFactor} <: RiskFactor
    rf::T
end

"""
Identifies a Risk Factor that has no currency value.
"""
abstract type NonCashRiskFactor <: RiskFactor end

"""
Identifies a Risk Factor that has a currency value.
"""
abstract type CashRiskFactor <: RiskFactor end

"""
Spot price for a currency.
"""
struct SpotCurrency{C<:Currencies.Currency} <: CashRiskFactor
    currency::C
end

"""
Discount factor from an interest rate curve.
"""
struct DiscountFactor <: NonCashRiskFactor
    sym::Symbol # curve symbol (:cpUSD, :PRE, etc.)
    maturity::Date
end

"""
Discount Factor from `start_date` maturing at `end_date`.

Given dates *a*, *b*, *c*, where ``a < b < c``,
we have the following relationship between effective factors:

`` f^{a \\to b} f_{FWD}^{ b \\to c } = f^{ a \\to c} ``

Rewriting as discount factors, we have:

`` DF_{FWD}^{ b \\to c } = \\frac{ DF^{ a \\to c} }{ DF^{ a \\to b } } ``
"""
struct DiscountFactorForward <: Observable{Float64}
    sym::Symbol
    start_date::Date
    end_date::Date
end

"Stock price."
struct Stock <: CashRiskFactor
    ticker::Symbol
end

"Risk Factor volatility."
struct Volatility{T<:RiskFactor} <: NonCashRiskFactor
    underlying::T
end

Currencies.currency_symbol(::SpotCurrency{Currencies.Currency{C}}) where {C} = C # see Currencies.currency_symbol(::Currencies.Currency{C})

"""
    risk_factor_symbol(rf::RiskFactor) :: Symbol

Returns a unique symbol used to identify the Risk Factor.

This is used to map the arguments of the pricing function
to the Risk Factors.

In the case of Discount Factors, the risk factor symbol
also carries the maturity date.
For instance, `:cpUSD_20200226` represents `DiscountFactor(:cpUSD, Date(2020, 2, 26))`.

See also [`market_data_symbol`](@ref).
"""
risk_factor_symbol(::SpotCurrency{Currencies.Currency{C}}) where {C} = C
risk_factor_symbol(rf::Stock) = rf.ticker

# :cpUSD_20200226
risk_factor_symbol(rf::DiscountFactor) = Symbol(rf.sym, :_, Dates.format(rf.maturity, dateformat"yyyymmdd"))

"""
    market_data_symbol(rf::RiskFactor) :: Symbol

Returns the name for the historical series for a Risk Factor.
This is used to search series in the `MarketData` module.

Discount Factors are identified by the curve name.
Therefore, this function differs from `risk_factor_symbol`
for Discount Factors, since it does not carry information
about the maturity of the Discount Factor.

See also [`risk_factor_symbol`](@ref).
"""
market_data_symbol(rf::RiskFactor) = risk_factor_symbol(rf)
market_data_symbol(rf::DiscountFactor) = rf.sym

"""
Models a pricing model input that is given as a fixed constant,
but that we would like to consider as a Risk Factor.
"""
struct FixedCashRiskFactor{R<:CashRiskFactor} <: CashRiskFactor
    rf::R
    val::Currencies.Cash
end

struct FixedNonCashRiskFactor{R<:NonCashRiskFactor} <: NonCashRiskFactor
    rf::R
    val::Float64
end

for T in (:FixedCashRiskFactor, :FixedNonCashRiskFactor)
    @eval begin
        risk_factor_symbol(rf::$T) = risk_factor_symbol(rf.rf)
    end
end

#=
"""
The value of `At(dt)` is `true` when `dt == value(CurrentDate())`.
"""
struct At <: Observable{Bool}
    date::Date
end
=#

@inline obstype(::Type{P}) where {T,P<:Observable{T}} = T
@inline obstype(obs::Observable) = obstype(typeof(obs))

struct LiftObs{F<:Function, R} <: Observable{R}
    f::F
    o::Observable
end

function LiftObs(f::Function, a::Observable)
    RR = Base.return_types(f, Tuple{obstype(a)})
    R = length(RR) > 1 ? Any : RR[1]
    return LiftObs{typeof(f), R}(f, a)
end

struct LiftObs2{F<:Function, R} <: Observable{R}
    f::F
    o1::Observable
    o2::Observable
end

function LiftObs2(f::Function, o1::Observable, o2::Observable)
    RR = Base.return_types(f, Tuple{obstype(o1), obstype(o2)})
    R = length(RR) > 1 ? Any : RR[1]
    return LiftObs2{typeof(f), R}(f, o1, o2)
end

struct ReduceObs{F<:Function, T} <: Observable{T}
    f::F
    observables::Vector{Observable{T}}
end

function ReduceObs(f::Function, ::Type{T}) where {T}
    return ReduceObs{typeof(f), T}(f, Vector{Observable{T}}())
end

function push_reduce_obs!(red::ReduceObs{F, T}, obs::Observable{T}) where {F, T}
    push!(red.observables, obs)
    nothing
end

# redefining push_obs! for Konst to avoid stackoverflow at convert Konst method
function push_reduce_obs!(red::ReduceObs{F, T}, obs::Konst{T}) where {F, T}
    push!(red.observables, obs)
    nothing
end

function push_reduce_obs!(red::ReduceObs{F, T}, obs::Konst{R}) where {F, T, R}
    push_reduce_obs!(red, Konst(convert(T, obs.val)))
end

"""
This struct is used to allow the reuse of
the result of `Compiler.lower!` for observables
that get repeated in the contract definition.

See also [`buffer`](@ref).
"""
mutable struct BufferedObservable{T} <: Observable{T}
    o::Observable{T}
end

"""
    buffer(observable)

Marks an `observable` as buffered.
For constants, this is a *no-op*.

See [`BufferedObservable`](@ref).
"""
@inline buffer(o::Observable) = BufferedObservable(o)
@inline buffer(k::Konst) = k # no-op for constants

"""
A Financial Contract.
"""
abstract type Contract end

#
# Contract primitives
#

"""
`Worthless` is a contract that has no rights and no obligations.
"""
struct Worthless <: Contract
end

"""
    Unit(o::SpotCurrency; carryless::Bool=false)

If you acquire `Unit(k)` you immediately receive one unit of the currency `k`.

`carryless::Bool`: if true, the unit does not use carry curves when it is being valued (discounted).
"""
struct Unit{RF<:CashRiskFactor} <: Contract
    o::RF
    carryless::Bool # controls wether we should use the carry curve when discounting

    function Unit(o::RF; carryless::Bool=false) where {RF<:CashRiskFactor}
        return new{RF}(o, carryless)
    end
end

"""
`Give(c)` inverts the position (right or obligation) of a contract `c`.
"""
struct Give <: Contract
    c::Contract
end

"""
Acquiring `Scale(o, c)` is equivalent to acquiring `c` with all
payments multiplied by `o` sampled at the time of acquisition.
"""
struct Scale <: Contract
    s::Observable
    c::Contract
end

# avoids Scale(s, scale) chain
Scale(s::Observable, c::Scale) = Scale(s * c.s, c.c)

"""
Acquiring `Both(c1, c2)` implies in acquiring immediately both contracts `c1` and `c2`.
"""
struct Both <: Contract
    c1::Contract
    c2::Contract
end

"""
`Either(c1, c2)` will choose one contract to aquire: either `c1` or `c2`.
"""
struct Either{C1<:Contract,C2<:Contract} <: Contract
    c1::C1
    c2::C2
end

#=
"""
`When(o, c)` acquires `c` as soon as `o` becomes `true`.
It's worthless after
"""
struct When{P<:Observable{Bool}, C<:Contract} <: Contract
    p::P
    c::C
end
=#

"""
`WhenAt(mat::Date, c::Contract; expires_at_maturity::Bool=false)` will acquire `c` at date `mat`.

Optional kwarg `expires_at_maturity` controls the behavior of `get_horizon(c)` for this contract:

* if `expires_at_maturity = false` (default), `get_horizon(c)` will return the maximum horizon found
in `c.maturity` and the result of `get_horizon(c.c)`.

* if `expires_at_maturity = true`, `get_horizon(c)` will always return `c.maturity`.

This is useful for Forward contracts, where the underlying is another fixed income contract,
but the settlement of the Forward contract occurs using cash at `maturity`.
"""
struct WhenAt{C<:Contract} <: Contract
    expires_at_maturity::Bool
    maturity::Date
    c::C

    function WhenAt(maturity::Date, c::C; expires_at_maturity::Bool=false) where {C<:Contract}
        new{C}(expires_at_maturity, maturity, c)
    end
end

"""
`Anytime(expiry::Date, c::Contract)` is an option to acquire `c` anytime until `expiry`.
"""
struct Anytime{C<:Contract} <: Contract
    expiry::Date
    c::C
end

#
# Fixed Income
#

"""
`AbstractFixedIncomeContract` identifies fixed income contracts.

These are contracts that are composed of a set of fixed income events,
where each event wraps a `WhenAt` primitive contract.

# Concrete Types:

* `FixedIncomeEvent`

* `FixedIncomeContract`

* `SwapContract`

"""
abstract type AbstractFixedIncomeContract <: Contract end

"""
Defines a financial event of a `FixedIncomeContract`.

# Constructors

```julia
evn = FixedIncomeEvent(:EVENT_NAME, c)
```

where `c` is a `WhenAt` contract.

The event name can be queried by `event_symbol` function.

```julia
evn = FixedIncomeEvent(:EVENT_NAME, Date(2019, 2, 1), 1.0, BRL)
```
"""
struct FixedIncomeEvent{E,C<:Union{Scale, Unit}} <: AbstractFixedIncomeContract
    c::WhenAt{C}

    function FixedIncomeEvent(evn::Symbol, contract::WhenAt{C}) where {C<:Unit}
        @assert Events.is_valid(evn) "$evn is not a valid event."
        return new{evn, C}(contract)
    end

    function FixedIncomeEvent(evn::Symbol, contract::WhenAt{C}) where {C<:Scale}
        @assert contract.maturity == get_horizon(contract) "contract maturity ($(contract.maturity)) should be equal to its horizon ($(get_horizon(contract)))."
        scale = contract.c
        @assert isa(scale.c, Unit) "FixedIncomeEvent WhenAt(scale) should have a Unit as underlying. Got type$(typeof(scale.c)): $(scale.c)."
        return new{evn, C}(contract)
    end
end

"""
A `FixedIncomeContract` is defined as a set of `FixedIncomeEvent`s.
"""
struct FixedIncomeContract <: AbstractFixedIncomeContract
    events::Vector{FixedIncomeEvent}
end

"""
A `SwapContract` has two legs: `asset::FixedIncomeContract`, `liability::FixedIncomeContract`.

The `liability` leg will be valued as `Give(liability)`.
"""
struct SwapContract <: AbstractFixedIncomeContract
    asset::FixedIncomeContract
    liability::FixedIncomeContract
end

include("types_models.jl")

#
# Scenario
#

"""
Provides values for the risk factors.

A Scenario is not required to be linked to a pricing date.

# Interface

* `Base.haskey(s, rf::RiskFactor) :: Bool`

* `Base.getindex(s, rf::CashRiskFactor) :: Cash`

* `Base.getindex(s, rf::NonCashRiskFactor) :: Float64`

For *writable* scenario instances:

* `Base.setindex!(s, val, rf::RiskFactor)`

# Provided Methods

* `Base.haskey(scenario::Scenario, c::Currencies.Currency) :: Bool`

* `Base.getindex(scenario::Scenario, c::Currencies.Currency) :: Currencies.Cash`

* `Base.setindex!(scenario::Scenario, val::Currencies.Cash, c::Currencies.Currency)`
"""
abstract type Scenario end

"""
    FixedScenario

A scenario implementation based on a dictionary of fixed values for the risk factors.
"""
struct FixedScenario <: Scenario
    cash_risk_factors::Dict{CashRiskFactor, Currencies.Cash}
    non_cash_risk_factors::Dict{NonCashRiskFactor, Float64}

    function FixedScenario()
        return new(Dict{CashRiskFactor, Currencies.Cash}(), Dict{NonCashRiskFactor, Float64}())
    end
end

"""
    ActualScenario

A scenario implementation that is linked to a `MarketData.AbstractMarketDataProvider`.
"""
struct ActualScenario{P<:MarketData.AbstractMarketDataProvider, F<:Function} <: Scenario
    provider::P
    date::Date
    locf_option::F
end

"""
    CompositeScenario

Builds a new scenario from a list of existing scenarios.

When a risk factor value is requested from this scenario,
it returns the first occurence of the risk factor
in the list of underlying scenarios.

This is useful to override some risk factors from the `ActualScenario`.
"""
struct CompositeScenario <: Scenario
    scenarios::Vector{Scenario}
end

"""
    DebugScenario

Wrapps an existing scenario, and tracks which risk factors
are asked from this scenario.
"""
struct DebugScenario <: Scenario
    scenario::Scenario
    record::Dict{RiskFactor, Union{obstype(RiskFactor), Currencies.Cash}}

    function DebugScenario(scenario::Scenario)
        return new(scenario, Dict{RiskFactor, Union{obstype(RiskFactor), Currencies.Cash}}())
    end
end

"""
    ScenarioMap{F<:Function, S<:Scenario} <: Scenario

Derives a new scenario by mapping a function
to an existing scenario.

For a `ScenarioMap`, `getindex` is implemented as :

```julia
Base.getindex(s::ScenarioMap, rf::RiskFactor) = s.f(rf, s.scenario[rf])
```

# Fields

* `f` mapping function: `f(risk_factor, risk_factor_value) -> new_risk_factor_value`.

* `scenario`: base scenario.

# Constructor

```julia
scenario_map = ScenarioMap(f, scenario)
```
"""
struct ScenarioMap{F<:Function, S<:Scenario} <: Scenario
    f::F
    scenario::S
end

#
# Pricer
#

"""
    AbstractPricer

Represents a pricing function along with
the Risk Factors that are arguments of the
pricing function.

# Interface

* `price(p::AbstractPricer, scenario::Scenario) :: Number`

* `exposures(method::AbstractExposuresMethod, p::AbstractPricer, scenario::Scenario) :: ExposureResult`

* `riskfactors(pricer::AbstractPricer) -> itr`

* `get_functional_currency(pricer::AbstractPricer) :: Currencies.Currency`

"""
abstract type AbstractPricer end

"""
    AbstractCashflowPricer

Used for Cashflow projection.
Has the same interface as `AbstractPricer`.

See also [`foreachcashflow`](@ref), [`collect_cashflows`](@ref).
"""
abstract type AbstractCashflowPricer <: AbstractPricer end

#
# Cashflow projection
#

struct Cashflow
    event::Symbol
    maturity::Date
    value::Float64
    currency::Currencies.Currency
end

#
# Methods for Risk Factors exposures
#

"""
Identifies the algorithm to calculate exposures to risk factors.
See [`exposures`](@ref).
"""
abstract type AbstractExposuresMethod end

"""
Linear exposures to risk factors.

``S \\frac{\\partial P}{\\partial S}``
"""
struct DeltaNormalExposuresMethod <: AbstractExposuresMethod
end

"""
Adds second order exposures approximation
to the standard linear exposures.

Known as delta-gamma approximation method.

As an example, for the exposure to Risk Factor `Stock(:PETR4)`,
the gamma exposure (2nd order) is approximated as:

``\\frac{1}{2} \\frac{ \\partial^2 P }{ \\partial S^2 } S^2``

Second order risk factors are wrapped by [`SecondOrderRiskFactor`](@ref).
"""
struct DeltaGammaApproxExposuresMethod <: AbstractExposuresMethod
end
