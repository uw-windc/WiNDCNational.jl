"""
    zero_profit(X::AbstractNationalTable; column = :value, output = :value)

Calculate the zero profit condition. For each sector, the zero profit 
condition is defined as the sum of the following parameters:

- `Intermediate_Demand`
- `Intermediate_Supply`
- `Value_Added`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:zero_profit`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:zp` 
and `:parameter` is filled with `parameter`.
"""
function zero_profit(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :zero_profit,
        minimal::Bool = true
    )
    X = table(data, :sector) |>
        x -> groupby(x, [:col, :year]) |>
        x -> combine(x, column => sum => output) |>
        x -> transform(x,
            :col => ByRow(_ -> (:zp, parameter)) => [:row, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])
        
    if minimal
        X |>
            x -> select!(x, [:col, :year, :parameter, output])
    end

    return X
end

"""
    market_clearance(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :market_clearance,
        minimal::Bool = true
    )

Calculate the market clearance condition. For each commodity, the market 
clearance condition is defined as the sum of the following parameters:

- `Intermediate_Demand`
- `Final_Demand`
- `Intermediate_Supply`
- `Household_Supply`
- `Margin_Supply`
- `Margin_Demand`
- `Imports`
- `Tax`
- `Duty`
- `Subsidies`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:market_clearance`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:mc` 
and `:parameter` is filled with `parameter`.
"""
function market_clearance(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :market_clearance,
        minimal::Bool = true
    )
    X = table(data, :commodity) |>
        x -> groupby(x, [:row, :year]) |>
        x -> combine(x, column => sum => output) |>
        x -> transform!(x, 
            :row => ByRow(_ -> (:mc, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])
        
        
    if minimal
        X |>
            x -> select!(x, [:row, :year, :parameter, output])
    end
    return X
end

"""
    margin_balance(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :margin_balance,
        minimal::Bool = true
    )

Calculate the margin balance condition. For each margin, the margin 
balance condition is defined as the sum of the following parameters:

- `Margin_Supply`
- `Margin_Demand`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:margin_balance`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:col, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:mb` 
and `:parameter` is filled with `parameter`.
"""
function margin_balance(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :margin_balance,
        minimal::Bool = true
    )
    X = table(data, :margin) |>
        x -> groupby(x, [:col, :year]) |>
        x -> combine(x, column => sum => output) |>
        x -> transform(x, 
            :col => ByRow(_ -> (:mb, parameter)) => [:row, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])
        
    if minimal
        X |>
            x -> select!(x, [:col, :year, :parameter, output])
    end

    return X
end


"""
    gross_output(
        data::AbstractNationalTable; 
        column = :value, 
        output = :value,
        parameter::Symbol = :gross_output,
        minimal::Bool = true
    )

Calculate the gross output of the sectors. For each commodity, gross output is 
defined as the sum of the following parameters:

- `Intermediate_Supply`
- `Household_Supply`
- `Margin_Supply`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:gross_output`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:go` 
and `:parameter` is filled with `parameter`.
"""
function gross_output(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :gross_output,
        minimal::Bool = true
    )
    exclude_domain = domain(data, :sector)
    group_domain = [d for d in domain(data) if d != exclude_domain]

    X = table(data, :Intermediate_Supply, :Household_Supply, :Margin_Supply) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (x -> sum(x; init=0)) => output) |>
        x -> transform(x, 
            :row => ByRow(_ -> (:go, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])
        
    if minimal
        X |>
          x -> select!(x, [:row, :year, :parameter, output])
    end

    return X
end

"""
    armington_supply(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :armington_supply
        minimal::Bool = true
    )

Calculate the armington supply of the sectors.  For each commodity, armington supply is 
defined as the sum of the following parameters:

- `Intermediate_Demand`
- `Other_Final_Demand`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:armington_supply`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:as` 
and `:parameter` is filled with `parameter`.
```
"""
function armington_supply(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :armington_supply,
        minimal::Bool = true
        )
    exclude_domain = domain(data, :sector)
    group_domain = [d for d in domain(data) if d != exclude_domain]
    X = table(data, :Intermediate_Demand, :Other_Final_Demand) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> -sum(y; init = 0)) => output) |>
        x -> transform(x, 
            :row => ByRow(_ -> (:as, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])
        
    if minimal
        X |>
            x -> select!(x, [:row, :year, :parameter, output])
    end
    
    return X
end

"""
    output_tax(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :actual_output_tax,
        minimal::Bool = true
    ) 

Calculate the actual output tax for each sector. For each sector, the output tax is
the sum of the parameters:

- `Output_Tax`
- `Sector_Subsidy`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:actual_output_tax`: The name of the parameter column. This is to avoid potential conflicts with the `:output_tax` parameter.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the
    essential columns are returned: [:col, :year, :parameter, output].


## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where
`output` is the renamed `column` column. Note that `:col` is filled with `:ot`
and `:parameter` is filled with `parameter`.
"""
function output_tax(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value, 
        parameter::Symbol = :actual_output_tax, 
        minimal::Bool = true
    )
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]
    X = table(data, :Output_Tax, :Sector_Subsidy) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> sum(y;init=0)) => output) |>
        x -> transform(x,
            :col => ByRow(_ -> (:ot, parameter)) => [:row, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])

    if minimal
        X |>
            x -> select!(x, [:col, :year, :parameter, output])
    end
    

    return X
