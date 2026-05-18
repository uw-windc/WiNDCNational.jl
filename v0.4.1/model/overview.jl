# # Model Overview

# The WiNDC National Model is written in [MPSGE](https://github.com/julia-mpsge/MPSGE.jl), 
# a high level language for writing computable general equilibrium models. The 
# syntax allows a modeler to focus on the economic structure of the model 
# rather than the mathematical details of its implementation. 

# For the full model specification, see the documentation: [`national_mpsge`](@ref). 
# This document will construct the model step by step, explaining each component
# along the way.

# ## Building the Model

# The first step is to load the data and filter to just the year we want to model, 
# in this case 2024. This step isn't strictly necessary, as the model can be built
# for multiple years at once, but the years don't interact so it's really just a 
# sequence of models. We will also calibrate the data, suppressing the output.

using WiNDCNational
using MPSGE
import DataStructures: DefaultDict

summary_raw_all_years = build_us_table();
summary_raw = National(
    table(summary_raw_all_years, :year => 2024),
    sets(summary_raw_all_years),
    elements(summary_raw_all_years);
)
summary, _ = calibrate(summary_raw, silent = true);

# Let's also break out a few sets we'll need later. This is primarily for convenience.

sectors = elements(summary, :sector) |> x -> x[!,:name];
commodities = elements(summary, :commodity) |> x -> x[!,:name];
margins = elements(summary, :margin) |> x -> x[!,:name];
value_added = elements(summary, :Value_Added; base=true) |> x -> x[!,:name];
final_demand = elements(summary, :Final_Demand; base=true) |> x -> x[!,:name];

exports = elements(summary, :export) |> x -> x[!,:name];
imports = elements(summary, :import) |> x -> x[!,:name];
PCE = elements(summary, :personal_consumption) |> x -> x[!,:name];
HHS = PCE;

# Now we can start building the model. The first step is to create the MPSGE model object.

M = MPSGEModel()

# The model starts empty, we add variables and parameters in the next steps.

# ### Parameters

# The model has three available parameters:
# 1. Absorption_Tax
# 2. Import_Tariff
# 3. Output_Tax
# with the expected initial values. We've written functions to extract these values
# from `summary` as DataFrames. We can combine them into a single DataFrame, convert 
# this to a default dictionary, and pass it to the `@parameters` macro.

vcat(
    absorption_tax_rate(summary; minimal=false),
    import_tariff_rate(summary; minimal=false),
    output_tax_rate(summary; minimal=false)
) |>
x -> DefaultDict(0, Dict((row[:row], row[:col]) => row[:value] for row in eachrow(x))) |> 
x -> @parameters(M, begin
    Absorption_Tax[c=commodities], x[c, :atr]
    Import_Tariff[c=commodities], x[c, :itr]
    Output_Tax[s=sectors], x[:otr, s]
end);

# The output is suppressed, but we can view the parameters in the model just by 
# viewing the model:

M

# ### Sectors

# The national model follows a standard Armington structure with three sectors 
# corresponding to Production, Supply, and Margins. We can add these sectors to the model
# using the `@sectors` macro.

@sectors(M, begin
    Y[s=sectors], (description = "Sectoral Production")
    A[c=commodities], (description = "Armington Supply")
    MS[m=margins], (description = "Margin Supply")
end);

M

# Notice in the model output, the sectors are displayed with their descriptions. 
# The same would apply for parameters, but the parameter names are self-descriptive. 

# ### Commodities

@commodities(M, begin
    PA[c=commodities], (description = "Armington Price")
    PY[c=commodities], (description = "Output Price")
    PVA[va=value_added], (description = "Value Added Price")
    PM[m=margins], (description = "Margin Price")
    PFX, (description = "Foreign Exchange")
end)

# ### Consumer

# The model has only a single consumer, the representative agent. In this case
# we add the consumer using the `@consumer` macro. Notice this is singular, both 
# versions exist for each of the variable macros.

@consumer(M, RA, description = "Representative Agent")

M

# ### Y Production

WiNDCNational.sectoral_production_data(summary; output=:Dict) |>  x -> 
@production(M, Y[s=sectors], [t=0,s=0, va => s=1], begin
    @output(PY[c=commodities], x[c, s, :intermediate_supply], t, taxes = [Tax(RA, M[:Output_Tax][s])])
    @input(PA[c=commodities], x[c, s, :intermediate_demand], s) 
    @input(PVA[va = value_added], x[va, s, :value_added], va)   
end)

# ### A Production

WiNDCNational.armington_supply_data(summary; output=:Dict) |>  x -> 
@production(M, A[c=commodities], [t=2, s=0, dm=>s=2], begin
    @output(PA[c], x[c, :as, :armington_supply], t, taxes = [Tax(RA, M[:Absorption_Tax][c])], reference_price = 1-x[c,:atr, :absorption_tax_rate]) 
    @output(PFX, sum(x[c, e, :export] for e in exports), t)
    @input(PM[m=margins], x[c, m, :margin_demand], s)
    @input(PFX, sum(x[c, i, :import] for i in imports), dm, taxes = [Tax(RA, M[:Import_Tariff][c])], reference_price = 1+x[c, :itr, :import_tariff_rate])
    @input(PY[c], x[c, :go, :gross_output], dm) 
end)


# ### MS Production


WiNDCNational.margin_supply_data(summary; output=:Dict) |>  x -> 
@production(M, MS[m=margins], [t=0, s=0], begin
    @output(PM[m], sum(x[c, m] for c in commodities if x[c, m] != 0), t) 
    @input(PY[c=commodities], x[c,m], s)
end)

# ### RA Demand

WiNDCNational.representative_agent_data(summary; output=:Dict) |>  x -> 
@demand(M, RA, begin
    @final_demand(PA[c=commodities], sum(x[c, pce, :personal_consumption] for pce in PCE)) 
    @endowment(PY[c=commodities], sum(x[c, hhs, :household_supply] for hhs in HHS)) 
    @endowment(PFX, x[:bop, :bop, :balance_of_payments])
    @endowment(PA[c=commodities], -x[c, :ofd, :ofd]) 
    @endowment(PVA[va=value_added], sum(x[va, s, :value_added] for s∈sectors))
end)

# ## Verifying the Calibration

solve!(M; cumulative_iteration_limit=0)

