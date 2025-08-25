
"""
    national_mpsge(data::National; year = 2023)

Create a MPSGE model from the given National object.

## Required Arguments

1. `data` - A National object.

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
```julia
table(X, 
    :Intermediate_Supply,
    :Intermediate_Demand,
    :Labor_Demand,
    :Capital_Demand;
    normalize = :Use
) |>
x -> DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(x))) |>
x -> 
@production(M, Y[s=sectors], [t=0,s=0, va => s=1], begin
    @output(PY[c=commodities], x[c, s, :intermediate_supply], t, taxes = [Tax(RA, Output_Tax[s])])
    @input(PA[c=commodities], x[c, s, :intermediate_demand], s) # Heads up, negative
    @input(PVA[va = value_added], x[va, s, :value_added], va)   # Heads up, negative
end)

table(X, :Margin_Supply; normalize=:Margin_Supply) |>
x -> DefaultDict(0, Dict((row[:row], row[:col]) => row[:value] for row in eachrow(x))) |>
x -> 
@production(M, MS[m=margins], [t=0, s=0], begin
    @output(PM[m], sum(x[c, m] for c in commodities if x[c, m] != 0), t) # Heads up, negative
    @input(PY[c=commodities], x[c,m], s)
end)


vcat(
    armington_supply(X, minimal=false),
    gross_output(X, minimal=false) |> x-> subset(x, :value => ByRow(>(1e-6))),
    absorption_tax_rate(X, minimal=false),
    import_tariff_rate(X, minimal=false),
    table(X, :Export, :Import, :Margin_Demand; normalize = :Use)
) |>
x -> DefaultDict(0, Dict((row[:row], row[:col], row[:parameter]) => row[:value] for row in eachrow(x))) |>
x -> 
@production(M, A[c=commodities], [t=2, s=0, dm=>s=2], begin
    @output(PA[c], x[c, :as, :armington_supply], t, taxes = [Tax(RA, Absorption_Tax[c])], reference_price = 1-x[c,:atr, :absorption_tax_rate]) 
    @output(PFX, sum(x[c, e, :export] for e in exports), t)
    @input(PM[m=margins], x[c, m, :margin_demand], s)
    @input(PFX, sum(x[c, i, :import] for i in imports), dm, taxes = [Tax(RA, Import_Tariff[c])], reference_price = 1+x[c, :itr, :import_tariff_rate])
    @input(PY[c], x[c, :go, :gross_output], dm) 
end)

### Demands

vcat(
    table(X, :Personal_Consumption, :Household_Supply, :Value_Added; normalize=:Use),
    balance_of_payments(X, minimal=false),
    table(X, :Investment_Final_Demand, :Government_Final_Demand; normalize=:Use) |>
        x-> groupby(x, [:row, :year]) |>
        x -> combine(x, 
            [:col, :parameter] .=> (y -> (:ofd)) .=> [:col, :parameter],
            :value => sum => :value)
) |> 
x -> DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(x))) |>
x -> @demand(M, RA, begin
    @final_demand(PA[c=commodities], sum(x[c, pce, :personal_consumption] for pce in PCE)) # Negative ##NAICS
    @endowment(PY[c=commodities], sum(x[c, hhs, :household_supply] for hhs in HHS)) ## NAICS
    @endowment(PFX, x[:bop, :bop, :balance_of_payments])
    @endowment(PA[c=commodities], -x[c, :ofd, :ofd]) # Double negative
    @endowment(PVA[va=value_added], sum(x[va, s, :value_added] for s∈sectors))
end)

```


"""
function national_mpsge(data::National; year = 2023)

    X = National(
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

    parameter_col(parameter) = parameter∈[:labor_demand, :capital_demand] ? :value_added : parameter

    table(X, 
        :Intermediate_Supply,
        :Intermediate_Demand,
        :Labor_Demand,
        :Capital_Demand;
        normalize = :Use
    ) |>
    x -> DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(x))) |>
    x -> 
    @production(M, Y[s=sectors], [t=0,s=0, va => s=1], begin
        @output(PY[c=commodities], x[c, s, :intermediate_supply], t, taxes = [Tax(RA, Output_Tax[s])])
        @input(PA[c=commodities], x[c, s, :intermediate_demand], s) # Heads up, negative
        @input(PVA[va = value_added], x[va, s, :value_added], va)   # Heads up, negative
    end)

    table(X, :Margin_Supply; normalize=:Margin_Supply) |>
    x -> DefaultDict(0, Dict((row[:row], row[:col]) => row[:value] for row in eachrow(x))) |>
    x -> 
    @production(M, MS[m=margins], [t=0, s=0], begin
        @output(PM[m], sum(x[c, m] for c in commodities if x[c, m] != 0), t) # Heads up, negative
        @input(PY[c=commodities], x[c,m], s)
    end)


    vcat(
        armington_supply(X, minimal=false),
        gross_output(X, minimal=false) |> x-> subset(x, :value => ByRow(>(1e-6))),
        absorption_tax_rate(X, minimal=false),
        import_tariff_rate(X, minimal=false),
        table(X, :Export, :Import, :Margin_Demand; normalize = :Use)
    ) |>
    x -> DefaultDict(0, Dict((row[:row], row[:col], row[:parameter]) => row[:value] for row in eachrow(x))) |>
    x -> 
    @production(M, A[c=commodities], [t=2, s=0, dm=>s=2], begin
        @output(PA[c], x[c, :as, :armington_supply], t, taxes = [Tax(RA, Absorption_Tax[c])], reference_price = 1-x[c,:atr, :absorption_tax_rate]) 
        @output(PFX, sum(x[c, e, :export] for e in exports), t)
        @input(PM[m=margins], x[c, m, :margin_demand], s)
        @input(PFX, sum(x[c, i, :import] for i in imports), dm, taxes = [Tax(RA, Import_Tariff[c])], reference_price = 1+x[c, :itr, :import_tariff_rate])
        @input(PY[c], x[c, :go, :gross_output], dm) 
    end)


    vcat(
        table(X, :Personal_Consumption, :Household_Supply, :Value_Added; normalize=:Use),
        balance_of_payments(X, minimal=false),
        table(X, :Investment_Final_Demand, :Government_Final_Demand; normalize=:Use) |>
            x-> groupby(x, [:row, :year]) |>
            x -> combine(x, 
                [:col, :parameter] .=> (y -> (:ofd)) .=> [:col, :parameter],
                :value => sum => :value)
    ) |> 
    x -> DefaultDict(0, Dict((row[:row], row[:col], parameter_col(row[:parameter])) => row[:value] for row in eachrow(x))) |>
    x -> @demand(M, RA, begin
        @final_demand(PA[c=commodities], sum(x[c, pce, :personal_consumption] for pce in PCE)) # Negative ##NAICS
        @endowment(PY[c=commodities], sum(x[c, hhs, :household_supply] for hhs in HHS)) ## NAICS
        @endowment(PFX, x[:bop, :bop, :balance_of_payments])
        @endowment(PA[c=commodities], -x[c, :ofd, :ofd]) # Double negative
        @endowment(PVA[va=value_added], sum(x[va, s, :value_added] for s∈sectors))
    end)


    return M
end