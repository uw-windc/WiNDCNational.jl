
function calibrate_fix_variables(M::Model, X::National)
    table(X, :Import, :Export, :Labor_Demand, :Household_Supply) |>
        x -> transform(x,
            [:value, :variable] => ByRow((val, var) -> fix(var, val; force=true))
        ) 

end

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

    table(X, :margin) |>
        x -> groupby(x, [:col, :year]) |>
        x -> combine(x, :variable => sum => :margin_balance) |>
        x -> @constraint(M, 
            margin_balance[i=1:size(x,1)],
            x[i,:margin_balance] == 0
        )


    # Bound gross output
    outerjoin(
        gross_output(X; column = :variable, output = :expr),
        gross_output(X; column = :value),
        on = [:row, :year]
    ) |> 
    x -> transform(x,
            :value => ByRow(v -> v>0 ? floor(lower_bound*v)-5 : upper_bound*v) => :lower, 
            :value => ByRow(v -> v>0 ? upper_bound*v : ceil(lower_bound*v)+5) => :upper, 
    )|>
    x -> @constraint(M,
        gross_output[i=1:size(x,1)],
        x[i,:lower] <= x[i,:expr] <= x[i,:upper]
    )


    # Bound armington supply
    outerjoin(
        armington_supply(X; column = :variable, output = :expr),
        armington_supply(X; column = :value),
        on = [:row, :year]
    ) |>
    x -> @constraint(M,
        armington_supply[i=1:size(x,1)],
        max(0,lower_bound * x[i,:value]) <= x[i,:expr] <= abs(upper_bound * x[i,:value])
    )


    # Fix tax rates
    outerjoin(
        sectoral_output(X; column = :variable, output = :total_output),
        output_tax(X, column = :variable, output = :ot),
        output_tax_rate(X, column = :value, output = :otr),
        on = filter(y -> y!=:row, domain(X))
    ) |>
    x -> dropmissing(x) |>
    x -> @constraint(M, 
        Output_Tax_Rate[i=1:size(x,1)],
        x[i,:ot] == x[i,:total_output] * x[i,:otr]
    )


    outerjoin(
        absorption_tax(X, column = :variable, output = :at),
        armington_supply(X, column = :variable, output = :as),
        absorption_tax_rate(X, output = :atr),
        on = filter(y -> y!=:col, domain(X))
    ) |>
    x -> dropmissing(x) |>
    x -> @constraint(M,
        Absorption_Tax_Rate[i=1:size(x,1)],
        x[i,:at] == x[i,:as] * x[i,:atr]
    )
    

    outerjoin(
        table(X, :Duty) |>
            x -> select(x, :row, :year, :variable => :it),
        table(X, :Import) |>
            x -> select(x, :row, :year, :variable => :import),
        import_tariff_rate(X, output = :itr),
        on = filter(y -> y!=:col, domain(X))
    ) |>
    x -> dropmissing(x) |>
    x -> @constraint(M,
        Import_Tariff_Rate[i=1:size(x,1)],
        x[i,:it] == x[i,:import] * x[i,:itr]
    )
  
end