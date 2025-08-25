# Introduction

The WiNDC National Module contains methods for analyzing national level input/output tables, with a focus on the United States Supply/Use framework tables.

!!! note
    All input values are negative and outputs are positive. We take this convention to reduce the complexity of computations. To normalize the data use the syntax `table(X; normalize = :Use)`, this will reverse the flow of all `Use` parameters.

## Basic Usage

The summary-level data can be downloaded and calibrated using two functions:

```julia
using WiNDCNational
using DataFrames
import MPSGE

summary = build_national_table(:summary) # replace :summary with :detailed for the detailed tables

zero_profit(summary) # Checking zero profit, not all values are zero
market_clearance(summary)
margin_balance(summary) 

Y,_ = calibrate(summary) # Calibrate returns both a new table and the JuMP model, which we discard.

zero_profit(Y) # The zero profit condition is now satisfied. 
market_clearance(Y)
margin_balance(Y)

M = mpsge_national(Y)
MPSGE.solve!(M; cumulative_iteration_limit=0) # Solve at benchmark

MPSGE.set_value!.(M[:Absorption_Tax], 0) # Set some taxes to 0
MPSGE.solve!(M)

```

## Installation

WiNDCNational is installed using the built-in Julia package manager. Launch Julia, enter the package manager by pressing `]`, at the `pkg>` prompt enter:

```julia
pkg> add WiNDCNational
```

It is highly recommended to create a Julia environment for each project you use,
check the [Pkg manage documentation](https://julialang.github.io/Pkg.jl/v1/environments/) for more information. 

## How this documentation is organized

- **Data** contains a full list of data sources, information on how the data is built, and lists the sets/parameters available.
- **Model** contains a full description of the MPSGE model.
- **API Reference** contains the API documentation for the WiNDCNational module, including all functions and types.