using Documenter, WiNDC, PATHSolver



const _PAGES = [
    "Introduction" => ["index.md"],
    "Data" => ["data_sources.md"],
    "National Module" => ["overview.md"],
    "API" => ["api.md"]
]


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