end


"""
    sectoral_output(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :sectoral_output,
        minimal::Bool = true
    ) 

Calculate the sectoral output tax for each sector. For each sector, the sectoral output is
the sum of the parameters:

- `Intermediate_Demand`
- `Value_Added`
- `Output_Tax`
- `Sector_Subsidy`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:sectoral_output`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the
    essential columns are returned: [:col, :year, :parameter, output].


## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where
`output` is the renamed `column` column. Note that `:col` is filled with `:so`
and `:parameter` is filled with `parameter`.
"""
function sectoral_output(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :sectoral_output,
        minimal::Bool = true
    )
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]
    X = table(data, :Intermediate_Demand, :Value_Added, :Output_Tax, :Sector_Subsidy) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => sum => output) |>
        x -> transform!(x,
            :col => ByRow(_ -> (:so, parameter)) => [:row, :parameter]
        ) |>
        x -> select!(x, [:row, :col, :year, :parameter, output])

    if minimal
        X |>
            x -> select!(x, [:col, :year, :parameter, output])
    end

    return X
end

"""
    output_tax_rate(
        data::AbstractNationalTable; 
        column = :value, 
        output = :value,
        parameter = :output_tax_rate,
        minimal::Bool = true
    )

Calculate the output tax rate of the sectors. This is the ratio of the [`output_tax`](@ref)
to the [`sectoral_output`](@ref).

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:output_tax_rate`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:col, :year, :parameter, output].

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:otr` 
and `:parameter` is filled with `parameter`.
"""
function output_tax_rate(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :output_tax_rate,
        minimal::Bool = true
    ) 
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]

    X = vcat(
        sectoral_output(data; parameter = :total_output, column = column),
        output_tax(data; parameter = :tax, column = column)
    ) |>
    x -> unstack(x, :parameter, column) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x,
        [:total_output, :tax] => ByRow((o,t) -> o == 0 ? 0 : t/o) => output,
        :col => ByRow(_ -> (:otr, parameter)) => [:row, :parameter]
    ) |>
    x -> select(x, [:row, :col, :year, :parameter, output]) 

    if minimal
        X |>
        x -> select!(x, [:col, :year, :parameter, output])
    end

    return X
end


