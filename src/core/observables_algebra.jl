
#
# Binary Operators
#

for fun in (:+, :-, :*, :/, :^, :min, :max)
    @eval begin
        # Konst eager algebra
        @inline function Base.$fun(k1::Konst{T1}, k2::Konst{T2}) where {T1<:Number, T2<:Number}
            return Konst(($fun)(k1.val, k2.val))
        end

        # Observables Binary operators
        @inline Base.$fun(o1::Observable, o2::Observable) = LiftObs2($fun, o1, o2)

        # Lift Number to Konst
        @inline Base.$fun(n::Number, o::Observable) = ($fun)(Konst(n), o)
        @inline Base.$fun(o::Observable, n::Number) = ($fun)(o, Konst(n))
    end
end

#
# Special functions
#

Base.round(k::Konst; digits=0) = Konst(round(k.val; digits=digits))
Base.trunc(k::Konst; digits=0) = Konst(trunc(k.val; digits=digits))
Base.iszero(k::Konst) = iszero(k.val)
Base.sqrt(o::Observable) = LiftObs(sqrt, o)
Base.exp(o::Observable) = LiftObs(exp, o)
Base.log(o::Observable) = LiftObs(log, o)
Base.exp(o::LiftObs{typeof(log)}) = o.o
Base.log(o::LiftObs{typeof(exp)}) = o.o

#
# Associative ops
#

@inline function associative_op(f::F, k::Konst{N1}, o1::Konst{N2}, o2::Observable) where {F<:Function, N1<:Number, N2<:Number}
    return f(f(k, o1), o2)
end

@inline function associative_op(f::F, k::Konst{N1}, o1::Observable, o2::Konst{N2}) where {F<:Function, N1<:Number, N2<:Number}
    return associative_op(f, k, o2, o1)
end

@inline function associative_op(f::F, k::Konst, o1::Observable, o2::Observable) where {F<:Function}
    return LiftObs2(f, k, LiftObs2(f, o1, o2))
end

# to the left: k1 * (k2 * obs) == (k1 * k2) * obs
# to the left: k1 * (obs * k2) == (k1 * k2) * obs
# to the right: (k1 * obs) * k2 == (k1 * k2) * obs
# to the right: (obs * k1) * k2 == (k1 * k2) * obs
for fun in (:+, :*)
    @eval begin
        @inline function Base.$fun(k::Konst{N}, lo::LiftObs2{typeof($fun)}) where {N<:Number}
            associative_op($fun, k, lo.o1, lo.o2)
        end

        @inline function Base.$fun(lo::LiftObs2{typeof($fun)}, k::Konst{N}) where {N<:Number}
            associative_op($fun, k, lo.o1, lo.o2)
        end
    end
end

#
# algebra for minus (-)
#

@inline Base.:(-)(k::Konst{T}) where {T<:Number} = Konst(-k.val) # Konst eager algebra
@inline Base.:(-)(o::Observable) = LiftObs(-, o)

# -(a + b) == (-a) + (-b)
@inline function Base.:(-)(lo::LiftObs2{typeof(+)})
    return LiftObs2(+, -lo.o1, -lo.o2)
end

# -(a - b) == -a + b
@inline function Base.:(-)(lo::LiftObs2{typeof(-)})
    return LiftObs2(+, -lo.o1, lo.o2)
end

# k - (a +- b) == k + (-(a +- b))
@inline function Base.:(-)(k::Konst{N}, lo::LiftObs2{F}) where {N<:Number, F<:Union{typeof(+), typeof(-)}}
    return k + (-lo)
end

@inline function Base.:(-)(lo::LiftObs2{F}, k::Konst{N}) where {N<:Number, F<:Union{typeof(+), typeof(-)}}
    return lo + (-k)
end

# (k1 - obs) + k2 == (k1 + k2) - obs
# (obs - k1) + k2 == (k2 - k1) + obs
@inline function Base.:(+)(lo::LiftObs2{typeof(-)}, k::Konst{N}) where {N<:Number}
    associative_op(+, k, lo.o1, -lo.o2)
end

# k2 + (k1 - obs) == (k1 + k2) + (-obs)
@inline function Base.:(+)(k::Konst{N}, lo::LiftObs2{typeof(-)}) where {N<:Number}
    return lo + k
end
