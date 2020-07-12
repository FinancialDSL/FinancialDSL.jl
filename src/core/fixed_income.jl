
function FixedIncomeEvent(evn::Symbol, maturity::Date, value::T, currency::Currencies.Currency) where {T<:Union{Number, Observable}}
    return FixedIncomeEvent(evn, WhenAt(maturity, Amount(value, currency)))
end

"""
    event_symbol(evn::FixedIncomeEvent) :: Symbol

Returns the event name for `evn`.
"""
event_symbol(evn::FixedIncomeEvent{E}) where {E} = E::Symbol

FixedIncomeContract() = FixedIncomeContract(Vector{FixedIncomeEvent}())

function FixedIncomeContract(events::FixedIncomeEvent...)
    return FixedIncomeContract([ evn for evn in events ])
end

Base.push!(fic::FixedIncomeContract, evn::FixedIncomeEvent) = push!(fic.events, evn)
