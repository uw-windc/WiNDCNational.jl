

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

For a full discussion on the structure of the YAML files, refer to the documentation.
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

Redistribute the CIF_FOB parameter to Transport and Import, add all insurance 
commodities values to Import and non-insurance commodities to Transport. Remove 
CIF_FOB parameter. 

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
            :name => ByRow(!=(:CIF_FOB))
        )

    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!=(:CIF_FOB))
        )

    return National(DATA, SETS, ELEMENTS; regularity_check=true)
end


"""
    create_margin_categories(X::National; kwargs...)

Split both the `Trade` and `Transport` parameters in to `Margin_Demand` (positive
values) and `Margin_Supply` (negative values).

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
        x -> push!(x, (name = :Margin_Supply, description = "Negative values in marginal categories", domain = :parameter))

    ELEMENTS = ELEMENTS |>
        x -> subset(x,
            :set => ByRow(!∈([:Transport, :Trade]))
        ) |>
        x -> push!(x, (name = :margin_demand, description = "Margin Demand", set = :Margin_Demand)) |>
        x -> push!(x, (name = :margin_supply, description = "Margin Supply", set = :Margin_Supply))

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
    load_national_data_single_year(
        X::XLSX.XLSXFile,
        year,
        range,
        table_name::String;
        scale = 1_000,
        data_start_row = 2
    )

Load a single year of national data. This function is used to load data from
the supply and use tables. The data is transformed into a DataFrame with the
following columns:

- `:commodities`: The commodities in the table.
- `:sectors`: The sectors in the table.
- `:value`: The value of the commodity in the sector.
- `:year`: The year of the data.
- `:table`: The name of the table.

## Required Arguments

- `X::XLSX.XLSXFile`: The XLSXFile containing the data.
- `year`: The year of the data.
- `range`: The range of the data in the XLSXFile.
- `table_name::String`: The name of the table. Usually "use" or "supply".

## Optional Arguments

- `scale::Int = 1_000`: The scale of the data.
- `data_start_row::Int = 2`: The row in the XLSXFile where the data starts. 
    Summary tables start at 3, detailed at 2.

## Return

A DataFrame.
"""
function load_national_data_single_year(
    X::XLSX.XLSXFile,
    year,
    range,
    table_name::String;
    scale = 1_000,
    data_start_row = 2)

    U = X[year][range]

    U[1,1] = :commodities
    U[1,2] = :drop

    U[@.(!ismissing(U) && U=="...")] .= missing

    return DataFrame(U[data_start_row:end,1:end], string.(U[1,:])) |>
                x -> select(x, Not(:drop)) |>
                x -> stack(x, Not(:commodities), variable_name = :sectors) |>
                x -> coalesce.(x, 0) |>
                x -> subset(x,
                    :value => ByRow(!=(0))
                ) |>
                x -> transform(x,
                    :value => (y -> y/scale) => :value,
                    [:commodities,:sectors] .=> ByRow(string) .=> [:commodities,:sectors],
                    :commodities => ByRow(y -> parse(Int, year)) => :year,
                    :commodities => ByRow(y -> table_name) => :table
                )
end

