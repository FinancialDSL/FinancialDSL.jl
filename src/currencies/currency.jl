
function Currency(str::AbstractString)
    @assert !isempty(str) "Can't create currency from an empty string."
    return Currency(Symbol(str))
end

function Currency(sym::Symbol)
    return Currency{sym}()
end

currency_symbol(::Currency{C}) where {C} = C

"""
    cashvalue(c::Cash{C,T}) :: T

Returns the numeric value of the amount of a cash.
"""
cashvalue(c::Cash{C,T}) where {C<:Currency,T<:Real} = c.value

"""
    cashcurrency(::Cash{C}) :: C

Returns the currency for a cash.
"""
cashcurrency(::Cash{C}) where {C<:Currency} = C()

# Allows syntax `Cash{BRL}(10.0)`
(::Type{Cash{C}})(x::T) where {C,T<:Real} = Cash{C,T}(x)

Base.show(io::IO, c::Currency{C}) where {C} = print(io, C)
Base.show(io::IO, c::Cash{C}) where {C<:Currency} = print(io, c.value, C())
