__precompile__(true)
module OnlineStatsBase

using NamedTuples

#-----------------------------------------------------------------------# Data
const ScalarOb = Union{Number, AbstractString, Symbol}  # 0
const VectorOb = Union{AbstractVector, Tuple, NamedTuple} # 1 
const XyOb     = Tuple{VectorOb, ScalarOb}              # (1, 0)
const Data = Union{ScalarOb, VectorOb, AbstractMatrix, XyOb}

#-----------------------------------------------------------------------# OnlineStat
abstract type OnlineStat{N} end

#-----------------------------------------------------------------------# ExactStat
"""
An OnlineStat which can be updated exactly.  Subtypes of `ExactStat` use `EqualWeight()`
as the default weight.
"""
abstract type ExactStat{N} <: OnlineStat{N} end

#-----------------------------------------------------------------------# StochasticStat
"""
An OnlineStat which must be approximated.  Subtypes of `StochasticStat` use 
`LearningRate()` as the default weight.  Additionally, subtypes should be parameterized
by an algorithm, which is an optional last argument.  For example:

    struct Quantile{T <: Updater} <: StochasticStat{0}
        value::Vector{Float64}
        τ::Vector{Float64}
        updater::T 
    end
    Quantile(τ::AbstractVector = [.25, .5, .75], u::Updater = SGD()) = ...
"""
abstract type StochasticStat{N} <: OnlineStat{N} end

#-----------------------------------------------------------------------# _value
# The default value(o) returns the first field
@generated function _value(o::OnlineStat)
    r = first(fieldnames(o))
    return :(o.$r)
end

function _fit! end

#-----------------------------------------------------------------------# show
function Base.show(io::IO, o::OnlineStat)
    print(io, name(o), "(")
    showcompact(io, _value(o))
    print(io, ")")
end

#-----------------------------------------------------------------------# ==
function Base.:(==)(o1::OnlineStat, o2::OnlineStat)
    typeof(o1) == typeof(o2) || return false
    nms = fieldnames(o1)
    all(getfield.(o1, nms) .== getfield.(o2, nms))
end

#-----------------------------------------------------------------------# copy
Base.copy(o::OnlineStat) = deepcopy(o)

#-----------------------------------------------------------------------# merge
function Base.merge!(o::T, o2::T, γ::Float64) where {T<:OnlineStat} 
    warn("Merging not well-defined for $(typeof(o)).  No merging occurred.")
end
Base.merge(o::T, o2::T, γ::Float64) where {T<:OnlineStat} = merge!(copy(o), o2, γ)

#-----------------------------------------------------------------------# default_weight
default_weight(o::OnlineStat)       = error("$(typeof(o)) has no `default_weight` method")
default_weight(o::ExactStat)        = EqualWeight()
default_weight(o::StochasticStat)   = LearningRate()

function default_weight(t::Tuple)
    W = default_weight(first(t))
    all(default_weight.(t) .== W) ||
        error("Weight must be specified when defaults differ.  Found: $(name.(default_weight.(t))).")
    return W
end

#-----------------------------------------------------------------------# Weight
"""
Subtypes of `Weight` must be callable to produce the weight given the current number of 
observations in an OnlineStat `n` and the number of new observations (`n2`).

    MyWeight(n, n2 = 1)
"""
abstract type Weight end 
include("weight.jl")

#-----------------------------------------------------------------------# name
function name(o, withmodule = false, withparams = true)
    s = string(typeof(o))
    if !withmodule
        # remove text that ends in period:  OnlineStats.Mean -> Mean
        s = replace(s, r"([a-zA-Z]*\.)", "")
    end
    if !withparams
        # replace everything from "{" to the end of the string
        s = replace(s, r"\{(.*)", "")
    end
    s
end

end
