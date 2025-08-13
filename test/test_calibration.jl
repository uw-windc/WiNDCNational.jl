@testitem "Calibration - Ensure Balance" begin
    using JuMP

    summary = build_national_table()
    Y,M = calibrate(summary)

    @test is_solved_and_feasible(M)

end