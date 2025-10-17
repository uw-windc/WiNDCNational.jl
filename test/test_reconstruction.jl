@testitem "Calibration - Ensure Balance" begin
    using MPSGE
    import PATHSolver
    PATHSolver.c_api_License_SetString("2830898829&Courtesy&&&USR&45321&5_1_2021&1000&PATH&GEN&31_12_2025&0_0_0&6000&0_0")

    summary = build_us_table()
    summary,_ = calibrate(summary)

    M = WiNDCNational.national_mpsge(summary, year=2017)

    solve!(M, cumulative_iteration_limit=0)

    new_summary = WiNDCNational.reconstruct_table(summary, M; year=2017)

    @test isapprox(0, WiNDCNational.zero_profit(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    @test isapprox(0, WiNDCNational.market_clearance(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    @test isapprox(0, WiNDCNational.margin_balance(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    
    set_value!(M[:Output_Tax], 0)
    set_value!(M[:Import_Tariff], .1)
    set_value!(M[:Absorption_Tax], .2)
    solve!(M)

    new_summary = WiNDCNational.reconstruct_table(summary, M; year=2017)

    @test isapprox(0, WiNDCNational.zero_profit(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    @test isapprox(0, WiNDCNational.market_clearance(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    @test isapprox(0, WiNDCNational.margin_balance(new_summary) |> x -> combine(x, :value => sum =>:value) |> x -> x[1,:value], atol = 1e-6)
    

end