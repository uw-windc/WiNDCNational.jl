"""
    calibrate_fix_variables(M::Model, X::National)

Four parameters are considered to be exogenous and fixed in the calibration:

- Import
- Export
- Labor Demand
- Household Supply
"""
function calibrate_fix_variables(M::Model, X::AbstractNationalTable)
    table(X, :Import, :Export, :Labor_Demand, :Household_Supply) |>
        x -> transform(x,
            [:value, :variable] => ByRow((val, var) -> fix(var, val; force=true))
        ) 

end


drop_parameter(X::DataFrame) = select(X, Not(:parameter))


"""
    calibrate_constraints(M::Model, X::National; lower_bound = .01, upper_bound = 10) 

We implement the following constraints:

1. [`zero_profit`](@ref) equal to 0
2. [`market_clearance`](@ref) equal to 0
3. [`margin_balance`](@ref) equal to 0
4. [`gross_output`](@ref) is bounded by `lower_bound` and `upper_bound` of its value
5. [`armington_supply`](@ref) is bounded by `lower_bound` and `upper_bound` of its value

We fix the following tax rates:

1. [`output_tax_rate`](@ref)
2. [`absorption_tax_rate`](@ref)
3. [`import_tariff_rate`](@ref)

"""
function calibrate_constraints(M::Model, X::AbstractNationalTable; lower_bound = .01, upper_bound = 10) 
    market_clearance(X; column = :variable, output = :market_clearance) |>
        x -> @constraint(M, 
            market_clearance[i=1:size(x,1)],
            x[i,:market_clearance] == 0
        )

    zero_profit(X; column = :variable, output = :zero_profit) |>
        x -> @constraint(M, 
            zero_profit[i=1:size(x,1)],
            x[i,:zero_profit] == 0
        )

    margin_balance(X; column = :variable, output = :margin_balance) |>
        x -> @constraint(M, 
            margin_balance[i=1:size(x,1)],
            x[i,:margin_balance] == 0
        )


    # Bound gross output
    outerjoin(
        gross_output(X; column = :variable, output = :expr) |> drop_parameter,
        gross_output(X; column = :value, output = :value) |> drop_parameter,
        on = [:row, :year]
    ) |>
    x -> transform(x,
            :value => ByRow(v -> v>0 ? floor(lower_bound*v)-5 : upper_bound*v) => :lower, 
            :value => ByRow(v -> v>0 ? upper_bound*v : ceil(lower_bound*v)+5) => :upper, 
    ) |>
    x -> @constraint(M,
        gross_output[i=1:size(x,1)],
        x[i,:lower] <= x[i,:expr] <= x[i,:upper]
    )


    # Bound armington supply
    innerjoin(
        armington_supply(X; column = :variable, output = :expr) |> drop_parameter,
        armington_supply(X; column = :value, output = :value) |> drop_parameter,
        on = [:row, :year]
    ) |>
    x -> @constraint(M,
        armington_supply[i=1:size(x,1)],
        max(0,lower_bound * x[i,:value]) <= x[i,:expr] <= abs(upper_bound * x[i,:value])
    )


    # Fix tax rates
    innerjoin(
        sectoral_output(X; column = :variable, output = :total_output) |> drop_parameter,
        output_tax(X, column = :variable, output = :ot) |> drop_parameter,
        output_tax_rate(X, column = :value, output = :otr) |> drop_parameter,
        on = [:col, :year]
    ) |>
    x -> @constraint(M, 
        Output_Tax_Rate[i=1:size(x,1)],
        x[i,:ot] == x[i,:total_output] * x[i,:otr]
    )


    innerjoin(
        absorption_tax(X, column = :variable, output = :at) |> drop_parameter,
        armington_supply(X, column = :variable, output = :as) |> drop_parameter,
        absorption_tax_rate(X, output = :atr) |> drop_parameter,
        on = [:row, :year]
    ) |>
    x -> @constraint(M,
        Absorption_Tax_Rate[i=1:size(x,1)],
        x[i,:at] == x[i,:as] * x[i,:atr]
    )
    


    innerjoin(
        table(X, :Import, :Duty) |> 
            x -> select(x, Not(:col, :value)) |> 
            x -> unstack(x, :parameter, :variable) |> 
            dropmissing,
        import_tariff_rate(X, output = :itr),
        on = [:row, :year]
    ) |>
    x -> @constraint(M,
        Import_Tariff_Rate[i=1:size(x,1)],
        x[i,:duty] == x[i,:import] * x[i,:itr]
    )
  
end