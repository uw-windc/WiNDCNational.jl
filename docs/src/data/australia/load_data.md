# Loading the Data

To load the Australia data into WiNDC National, you first need to download the necessary tables from the Australian Bureau of Statistics (ABS) as described in the [Data Sources section](@ref australia_data_sources). Be sure to convert the downloaded files to `.xlsx`.

An example YAML file can be [downloaded here](./australia_local.yaml). Update the `paths` section of the YAML file to point to the downloaded data files. In other words, replace
```yaml
  paths:
    use: 
      path: path/to/use/data.xlsx
    supply:
      path: path/to/supply/data.xlsx
    value_added:
      path: path/to/value_added/data.xlsx
```
with the actual paths to the downloaded files.

## Modifying Years

The years section of the YAML file looks like:
```yaml
  years:
    "2021-22": 2022
    "2022-23": 2023
    "2023-24": 2024
```
The left hand side is the name of the sheet in the Excel file, and the right hand side is the year that will be used in WiNDC National. Modify this section if you are using different years or sheets.

## Example Usage

To load the data using the YAML file, use the following code in Julia:
```julia
australia_raw = build_australia_table("australia.yaml") # Change to your YAML file path

australia,M = calibrate(australia_raw)
```