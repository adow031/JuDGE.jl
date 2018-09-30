workspace()

include("tree.jl")
# using JudgeTree
include("judge2.jl")
# using JuDGE
using JuMP
using Gurobi

investcost = [180 50 60 40 60 10 10];
investvol = 4;
u_0 = 3;


volume = [ 6   2   1   1  1
    8   2   2   2  1
    8   1   1   1  3
    4   4   3   1  2
    1   3   1   1  2
    7   3   1   1  1
    2   5   2   1  2];

cost = [ 60   20   10   15   10
    8   10   20   20  10
    8   10   15   10  30
    40   40   35   10  20
    15   35   15   15  20
    70   30   15   15  10
    25   50   25   15  20];

mutable struct Knapsack
    itemreward::Array{Float64,1}
    volume::Array{Float64,1}
    p::Float64
    investcost::Float64
    items::UnitRange{Int64}
end


function P(n::Node)
    list = Node[]
    list = getparents(n)
    push!(list,n)
end

# build a tree
# mytree = JudgeTree.buildtree(2,2)
mytree = buildtree(2,2)

getnode(mytree,[1]).data = Knapsack(cost[1,:],volume[1,:],1,investcost[1],1:5);
getnode(mytree,[1,1]).data = Knapsack(cost[2,:],volume[2,:],0.5,investcost[2],1:5);
getnode(mytree,[1,2]).data = Knapsack(cost[3,:],volume[3,:],0.5,investcost[3],1:5);
getnode(mytree,[1,1,1]).data = Knapsack(cost[4,:],volume[4,:],0.25,investcost[4],1:5);
getnode(mytree,[1,1,2]).data = Knapsack(cost[5,:],volume[5,:],0.25,investcost[5],1:5);
getnode(mytree,[1,2,1]).data = Knapsack(cost[6,:],volume[6,:],0.25,investcost[6],1:5);
getnode(mytree,[1,2,2]).data = Knapsack(cost[7,:],volume[7,:],0.25,investcost[7],1:5);


nodes = mytree.nodes
items = 1:5

function something(node::Node)
    println(node)
end

items = 1:5
tech = [:gas,:hydro]

####
# Set up empty JuDGE Model
####


hello = JuDGEModel(mytree)

println("We got here")

####
# Set up the sets
####
items = 1:5
tech = [:gas, :hydro]

####
# Set up the duals required for each node
####
JuDGEduals!(hello) do n
    @dual(pi,tech)
    # @dual(mu)
    return [pi]
end

####
# Set up the subproblems for each node
####
JuDGEsubproblems!(hello) do n
    # Set up an empty jump model
    sp = JuMP.Model(solver=GurobiSolver())

    # Set up the variables
    @variable(sp, z, category=:Bin)
    @variable(sp, y[n.data.items], category=:Bin)

    # set up the constraints
    @constraint(sp, sum(n.data.volume[i]*y[i] for i in n.data.items) <= u_0 + investvol*z)

    return sp 
end

####
# Set up the objectives
####
JuDGEobjective!(hello) do n
    # bring into scope to make writing the objective easier
    sp = hello.subprob[n]
    dual = hello.duals[n]
    data = n.data

    @objective(sp, Min, data.p * sum(data.itemreward[i]*sp[:y][i] for i in data.items) - dual[:pi][]*sp[:z] - mu[])
end

println("James is a cunt")

####
# Write out the master problem
####
JuDGEmaster!(hello) do
    master = Model(solver=GurobiSolver(OutputFlag=0,Method=2))

    @variable(master, 0 <= x[n in hello.tree.nodes] <=1)
    @objective(master,Min, sum(n.data.p*n.data.investcost*x[n] for n in hello.tree.nodes))

    @constraint(master, [n in hello.tree.nodes], sum(x[h] for h in P(n)) <= 1)

    @constraint(master, pi[n in hello.tree.nodes] ,0 <= sum(x[h] for h in P(n)))
    @constraint(master, mu[n in hello.tree.nodes], 0 == 1)

    return master
end

####
# populate the duals from the solution of the master problem
####
JuDGEupdateduals!(hello) do n
    # hello.master
    hello.duals[n][:pi][] = getdual(hello.master.objDict[:pi][n])
    hello.duals[n][:mu][] = getdual(hello.master.objDict[:mu][n])
end

####
# tell JuDGE how to build a column from a nodal solution
####
JuDGEbuildcolumn!(hello) do n 
    sp = hello.subprob[n]
    lb = 0;
    ub = 1;
    obj = n.data.p*sum(-n.data.itemcost[i]*getvalue(sp[:y][i]) for i in items)   
    contr = [hello.master.objDict[:pi][n]; hello.master.objDict[:mu][n]]
    colcoef = [getvalue(sp[:z]),1]
    name = "James"

    return (lb,ub,:Cont ,obj, contr, colcoef, name)
end