

"""
    build_australia_table(yaml_path::String)

Build the Australia national table. Structure YAML file as specified by [build_national_table](@ref).

!!!note
    The data files provided by Australia are only available in XLSB format, which
    Julia cannot open. There are also missing headers in final demand, supply extras,
    and value added. More work is necessary to rectify these issues.
"""
function build_australia_table(yaml_path::String)
    X, metadata = build_national_table(yaml_path, AustraliaNational)

    X = create_margin_categories(X)
    X = create_pce_categories(X)

    X = merge_export_reexport(X)

    return X

end



"""
    create_margin_categories(X::AustraliaNational; kwargs...)

Split both the `Trade` and `Transport` parameters in to `Margin_Demand` (positive
values) and `Margin_Supply` (negative values).

Also create the set `margin` which points at the `Transport` and `Trade` sectors.

Return a AustraliaNational table.
"""
function create_margin_categories(X::AustraliaNational; kwargs...)

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

    return AustraliaNational(DATA, SETS, ELEMENTS; regularity_check=true)

end



"""
    create_pce_categories(X::AustraliaNational; kwargs...)

Split `Personal_Consumption` parameters into `Personal_Consumption` (negative 
values) and `Household_Supply` (positive values).

Return a AustraliaNational table.
"""
function create_pce_categories(X::AustraliaNational; kwargs...)

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

    return AustraliaNational(DATA, SETS, ELEMENTS; regularity_check=true)

end


"""
    merge_export_reexport(X::AustraliaNational; kwargs...)

Merge export and re-export values in the dataset.

Return a AustraliaNational table.
"""
function merge_export_reexport(X::AustraliaNational; kwargs...)

    DATA = table(X)
    SETS = sets(X)
    ELEMENTS = elements(X)


    adjusted_values = table(X, :Export, :Reexport) |>
        x -> groupby(x, [:row, :year]) |>
        x -> combine(x, :value => sum => :value) |>
        x -> transform(x,
            :row => ByRow(y -> (:export, :export)) => [:col, :parameter]
        )
        

    DATA = DATA |>
        x -> subset(x,
            :parameter => ByRow(!∈([:export, :reexport]))
        ) |>
        x -> vcat(x, adjusted_values)
        
    SETS = SETS |> 
        x -> subset(x,
            :name => ByRow(!∈([:Reexport]))
        ) #|>
        #x -> push!(x, (name = :Household_Supply, description = "Positive values in PCE (negative in USE table)", domain = :parameter)) |>
        #x -> push!(x, (name = :Personal_Consumption, description = "Negative values in PCE (positive in USE table)", domain = :parameter))

    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!∈([:Reexport]))
        ) #|>
        #x -> push!(x, (name = :household_supply, description = "Household Supply", set = :Household_Supply)) |>
        #x -> push!(x, (name = :personal_consumption, description = "Personal Consumption", set = :Personal_Consumption))

    return AustraliaNational(DATA, SETS, ELEMENTS; regularity_check=true)

end