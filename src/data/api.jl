"""
    fetch_zip_data(
        url::String,
        filter_function::Function;;
        output_path::String = tempname(),
    )

Download a zip file from a given url and extract the files in the zip file that 
are in the `data` NamedTuple.

This function will throw an error if not all files in `data` are extracted.

## Required Arguments

1. `url::String`: The url of the zip file to download.
2. `filter_function::Function;`: A function that takes a string and returns a boolean.
    This function is used to filter the files in the zip file, it should return `true` 
    if the file should be extracted and `false` otherwise.


## Optional Arguments

- `output_path::String`: The path to save the extracted files. Default is a 
temporary directory. If this is not an absolute path, it will be joined with the 
current working directory.

## Output

Returns a vector of the absolute paths to the extracted files.
"""

function fetch_zip_data(
    url::String,
    filter_function::Function;
    output_path::String = tempname(),
)
    if !isabspath(output_path)
        output_path = joinpath(pwd(), output_path)
    end

    if !isdir(output_path)
        mkpath(output_path)
    end

    X = Downloads.download(url, "tmp.zip")
    r = ZipFile.Reader(X)

    extracted_files = String[]
    for f in r.files
        if filter_function(f.name)
            write(joinpath(output_path,f.name),read(f))
            push!(extracted_files, f.name)
        end
    end

    close(r)
    rm(X)

    return joinpath.(Ref(output_path),extracted_files)
end



"""
    filter_to_sut(x::AbstractString)

Return `true` if the string `x` corresponds to either a detailed or summary supply
or use table. Otherwise, return `false`.
"""
function filter_to_sut(x::AbstractString)
    return occursin(r"Supply.*_DET",x) || occursin(r"Use.*_DET",x) || occursin(r"Supply.*Summary",x) || occursin(r"Use.*_Summary",x)
end


"""
    fetch_supply_use(
        ;
        url::String = "https://apps.bea.gov/industry/iTables%20Static%20Files/AllTablesSUP.zip",
        output_path::String = tempname(),
    )

Fetch the supply and use tables from the BEA website. The data is stored in a zip file,
which is downloaded and extracted to the `output_path`. The extracted files are then
returned as a vector of strings.

## Optional Arguments

- `url::String`: The url of the zip file containing the supply and use tables. Default is
"https://apps.bea.gov/industry/iTables%20Static%20Files/AllTablesSUP.zip".

- `output_path::String`: The path to save the extracted files. Default is a temporary directory.

## Output

Returns a vector of the absolute paths to the extracted files.
"""
function fetch_supply_use(
    ;
    url::String = "https://apps.bea.gov/industry/iTables%20Static%20Files/AllTablesSUP.zip",
    output_path::String = tempname(),
)
    return fetch_zip_data(url, filter_to_sut; output_path = output_path)
end

