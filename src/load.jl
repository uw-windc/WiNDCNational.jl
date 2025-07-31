function load_table()

    base_dir = @__DIR__
    data_dir = joinpath(base_dir, "data")

    DATA = CSV.read(joinpath(data_dir, "data.csv"), DataFrame, stringtype=String) |>
        x -> transform(x,
            :parameter => ByRow(Symbol) => :parameter
        )
    SETS = CSV.read(joinpath(data_dir, "sets.csv"), DataFrame, stringtype=String) |>
            x -> transform(x,
            [:name, :domain] .=> ByRow(Symbol) .=> [:name, :domain]
        )

    ELEMENTS = CSV.read(joinpath(data_dir, "elements.csv"), DataFrame, stringtype=String) |>
        x -> transform(x,
            :set => ByRow(Symbol) => :set
        )

    PARAMETERS = CSV.read(joinpath(data_dir, "parameters.csv"), DataFrame) |>
        x -> transform(x,
            names(x) .=> ByRow(Symbol) .=> names(x)
        )

    X = National(DATA, SETS, ELEMENTS, PARAMETERS; regularity_check = true)

   return X
end