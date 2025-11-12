# # Sets and Parameters

# WiNDCNational is built using `WiNDCContainer`, which provides a flexible way 
# to define and manage sets and parameters within the data model. We will provide 
# a listing of the sets used and demonstrate how to access and view them in code.

# The sets and parameters are the same for both the `summary` and `detailed` 
# tables. For this reason we will use the `summary` table as the basis for our
# examples.

using WiNDCNational 
using DataFrames
summary = build_us_table(:summary); 

# ## Sets

# To view all the sets, use the `sets` function:

sets(summary) |> x-> sort(x, [:domain, :name])

# The `|> x -> sort(x, :[:domain, :name])` sorts the sets by their domain, or the column
# in the data table where the set elements are located, and their name. 

#  By convention we use `snake_case` for sets that do not have the `parameter` domain.

# Let's consider the set `margin` with domain `col`. I would like to view the 
# elements:

elements(summary, :margin)

# The values in the `name` column are the elements of the set, they are 
# NAICS codes as they appear in the BEA input/output tables. To examine the actual
# data use:

table(summary, :margin) |> x -> first(x, 5)

# This will show the first 5 rows of the data table restricted to the  `margin` 
# set. Recall `margin` had domain `col` and that is the column where the elements 
# live. To demonstrate the multiple values in `col`, just view the unique values:

table(summary, :margin) |> x -> unique(x, :col)

# Because we are only viewing the first few rows, we only see the `Trans` code. 
# We can further filter the data by specifying a particular element:

table(summary, :margin => :Trade) |> x -> first(x, 5)

# Again, we can extract the unique values:

table(summary, :margin => :Trade) |> x -> unique(x, :col)

# ## Parameters

# Parameters are just sets with domain `:parameter`. 

sets(summary) |> x-> subset(x, :domain => ByRow(==(:parameter)))

# By convention, parameter names are capital-version of `snake_case`. Sets are 
# required to have distinct names and this avoid conflicts. 

# Extracting parameters is identical to extracting sets.

table(summary, :Intermediate_Demand) |> x -> first(x, 5)

# We can extract multiple parameters:

table(summary, :Intermediate_Demand, :Intermediate_Supply) |> x -> first(x, 5)

# Some parameters are composites of multiple parameters:

elements(summary, :Value_Added)


# ## Composite Parameters

# Some parameters are require aggregations and can't be extracted directly. Here
# is a full list of these parameters:
#
# - [`zero_profit`](@ref)
# - [`market_clearance`](@ref)
# - [`margin_balance`](@ref)
# - [`gross_output`](@ref)
# - [`armington_supply`](@ref)
# - [`output_tax`](@ref)
# - [`sectoral_output`](@ref)
# - [`output_tax_rate`](@ref)
# - [`absorption_tax`](@ref)
# - [`absorption_tax_rate`](@ref)
# - [`import_tariff_rate`](@ref)
# - [`balance_of_payments`](@ref)
