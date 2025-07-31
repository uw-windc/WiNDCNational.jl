# WiNDC National

If you clone this repository you may need to `add` the `WiNDCContainer` package to the package environment. 
```
pkg> add https://github.com/uw-windc/WiNDCContainer.jl
```
This is an unregistered package that this project depends on. When the package gets registered I'll remove this warning.

This package is a work in progress and you can expect changes to the API and functionality as we continue to develop it.

## Example Usage

```julia
using WiNDCNational
using DataFrames

X = load_table()

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

