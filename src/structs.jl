abstract type AbstractNationalTable <: WiNDCtable end


domain(data::AbstractNationalTable) = [:row, :col, :year]
base_table(data::AbstractNationalTable) = data.data
sets(data::AbstractNationalTable) = data.sets
elements(data::AbstractNationalTable) = data.elements

"""
    National

The primary container for national data tables. There are three fields, all dataframes:

- `data`: The main data table.
- `sets`: The sets table, describing the different sets used in the model.
- `elements`: The elements table, describing the different elements in the model.
"""
struct National <: AbstractNationalTable
    data::DataFrame
    sets::DataFrame
    elements::DataFrame
end


struct AustraliaNational <: AbstractNationalTable
    data::DataFrame
    sets::DataFrame
    elements::DataFrame
end