module WiNDCNational

    using WiNDCContainer
    using DataFrames
    using CSV, Downloads, XLSX, ZipFile, YAML
    using JuMP
    using MPSGE

    import WiNDCContainer: WiNDCtable, table, sets, domain, elements, base_table
    import WiNDCContainer: calibrate, calibrate_fix_variables, calibrate_constraints
    import DataStructures: DefaultDict


    include("structs.jl")

    export National, AustraliaNational, WiNDCtable, table, sets, domain, elements, base_table

    include("aggregate_parameters.jl")

    export zero_profit, market_clearance, margin_balance, gross_output, armington_supply, output_tax, sectoral_output, output_tax_rate,
        absorption_tax, absorption_tax_rate, import_tariff_rate, balance_of_payments

    include("calibrate.jl")

    export calibrate

    include("model.jl")

    export national_mpsge

    include("api.jl")

    include("build.jl")

    #include("united_states/api.jl")

    #export download_supply_use

    include("united_states/build.jl")

    export build_us_table

    include("australia/build.jl")

    export build_australia_table


end # module WiNDCNational
