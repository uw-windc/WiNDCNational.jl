module WiNDCNational

    using WiNDCContainer
    using DataFrames
    using CSV, Downloads, XLSX, ZipFile
    using JuMP
    using MPSGE

    import WiNDCContainer: WiNDCtable, table, sets, domain, elements
    import WiNDCContainer: calibrate, calibrate_fix_variables, calibrate_constraints


    include("structs.jl")

    export WiNDCtable, table, sets, domain, elements

    include("load.jl")

    export load_table_with_data

    include("aggregate_parameters.jl")

    export gross_output, armington_supply, output_tax, sectoral_output, output_tax_rate,
        absorption_tax, absorption_tax_rate, import_tariff_rate, balance_of_payments

    include("calibrate.jl")

    export calibrate

    include("data/api.jl")

    export fetch_supply_use



    #include("model.jl")

    #export national_mpsge


end # module WiNDCNational
