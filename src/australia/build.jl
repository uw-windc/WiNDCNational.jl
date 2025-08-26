function build_australia_table(yaml_path::String)
    info = WiNDCNational.load_national_yaml(yaml_path)

    # Parse metadata
    metadata = get(info, "metadata", Dict())


    years = get(metadata, "years", "all")
    supply_path = get(metadata, "supply_path", "")
    use_path = get(metadata, "use_path", "")
    supply_pattern = get(metadata, "supply_pattern", "")
    use_pattern = get(metadata, "use_pattern", "")


    # Download the tables and extract the paths if necessary
    if isempty(supply_path) || isempty(use_path)
        use_path, supply_path = download_supply_use(Regex(use_pattern), Regex(supply_pattern))
    end

    tables = Dict(
        "use" => XLSX.readxlsx(use_path),
        "supply" => XLSX.readxlsx(supply_path)
    )

    
    if years == "all" # If years is "all", extract all years from the use table
        years = filter(x -> !isnothing(match(r"^\d{4}$", x)), XLSX.sheetnames(tables["use"]))
    end
    years = string.(years) # The sheet names are strings, so make sure years are strings.

    ELEMENTS, SETS, DATA = initialize_tables(years)

   # Build sets and elements
    year = years[1] # Sets and elements are the same for all years.
    for (set_name,set) in info["sets"]

        X = tables[set["table"]][year]

        # Create a new set
        push!(SETS, (name = Symbol(set_name), description = set["description"], domain = Symbol(set["domain"])))

        # Add all the elements
        names = parse_excel_set_elements(X[set["values"]])
        ELEMENTS = vcat(
            ELEMENTS, 
            DataFrame(
                name = Symbol.(names),
                description = parse_excel_set_elements(X[set["descriptions"]]),
                set = repeat([Symbol(set_name)], length(names))
            ) 
        )
    end

    for (parm_name, parm) in info["parameters"] # Create sets and elements for parameters
        push!(SETS, (name = Symbol(parm["param"]), description = parm["description"], domain = :parameter ))
        push!(ELEMENTS, (name = Symbol(parm_name), description = parm["description"], set = Symbol(parm["param"])))
    end

    for (param_name, parm) in info["composite_parameters"] # Create sets and elements for composite parameters
        elements = Symbol.(parm["elements"])
        push!(SETS, (name = Symbol(param_name), description = parm["description"], domain = :parameter ))
        for element in elements    
            push!(ELEMENTS, (name = element, description = parm["description"], set = Symbol(param_name)))
        end
    end

    # Load data
    set_info = info["sets"]
    for year in years
        for (parm_name, parm) in info["parameters"]
            X = tables[parm["table"]][year]
            sign = parm["table"] == "use" ? -1 : 1 # Consider inputs to be negative
            flip_sign = get(parm, "flip_sign", false) # Some parameters may need to flip the sign, `sector_subsidy` is the reason
            sign = flip_sign ? -sign : sign

            row_range = set_info[parm["row"]]["values"]
            col_range = set_info[parm["col"]]["values"]

            # Transform set ranges into a rectangular excel range
            data_range = excel_intersection(
                ExcelRange(set_info[parm["row"]]["values"]),
                ExcelRange(set_info[parm["col"]]["values"])
            )

            new_data = DataFrame(
                    [Symbol.(parse_excel_set_elements(X[row_range])) X[data_range]],
                    [:row, Symbol.(parse_excel_set_elements(X[col_range]))...]
                ) |>
                x -> stack(x, Not(:row), variable_name = :col) |>
                x -> dropmissing(x) |>
                x -> subset(x,
                    :value => ByRow(!=("n.p.")), # Make metadata feature
                ) |>
                x -> transform(x,
                    :row => ByRow(y -> Symbol(parm_name)) => :parameter,
                    :row => (y -> Symbol.(y)) => :row,
                    :col => ByRow(y -> Symbol(y)) => :col,
                    :value => ByRow(y -> sign* (isa(y,String) ? parse(Float64, y) : y) /1_000) => :value,
                    :row => ByRow(y -> parse(Int, year)) => :year,
                ) |>
                x -> subset(x,
                    :value => ByRow(!=(0))
                )
            DATA = vcat(DATA, new_data)
        end

    end

    X = AustraliaNational(DATA, SETS, ELEMENTS; regularity_check=true)


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