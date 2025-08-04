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

    include("calibrate.jl")

    export calibrate

end # module WiNDCNational
