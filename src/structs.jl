struct National <: WiNDCtable
    data::DataFrame
    sets::DataFrame
    elements::DataFrame
end


domain(data::National) = [:row, :col, :year]
table(data::National) = data.data
sets(data::National) = data.sets
elements(data::National) = data.elements