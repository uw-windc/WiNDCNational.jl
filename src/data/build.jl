

function parse_excel_set_elements(data::Matrix{Any})
    1∈size(data) || error("Must be either a column or row vector")
    return vec(data)
end

function parse_excel_set_elements(data::String)
    return [data]
end



struct ExcelRange
    start::Tuple{String, Int}
    stop::Tuple{String, Int}
    function ExcelRange(range::String)
        if !occursin(":", range)
            range = "$range:$range"
        end
        (a1, a2, a3, a4) = match(r"^([a-zA-Z]+)(\d+):([a-zA-Z]+)(\d+)$", range)

        start = (a1, parse(Int, a2))
        stop = (a3, parse(Int, a4))
        return new(start, stop)
    end
end

function excel_intersection(range1::ExcelRange, range2::ExcelRange)
    r1_c1_row, r1_c1_col = range1.start
    r1_c2_row, r1_c2_col = range1.stop
    r2_c1_row, r2_c1_col = range2.start
    r2_c2_row, r2_c2_col = range2.stop

    return "$r2_c1_row$r1_c1_col:$r2_c2_row$r1_c2_col"
end


function excel_intersection(range1::String, range2::String)
    return excel_intersection(ExcelRange(range1), ExcelRange(range2))
end



function initialize_tables(years::Vector{String})
    ELEMENTS = DataFrame(
        name = Any[parse.(Int, years)...],
        description = years,
        set = Symbol[:year for _ in years]
    )

    SETS = DataFrame(
        name = Symbol[:year],
        description = [""],
        domain = Symbol[:year]
    )

    DATA = DataFrame(
        row = Symbol[],
        col = Symbol[],
        year = Int[],
        parameter = Symbol[],
        value = []
    )

    return ELEMENTS, SETS, DATA
end


"""
    load_national_yaml(yaml_path::String)

Load the YAML file that describes the national tables. This function also ensures 
the file has the correct structure and fields.

Examples of this file are available for the [summary data](https://github.com/uw-windc/WiNDCNational.jl/blob/main/src/data/summary.yaml) and
[detailed data](https://github.com/uw-windc/WiNDCNational.jl/blob/main/src/data/detailed.yaml).

## Structure of YAML file

### metadata

- years: A list of years covered by the data (e.g., [2020, 2021, 2022]). Defaults to "all".
- supply_path: The path to the supply data. Defaults to ""
- use_path: The path to the use data. Defaults to ""
- supply_pattern: A regex pattern to match the file name of the supply table. Defaults to ""
- use_pattern: A regex pattern to match the file name of the use table. Defaults to ""
- transformation_keywords: A list of keywords for data transformation. Defaults to []

You must either specify both `use_path` and `supply_path` or `supply_pattern` and
`use_pattern`. 

The `transformation_keywords` are used to pass parameters to the data transformation 
functions. In particular, it's useful to have an `insurance_codes` keyword for 
the redistribution of `CIF_FOB` data to imports and transport.

### sets

Each set is listed with the following attributes:

- description - A description for the set
- domain - Which column the set operates on
- values - An Excel range that corresponds to the NAICS codes
- descriptions - An Excel range that corresponds to the descriptions of the NAICS codes
- table - Either "use" or "supply"

### parameters

Each parameter name is listed with the following attributes:

- param - The name of the parameter. This acts as the set to access the parameter.
- description - A description of the parameter
- row - The row set of the parameter.
- col - The column set of the parameter
- table - Either "use" or "supply"
- flip_sign - Boolean, changes the sign of the data. Only used on `sector_subsidy` 
    since the values are reported as positive, but must be negative.

The parameters reference the sets, you shouldn't need to update the parameters if
you only change the sets.

### composite_parameters

Each composite parameter is listed with the following attributes:

- description - A description of the composite parameter
- elements - A list of elements that make up the composite parameter. These should be parameter names

"""
function load_national_yaml(yaml_path::String)
    info = YAML.load_file(yaml_path)

    metadata = get(info, "metadata", Dict())
    sets = get(info, "sets", Dict())
    parameters = get(info, "parameters", Dict())
    composite_parameters = get(info, "composite_parameters", Dict())

    # Metadata
    if isempty(metadata)
        @warn("Metadata section is missing in the YAML file, defaulting to all" * 
             "years at the summary level"
             )
    end

    supply_path = get(metadata, "supply_path", "")
    use_path = get(metadata, "use_path", "")
    supply_pattern = get(metadata, "supply_pattern", "")
    use_pattern = get(metadata, "use_pattern", "")

    # Validate paths
    (isempty(supply_path) && isempty(use_path)) || (!isempty(supply_path) && !isempty(use_path)) ||
        error("Either provide both `supply_path` and `use_path` or neither.")

    !(isempty(supply_path) && (isempty(supply_pattern) || isempty(use_pattern))) ||
        error("If `supply_path` and `use_path` are not provided, `supply_pattern` and `use_pattern` must be specified.")


    for (set_name, set) in sets
        required_fields = ["description","domain","values","descriptions","table"] 

        missing_fields = setdiff(required_fields, keys(set))
        if !isempty(missing_fields)
            error("Missing fields in set '$set_name':  $([missing_fields...])")
        end
    end

    for (param_name, param) in parameters
        required_fields = ["param","description","row","col","table"] 
        missing_fields = setdiff(required_fields, keys(param))
        if !isempty(missing_fields)
            error("Missing fields in parameter '$param_name': ", missing_fields)
        end
    end

    for (param_name, param) in composite_parameters
        required_fields = ["description","elements"] 
        missing_fields = setdiff(required_fields, keys(param))
        if !isempty(missing_fields)
            error("Missing fields in composite parameter '$param_name': ", missing_fields)
        end
    end

    return info
end


"""
    build_national_table(aggregation::Symbol = :summary)
    build_national_table(yaml_path::String)

Build and return the national table. By default this accepts a path to a YAML 
file describing the sets and parameters in the excel files. For convenience, 
you can also call this function with the `:summary` or `:detailed` symbols to 
load the corresponding YAML files.

For a full discussion on the structure of the YAML files, refer to [`load_national_yaml`](@ref).
"""
function build_national_table(yaml_path::String)
    info = load_national_yaml(yaml_path)

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
                    :value => ByRow(!=("...")), # Make metadata feature
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

    X = National(DATA, SETS, ELEMENTS; regularity_check=true)

    transformation_keywords = get(metadata, "transformation_keywords", Dict())
    transformation_keywords = Dict(Symbol(k) => v for (k,v) in transformation_keywords)
    X = redistribute_cif_fob(X; transformation_keywords...)
    X = create_margin_categories(X; transformation_keywords...)
    X = create_pce_categories(X; transformation_keywords...)
    X = adjust_intermediate_flows(X; transformation_keywords...)

    return X

end


function build_national_table(aggregation::Symbol = :summary)
    aggregation ∈ [:summary, :detailed] || error("Aggregation must be either :summary or :detailed")
    yaml_path = joinpath(@__DIR__, "$aggregation.yaml")
    return build_national_table(yaml_path)
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














