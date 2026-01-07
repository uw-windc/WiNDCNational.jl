function parse_excel_set_elements(data::Matrix{Any})
    1∈size(data) || error("Must be either a column or row vector")
    return vec(data)
end

function parse_excel_set_elements(data::String)
    return [data]
end

parse_excel_set_elements(::Missing) = missing


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

function initialize_tables(years::Dict{Any, Any})
        ELEMENTS = DataFrame(
        name = Any[values(years)...],
        description = Any[keys(years)...],
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
    load_national_yaml(yaml_path::String; base_dir::String = pwd())

Load the YAML file that describes the national tables. This function also ensures 
the file has the correct structure and fields.

Examples of this file are available for the [summary data](https://github.com/uw-windc/WiNDCNational.jl/blob/main/src/data/summary.yaml) and
[detailed data](https://github.com/uw-windc/WiNDCNational.jl/blob/main/src/data/detailed.yaml).

The `base_dir` argument is used to specify the base directory for relative paths in the YAML file. 
The default is the current working directory.

## Structure of YAML file

### metadata

There are two options for the metadata, either local or remote. 

Remote:

- download: A dictionary with keys the names of the tables and values (at least one needs to be provided):
    - pattern: A regex pattern to match the file name.
    - url: The URL to download the file from.
- download_url_common: If the tables are contained a shared zip file. Defaults to "".

Local:

- paths: A dictionary with keys the names of the tables and values the file paths.

Common: 

- years: A dictionary of years with keys the sheet names and value the year `Dict{String, Int}`.
- `transformation_keywords`: Used to pass parameters to the data transformation 
functions. For the United States national tables, we use two transformations:
    - `insurance_codes`: A list of insurance codes for the redistribution of `CIF_FOB` data to imports and transport.
    - `marginal_commodities`: A list of marginal commodities to include in the transformation.
- `na_values`: A list of values to treat as NA (not available). This is useful for
  handling missing data in the Excel files.

### sets

Each set is listed with the following attributes:

- description - A description for the set
- domain - Which column the set operates on
- values - An Excel range that corresponds to the NAICS codes
- descriptions - An Excel range that corresponds to the descriptions of the NAICS codes
- table - Needs to match the listed paths for download names
- value_labels (optional) - A list of labels for the set elements. If not provided, the values from the Excel range will be used.

### parameters

Each parameter name is listed with the following attributes:

- param - The name of the parameter. This acts as the set to access the parameter.
- description - A description of the parameter
- row - The row set of the parameter.
- col - The column set of the parameter
- table - Needs to match the listed paths for download names
- flip_sign - Boolean, changes the sign of the data. Only used on `sector_subsidy` 
    since the values are reported as positive, but must be negative.

The parameters reference the sets, you shouldn't need to update the parameters if
you only change the sets.

### composite_parameters

Each composite parameter is listed with the following attributes:

- description - A description of the composite parameter
- elements - A list of elements that make up the composite parameter. These should be parameter names

"""
function load_national_yaml(yaml_path::String; base_dir::String = pwd())
    info = YAML.load_file(joinpath(base_dir, yaml_path))

    metadata = get(info, "metadata", Dict())
    sets = get(info, "sets", Dict())
    parameters = get(info, "parameters", Dict())
    composite_parameters = get(info, "composite_parameters", Dict())

    # Metadata
    if isempty(metadata)
        error("Metadata section is missing in the YAML file")
    end

    paths = get(metadata, "paths", Dict()) # Local
    download = get(metadata, "download", Dict()) # Download

    if isempty(paths) && isempty(download)
        error("Either `paths` or `download` section must be provided in the metadata")
    end

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
    build_national_table(yaml_path::String, output_type::Type{<:AbstractNationalTable}; base_dir::String = pwd())

Build and return the national table. By default this accepts a path to a YAML 
file describing the sets and parameters in the excel files. For convenience, 
you can also call this function with the `:summary` or `:detailed` symbols to 
load the corresponding YAML files.

For a full discussion on the structure of the YAML files, refer to [`load_national_yaml`](@ref).
"""
function build_national_table(yaml_path::String, output_type::Type{<:AbstractNationalTable}; base_dir::String = pwd()) 
    info = load_national_yaml(yaml_path; base_dir = base_dir)

    # Parse metadata
    metadata = get(info, "metadata", Dict())


    years = get(metadata, "years", Dict())
    paths = get(metadata, "paths", Dict()) # Local
    download = get(metadata, "download", Dict()) # Download
    download_url_common = get(metadata, "download_url_common", "")

    na_values = get(metadata, "na_values", [])


    tables = Dict{String, Any}()

    if !isempty(paths)
        for (table_name, table_data) in paths
            if "path" ∉ keys(table_data)
                error("Each entry in `paths` must have a `path` field.")
            end
            path = table_data["path"]
            tables[table_name] = XLSX.readxlsx(joinpath(base_dir, path)) # This is going to be a problem
        end
    elseif !isempty(download)
        if !isempty(download_url_common)
           paths = fetch_zip_data(
                download_url_common,
                Dict(table => Regex(d["pattern"]) for (table,d) in download)
            )

            for (table_name, path) in paths
                tables[table_name] = XLSX.readxlsx(path)
            end
        end
        
        #for (table_name, table_data) in download

        #end

    end

    

    ELEMENTS, SETS, DATA = initialize_tables(years)

   # Build sets and elements
    year = first(keys(years)) # Sets and elements are the same for all years.
    for (set_name,set) in info["sets"]
        X = tables[set["table"]][year]

        # Create a new set
        push!(SETS, (name = Symbol(set_name), description = set["description"], domain = Symbol(set["domain"])))
        
        # Add all the elements - Perhaps an error should be thrown if both value_labels and values are missing
        names = Symbol.(get(set, "value_labels", []))
        if isempty(names)
            names = Symbol.(parse_excel_set_elements(X[set["values"]]))
        end

        ELEMENTS = vcat(
            ELEMENTS, 
            DataFrame(
                name = names,
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
    for (sheet_name, year) in years
        for (parm_name, parm) in info["parameters"]
            X = tables[parm["table"]][sheet_name]
            sign = parm["table"] ∈ ["use", "value_added"] ? -1 : 1 # Consider inputs to be negative
            flip_sign = get(parm, "flip_sign", false) # Some parameters may need to flip the sign, `sector_subsidy` is the reason
            sign = flip_sign ? -sign : sign

            row_names = Symbol.(get(set_info[parm["row"]], "value_labels", []))
            if isempty(row_names)
                row_names = Symbol.(parse_excel_set_elements(X[set_info[parm["row"]]["values"]]))
            end

            col_names = Symbol.(get(set_info[parm["col"]], "value_labels", []))
            if isempty(col_names)
                col_names = Symbol.(parse_excel_set_elements(X[set_info[parm["col"]]["values"]]))
            end

            # Transform set ranges into a rectangular excel range
            data_range = excel_intersection(
                ExcelRange(set_info[parm["row"]]["values"]),
                ExcelRange(set_info[parm["col"]]["values"])
            )


            new_data = DataFrame(
                    [row_names X[data_range]],
                    [:row, col_names...]
                ) |>
                x -> stack(x, Not(:row), variable_name = :col) |>
                x -> dropmissing(x) |>
                x -> subset(x,
                    :value => ByRow(!in(na_values)), # Make metadata feature
                ) |>
                x -> transform(x,
                    :row => ByRow(y -> Symbol(parm_name)) => :parameter,
                    #:row => (y -> Symbol.(y)) => :row,
                    :col => ByRow(y -> Symbol(y)) => :col,
                    :value => ByRow(y -> sign* (isa(y,String) ? parse(Float64, y) : y) /1_000) => :value,
                    :row => ByRow(y -> year) => :year,
                ) |>
                x -> subset(x,
                    :value => ByRow(!=(0))
                )

            DATA = vcat(DATA, new_data)
        end

    end

    X = output_type(DATA, SETS, ELEMENTS; regularity_check=true)
    return X, metadata

end













