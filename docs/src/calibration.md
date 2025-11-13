# Overview

The calibration routine uses a standard least-squares approach to fit model parameters to observed data. The `calibrate` function is inherited from `WiNDCContainer`, but requires specification of exogenous (fixed) variables and constraints to guide the calibration process. Variables are fixed by [`calibrate_fix_variables`](@ref) and the constraints are defined using [`calibrate_constraints`](@ref). 

The `calibrate` function returns a pair `(table, JuMP.Model)` where `table` is a WiNDCTable type and the `JuMP.Model` is the JuMP model used in the calibration. The JuMP model can be used to determine if the model calibrates and debug the constraints if it does not.
