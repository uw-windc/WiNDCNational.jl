"""
    fetch_zip_data(
        url::String,
        pattern_dict::Dict{String, T};
        output_path::String = tempname(),
    ) where T<:Any

Download a zip file from a given url and extract the files in the zip file that 
are in the `data` NamedTuple.

This function will throw an error if not all files in `data` are extracted.

## Required Arguments

1. `url::String`: The url of the zip file to download.
2. `pattern_dict::Dict{String, T};`: A dictionary where the keys are the names of the
   tables to extract and the values are regex patterns to match the files in the zip file.


## Optional Arguments

- `output_path::String`: The path to save the extracted files. Default is a 
temporary directory. If this is not an absolute path, it will be joined with the 
current working directory.

## Output

Returns a vector of the absolute paths to the extracted files.
"""

function fetch_zip_data(
    url::String,
    pattern_dict::Dict{String, T}; # Could probably be Regex instead of Any
    output_path::String = tempname(),
) where T<:Any
    if !isabspath(output_path)
        output_path = joinpath(pwd(), output_path)
    end

    if !isdir(output_path)
        mkpath(output_path)
    end

    X = Downloads.download(url, joinpath(output_path,"tmp.zip"))
    r = ZipFile.Reader(X)

    extracted_files = Dict{String, String}()
    for (table, pattern) in pattern_dict
        matched_files = [f for f in r.files if occursin(pattern, f.name)]
        if length(matched_files) > 1
            error("More than one file matched for table $table with pattern $pattern: $matched_files")
        elseif length(matched_files) == 1
            f = matched_files[1]
            extracted_files[table] = joinpath(output_path,f.name)
            write(extracted_files[table], read(f))
        end

    end

    close(r)
    rm(X)

    return extracted_files
end

