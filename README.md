# WiNDC National



[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://uw-windc.github.io/WiNDCNational.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://uw-windc.github.io/WiNDCNational.jl/dev/)

This package contains methods to build the WiNDC National data from the source BEA input/output tables. 

## Example Usage

```julia
using WiNDCNational
using DataFrames

X = build_national_table(:summary)

Y, M = calibrate(X) # Example calibration. Data should already be balanced.


# Compare pre-calibration and post-calibration data
# They're the same so nothing gets printed.
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
```

