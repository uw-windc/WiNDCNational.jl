abstract type AbstractNationalTable <: WiNDCtable end


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


domain(data::National) = [:row, :col, :year]
table(data::National) = data.data
sets(data::National) = data.sets
elements(data::National) = data.elements