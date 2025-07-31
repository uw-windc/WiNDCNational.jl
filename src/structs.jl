struct National <: WiNDCtable
    data::DataFrame
    sets::DataFrame
    elements::DataFrame
    parameters::DataFrame
end


domain(data::National) = [:row, :col, :year]
parameters(data::National) = data.parameters
table(data::National) = data.data
sets(data::National) = data.sets
elements(data::National) = data.elements