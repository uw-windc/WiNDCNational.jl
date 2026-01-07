
"""
    build_us_table(yaml_path::String; base_dir = pwd())
    build_us_table(aggregation::Symbol = :summary)

Build the US national table. Structure YAML file as specified by [`build_national_table`](@ref).

The data is loaded and then transformed using the following processing steps:

1. [`redistribute_cif_fob`])(@ref)
2. [`create_margin_categories`](@ref)
3. [`create_pce_categories`](@ref)
4. [`adjust_intermediate_flows`](@ref)
5. [`adjust_negative_value_added`](@ref)
6. [`zero_marginal_tax_subsidy`](@ref)
"""
function build_us_table(yaml_path::String; base_dir = pwd())
    X, metadata = build_national_table(yaml_path, National; base_dir = base_dir)

    
    transformation_keywords = get(metadata, "transformation_keywords", Dict())
    transformation_keywords = Dict(Symbol(k) => v for (k,v) in transformation_keywords)
    X = redistribute_cif_fob(X; transformation_keywords...)
    X = create_margin_categories(X; transformation_keywords...)
    X = create_pce_categories(X; transformation_keywords...)
    X = adjust_intermediate_flows(X; transformation_keywords...)
    X = adjust_negative_value_added(X; transformation_keywords...)
    X = zero_marginal_tax_subsidy(X; transformation_keywords...)

    return X
end

function build_us_table(aggregation::Symbol = :summary)
    aggregation ∈ [:summary, :detailed] || error("Aggregation must be either :summary or :detailed")
    #yaml_path = joinpath(@__DIR__, "$aggregation.yaml")
    return build_us_table("$aggregation.yaml"; base_dir = @__DIR__)
end


"""
    redistribute_cif_fob(X::National; insurance_codes::Vector{String} = [], kwargs...)

Redistribute the CIF\\_FOB parameter to Transport and Import, add all insurance 
commodities values to Import and non-insurance commodities to Transport. Remove 
CIF\\_FOB parameter. 

Returns a National table.
"""
function redistribute_cif_fob(X::National; insurance_codes::Vector{String} = [], kwargs...)
    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)

    col_labels = table(X, :Transport, :Import) |>
        x -> select(x, [:col, :parameter]) |>
        unique


    adjusted_values = table(X, :Transport, :Import, :CIF_FOB) |>
        x -> select(x, Not(:col)) |>
        x -> unstack(x, :parameter, :value) |>
        x -> coalesce.(x, 0) |>
        x -> transform(x,
            [:row, :transport, :import, :cif_fob] =>
                ByRow((r, t, i, c) -> r∈insurance_codes ? (t, i+c) : (t+c, i)) =>
                [:transport, :import]
        ) |>
        x -> select(x, Not(:cif_fob)) |>
        x -> stack(x, [:transport, :import], variable_name = :parameter) |>
        x -> transform(x,
            :parameter => ByRow(Symbol) => :parameter
        ) |>
        x -> subset(x,
            :value => ByRow(!=(0))
        ) |>
        x -> leftjoin(
            x,
            col_labels,
            on = :parameter
        )

    DATA = DATA |>
        x -> outerjoin(x, adjusted_values, on = [:row, :col, :year, :parameter], renamecols = "" => "_new") |>
        #x -> coalesce.(x, 0) |>
        x -> transform(x,
            [:value, :value_new] => ((v, new) -> coalesce.(new, v)) => :value
        ) |>
        x -> select(x, Not(:value_new)) |>
        x -> subset(x, 
            :parameter => ByRow(!=(:cif_fob)),
            :value => ByRow(!=(0))
        )

    SETS = SETS |> 
        x -> subset(x,
            :name => ByRow(!∈([:cif_fob,:CIF_FOB]))
        )

    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!∈([:cif_fob, :CIF_FOB]))
        )

    return National(DATA, SETS, ELEMENTS; regularity_check=true)
end


"""
    create_margin_categories(X::National; kwargs...)

Split both the `Trade` and `Transport` parameters in to `Margin_Demand` (positive
values) and `Margin_Supply` (negative values).

Also create the set `margin` which points at the `Transport` and `Trade` sectors.

Return a National table.
"""
function create_margin_categories(X::National; kwargs...)

    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)


    adjusted_values = table(X, :Transport, :Trade) |>
        x -> transform(x,
            :value => ByRow(y -> y>0 ? :margin_demand : :margin_supply) => :parameter
        )
        

    DATA = DATA |>
        x -> subset(x,
            :parameter => ByRow(!∈([:transport, :trade]))
        ) |>
        x -> vcat(x, adjusted_values)
        
    SETS = SETS |> 
        x -> subset(x,
            :name => ByRow(!∈([:Transport, :Trade]))
        ) |>
        x -> push!(x, (name = :Margin_Demand, description = "Positive values in marginal categories", domain = :parameter)) |>
        x -> push!(x, (name = :Margin_Supply, description = "Negative values in marginal categories", domain = :parameter)) |>
        x -> push!(x, (name = :margin, description = "Margin sectors", domain = :col))




    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!∈([:Transport, :Trade]))
        ) |>
        x -> push!(x, (name = :margin_demand, description = "Margin Demand", set = :Margin_Demand)) |>
        x -> push!(x, (name = :margin_supply, description = "Margin Supply", set = :Margin_Supply)) |>
        x -> vcat(
            x,
            elements(X, :transport, :trade) |>
                x -> transform(x,
                    :set => ByRow(y -> :margin) => :set
                )
        )

    return National(DATA, SETS, ELEMENTS; regularity_check=true)

