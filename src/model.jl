
"""
    national_mpsge(data::T; year = elements(data, :year) |> x -> maximum(x[!, :name])) where T<:AbstractNationalTable

Create a MPSGE model from the given National object.

## Required Arguments

1. `data` - A National object.

## Keyword Arguments

- `year` - The year for which to build the model. Defaults to the maximum year in the data.

## Output

Returns a MPSGEModel object.

## Model Description

### Parameters
    - Absorption_Tax[c=commodities], absorption_tax_rate[c]
    - Import_Tariff[c=commodities], import_tariff_rate[c]
    - Output_Tax[s=sectors], output_tax_rate[s]

### Sectors
    - Y[s=sectors]  - "Sectoral Production"
    - A[c=commodities]  - "Armington Supply"
    - MS[m=margins]  - "Margin Supply"

### Commodities 
    - PA[c=commodities] - "Armington Price"
    - PY[c=commodities] - "Output Price"
    - PVA[va=value_added] - "Value Added Price"
    - PM[m=margins] - "Margin Price"
    - PFX - Foreign Exchange

### Consumers
    - RA - Representative Agent


### Productions

The data functions are:
- [`sectoral_production_data`](@ref)
- [`margin_supply_data`](@ref)
- [`armington_supply_data`](@ref)
- [`representative_agent_data`](@ref)


```julia
    sectoral_production_data(X; output=:Dict) |>  x -> 
    @production(M, Y[s=sectors], [t=0,s=0, va => s=1], begin
        @output(PY[c=commodities], x[c, s, :intermediate_supply], t, taxes = [Tax(RA, Output_Tax[s])])
        @input(PA[c=commodities], x[c, s, :intermediate_demand], s) 
        @input(PVA[va = value_added], x[va, s, :value_added], va)   
    end)

    margin_supply_data(X; output=:Dict) |>  x -> 
    @production(M, MS[m=margins], [t=0, s=0], begin
        @output(PM[m], sum(x[c, m] for c in commodities if x[c, m] != 0), t) 
        @input(PY[c=commodities], x[c,m], s)
    end)


    armington_supply_data(X; output=:Dict) |>  x -> 
    @production(M, A[c=commodities], [t=2, s=0, dm=>s=2], begin
        @output(PA[c], x[c, :as, :armington_supply], t, taxes = [Tax(RA, Absorption_Tax[c])], reference_price = 1-x[c,:atr, :absorption_tax_rate]) 
        @output(PFX, sum(x[c, e, :export] for e in exports), t)
        @input(PM[m=margins], x[c, m, :margin_demand], s)
        @input(PFX, sum(x[c, i, :import] for i in imports), dm, taxes = [Tax(RA, Import_Tariff[c])], reference_price = 1+x[c, :itr, :import_tariff_rate])
        @input(PY[c], x[c, :go, :gross_output], dm) 
    end)


    representative_agent_data(X; output=:Dict) |>  x -> 
    @demand(M, RA, begin
        @final_demand(PA[c=commodities], sum(x[c, pce, :personal_consumption] for pce in PCE)) 
        @endowment(PY[c=commodities], sum(x[c, hhs, :household_supply] for hhs in HHS)) 
        @endowment(PFX, x[:bop, :bop, :balance_of_payments])
        @endowment(PA[c=commodities], -x[c, :ofd, :ofd]) 
        @endowment(PVA[va=value_added], sum(x[va, s, :value_added] for s∈sectors))
    end)
```
"""
function national_mpsge(data::T; year = elements(data, :year) |> x -> maximum(x[!, :name])) where T<:AbstractNationalTable

    X = T(
        table(data, :year => year),
        sets(data),
        elements(data)
    )
    
    sectors = elements(X, :sector) |> x -> x[!,:name]
    commodities = elements(X, :commodity) |> x -> x[!,:name]
    margins = elements(X, :margin) |> x -> x[!,:name]
    value_added = elements(X, :Value_Added; base=true) |> x -> x[!,:name]
    final_demand = elements(X, :Final_Demand; base=true) |> x -> x[!,:name]

    exports = elements(X, :export) |> x -> x[!,:name]
    imports = elements(X, :import) |> x -> x[!,:name]
    PCE = elements(X, :personal_consumption) |> x -> x[!,:name]
    HHS = PCE

    
    M = MPSGEModel()

    params = vcat(
        absorption_tax_rate(X; minimal=false),
        import_tariff_rate(X; minimal=false),
        output_tax_rate(X; minimal=false)
    ) |>
    x -> DefaultDict(0, Dict((row[:row], row[:col]) => row[:value] for row in eachrow(x)))
    @parameters(M, begin
        Absorption_Tax[c=commodities], params[c, :atr]
        Import_Tariff[c=commodities], params[c, :itr]
        Output_Tax[s=sectors], params[:otr, s]
    end)

    @sectors(M, begin
        Y[s=sectors], (description = "Sectoral Production")
        A[c=commodities], (description = "Armington Supply")
        MS[m=margins], (description = "Margin Supply")
    end)


    @commodities(M, begin
        PA[c=commodities], (description = "Armington Price")
        PY[c=commodities], (description = "Output Price")
        PVA[va=value_added], (description = "Value Added Price")
        PM[m=margins], (description = "Margin Price")
        PFX, (description = "Foreign Exchange")
    end)


    @consumer(M, RA, description = "Representative Agent")



    sectoral_production_data(X; output=:Dict) |>  x -> 
    @production(M, Y[s=sectors], [t=0,s=0, va => s=1], begin
        @output(PY[c=commodities], x[c, s, :intermediate_supply], t, taxes = [Tax(RA, Output_Tax[s])])
        @input(PA[c=commodities], x[c, s, :intermediate_demand], s) 
        @input(PVA[va = value_added], x[va, s, :value_added], va)   
    end)

    margin_supply_data(X; output=:Dict) |>  x -> 
    @production(M, MS[m=margins], [t=0, s=0], begin
        @output(PM[m], sum(x[c, m] for c in commodities if x[c, m] != 0), t) 
        @input(PY[c=commodities], x[c,m], s)
    end)


    armington_supply_data(X; output=:Dict) |>  x -> 
    @production(M, A[c=commodities], [t=2, s=0, dm=>s=2], begin
        @output(PA[c], x[c, :as, :armington_supply], t, taxes = [Tax(RA, Absorption_Tax[c])], reference_price = 1-x[c,:atr, :absorption_tax_rate]) 
        @output(PFX, sum(x[c, e, :export] for e in exports), t)
        @input(PM[m=margins], x[c, m, :margin_demand], s)
        @input(PFX, sum(x[c, i, :import] for i in imports), dm, taxes = [Tax(RA, Import_Tariff[c])], reference_price = 1+x[c, :itr, :import_tariff_rate])
        @input(PY[c], x[c, :go, :gross_output], dm) 
    end)


    representative_agent_data(X; output=:Dict) |>  x -> 
    @demand(M, RA, begin
        @final_demand(PA[c=commodities], sum(x[c, pce, :personal_consumption] for pce in PCE)) 
        @endowment(PY[c=commodities], sum(x[c, hhs, :household_supply] for hhs in HHS)) 
        @endowment(PFX, x[:bop, :bop, :balance_of_payments])
        @endowment(PA[c=commodities], -x[c, :ofd, :ofd]) 
        @endowment(PVA[va=value_added], sum(x[va, s, :value_added] for s∈sectors))
    end)


    return M
