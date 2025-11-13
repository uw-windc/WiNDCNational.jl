# Building the Data Locally

By default the function [`build_us_table`](@ref) will download the latest data from the BEA website. However, this isn't always ideal, you may not have access to the internet or want to save data to prevent later breaking changes. In these cases you can build the data locally by downloading the necessary files yourself and providing the file paths to the function.

## Download Data

Obviously, the first step to download the data and save it locally. This links to the necessary data are in the [`Data Sources`](@ref data_sources) section of the United States Data.

## Configuring the YAML file

The default YAML files are [`summary.yaml`](summary.yaml) and [`detailed.yaml`](detailed.yaml). Download one of these files. In the `metadata` section, replace the sections

```yaml
download_url_common: "https://apps.bea.gov/industry/release/zip/SUPPLY-USE.zip"
download:
    supply:
        pattern: "^Supply_Summary.xlsx$"
    use:
        pattern: "^Use_Summary.xlsx$"
```
with 
```yaml
paths:
    supply:
        path: path/to/supply/file.xlsx
    use:
        path: path/to/use/file.xlsx
```
where `path/to/supply/file.xlsx` and `path/to/use/file.xlsx` are the paths to the files you downloaded in the previous step.

Load the data using the modified YAML file.

```julia
summary_raw = build_us_table("path/to/modified/summary.yaml")
```
