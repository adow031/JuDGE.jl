# module JuDGE

# include("tree.jl")
# using JudgeTree
using JuMP
using Gurobi

export JuDGEModel

mutable struct JuDGEModel
    tree::Tree
    master::JuMP.Model
    subprob::Dict{Node,JuMP.Model}
    duals::Dict{Node,Any}
    updateduals::Dict{Node,Any}
    buildcolumn::Dict{Node,Any}
    updateobjective::Dict{Node,Any}
    function JuDGEModel(tree::Tree)
        this = new()
        this.tree = tree
        return this
    end
end

mutable struct Dual
    indexset::Array{Any,1}
    value::Array{Float64,1}
end

function cart(iterables...)
    for i in Iterators.product(iterables...)
        println(i)
        println(typeof(i))
    end
end

function JuDGEduals!(f,jmodel::JuDGEModel)
    duals = Dict{Node,Any}()
    for n in jmodel.tree.nodes
        dualsForThisNode = Dict{Symbol,Dual}()
        duals[n] = dualsForThisNode
        out = f(n)
        for dual in out
            dualsForThisNode[dual[1]] = dual[2]
        end
    end
    jmodel.duals = duals
end

function JuDGEsubproblems!(f,jmodel::JuDGEModel)
    jmodel.subprob = Dict{Node,JuMP.Model}()
    for n in jmodel.tree.nodes
        jmodel.subprob[n] = f(n)
    end

end

function JuDGEobjective!(f,jmodel::JuDGEModel)
    jmodel.updateobjective = Dict{Node,Any}()
    for n in jmodel.tree.nodes
        jmodel.updateobjective[n] = f
    end
end

function JuDGEupdateduals!(f,jmodel::JuDGEModel)
    jmodel.updateduals = Dict{Node,Any}()
    for n in jmodel.tree.nodes
        jmodel.updateduals[n] = f
    end
end

function JuDGEbuildcolumn!(f,jmodel::JuDGEModel)
    jmodel.buildcolumn = Dict{Node,Any}()
    for n in jmodel.tree.nodes
        jmodel.buildcolumn[n] = f
    end
end

function JuDGEmaster!(f,jmodel::JuDGEModel)
    jmodel.master = f()
end

function makeDual(iterables...)
    # because the dictionary breaks, here we have to see if iterable is unique and use an array
    # indexset = Array{Any,1}()
    indexset = [];
    value = Array{Float64,1}()
    for i in Iterators.product(iterables...)
        push!(indexset,i)
        push!(value,0.0)
    end
    Dual(indexset,value)
end

function makeDual()
    # because the dictionary breaks, here we have to see if iterable is unique and use an array
    # indexset = Array{Any,1}()
    indexset = [()];
    value = [0.0]
    return Dual(indexset,value)
end

function Dual()
    indexset = Array{Any,1}()
    value = Array{Float64,1}()
    for i in iterable
        push!(indexset,i)
        push!(value,0.0)
    end
    Dual(indexset,value)
end

function Base.getindex(pi::Dual, i...)
    pi.value[findfirst(pi.indexset,i)]
end

function Base.setindex!(pi::Dual, value ,i...)
    pi.value[findfirst(pi.indexset,i)] = value
end

function JuDGEModel(f,tree::Tree)
    master = JuMP.Model(solver=GurobiSolver())
    subprob = Dict{Node{Tree},JuMP.Model}()
    duals = Dict{Node{Tree},Any}()
    for n in tree.nodes
        # sp = JuMP.Model(solver=GurobiSolver())
        # subprob[n] = f(n)
        subprob[n] = f(n)
    end
    JuDGEModel(tree,master,subprob,duals,nothing,nothing)
end



macro dual(pi, indices...)
    tmp = String(pi) * " = makeDual( "
    for set in indices[1:end-1]
        if typeof(set) == Symbol
            tmp = tmp * String(set) * ", "
        elseif typeof(set) == Expr
            tmp = tmp * repr(set)[3:end-1] * ", "
        end
    end
    if typeof(indices[end]) == Symbol
        tmp = tmp * String(indices[end]) *")"
    elseif typeof(indices[end]) == Expr
        tmp = tmp * repr(indices[end])[3:end-1] *")"
    end
    tmp2 = String(pi) * " = (:" * String(pi) * " , " * String(pi) * ")"
    final = quote
        $(esc(parse(tmp)))
        $(esc(parse(tmp2)))
    end
    return final
end

macro dual(pi)
    tmp = String(pi) * " = makeDual() "
    tmp2 = String(pi) * " = (:" * String(pi) * " , " * String(pi) * ")"
    final = quote
        $(esc(parse(tmp)))
        $(esc(parse(tmp2)))
    end
    return final
end