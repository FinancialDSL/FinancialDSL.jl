
struct Currency{C} end

struct Cash{C<:Currency, T<:Real} <: Number
    value::T
end
