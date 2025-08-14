@testitem "Parameters - Test Correctness" begin

    using DataFrames

    function create_parameter(E, row, col, parameter, value)
        rows = subset(E, :set => ByRow(==(row))) |> x -> x[!, :name]
        cols = subset(E, :set => ByRow(==(col))) |> x -> x[!, :name]
        return vec([
            (row = r, col = c, year = 2023, parameter = parameter, value = value) for r∈rows,c∈cols
        ])
    end

    function create_test_data(NUM_COMMODITIES, NUM_SECTORS)

        SETS = DataFrame([
            (name = :year,                      description = "", domain = :year),

            (name = :commodity,                 description = "", domain = :row),
            (name = :output_tax,                description = "", domain = :row),
            (name = :labor_demand,              description = "", domain = :row),
            (name = :capital_demand,            description = "", domain = :row),
            (name = :sector_subsidy,            description = "", domain = :row),

            (name = :sector,                    description = "", domain = :col),
            (name = :trade,                     description = "", domain = :col),
            (name = :export,                    description = "", domain = :col),
            (name = :subsidy,                   description = "", domain = :col),
            (name = :transport,                 description = "", domain = :col),
            (name = :investment_final_demand,   description = "", domain = :col),
            (name = :import,                    description = "", domain = :col),
            (name = :government_final_demand,   description = "", domain = :col),
            (name = :duty,                      description = "", domain = :col),
            (name = :tax,                       description = "", domain = :col),
            (name = :personal_consumption,      description = "", domain = :col),
            (name = :margin,                    description = "", domain = :col),


            (name = :Intermediate_Demand,       description = "", domain = :parameter),
            (name = :Labor_Demand,              description = "", domain = :parameter),
            (name = :Capital_Demand,            description = "", domain = :parameter),
            (name = :Value_Added,               description = "", domain = :parameter),
            (name = :Output_Tax,                description = "", domain = :parameter),
            (name = :Sector_Subsidy,            description = "", domain = :parameter),
            (name = :Final_Demand,              description = "", domain = :parameter),
            (name = :Other_Final_Demand,        description = "", domain = :parameter),
            (name = :Personal_Consumption,      description = "", domain = :parameter),
            (name = :Investment_Final_Demand,   description = "", domain = :parameter),
            (name = :Export,                    description = "", domain = :parameter),
            (name = :Government_Final_Demand,   description = "", domain = :parameter),


            (name = :Intermediate_Supply,       description = "", domain = :parameter),
            (name = :Household_Supply,          description = "", domain = :parameter),
            (name = :Import,                    description = "", domain = :parameter),
            (name = :Margin_Demand,             description = "", domain = :parameter),
            (name = :Margin_Supply,             description = "", domain = :parameter),
            (name = :Duty,                      description = "", domain = :parameter),
            (name = :Tax,                       description = "", domain = :parameter),
            (name = :Subsidy,                   description = "", domain = :parameter),
        ])

        ELEMENTS = DataFrame([
            (name = 2023,                       description = "", set = :year),
            [(name = Symbol("c",i),             description = "", set = :commodity) for i in 1:NUM_COMMODITIES]...,
            (name = :output_tax,                description = "", set = :output_tax),
            (name = :labor_demand,              description = "", set = :labor_demand),
            (name = :capital_demand,            description = "", set = :capital_demand),
            (name = :sector_subsidy,            description = "", set = :sector_subsidy),
            (name = :investment_final_demand,   description = "", set = :investment_final_demand),
            (name = :personal_consumption,      description = "", set = :personal_consumption),
            (name = :government_final_demand,   description = "", set = :government_final_demand),
            
            [(name = Symbol("s",i),             description = "", set = :sector) for i in 1:NUM_SECTORS]...,
            (name = :trade,                     description = "", set = :trade),
            (name = :export,                    description = "", set = :export),
            (name = :subsidy,                   description = "", set = :subsidy),
            (name = :transport,                 description = "", set = :transport),
            (name = :import,                    description = "", set = :import),
            (name = :duty,                      description = "", set = :duty),
            (name = :tax,                       description = "", set = :tax),
            (name = :trade,                     description = "", set = :margin),
            (name = :transport,                 description = "", set = :margin),


            (name = :intermediate_demand,       description = "", set = :Intermediate_Demand),
            (name = :labor_demand,              description = "", set = :Labor_Demand),
            (name = :capital_demand,            description = "", set = :Capital_Demand),
            (name = :labor_demand,              description = "", set = :Value_Added),
            (name = :capital_demand,            description = "", set = :Value_Added),
            (name = :output_tax,                description = "", set = :Output_Tax),
            (name = :sector_subsidy,            description = "", set = :Sector_Subsidy),
            (name = :personal_consumption,      description = "", set = :Final_Demand),
            (name = :investment_final_demand,   description = "", set = :Final_Demand),
            (name = :government_final_demand,   description = "", set = :Final_Demand),
            (name = :export,                    description = "", set = :Final_Demand),
            (name = :personal_consumption,      description = "", set = :Other_Final_Demand),
            (name = :investment_final_demand,   description = "", set = :Other_Final_Demand),
            (name = :government_final_demand,   description = "", set = :Other_Final_Demand),
            (name = :personal_consumption,      description = "", set = :Personal_Consumption),
            (name = :investment_final_demand,   description = "", set = :Investment_Final_Demand),
            (name = :export,                    description = "", set = :Export),
            (name = :government_final_demand,   description = "", set = :Government_Final_Demand),

            (name = :intermediate_supply,       description = "", set = :Intermediate_Supply),
            (name = :household_supply,          description = "", set = :Household_Supply),
            (name = :import,                    description = "", set = :Import),
            (name = :duty,                      description = "", set = :Duty),
            (name = :tax,                       description = "", set = :Tax),
            (name = :margin_demand,             description = "", set = :Margin_Demand),
            (name = :margin_supply,             description = "", set = :Margin_Supply),
            (name = :subsidy,                   description = "", set = :Subsidy),
            
        ])




        DATA = DataFrame([
            create_parameter(ELEMENTS, :commodity, :sector, :intermediate_demand, 1)...,
            create_parameter(ELEMENTS, :labor_demand, :sector, :labor_demand, 1)...,
            create_parameter(ELEMENTS, :capital_demand, :sector, :capital_demand, 1)...,
            create_parameter(ELEMENTS, :output_tax, :sector, :output_tax, 1)...,
            create_parameter(ELEMENTS, :sector_subsidy, :sector, :sector_subsidy, 1)...,
            create_parameter(ELEMENTS, :commodity, :personal_consumption, :personal_consumption, 1)...,
            create_parameter(ELEMENTS, :commodity, :investment_final_demand, :investment_final_demand, 1)...,
            create_parameter(ELEMENTS, :commodity, :government_final_demand, :government_final_demand, 1)...,
            create_parameter(ELEMENTS, :commodity, :export, :export, 1)...,

            create_parameter(ELEMENTS, :commodity, :sector, :intermediate_supply, 1)...,
            create_parameter(ELEMENTS, :commodity, :margin, :margin_supply, 1)...,
            create_parameter(ELEMENTS, :household_supply, :sector, :household_supply, 1)...,
            create_parameter(ELEMENTS, :commodity, :import, :import, 1)...,
            create_parameter(ELEMENTS, :commodity, :duty, :duty, 1)...,
            create_parameter(ELEMENTS, :commodity, :tax, :tax, 1)...,
            create_parameter(ELEMENTS, :commodity, :subsidy, :subsidy, 1)...,
        ])

        X = National(
            DATA,
            SETS,
            ELEMENTS;
            regularity_check = true
        )

        return X
    end


    function test_function(func::Function, X, min_cols, parameter)
        Y = func(X)
        @test Symbol.(names(Y)) == min_cols
        @test Y[1,:parameter] == parameter

        Y = func(X, parameter = :test)
        @test Y[1,:parameter] == :test

        Y = func(X, output = :test)
        @test Symbol.(names(Y)) == [filter(x -> x!=:value, min_cols)..., :test]

        Y = func(X, minimal=false)
        @test Symbol.(names(Y)) == [:row, :col, :year, :parameter, :value]
    end


    X = create_test_data(2, 2)

    test_function(zero_profit,         X, [:col, :year,:parameter, :value],  :zero_profit)
    test_function(market_clearance,    X, [:row, :year,:parameter, :value],  :market_clearance)
    test_function(margin_balance,      X, [:col, :year,:parameter, :value],  :margin_balance)
    test_function(gross_output,        X, [:row, :year, :parameter, :value], :gross_output)
    test_function(armington_supply,    X, [:row, :year, :parameter, :value], :armington_supply)
    test_function(output_tax,          X, [:col, :year, :parameter, :value], :actual_output_tax)
    test_function(sectoral_output,     X, [:col, :year, :parameter, :value], :sectoral_output)
    test_function(output_tax_rate,     X, [:col, :year, :parameter, :value], :output_tax_rate)
    test_function(absorption_tax,      X, [:row, :year, :parameter, :value], :absorption_tax)
    test_function(absorption_tax_rate, X, [:row, :year, :parameter, :value], :absorption_tax_rate)
    test_function(import_tariff_rate,  X, [:row, :year, :parameter, :value], :import_tariff_rate)
    test_function(balance_of_payments, X, [:year, :parameter, :value],       :balance_of_payments)

end