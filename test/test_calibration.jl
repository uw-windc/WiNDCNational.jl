@testitem "Calibration - Ensure Balance" begin
    using JuMP

    summary = build_us_table()
    Y,M = calibrate(summary)

    @test is_solved_and_feasible(M)



    detailed = build_us_table(:detailed)
    Y,M = calibrate(detailed)

    @test is_solved_and_feasible(M)


end