"""
    load_national_data(
        use::XLSX.XLSXFile,
        supply::XLSX.XLSXFile;
        table_type = :detailed,
        use_range = "A6:PI417",
        supply_range = "A6:OZ409"
    )

Load the national supply and use tables. This function loads the data from the
XLSXFiles and returns a DataFrame with the following columns:

- `:commodities`: The commodities in the table.
- `:sectors`: The sectors in the table.
- `:value`: The value of the commodity in the sector.
- `:year`: The year of the data.

## Required Arguments

- `use::XLSX.XLSXFile`: The XLSXFile containing the use table.
- `supply::XLSX.XLSXFile`: The XLSXFile containing the supply table.

## Optional Arguments

- `table_type::Symbol = :detailed`: The type of table. Either `:detailed` or `:summary`.
- `use_range::String = "A6:PI417"`: The range of the use table in the XLSXFile.
- `supply_range::String = "A6:OZ409"`: The range of the supply table in the XLSXFile.

## Return

A DataFrame.
"""
function load_national_data(
    use::XLSX.XLSXFile,
    supply::XLSX.XLSXFile;
    table_type = :detailed,
    use_range = "A6:PI417",
    supply_range = "A6:OZ409"
)

    @assert XLSX.sheetnames(use) == XLSX.sheetnames(supply) "Use and supply tables do not have the same years."

    data_start_row = table_type == :detailed ? 2 : 3
    insurance_codes = table_type == :detailed ? ["524113","5241XX","524200"] : ["524"]  
    trans_col = table_type == :detailed ? :TRANS : :Trans

    out = DataFrame()
    for year in [f for f in XLSX.sheetnames(use) if f!="NAICS Codes"]
        use_df_year = load_national_data_single_year(
            use,
            year,
            use_range,
            "use";
            data_start_row = data_start_row
        )

        supply_df_year = load_national_data_single_year(
            supply,
            year,
            supply_range,
            "supply";
            data_start_row = data_start_row
        )|>
        x -> unstack(x, :sectors, :value) |>
        x -> coalesce.(x, 0) |>
        x -> transform(x, 
            # adjust transport margins for transport sectors according to CIF/FOP 
            # adjustments. Insurance imports are specified as net of adjustments.
        [:commodities, trans_col, :MADJ] => ByRow((c,t,f) -> c∈insurance_codes ? t : t+f) => trans_col,
        [:commodities, :MCIF, :MADJ] => ByRow((c,i,f) -> c∈insurance_codes ? i+f : i) => :MCIF,
        ) |>
        x -> select(x, Not(:MADJ)) |>
            x -> stack(x, Not(:commodities, :year,:table), variable_name = :sectors, value_name = :value) |>
        x -> dropmissing(x) |>
        x -> subset(x, :value => ByRow(x -> x!=0)) 

        # Remove subsidies from 441 commodity. This is only non-zero in 2009, 2010, and 2011
        if table_type == :summary
            supply_df_year |>
                x -> transform!(x,
                    [:commodities, :sectors, :value] => ByRow((c,s,v) -> (c=="441" && s=="SUB") ? 0 : v) => :value
                )
        end


        out = vcat(out, use_df_year, supply_df_year)
    end

    return out

end

