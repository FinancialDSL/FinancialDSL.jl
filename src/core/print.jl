
#
# Print
#

Base.show(io::IO, c::Contract) = _show_tree(io, c)
Base.show(io::IO, o::Observable) = _show_tree(io, o)

function Base.show(io::IO, sc::SpotCurrency; color::Bool=true)
    if color
        printstyled(io, "SpotCurrency(", sc.currency, ")", color=:yellow)
    else
        print(io, "SpotCurrency(", sc.currency, ")")
    end
end

function Base.show(io::IO, disc::DiscountFactor; color::Bool=true)
    if color
        printstyled(io, "DiscountFactor(", disc.sym, ", ", disc.maturity, ")", color=:yellow)
    else
        print(io, "DiscountFactor(", disc.sym, ", ", disc.maturity, ")")
    end
end

for T in (:FixedCashRiskFactor, :FixedNonCashRiskFactor)
    @eval begin
        function Base.show(io::IO, i::$T; color::Bool=true)
            if color
                printstyled(io, $T,"(", i.rf, " = ", i.val, ")", color=:yellow)
            else
                print(io, $T,"(", i.rf, " = ", i.val, ")")
            end
        end
    end
end

_show_root(io::IO, x) = print(io, x)
_children(x) = ()

_show_root(io::IO, c::Contract) = printstyled(io, string(typeof(c).name.name), color=:magenta)
_show_root(io::IO, evn::FixedIncomeEvent) = printstyled(io, string(typeof(evn).name.name), "{:", event_symbol(evn), "}", color=:magenta)
_children(c::Contract) = (getfield(c,i) for i = 1:nfields(c))

_show_root(io::IO, o::Observable) = printstyled(io, string(typeof(o).name.name), color=:cyan)
_children(o::Observable) = (getfield(o,i) for i = 1:nfields(o))

_show_root(io::IO, o::Konst) = printstyled(io, string(o.val), color=:yellow)
_children(o::Konst) = ()

#=
function _show_root(io::IO, o::LiftObs)
    printstyled(io, "{", color=:cyan)
    print(io,o.f)
    printstyled(io, "}", color=:cyan)
end
_children(o::LiftObs) = o.a
=#

function _show_tree(io::IO, x, indent_root="", indent_leaf="")
    print(io, indent_root)
    _show_root(io, x)
    print(io, '\n')
    cs = _children(x)
    for (i,c) in enumerate(cs)
        if i < length(cs)
            _show_tree(io, c, indent_leaf*" ├─",indent_leaf*" │ ")
        else
            _show_tree(io, c, indent_leaf*" └─",indent_leaf*"   ")
        end
    end
end

# Bash colors
const COLOR_RED = 196
const COLOR_PURPLE = 165
const COLOR_BLUE = 20
const COLOR_GREY = 237
const COLOR_GREEN = 70

function pretty_formula(x::LiftObs)
    str_f = nameof(x.f)
    str_vp = pretty_formula(x.o)
    "$str_f($str_vp)"
end

function pretty_formula(x::LiftObs2)
    str_vp1 = pretty_formula(x.o1)
    str_vp2 = pretty_formula(x.o2)
    str_f = nameof(x.f)
    #str_new_line = ((x.f in [+, -]) ? "\n" : "")
    str_new_line = ""

    if x.f in [+, -, /, *, ^]
        result = "($str_vp1 $str_f$str_new_line $str_vp2)"
    else
        result = "$str_f($str_vp1, $str_vp2)"
    end
    result
end

pretty_formula(x::Konst) = "$(x.val)"
function pretty_formula(x::Konst{T}) where {T<:AbstractFloat}
    @sprintf("%15.6f", x.val)
end

# Risk Factors
function pretty_formula(x::SpotCurrency)
    io = IOBuffer()
    printstyled(io, x.currency, color=COLOR_PURPLE)
    print(io, "@")
    printstyled(io, "t", color=COLOR_BLUE)
    String(take!(io))
end

function pretty_formula(x::Stock)
    io = IOBuffer()
    printstyled(io, x.ticker, color=COLOR_GREY)
    print(io, "@")
    printstyled(io, "t", color=COLOR_BLUE)
    String(take!(io))
end

function pretty_formula(x::DiscountFactor)
    io = IOBuffer()
    printstyled(io, x.sym, color=COLOR_GREEN)
    print(io, "@")
    printstyled(io, "t", color=COLOR_BLUE)
    print(io, "→")
    printstyled(io, x.maturity, color=COLOR_BLUE)
    String(take!(io))
end

function pretty_formula(x::DiscountFactorForward)
    io = IOBuffer()
    printstyled(io, x.sym, color=COLOR_GREEN)
    print(io, "@")
    printstyled(io, x.start_date, color=COLOR_BLUE)
    print(io, "→")
    printstyled(io, x.end_date, color=COLOR_BLUE)
    String(take!(io))
end
