module WiNDCNational

    using WiNDCContainer
    using DataFrames
    using CSV
    using JuMP

    import WiNDCContainer: WiNDCtable, table, sets, domain, elements
    import WiNDCContainer: calibrate, calibrate_fix_variables, calibrate_constraints


    include("structs.jl")

    export WiNDCtable, table, sets, domain, elements

    include("load.jl")

    export load_table

    include("aggregate_parameters.jl")

    export gross_output, armington_supply, output_tax, sectoral_output, output_tax_rate,
        absorption_tax, absorption_tax_rate, import_tariff_rate, balance_of_payments

    include("calibrate.jl")

    export calibrate

    include("model.jl")

    export national_mpsge

end # module WiNDCNational
