function load_table()

    base_dir = @__DIR__
    data_dir = joinpath(base_dir, "data")

    DATA = CSV.read(joinpath(data_dir, "data.csv"), DataFrame, stringtype=String) |>
        x -> transform(x,
            [:row, :col, :parameter] .=> ByRow(Symbol) .=> [:row, :col, :parameter]
        )
    SETS = CSV.read(joinpath(data_dir, "sets.csv"), DataFrame, stringtype=String) |>
            x -> transform(x,
            [:name, :domain] .=> ByRow(Symbol) .=> [:name, :domain]
        )

    ELEMENTS = CSV.read(
            joinpath(data_dir, "elements.csv"), 
            DataFrame, 
            types = Dict(
                :name => Symbol,
                :description => String,
                :set => Symbol
            )
        ) |>
        x -> transform(x,
            [:name, :set] => ByRow((n,s) -> s==:year ? parse(Int, String(n)) : n) => :name
        )


    X = National(DATA, SETS, ELEMENTS; regularity_check = true)

   return X
end