"""
    build_national_table(
        file_paths::Vector{String};
        aggregation = :detailed
    )

Builds the national data from the supply and use tables. 

## Required Arguments

- `file_paths::Vector{String}`: A vector of file paths to the supply and use tables.
    Uses regex to search for the correct files. This should be the output of [`fetch_supply_use`](@ref)

## Optional Arguments

- `aggregation::Symbol = :detailed`: The type of table. Either `:detailed` or `:summary`.


## Return

A [`NationalTable`](@ref).

## Process

The data undergoes a series of transformations to create the final table. The data is loaded
from the XLSXFiles, transformed into a DataFrame, and then joined with the sets created from
the table. 

The following data tranformations take place:

1. Negative flows from `intermediate_demand` and `intermediate_supply` are reversed.
2. `subsidies` and `sector_subsidy` are negated.
3. `margin_demand` retains only positive values.
4. `margin_supply` retains only negative values, these are made positive
5. `personal_consumption` retains only positive values.
6. `household_supply` retains only negative values, these are made positive.
"""
function build_national_table(
    file_paths::Vector{String};
    aggregation = :detailed
)

    if aggregation == :detailed
        use_range = "A6:PI417"
        supply_range = "A6:OZ409"

        set_regions = Dict(
            "commodities" => ("use", ["A7:B408"], :commodities),
            "labor_demand" => ("use", ["A410:B410"], :commodities),
            "other_tax" => ("use", ["A411:B411"], :commodities),
            "capital_demand" => ("use", ["A412:B412"], :commodities),
            "sectors" => ("use", ["C5:ON6"], :sectors),
            "personal_consumption" => ("use", ["OP5:OP6"], :sectors),
            "household_supply" => ("use", ["OP5:OP6"], :sectors),
            "exports" => ("use", ["OV5:OV6"], :sectors),
            "exogenous_final_demand" => ("use", ["OQ5:OU6","OW5:PH6"], :sectors),
            "imports" => ("supply", ["OP5:OP6"], :sectors),
            "margin_demand" => ("supply", ["OS5:OT6"], :sectors),
            "margin_supply" => ("supply", ["OS5:OT6"], :sectors),
            "duty" => ("supply", ["OV5:OV6"], :sectors),
            "tax" => ("supply", ["OW5:OW6"], :sectors),
            "subsidies" => ("supply", ["OX5:OX6"], :sectors),
            #"cif" => ("supply", ["OQ5:OQ6"], :sectors),
        )

        use_path = filter(x -> occursin(r"Use_.*_DET",x), file_paths)[1]
        supply_path = filter(x -> occursin(r"Supply_.*_DET",x), file_paths)[1]


    else
        use_range = "A6:CP90"
        supply_range = "A6:CG81"
        set_regions = Dict(
            "commodities" => ("use", ["A8:B80"], :commodities),
            "labor_demand" => ("use", ["A82:B82"], :commodities),
            "other_tax" => ("use", ["A83:B83"], :commodities),
            "sector_subsidy" => ("use", ["A84:B84"], :commodities),
            "capital_demand" => ("use", ["A85:B85"], :commodities),
            "sectors" => ("use", ["C6:BU7"], :sectors),
            "personal_consumption" => ("use", ["BW6:BW7"], :sectors),
            "household_supply" => ("use", ["BW6:BW7"], :sectors),
            "exports" => ("use", ["CC6:CC7"], :sectors),
            "exogenous_final_demand" => ("use", ["BX6:CB7","CD6:CO7"], :sectors),
            "imports" => ("supply", ["BW6:BW7"], :sectors),
            "margin_demand" => ("supply", ["BZ6:CA7"], :sectors),
            "margin_supply" => ("supply", ["BZ6:CA7"], :sectors),
            "duty" => ("supply", ["CC6:CC7"], :sectors),
            "tax" => ("supply", ["CD6:CD7"], :sectors),
            "subsidies" => ("supply", ["CE6:CE7"], :sectors),
            #"cif" => ("supply", ["BX6:BX7"], :sectors),
        )

        use_path = filter(x -> occursin(r"Use_.*Summary",x), file_paths)[1]
        supply_path = filter(x -> occursin(r"Supply_.*Summary",x), file_paths)[1]

    end
    
    use = XLSX.readxlsx(use_path)
    supply = XLSX.readxlsx(supply_path)

    data = load_national_data(
            use, 
            supply; 
            table_type = aggregation,
            use_range = use_range,
            supply_range = supply_range
            )

    summary_sets = WiNDC.create_national_sets(use["2017"], supply["2017"], set_regions; table_type = aggregation)

    subtables = WiNDC.create_national_subtables(summary_sets)

    summary_data = innerjoin(
        data,
        subtables,
        on = [:commodities, :sectors, :table],
    )|>
    x -> select(x, :commodities, :sectors, :year, :subtable, :value) |>
    x -> unstack(x, :subtable, :value) |>
    x -> coalesce.(x,0) |>
    x -> transform(x, 
        [:intermediate_demand, :intermediate_supply] => ByRow(
            (d,s) -> (max(0, d - min(0, s)), max(0, s - min(0, d)))) => [:intermediate_demand, :intermediate_supply], #negative flows are reversed
        
        :margin_demand => ByRow(y ->  max(0,y)) => :margin_demand,
        :margin_supply => ByRow(y -> -min(0,y)) => :margin_supply,
        :personal_consumption => ByRow(y -> max(0,y)) => :personal_consumption,
        :household_supply => ByRow(y -> -min(0,y)) => :household_supply,
        ifelse("sector_subsidy" ∈ names(x), 
            [:subsidies, :sector_subsidy] .=> ByRow(y -> -y) .=> [:subsidies, :sector_subsidy], 
            :subsidies => ByRow(y -> -y) => :subsidies
            )
    )  |>
    x -> stack(x, Not(:commodities, :sectors, :year), variable_name = :subtable, value_name = :value) |>
    x -> subset(x, :value => ByRow(!=(0)))


    return NationalTable(summary_data, summary_sets)

end


