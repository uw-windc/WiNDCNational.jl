
calibrate_fix_variables(M::Model, X::National) = nothing

function calibrate_constraints(M::Model, X::National; lower_bound = .01, upper_bound = 10) 
    table(X, :commodity) |>
        x -> groupby(x, [:row, :year]) |>
        x -> combine(x, :variable => sum => :market_clearance) |>
        x -> @constraint(M, 
            market_clearance[i=1:size(x,1)],
            x[i,:market_clearance] == 0
        )

    table(X, :sector) |>
        x -> groupby(x, [:col, :year]) |>
        x -> combine(x, :variable => sum => :zero_profit) |>
        x -> @constraint(M, 
            zero_profit[i=1:size(x,1)],
            x[i,:zero_profit] == 0
        )
end