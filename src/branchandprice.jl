function add_branch_constraint(master::JuMP.Model,branch)
	if branch[2]==:eq
		@constraint(master,branch[1]==branch[3])
	elseif branch[2]==:le
		@constraint(master,branch[1]<=branch[3])
	elseif branch[2]==:ge
		@constraint(master,branch[1]>=branch[3])
	end
end

function new_branch_constraint(master::JuMP.Model,branch::Any)
	add_branch_constraint(master,branch)
	push!(master.ext[:branches],branch)
end

function copy_model(jmodel::JuDGEModel, branch::Any)
	newmodel=JuDGEModel(jmodel.tree, jmodel.probabilities, jmodel.sub_problems, jmodel.master_solver, Bounds(Inf,jmodel.bounds.LB), jmodel.discount_factor, jmodel.CVaR, jmodel.sideconstraints)

	newmodel.master_problem.ext[:branches]=Array{Any,1}()

	all_newvar=all_variables(newmodel.master_problem)
	all_var=all_variables(jmodel.master_problem)

	if typeof(branch)!=Nothing
		for b in jmodel.master_problem.ext[:branches]
			if typeof(b[1])==VariableRef
				push!(newmodel.master_problem.ext[:branches],(all_newvar[JuMP.index(b[1]).value],b[2],b[3]))
			elseif typeof(b[1])==GenericAffExpr{Float64,VariableRef}
				exp=0
				for (var,coef) in b[1].terms
					exp+=coef*all_newvar[JuMP.index(var).value]
				end
				push!(newmodel.master_problem.ext[:branches],(exp,b[2],b[3]))
			end
			add_branch_constraint(newmodel.master_problem,newmodel.master_problem.ext[:branches][end])
		end

		if typeof(branch[1])==VariableRef
			branch=(all_newvar[JuMP.index(branch[1]).value],branch[2],branch[3])
		elseif typeof(branch[1])==GenericAffExpr{Float64,VariableRef}
			exp=0
			for (var,coef) in branch[1].terms
				exp+=coef*all_newvar[JuMP.index(var).value]
			end
			branch=(exp,branch[2],branch[3])
		end
		new_branch_constraint(newmodel.master_problem,branch)
	end

	for column in jmodel.master_problem.ext[:columns]
		push!(newmodel.master_problem.ext[:columns],column)
		newvar=add_variable_as_column(newmodel.master_problem, UnitIntervalInformation(), column)
	end

	newmodel
end

function copy_column(master, sub_problem ,node, master_var)
	singlevars=Array{Any,1}()
	arrayvars=Dict{Any,Array{Any,1}}()

	for (name,variable) in sub_problem.ext[:expansions]
		if typeof(variable) <: AbstractArray
			arrayvars[name]=Array{Int64,1}()
			for i in eachindex(variable)
				if normalized_coefficient(master.ext[:coverconstraint][node][name][i],master_var) == 1.0
					push!(arrayvars[name],i)
				end
			end
		else
			if normalized_coefficient(master.ext[:coverconstraint][node][name],master_var) == 1.0
				push!(singlevars,name)
			end
		end
	end
	Column(node,singlevars,arrayvars,objcoef(master_var))
end

function variable_branch(master, tree, expansions, inttol)
	branches=Array{Any,1}()

	branch=nothing
	maxfrac=inttol
	for node in collect(tree)
		for x in keys(expansions[node])
			var = expansions[node][x]
			if typeof(var) <: AbstractArray
				for key in keys(var)
					fractionality=min(JuMP.value(var[key]),1-JuMP.value(var[key]))
					if fractionality>maxfrac
						branch=@expression(master,var[key])
						maxfrac=fractionality
					end
				end
			else
				fractionality=min(JuMP.value(var),1-JuMP.value(var))
				if fractionality>maxfrac
					branch=@expression(master,var)
					maxfrac=fractionality
				end
			end
		end
	end
	if branch!=nothing
		push!(branches,(branch,:eq,1))
		push!(branches,(branch,:eq,0))
	end
	branches
end


"""
	constraint_branch(master, tree, expansions, inttol)

This is an in-built function that is called during branch-and-price to perform a branch.
Users can define their own functions that follow this format to create new branching strategies.

### Required Arguments
`master` is the master problem of the JuDGE model

`tree` is the tree of the JuDGE model

`expansions` is a dictionary of capacity expansion variables, indexed by node.

`inttol` is the maximum permitted deviation from 0 or 1 for a value to still be considered binary.
"""
function constraint_branch(master::JuMP.Model, tree::AbstractTree, expansions::T where T <: Dict, inttol::Float64)
	branches=Array{Any,1}()
	parents=history(tree)
	biggest_frac=inttol
	for leaf in collect(tree)
		if typeof(leaf)==Leaf
			for x in keys(expansions[leaf])
				var = expansions[leaf][x]
				if typeof(var) <: AbstractArray
					for key in keys(var)
						nodes=[]
						for node in parents(leaf)
							if min(JuMP.value(expansions[node][x][key]),1-JuMP.value(expansions[node][x][key]))>inttol
								push!(nodes,node)
							end
						end
						if length(nodes)!=0
							for node in nodes
								expr=@expression(master,expansions[node][x][key])
								push!(branches,(expr,:eq,1))
							end
							expr=@expression(master,sum(expansions[n][x][key] for n in nodes))
							push!(branches,(expr,:eq,0))
							return branches
						end
					end
				else
					nodes=[]
					for node in parents(leaf)
						if min(JuMP.value(expansions[node][x]),1-JuMP.value(expansions[node][x]))>inttol
							push!(nodes,node)
						end
					end
					if length(nodes)!=0
						for node in nodes
							expr=@expression(master,expansions[node][x])
							push!(branches,(expr,:eq,1))
						end
						expr=@expression(master,sum(expansions[n][x] for n in nodes))
						push!(branches,(expr,:eq,0))
						return branches
					end
				end
			end
		end
	end
	branches