end

"""
    sectoral_production_data(data::T; output = :DataFrame) where T<:AbstractNationalTable

Extract `Intermediate_Demand`, `Intermediate_Supply`, `Labor_Demand`, and `Capital_Demand` from a National object.
Also make `Labor_Demand` and `Capital_Demand` use `value_added` as the parameter column.

```julia
out = table(data, 
    :Intermediate_Demand,
    :Intermediate_Supply,
    :Labor_Demand,
    :Capital_Demand;
    normalize = :Use
)
```

"""
function sectoral_production_data(data::T; output = :DataFrame) where T<:AbstractNationalTable
    parameter_col(parameter) = parameter∈[:labor_demand, :capital_demand] ? :value_added : parameter

    out = table(data, 
        :Intermediate_Demand,
        :Intermediate_Supply,
        :Labor_Demand,
        :Capital_Demand;
        normalize = :Use
    )

    if output == :DataFrame
        return out
    elseif output == :Dict
        return DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(out)))
    else
        error("Unsupported output type: $output")
    end
end


"""
    margin_supply_data(data::T; output = :DataFrame) where T<:AbstractNationalTable

Extract `Margin_Supply` from a National object.

```julia
table(data, :Margin_Supply; normalize=:Margin_Supply)
```
"""
function margin_supply_data(data::T; output = :DataFrame) where T<:AbstractNationalTable
    out = table(data, :Margin_Supply; normalize=:Margin_Supply)

    if output == :DataFrame
        return out
    elseif output == :Dict
        return DefaultDict(0, Dict((row[:row], row[:col]) => row[:value] for row in eachrow(out)))
    else
        error("Unsupported output type: $output")
    end
