using Distributed
if length(workers())==1
   addprocs(14)
end
using Random, Test
@everywhere using Gurobi, JuMP, JuDGE

include("solvers/setup_gurobi.jl")

function knapsack_parallel(parallel,check)
   Random.seed!(50)
   # how many investments?
   numinvest = 5;

   # number of items to pick from in the knapsack?
   numitems = 1000

   # size of tree?
   degree = 6
   height = 4

   totalnodes = Int64((degree^(height+1) - 1)/(degree-1))

   investcost = zeros(totalnodes,numinvest)
   for i = 1:totalnodes
      investcost[i,:] = ([1,1.8,3.5,6.8,13.5])*(1-((i-1)/(totalnodes*1.2)))
   end

   # investvol = [40,45,50,70]
   investvol = [1,2,4,8,16]
   initialcap = 0

   itemvolume = zeros(totalnodes,numitems)
   for i = 1:totalnodes
      itemvolume[i,:] = ((rand(numitems))*2) + collect(range(4,22,length = numitems))
   end

   itemcost = zeros(totalnodes,numitems)
   for i = 1:totalnodes
      itemcost[i,:] = ((rand(numitems) .- 0.5)*2)*2# + collect(range(0.5,1,length = numitems))
   end

   mytree = narytree(height,degree)

   nodes = collect(mytree)
   function data(node, input)
      input[findall(x -> x == node, nodes)[1], :]
   end

   function sub_problems(node)
      #println("Formulating subproblem for node "*node.name)
      model = Model()
      @expansion(model, bag[1:numinvest])
      @capitalcosts(model, sum(data(node,investcost)[i] * bag[i] for i in  1:numinvest))
      @variable(model, y[1:numitems], Bin)
      @constraint(model, BagExtension ,sum( y[i]*data(node,itemvolume)[i] for i in 1:numitems) <= initialcap + sum(bag[i]*investvol[i] for i in 1:numinvest))
      @sp_objective(model, sum(-data(node,itemcost)[i] * y[i] for i in 1:numitems))
      return model
   end

   function format_output(s::Symbol,values)
      if s==:bag
         return sum(values[i]*investvol[i] for i in 1:numinvest)
      end
      return nothing
   end

   judy = JuDGEModel(mytree, ConditionallyUniformProbabilities, sub_problems, JuDGE_MP_Solver, parallel=parallel, check=check, sp_solver=JuDGE_SP_Solver)

   return num_variables(judy.master_problem)
end

