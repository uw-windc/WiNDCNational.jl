"""
    gross_output(data::AbstractNationalTable; column::Symbol = :value, output::Symbol = :value)

Calculate the gross output of the sectors.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.

## Output

Returns a DataFrame with the columns `:sectors` and `:value`.

## Process

Note that the below is negative as we take outputs to be negative and we want gross
output to be positive.

```math
-\\sum_{s\\in\\text{Sectors}} \\text{Intermediate_Supply} + \\text{Household_Supply} - \\text{Margin_Supply}
```
"""
function gross_output(X::AbstractNationalTable; column = :value, output = :value)
    exclude_domain = domain(X, :sector)
    group_domain = [d for d in domain(X) if d != exclude_domain]

    return table(X, :IntermediateSupply, :HouseholdSupply, :MarginSupply) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (x -> -sum(x; init=0)) => output)
end



"""
    armington_supply(data::AbstractNationalTable; column::Symbol = :value, output::Symbol = :value)

Calculate the armington supply of the sectors.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.

## Output

Returns a DataFrame with the columns `:sectors` and `:value`.

## Process

```math
\\sum_{s\\in\\text{Sectors}} \\text{Intermediate_Demand} + \\text{Exogenous_Final_Demand} + \\text{Personal_Consumption}
```
"""
function armington_supply(data::AbstractNationalTable; column = :value, output = :value)
    exclude_domain = domain(data, :sector)
    group_domain = [d for d in domain(data) if d != exclude_domain]
    return table(data, :IntermediateDemand, :ExogenousFinalDemand, :PersonalConsumption) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> sum(y; init = 0)) => output)
    

end


function output_tax(data::AbstractNationalTable; column = :value, output = :value) 
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]
    return table(data, :OtherTax, :SectorSubsidy) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> sum(y;init=0)) => output)
end



function sectoral_output(data::AbstractNationalTable; column = :value, output = :value)
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]
    return table(data, :IntermediateDemand, :ValueAdded, :OtherTax) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => sum => output)

end

"""
    other_tax_rate(data::AbstractNationalTable; column = :value, output = :value)

Calculate the other tax rate of the sectors.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.

## Output

Returns a DataFrame with the columns `:sectors` and `:value`.
"""
function output_tax_rate(data::AbstractNationalTable; column = :value, output = :value) 
    exclude_domain = :row
    group_domain = [d for d in domain(data) if d != exclude_domain]

    outerjoin(
        sectoral_output(data; column = column, output = :total_output),
        output_tax(data, column = column, output = :tax),
        on = group_domain
    ) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x,
        [:total_output, :tax] => ByRow((o,t) -> o == 0 ? 0 : t/o) => output
    ) |>
    x -> select(x, Not(:total_output, :tax))

end



function absorption_tax(data::AbstractNationalTable; column = :value, output = :value) 
    exclude_domain = :col
    group_domain = [d for d in domain(data) if d != exclude_domain]
    return table(data, :tax, :subsidies) |>
        x -> groupby(x, group_domain) |>
        x -> combine(x, column => (y -> -sum(y; init = 0)) => output) 

end

"""
    absorption_tax_rate(data::AbstractNationalTable; column::Symbol = :value, output::Symbol = :value)

Calculate the absorption tax rate of the sectors.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.

## Output

Returns a DataFrame with the columns `:sectors` and `:value`.
"""
function absorption_tax_rate(data::AbstractNationalTable; column = :value, output = :value) 
    exclude_domain = :col
    group_domain = [d for d in domain(data) if d != exclude_domain]
    outerjoin(
        absorption_tax(data; column = column, output = :total_tax),
        armington_supply(data; column = column, output = :arm_sup),
        on = group_domain
    ) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x,
        [:arm_sup, :total_tax] => ByRow((v,t) -> v == 0 ? 0 : t/v) => output
    ) |>
    x -> select(x, Not(:total_tax, :arm_sup)) |>
    x -> subset(x, output => ByRow(!=(0)))

end


"""
    import_tariff_rate(data::AbstractNationalTable; column::Symbol = :value, output::Symbol = :value)

Calculate the import tariff rate of the sectors.

## Required Arguments

- `data::AbstractNationalTable`: The national data.

## Keyword Arguments

- `column::Symbol = :value`: The column to be used for the calculation.
- `output::Symbol = :value`: The name of the output column.

## Output

Returns a DataFrame with the columns `:sectors` and `:value`.
"""
function import_tariff_rate(X::AbstractNationalTable; column = :value, output = :value)
    return innerjoin(
        table(X, :imports, column = column, output = :imports) |> x-> select(x, Not(:parameter, :col)),
        table(X, :duty; column = column, output = :duty) |> x-> select(x, Not(:parameter, :col)),
        on = [:row, :year]
    )  |>
        x -> transform(x,
            [:duty, :imports] => ByRow((d,i) -> i==0 ? 0 : d/i) => output
        ) |>
        x -> select(x, Not(:duty, :imports)) 
end

function balance_of_payments(data::AbstractNationalTable; column = :value, output = :value)
    return table(X, :imports, :exports) |>
        x -> groupby(x, :year) |>
        x -> combine(x, :value => (y -> -sum(y; init = 0)) => :value) 
end