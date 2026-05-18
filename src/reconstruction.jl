function quantity(S::MPSGE.Sector, C::MPSGE.Commodity; sign = -1)
    return sign * value(S)*value(C)*value(compensated_demand(S,C; depth=0))
end

function quantity(S::MPSGE.Sector, C::MPSGE.Commodity, nest::Symbol; sign = -1)
    try
        return sign * value(S)*value(C)*value(compensated_demand(S,C, nest; depth=0))
    catch e
        return 0
    end
end

function quantity(H::MPSGE.Consumer, C::MPSGE.Commodity, nest::Symbol; sign = 1)
    if nest == :demand
        return sign * value(MPSGE.demand(H,C))*value(C)
    else
        return sign * value(C*endowment(H,C))
    end
end




function reconstruct_table(summary::National, M::MPSGEModel; year = 2023)


    commodities = elements(summary, :commodity) |> x -> x[!,:name]
    sectors = elements(summary, :sector) |> x -> x[!,:name]
    value_added = elements(summary, :Value_Added; base=true) |> x -> x[!,:name]
    margins = elements(summary, :margin) |> x -> x[!,:name]

    intermediate_demand = [
        (row = c, col = s, year = year, parameter = :intermediate_demand, value = quantity(M[:Y][s], M[:PA][c], :s, sign = -1))
        for c in commodities, s in sectors
    ]  |> 
    vec  |>
    DataFrame

    intermediate_supply = [
        (row = c, col = s, year = year, parameter = :intermediate_supply, value = quantity(M[:Y][s], M[:PY][c], :t, sign = -1))
        for c in commodities, s in sectors
    ]  |> 
    vec  |>
    DataFrame


    va_map = elements(summary, :Value_Added; base=true) |>
        x -> Dict(x[!,:name] .=> x[!,:set])
    Value_Added = [
        (row = va, col = s, year = year, parameter = va_map[va], value = quantity(M[:Y][s], M[:PVA][va], sign = -1))
        for va in value_added, s in sectors
    ]  |>
    vec  |>
    DataFrame


    _exports = elements(summary, :Export; base=true) |> x -> x[!,:name]
    exports = [
        (row = c, col = e, year = year, parameter = :export, value = quantity(M[:A][c], M[:PFX], :t, sign = 1))
        for c in commodities, e in _exports
    ]  |>
    vec  |>
    DataFrame 

    government_final_demand = table(summary, :Government_Final_Demand) |>
        x -> subset(x, :year => ByRow(==(year))) |>
        x -> groupby(x, [:row, :year, :parameter]) |>
        x -> combine(x, :value => sum => :value) |>
        x -> transform(x, :row => ByRow(c -> :government) => :col) 

    investment_final_demand = [
        (row = c, col = :investment, year = year, parameter = :investment_final_demand, value = quantity(M[:RA], M[:PA][c], :endow, sign = 1))
        for c in commodities
    ]  |>
    vec  |>
    DataFrame |>
    x -> outerjoin(
        x, 
        government_final_demand |> x -> select(x, :row, :value => :value_gov),
        on = :row,
    ) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x, 
        [:value, :value_gov] => ByRow(-) => :value
    ) |>
    x -> select(x, Not(:value_gov))


    _imports = elements(summary, :Import; base=true) |> x -> x[!,:name]
    imports = [
        (row = c, col = e, year = year, parameter = :import, value = quantity(M[:A][c], M[:PFX], :s, sign = 1))
        for c in commodities, e in _imports
    ]  |>
    vec  |>
    DataFrame


    _personal_consumption = elements(summary, :personal_consumption) |> x -> x[!,:name]
    personal_consumption = [
        (row = c, col = pc, year = year, parameter = :personal_consumption, value = quantity(M[:RA], M[:PA][c], :demand, sign = -1))
        for c in commodities, pc in _personal_consumption
    ] |>
    vec  |>
    DataFrame


    _household_supply = elements(summary, :personal_consumption) |> x -> x[!,:name]
    household_supply = [
        (row = c, col = pc, year = year, parameter = :household_supply, value = quantity(M[:RA], M[:PY][c], :endow, sign = 1))
        for c in commodities, pc in _household_supply
    ] |>
    vec  |>
    DataFrame

    margin_demand = [
        (row = c, col = m, year = year, parameter = :margin_demand, value = quantity(M[:A][c], M[:PM][m], sign = 1))
        for m in margins, c in commodities
    ]  |>
    vec  |>
    DataFrame 

    margin_supply = [
        (row = c, col = m, year = year, parameter = :margin_supply, value = quantity(M[:MS][m], M[:PY][c], sign = -1))
        for m in margins, c in commodities
    ]  |>
    vec  |>
    DataFrame 


    df = vcat(
        intermediate_demand,
        intermediate_supply,
        Value_Added,
        exports,
        imports,
        personal_consumption,
        household_supply,
        investment_final_demand,
        government_final_demand,
        margin_demand,
        margin_supply,
    ) |>
    x -> subset(x, :value => ByRow(!=(0)))

    new_sets = sets(summary) 


    new_elements = elements(summary) |>
        x -> subset(x, 
            :set => ByRow(∉([:government_final_demand, :investment_final_demand]))
        ) |>
        x -> vcat(
            x,
            DataFrame([
                (name = :invest, description = "Investment", set = :investment_final_demand),
                (name = :government, description = "Government", set = :government_final_demand),
            ])
        )

    N = National(
        df,
        new_sets,
        new_elements
    )


    Output_tax_rate = value.(M[:Output_Tax]) |> 
        x -> DataFrame([axes(x,1),x.data], [:col, :rate]) |>
        x -> transform(x,
            :col => ByRow(s -> year) => :year
        )
    _tax_code = elements(summary, :output_tax) |> x -> only(x[!, :name])
    Output_Tax = innerjoin(
        sectoral_output(N; output = :output) |> x -> select(x, Not(:parameter)),
        Output_tax_rate,
        on = [:col, :year]
    ) |>
    x -> transform(x,
        [:output, :rate] => ByRow((O,r) -> r/(1-r)*O) => :value,
        :col => ByRow(s -> :output_tax) => :parameter,
        :col => ByRow(s -> _tax_code) => :row
    )  |>
    x -> select(x, [:row, :col, :year, :parameter, :value]) 


    Import_tariff_rate = value.(M[:Import_Tariff]) |>
        x -> DataFrame([axes(x,1), x.data], [:row, :rate]) |>
        x -> transform(x,
            :row => ByRow(c -> year) => :year
        )
    _duty_code = elements(summary, :duty) |> x -> only(x[!, :name])
    Duty = innerjoin(
        table(N, :Import) |> x -> select(x, :row, :year, :value => :import),
        Import_tariff_rate,
        on = [:row, :year]
    ) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x,
        [:import, :rate] => ByRow((M,r) -> r*M) => :value,
        :row => ByRow(c -> :duty) => :parameter,
        :row => ByRow(c -> _duty_code) => :col
    ) |>
    x -> select(x, [:row, :col, :year, :parameter, :value]) 


    Absorption_tax_rate = value.(M[:Absorption_Tax]) |> 
        x -> DataFrame([axes(x,1), x.data], [:row, :rate]) |>
        x -> transform(x,
            :row => ByRow(c -> year) => :year
        )
    _tax_code = elements(summary, :tax) |> x -> only(x[!, :name])
    tax = innerjoin(
        armington_supply(N; output = :output),
        Absorption_tax_rate,
        on = [:row, :year]
    ) |>
    x -> coalesce.(x, 0) |>
    x -> transform(x,
        [:output, :rate] => ByRow((A,r) -> r*A) => :value,
        :row => ByRow(c -> :tax) => :parameter,
        :row => ByRow(c -> _tax_code) => :col
    ) |>
    x -> select(x, [:row, :col, :year, :parameter, :value])



    return National(
        vcat(
            df,
            Output_Tax,
            Duty,
            tax,
        ) |> x -> subset(x, :value => ByRow(!=(0))),
        new_sets,
        new_elements
    )

end