function knapsack_callbacks(seed::Int64, tree_size::Tuple{Int64,Int64}, numitems::Int64, custom_solve_settings)
   Random.seed!(50)
   # how many investments?
   numinvest = 6;

   # size of tree?
   degree = tree_size[2]
   height = tree_size[1]

   totalnodes = Int64((degree^(height+1) - 1)/(degree-1))

   investcost = zeros(totalnodes,numinvest)
   for i = 1:totalnodes
      investcost[i,:] = ([1,1.8,3.5,6.8,13.5,25])*(1-((i-1)/(totalnodes*1.2)))
   end

   # investvol = [40,45,50,70]
   investvol = [1,2,4,8,16,32]
   initialcap = 0

   itemvolume = zeros(totalnodes,numitems)
   for i = 1:totalnodes
      itemvolume[i,:] = ((rand(numitems))*2) + collect(range(4,22,length = numitems))
   end

   itemcost = zeros(totalnodes,numitems)
   for i = 1:totalnodes
      itemcost[i,:] = ((rand(numitems) .- 0.5)*2)*2# + collect(range(0.5,1,length = numitems))
   end

   mytree = narytree(height,degree)

   nodes = collect(mytree)
   function data(node, input)
      input[findall(x -> x == node, nodes)[1], :]
   end

   function sub_problems(node)
      println("Formulating subproblem for node "*node.name)
      model = Model(JuDGE_SP_Solver)
      @expansion(model, bag[1:numinvest])
      @capitalcosts(model, sum(data(node,investcost)[i] * bag[i] for i in  1:numinvest))
      @variable(model, y[1:numitems], Bin)
      @constraint(model, BagExtension ,sum( y[i]*data(node,itemvolume)[i] for i in 1:numitems) <= initialcap + sum(bag[i]*investvol[i] for i in 1:numinvest))
      @sp_objective(model, sum(-data(node,itemcost)[i] * y[i] for i in 1:numitems))
      set_optimizer_attribute(model,"MIPGap",0.0005)
      return model
   end

   function format_output(s::Symbol,values)
      if s==:bag
         return sum(values[i]*investvol[i] for i in 1:numinvest)
      end
      return nothing
   end

   judy = JuDGEModel(mytree, ConditionallyUniformProbabilities, sub_problems, JuDGE_MP_Solver)

   if custom_solve_settings
      function oa(judge::JuDGEModel,stalled::Bool,initialize::Bool)
         function slowed()
      	  if judge.log[end].iter>3
      		  if judge.log[end].rlx_abs/judge.log[end-3].rlx_abs>0.5
      			  return true
      		  end
      	  end
      	  false
         end

         function relgap_factor(probability)
            if judge.optimizer_settings[1]==4
               0.0005
            else
               10^-4/probability*20^(4-judge.optimizer_settings[1])
            end
         end


         if initialize
            push!(judge.optimizer_settings,1)

            println("\u1b[1F\u1b[130GInitializing optimizer settings at level "*string(judge.optimizer_settings[1]))

            for (node,sp) in judge.sub_problems
              set_optimizer_attribute(sp,"MIPGap",relgap_factor(judge.probabilities[node]))
            end
            return false
         elseif judge.optimizer_settings[1]==4
   	   	if stalled
   	   		return true
   		   else
   			   return false
   		   end
         elseif stalled || slowed()
      	  judge.optimizer_settings[1]+=1

      	  for (node,sp) in judge.sub_problems
      		 set_optimizer_attribute(sp,"MIPGap",relgap_factor(judge.probabilities[node]))
      	  end

      	  if judge.optimizer_settings[1]==4
      		 println("\u1b[1F\u1b[130GFinal optimizer settings")
      	  else
      		 println("\u1b[1F\u1b[130GIncremented optimizer settings to level "*string(judge.optimizer_settings[1]))
      	  end
         end

         return false
      end

      function mp_cb(judge::JuDGEModel,abs_tol::Float64,rel_tol::Float64)
      	function earlytermination(cb_data, cb_where)
      		if cb_where == Gurobi.CB_MIP
      			#@info("Executing callback")
      			objbst = Gurobi.cbget_mip_objbst(cb_data, cb_where)
      			objbnd = Gurobi.cbget_mip_objbnd(cb_data, cb_where)
      			runtime = Gurobi.cbget_runtime(cb_data, cb_where)
      			JuDGE.printright("Incumbent: "*string(objbst)*" Bound: "*string(objbnd)*" Runtime: "*string(runtime))
      			if (objbnd>judge.bounds.LB+abs_tol && objbnd>judge.bounds.LB+rel_tol*abs(judge.bounds.LB)) || objbst<judge.bounds.LB+abs_tol || objbst<judge.bounds.LB+rel_tol*abs(judge.bounds.LB)
      				Gurobi.terminate(backend(judge.master_problem).optimizer.model.inner)
      			end
      		end
      		return
      	end
      	MOI.set(judge.master_problem, Gurobi.CallbackFunction(), earlytermination)
      end

      judy=JuDGE.branch_and_price(judy,rlx_reltol=10^-6,reltol=5*10^-3,inttol=10^-6,
                  branch_method=JuDGE.constraint_branch,search=:lowestLB,
                  optimizer_attributes=oa,mp_callback=mp_cb,max_no_int=5)
   else
      judy=JuDGE.branch_and_price(judy,rlx_reltol=10^-6,reltol=5*10^-3,inttol=10^-6,
                  branch_method=JuDGE.constraint_branch,search=:lowestLB,max_no_int=5)
   end

   println("Objective: "*string(objective_value(judy.master_problem)))
   JuDGE.print_expansions(judy,format=format_output,inttol=10^-6)

   return objective_value(judy.master_problem)
end

# Formulate with checks in serial mode
@time @test knapsack_parallel(false,true) ≈ 9071 atol = 1e-3

# Formulate with checks in parallel mode (muxh slower, so probably shouldn't use)
@time @test knapsack_parallel(true,true) ≈ 9071 atol = 1e-3

# Formulate without checks in parallel mode
@time @test knapsack_parallel(true,false) ≈ 9071 atol = 1e-3

# Solve without callbacks for medium tree and 500 items
@time @test knapsack_callbacks(50,(3,4),500,false) ≈ -19.46 atol = 2e-2

# Solve with callbacks for medium tree and 500 items
@time @test knapsack_callbacks(50,(3,4),500,true) ≈ -19.46 atol = 2e-2