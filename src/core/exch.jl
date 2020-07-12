
function exch(::Scenario, from::C, to::C) :: Float64 where {C<:Currencies.Currency}
    # same currency
    return 1.0
end

function exch(p::Scenario, from::C1, to::C2) :: Float64 where {C1<:Currencies.Currency, C2<:Currencies.Currency}

    if !haskey(p, from) # ex.: BRL -> USD
        @assert haskey(p, to)
        @assert Currencies.cashcurrency(p[to]) == from
        return 1.0 / Currencies.cashvalue(p[to])

    elseif Currencies.cashcurrency(p[from]) == to # ex.: USD -> BRL
        return Currencies.cashvalue(p[from])

    else
        @assert haskey(p, to)
        @assert Currencies.cashcurrency(p[from]) == Currencies.cashcurrency(p[to]) # same functional currency
        return Currencies.cashvalue(p[from]) / Currencies.cashvalue(p[to])
    end
end

@inline function exch(p::Scenario, from_cash::Currencies.Cash{C1, T}, to_currency::C2) :: T where {C1<:Currencies.Currency, C2<:Currencies.Currency, T<:Real}
    return exch(p, C1(), C2()) * Currencies.cashvalue(from_cash)
end

function exchcash(p::Scenario, from::C1, to::C2) :: Currencies.Cash{C2, Float64} where {C1<:Currencies.Currency, C2<:Currencies.Currency}
    return exch(p, from, to) * to
end
