# WiNDC National



[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://uw-windc.github.io/WiNDCNational.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://uw-windc.github.io/WiNDCNational.jl/dev/)

This package contains methods to build the WiNDC National data from the source BEA input/output tables. 

## Example Usage

```julia
using WiNDCNational
using DataFrames
import MPSGE # import MPSGE to avoid name conflicts


X = build_us_table(:summary)

Y, M = calibrate(X) # Calibrate the model


# Compare pre-calibration and post-calibration data
leftjoin(
    table(X),
    table(Y),
    on = [:row, :col, :year, :parameter],
    renamecols = "_X" => "_Y"
) |>
x -> transform(x,
    [:value_X, :value_Y] => ByRow((x,y) -> abs(x - y)) => :diff
) |>
x -> subset(x, :diff => ByRow(>(1e-6))) |>
x -> sort(x, :diff)



M = national_mpsge(Y; year = 2023)
MPSGE.solve!(M; cumulative_iteration_limit=0) # Solve at benchmark

MPSGE.set_value!.(M[:Absorption_Tax], 0) # Set some taxes to 0
MPSGE.solve!(M)
```