end

function perform_branch(jmodel::JuDGEModel,branches::Array{Any,1})
	newmodels=Array{JuDGEModel,1}()

	for i in 2:length(branches)
		push!(newmodels,copy_model(jmodel,branches[i]))
	end

	new_branch_constraint(jmodel.master_problem,branches[1])
	jmodel.bounds.UB=Inf
	insert!(newmodels,1,jmodel)

	newmodels
end

"""
	branch_and_price(judge::JuDGEModel;
		  branch_method=JuDGE.constraint_branch,
		  search=:depth_first_resurface,
	      abstol = 10^-14,
	      reltol = 10^-14,
	      rlx_abstol = 10^-14,
	      rlx_reltol = 10^-14,
	      duration = Inf,
	      iter = 2^63 - 1,
	      inttol = 10^-9)

Solve a JuDGEModel `judge` without branch and price.

### Required Arguments
`judge` is the JuDGE model that we wish to solve.

### Optional Arguments
`branch_method` specifies the way that constrants are added to create node nodes

`search` specifies the order in which nodes are solved in the (brnach-and-price) tree

`abstol` is the absolute tolerance for the best integer-feasible objective value and the lower bound

`reltol` is the relative tolerance for the best integer-feasible objective value and the lower bound

`rlx_abstol` is the absolute tolerance for the relaxed master objective value and the lower bound

`rlx_reltol` is Set the relative tolerance for the relaxed master objective value and the lower bound

`duration` is the maximum duration

`iter` is the maximum number of iterations

`inttol` is the maximum deviation from 0 or 1 for integer feasible solutions

### Examples
	JuDGE.branch_and_price(jmodel, abstol=10^-6)
	JuDGE.branch_and_price(jmodel, branch_method=JuDGE.variable_branch, search=:lowestLB)
"""
function branch_and_price(judge::JuDGEModel;branch_method=JuDGE.constraint_branch,search=:depth_first_resurface,
   abstol=10^-14,
   reltol=10^-14,
   rlx_abstol=10^-14,
   rlx_reltol=10^-14,
   duration=Inf,
   iter=2^63-1,
   inttol=10^-8)

	initial_time = time()

	if typeof(rlx_abstol) <: Function
		rlx_abstol_func=true
	elseif typeof(rlx_abstol)==Float64
		rat=rlx_abstol
		rlx_abstol_func=false
	end
	if typeof(rlx_reltol) <: Function
		rlx_reltol_func=true
	elseif typeof(rlx_reltol)==Float64
		rrt=rlx_reltol
		rlx_reltol_func=false
	end

	models = Array{JuDGEModel,1}()

	#push!(models,copy_model(judge,nothing))
	push!(models,judge)
	models[1].master_problem.ext[:branches]=Array{Any,1}()

	UB=Inf
	LB=Inf
	i=1
	best=0
	bestLB=1
	while true
		model=models[i]

		N=length(models)
		while model.bounds.LB>UB
			println("\nModel "*string(i)*" dominated. UB: "*string(model.bounds.UB)*", LB:"*string(model.bounds.LB))
			if i==N
				break
			end
			i+=1
			model=models[i]
		end

		bestLB=0
 	    LB=Inf
 		for j in i:N
 			if models[j].bounds.LB<LB
 			 	LB=models[j].bounds.LB
 				bestLB=j
 			end
 		end

		if search==:lowestLB
			model=models[bestLB]
			deleteat!(models,bestLB)
			insert!(models,i,model)
		end

		println("\nModel "*string(i)*" of "*string(N)*". UB: "*string(UB)*", LB:"*string(LB)*", Time: "*string(Int(floor((time()-initial_time)*1000+0.5))/1000)*"s")

		if rlx_reltol_func
			rrt=rlx_reltol(i,N)
		end

		if rlx_abstol_func
			rat=rlx_abstol(i,N)
		end

		solve(model,abstol=abstol,reltol=reltol,rlx_abstol=rat,rlx_reltol=rrt,duration=duration,iter=iter,inttol=inttol,allow_frac=1,prune=UB)

		if model.bounds.UB<UB
			UB=model.bounds.UB
			best=copy_model(model,nothing)
		end

		status=termination_status(model.master_problem)
		if (LB+abstol<UB && UB-LB>reltol*abs(UB)) && (status!=MathOptInterface.INFEASIBLE_OR_UNBOUNDED && status!=MathOptInterface.INFEASIBLE && status!=MathOptInterface.DUAL_INFEASIBLE)
			println("\nAttempting to branch.")
			branches=branch_method(model.master_problem, model.tree, model.master_problem.ext[:expansions], inttol)
			if length(branches)>0
				println("Adding "*string(length(branches))*" new nodes to B&P tree.")
			    newmodels=perform_branch(model,branches)
				i+=1
				if search==:depth_first_dive
					for j in 1:length(newmodels)
						insert!(models,i,newmodels[length(newmodels)+1-j])
					end
				elseif search==:breadth_first || search==:lowestLB
					append!(models,newmodels)
				elseif search==:depth_first_resurface
					insert!(models,i,newmodels[1])
					deleteat!(newmodels,1)
					append!(models,newmodels)
				end
			elseif i==length(models)
				break
			else
				i+=1
			end
		elseif i==length(models) || UB-LB<=abstol || UB-LB<=reltol*abs(UB)
			break
		else
			i+=1
		end
	end
	solve_binary(best)

	println("\nObjective value of best integer-feasible solution: "*string(best.bounds.UB))
	println("Solve time: "*string(Int(floor((time()-initial_time)*1000+0.5))/1000)*"s")
	best
end