"""
    absorption_tax(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :absorption_tax,
        minimal::Bool = true
    )

Calculate the absorption tax of the sectors.  For each commodity, absorption tax is 
defined as the sum of the following parameters:

- `Tax`
- `Subsidy`

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:absorption_tax`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:at` 
and `:parameter` is filled with `parameter`.
```
"""
function absorption_tax(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :absorption_tax,
        minimal::Bool = true
    ) 
    exclude_domain = :col
    group_domain = [d for d in domain(data) if d != exclude_domain]
    X = table(data, :Tax, :Subsidy) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> sum(y; init = 0)) => output) |>
        x -> transform(x, 
            :row => ByRow(_ -> (:at, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])

    if minimal
        X |>
            x -> select!(x, [:row, :year, :parameter, output])
    end

    return X

end

"""
    absorption_tax_rate(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :absorption_tax_rate,
        minimal::Bool = true
    )

Calculate the absorption tax rate of the sectors.  For each commodity, absorption 
tax rate is defined as the ratio of [`absorption_tax`](@ref) and [`armington_supply`](@ref).

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:absorption_tax_rate`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:atr` 
and `:parameter` is filled with `parameter`.
```
"""
function absorption_tax_rate(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :absorption_tax_rate,
        minimal::Bool = true
    ) 
    exclude_domain = :col
    group_domain = [d for d in domain(data) if d != exclude_domain]
    
    X = vcat(
            absorption_tax(data; column = column, parameter = :total_tax),
            armington_supply(data; column = column, parameter = :arm_sup)
        ) |>
        x -> unstack(x, :parameter, column) |>
        x -> coalesce.(x, 0) |>
        x -> transform(x,
            [:arm_sup, :total_tax] => ByRow((v,t) -> v == 0 ? 0 : t/v) => output,
            :row => ByRow(_ -> (:atr, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output]) 

    if minimal
        X |>
          x -> select!(x, [:row, :year, :parameter, output])
    end

    return X

end


"""
    import_tariff_rate(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :import_tariff_rate,
        minimal::Bool = true
    )

Calculate the import tariff rate of the sectors.  For each commodity, import tariff rate is 
defined as the ratio of the parameters `Duty` and `Import`.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:import_tariff_rate`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:row, :year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:col` is filled with `:itr` 
and `:parameter` is filled with `parameter`.
```
"""
function import_tariff_rate(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :import_tariff_rate,
        minimal::Bool = true
    )
    X = table(data, :Import, :Duty) |>
        x -> select(x, Not(:col)) |>
        x -> unstack(x, :parameter, column) |>
        dropmissing |>
        x -> transform(x,
            [:duty, :import] => ByRow((d,i) -> i==0 ? 0 : d/i) => output,
            :row => ByRow(_ -> (:itr, parameter)) => [:col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])

    if minimal
        X |>
          x -> select!(x, [:row, :year, :parameter, output])
    end

    return X

end

"""
    balance_of_payments(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :balance_of_payments,
        minimal::Bool = true
    )

Calculate the balance of payments of the sectors.  For each commodity, balance of payments is 
defined as the sum of the parameters `Exports` and `Imports`. This is a scalar for
each year.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.
- `parameter::Symbol = `:balance_of_payments`: The name of the parameter column.
- `minimal::Bool = true`: Whether to return a minimal output. If true, only the 
    essential columns are returned: [:year, :parameter, output]. 

## Output

Returns a DataFrame with columns [:row, :col, :year, :parameter, output], where 
`output` is the renamed `column` column. Note that `:row` and `:col` are filled with `:bop` 
and `:parameter` is filled with `parameter`.
```
"""
function balance_of_payments(
        data::AbstractNationalTable; 
        column::Symbol = :value, 
        output::Symbol = :value,
        parameter::Symbol = :balance_of_payments,
        minimal::Bool = true
    )
    X = table(data, :Import, :Export) |>
        x -> groupby(x, :year) |>
        x -> combine(x, column => (y -> sum(y; init = 0)) => output) |>
        x -> transform(x,
            :year => ByRow(_ -> (:bop, :bop, parameter)) => [:row, :col, :parameter]
        ) |>
        x -> select(x, [:row, :col, :year, :parameter, output])


    if minimal
        X |>
            x -> select!(x, [:year, :parameter, output])
    end

    return X
end