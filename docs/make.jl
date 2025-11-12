using Documenter, WiNDCNational, Literate



const _PAGES = [
    "Introduction" => ["index.md"],
    "Data" => [
        "United States" => [
            "data/united_states/data_sources.md",
            "data/united_states/data_build.md",
            "data/united_states/sets.md"
            ],
        "Australia" => [
            "data/australia/australia_data.md"
            ]
    ],
    "National Module" => ["overview.md"],
    "API" => ["api.md"]
]


literate_files = Dict(
    "sets" => ( 
        input = "src/sets.jl",
        output = "src/"
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
    pages = _PAGES
)



deploydocs(
    repo = "https://github.com/uw-windc/WiNDCNational.jl",
    target = "build",
    branch = "gh-pages",
    versions = ["stable" => "v^", "v#.#", "dev" => "dev" ],
    push_preview = true
)