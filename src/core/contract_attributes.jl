
ContractAttributes() = ContractAttributes(Dict{Symbol, Any}())

Base.setindex!(a::ContractAttributes, x, y) = setindex!(a.attributes, x, y)
Base.getindex(a::ContractAttributes, k) = getindex(a.attributes, k)
Base.haskey(a::ContractAttributes, k) = haskey(a.attributes, k)
Base.keys(a::ContractAttributes) = keys(a.attributes)

function ContractAttributes(x...)
    result = ContractAttributes()

    for i in x
        @assert isa(i, Pair)
        result[Symbol(i.first)] = i.second
    end

    return result
end

function Base.:(==)(a1::ContractAttributes, a2::ContractAttributes)
    if isempty(a1.attributes) && isempty(a2.attributes)
        return true
    end

    if (isempty(a1.attributes) && !isempty(a2.attributes)) || (!isempty(a1.attributes) && isempty(a2.attributes))
        return false
    end

    for k in keys(a1.attributes)
        if !haskey(a2.attributes, k)
            return false
        end
    end

    for k in keys(a2.attributes)
        if !haskey(a1.attributes, k)
            return false
        end
    end

    for k in keys(a1.attributes)
        if a1.attributes[k] != a2.attributes[k]
            return false
        end
    end

    return true
end

Base.hash(a::ContractAttributes) = 101 + hash(a.attributes)

# attributes with dedicated API

get_currency(a::ContractAttributes) :: Currencies.Currency = Currencies.Currency(a[:currency])
get_maturity(a::ContractAttributes) :: Date = Date(a[:maturity])
get_issue(a::ContractAttributes) :: Date = Date(a[:issue])

"Returns `true` if `sc` has a carry curve defined in the contract attributes."
function has_carry_curve(attr::ContractAttributes, sc::SpotCurrency) :: Bool
    @assert haskey(attr, :carry_curves) "Contract has no `carry_curves` attribute."
    currency_name = string(Currencies.currency_symbol(sc))
    carry_curves = attr[:carry_curves]

    # returns true if there's a carry curve for the given currency, or to any currency
    return haskey(carry_curves, currency_name) || haskey(carry_curves, "Any")
end

function get_carry_curve_symbol(attr::ContractAttributes, sc::SpotCurrency) :: Symbol
    @assert haskey(attr, :carry_curves) "Contract has no `carry_curves` attribute."
    carry_curves = attr[:carry_curves]
    cur_sym = Currencies.currency_symbol(sc)
    cur_str = String(cur_sym)
    @assert haskey(carry_curves, cur_str) || haskey(carry_curves, "Any") "Contract has no carry curve defined for the currency $cur_sym."

    if haskey(carry_curves, cur_str)
        return Symbol(carry_curves[cur_str])
    else
        return Symbol(carry_curves["Any"])
    end
end

get_settlement_currency(a::ContractAttributes) :: Currencies.Currency = Currencies.Currency(a[:settlement_currency])
