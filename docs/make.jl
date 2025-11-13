using Documenter, WiNDCNational, Literate

# Copy YAML Files to docs
cp(joinpath(@__DIR__, "..", "src", "united_states", "summary.yaml"), # Source
   joinpath(@__DIR__, "src", "data", "united_states", "summary.yaml"); # `Dest 
   force = true)

cp(joinpath(@__DIR__, "..", "src", "united_states", "detailed.yaml"), # Source
   joinpath(@__DIR__, "src", "data", "united_states", "detailed.yaml"); # `Dest 
   force = true)

const _PAGES = [
    "Introduction" => ["index.md"],
    "Data" => [
        "United States" => [
            "data/united_states/data_sources.md",
            "data/united_states/data_build.md",
            "data/united_states/sets.md",
            "data/united_states/build_local.md"
            ],
        "Australia" => [
            "data/australia/australia_data.md",
            "data/australia/load_data.md"
            ],
    ],
    "Calibration" => ["calibration.md"],
    "The National Model" => ["model/overview.md"],
    "API" => ["api.md"]
]


literate_files = Dict(
    "sets" => ( 
        input = "src/data/united_states/sets.jl",
        output = "src/data/united_states/"
    ),
)


for (name, paths) in literate_files
    EXAMPLE = joinpath(@__DIR__, paths.input)
    OUTPUT = joinpath(@__DIR__, paths.output)
    Literate.markdown(EXAMPLE, 
                      OUTPUT;
                      name = name)
end



makedocs(
    sitename="WiNDCNational.jl",
    authors="Mitch Phillipson",
    format = Documenter.HTML(),
    modules = [WiNDCNational],
    pages = _PAGES,
    assets = ["assets/custom.css"]
)



deploydocs(
    repo = "https://github.com/uw-windc/WiNDCNational.jl",
    target = "build",
    branch = "gh-pages",
    versions = ["stable" => "v^", "v#.#", "dev" => "dev" ],
    push_preview = true
)