end

"""
    armington_supply_data(X::T; output = :DataFrame) where T<:AbstractNationalTable

Extract Armington supply related data from a National object, including:
- [`armington_supply`](@ref)
- [`gross_output`](@ref)
- [`absorption_tax_rate`](@ref)
- [`import_tariff_rate`](@ref)
- `Export`, `Import`, and `Margin_Demand`

```julia
vcat(
    armington_supply(X, minimal=false),
    gross_output(X, minimal=false) |> x-> subset(x, :value => ByRow(>(1e-6))),
    absorption_tax_rate(X, minimal=false),
    import_tariff_rate(X, minimal=false),
    table(X, :Export, :Import, :Margin_Demand; normalize = :Use)
)
```
"""
function armington_supply_data(X::T; output = :DataFrame) where T<:AbstractNationalTable
    out = vcat(
        armington_supply(X, minimal=false),
        gross_output(X, minimal=false) |> x-> subset(x, :value => ByRow(>(1e-6))),
        absorption_tax_rate(X, minimal=false),
        import_tariff_rate(X, minimal=false),
        table(X, :Export, :Import, :Margin_Demand; normalize = :Use)
    ) 

    if output == :DataFrame
        return out
    elseif output == :Dict
        return DefaultDict(0, Dict((row[:row], row[:col], row[:parameter]) => row[:value] for row in eachrow(out)))
    else
        error("Unsupported output type: $output")
    end
end

"""
    representative_agent_data(X::T; output = :DataFrame) where T<:AbstractNationalTable

Extract representative agent related data from a National object, including:
- `Personal_Consumption`, `Household_Supply`, `Value_Added`
- [`balance_of_payments`](@ref)
- `Investment_Final_Demand`, `Government_Final_Demand` -> Sum values as a new parameter `ofd`.

```julia
vcat(
    table(X, :Personal_Consumption, :Household_Supply, :Value_Added; normalize=:Use),
    balance_of_payments(X, minimal=false),
    table(X, :Investment_Final_Demand, :Government_Final_Demand; normalize=:Use) |>
        x-> groupby(x, [:row, :year]) |>
        x -> combine(x, 
            [:col, :parameter] .=> (y -> (:ofd)) .=> [:col, :parameter],
            :value => sum => :value)
)
```
"""
function representative_agent_data(X::T; output = :DataFrame) where T<:AbstractNationalTable
    parameter_col(parameter) = parameter∈[:labor_demand, :capital_demand] ? :value_added : parameter

    out = vcat(
        table(X, :Personal_Consumption, :Household_Supply, :Value_Added; normalize=:Use),
        balance_of_payments(X, minimal=false),
        table(X, :Investment_Final_Demand, :Government_Final_Demand; normalize=:Use) |>
            x-> groupby(x, [:row, :year]) |>
            x -> combine(x, 
                [:col, :parameter] .=> (y -> (:ofd)) .=> [:col, :parameter],
                :value => sum => :value)
    )

    if output == :DataFrame
        return out
    elseif output == :Dict
        return DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(out)))
    else
        error("Unsupported output type: $output")
    end
end