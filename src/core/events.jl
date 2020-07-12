
module Events

import ..Core
import ..Currencies
using Dates

#
# TODO: this content could be generated using macros
#

#
# :AMORT -> Amortization
# :INTEREST -> Interest payment
# :CAP -> Capitalization
# :PAYMENT -> Generic cashflow event
#

const EVN_AMORT = :AMORT
const EVN_INTEREST = :INTEREST
const EVN_CAPITALIZATION = :CAP
const EVN_PAYMENT = :PAYMENT

const EVENT_SYMS = [ EVN_AMORT, EVN_INTEREST, EVN_CAPITALIZATION, EVN_PAYMENT ]

is_valid(evn::Symbol) = evn ∈ EVENT_SYMS

function Amort(contract::C) where {C<:Core.WhenAt}
    return Core.FixedIncomeEvent(EVN_AMORT, contract)
end

function Amort(maturity::Date, value::T, currency::Currencies.Currency) where {T<:Union{Number, Core.Observable}}
    return Core.FixedIncomeEvent(EVN_AMORT, maturity, value, currency)
end

function Interest(contract::C) where {C<:Core.WhenAt}
    return Core.FixedIncomeEvent(EVN_INTEREST, contract)
end

function Interest(maturity::Date, value::T, currency::Currencies.Currency) where {T<:Union{Number, Core.Observable}}
    return Core.FixedIncomeEvent(EVN_INTEREST, maturity, value, currency)
end

function Payment(contract::C) where {C<:Core.WhenAt}
    return Core.FixedIncomeEvent(EVN_PAYMENT, contract)
end

function Payment(maturity::Date, value::T, currency::Currencies.Currency) where {T<:Union{Number, Core.Observable}}
    return Core.FixedIncomeEvent(EVN_PAYMENT, maturity, value, currency)
end

end
