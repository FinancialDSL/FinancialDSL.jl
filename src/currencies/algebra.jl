
Base.:*(::C, x::Real) where {C<:Currency} = Cash{C}(x)
Base.:*(x::Real, ::C) where {C<:Currency} = Cash{C}(x)

Base.:-(x::Cash{C}) where {C<:Currency} = Cash{C}(-x.value)

Base.:+(x::Cash{C}, y::Cash{C}) where {C<:Currency} = Cash{C}(x.value + y.value)
Base.:-(x::Cash{C}, y::Cash{C}) where {C<:Currency} = Cash{C}(x.value - y.value)

Base.:*(c::Cash{C}, x::Real) where {C<:Currency} = Cash{C}(c.value * x)
Base.:*(x::Real, c::Cash{C}) where {C<:Currency} = Cash{C}(c.value * x)
Base.:*(x::Cash{C}, y::Cash{C}) where {C<:Currency} = Cash{C}(x.value * y.value)

Base.:/(c::Cash{C}, x::Real) where {C<:Currency} = Cash{C}(c.value / x)
Base.:/(c1::Cash{C}, c2::Cash{C}) where {C<:Currency} = c1.value / c2.value

Base.:(==)(x::Cash{C}, y::Cash{C}) where {C<:Currency} = x.value == y.value
Base.:(<)(x::Cash{C}, y::Cash{C}) where {C<:Currency} = x.value < y.value
Base.:(<=)(x::Cash{C}, y::Cash{C}) where {C<:Currency} = x.value <= y.value

Base.isless(x::Cash{C}, y::Cash{C}) where {C<:Currency} = isless(x.value, y.value)
Base.isequal(x::Cash{C}, y::Cash{C}) where {C<:Currency} = isequal(x.value, y.value)

Base.abs(x::Cash{C}) where {C<:Currency} = Cash{C}(abs(x.value))

Base.isapprox(x::Cash{C}, y::Cash{C}; kwargs...) where {C<:Currency} = isapprox(x.value, y.value; kwargs...)

Base.zero(::Cash{C,T}) where {C,T} = Cash{C,T}(zero(T))
Base.zero(::Type{Cash{C,T}}) where {C,T} = Cash{C,T}(zero(T))
Base.one(::Cash{C,T}) where {C,T} = Cash{C,T}(one(T))
Base.one(::Type{Cash{C,T}}) where {C,T} = Cash{U,T}(one(T))

Base.trunc(x::Cash{C}; digits=0) where {C<:Currency} = Cash{C}(trunc(x.value, digits=digits))
Base.round(x::Cash{C}; digits=0) where {C<:Currency} = Cash{C}(round(x.value, digits=digits))