end


"""
    create_pce_categories(X::National; kwargs...)

Split `Personal_Consumption` parameters into `Personal_Consumption` (negative 
values) and `Household_Supply` (positive values).

Return a National table.
"""
function create_pce_categories(X::National; kwargs...)

    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)


    adjusted_values = table(X, :Personal_Consumption) |>
        x -> transform(x,
            :value => ByRow(y -> y>0 ? :household_supply : :personal_consumption) => :parameter
        )
        

    DATA = DATA |>
        x -> subset(x,
            :parameter => ByRow(!∈([:personal_consumption]))
        ) |>
        x -> vcat(x, adjusted_values)
        
    SETS = SETS |> 
        x -> subset(x,
            :name => ByRow(!∈([:Personal_Consumption]))
        ) |>
        x -> push!(x, (name = :Household_Supply, description = "Positive values in PCE (negative in USE table)", domain = :parameter)) |>
        x -> push!(x, (name = :Personal_Consumption, description = "Negative values in PCE (positive in USE table)", domain = :parameter))

    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!∈([:Personal_Consumption]))
        ) |>
        x -> push!(x, (name = :household_supply, description = "Household Supply", set = :Household_Supply)) |>
        x -> push!(x, (name = :personal_consumption, description = "Personal Consumption", set = :Personal_Consumption))

    return National(DATA, SETS, ELEMENTS; regularity_check=true)

end


"""
    adjust_intermediate_flows(X::National; kwargs...)

We take inputs to be negative and outputs to be positive. However, it is possible
to have positive values in `Intermediate_Demand` and negative values in
`Intermediate_Supply`. This function adjusts the flows accordingly.

Returns a National table.
"""
function adjust_intermediate_flows(X::National; kwargs...)
    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)


    adjusted_values = table(X, :Intermediate_Demand, :Intermediate_Supply) |>
        x -> unstack(x, :parameter, :value) |>
        x -> coalesce.(x, 0) |>
        x -> transform(x,
            [:intermediate_demand, :intermediate_supply] => 
                ByRow((d,s) -> (min(0, d + min(0, s)), max(0, s + max(0, d)))) => 
                [:intermediate_demand, :intermediate_supply],
        ) |>
        x -> stack(x, [:intermediate_demand, :intermediate_supply], variable_name = :parameter) |>
        x -> subset(x,
            :value => ByRow(!=(0))
        ) |>
        x -> transform(x,
            :parameter => (y -> Symbol.(y)) => :parameter
        ) 

    DATA = DATA |>
        x -> subset(x,
            :parameter => ByRow(!∈([:intermediate_demand, :intermediate_supply]))
        ) |>
        x -> vcat(x, adjusted_values)
        
    return National(DATA, SETS, ELEMENTS; regularity_check=true)

end

"""
    adjust_negative_value_added(X::National; kwargs...)

There are negative capital demeands in the US table. This function adjusts value added
to ensure that all capital demands are non-negative. The adjustment is given by

```math 
\\sum_{va} VA(year, va, sector) \\cdot \\frac{\\sum_{year} VA(year, va, sector)}{\\sum_{year, va} VA(year, va, sector)} 
```

for any negative value in value added.

Returns a National table.
"""
function adjust_negative_value_added(X::National; kwargs...)
    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)

    shares = table(X, :Value_Added) |>
        x -> groupby(x, [:col]) |>
        x -> combine(x, 
            [:year, :row, :parameter, :value] .=> identity .=> [:year, :row, :parameter, :value],
            :value => sum => :total_value
        ) |>
        x -> groupby(x, [:row, :col, :parameter]) |>
        x -> combine(x, 
            :year => identity => :year,
            [:value, :total_value] => ((v,tv) -> sum(v)./tv) => :share
        ) 

    new_value_added = outerjoin(
            table(X, :Value_Added),
            shares,
            on = [:year, :row, :col, :parameter]
        ) |>
        x -> groupby(x, [:col, :year]) |>
        x -> combine(x,
            [:row, :parameter] .=> identity .=> [:row, :parameter],
            [:value, :share] => (
                (v,s) -> ifelse.(v.<0, v, s.*sum(v))
                ) => :value
        )
    
    va_params = elements(X, :Value_Added; base=true) |> x -> x[!,:set]

    DATA = DATA |>
        x -> subset(x,
            :parameter => ByRow(!∈(va_params))
        ) |>
        x -> vcat(x, new_value_added)



    return National(DATA, SETS, ELEMENTS; regularity_check=true)
end


"""
    zero_marginal_tax_subsidy(X::National; marginal_commodities::Vector{String} = [], kwargs...)
    
Set the subsidy and tax parameters for marginal commodities to zero.

Returns a National table.
"""
function zero_marginal_tax_subsidy(X::National; marginal_commodities::Vector{String} = [], kwargs...)
    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)

    DATA = DATA |>
        x -> subset(x,
            [:row, :parameter] => ByRow((r,p) -> !( (r in Symbol.(marginal_commodities)) && (p in (:subsidy, :tax)) ))
        )

    return National(DATA, SETS, ELEMENTS; regularity_check=true)
end