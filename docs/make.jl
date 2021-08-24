
using Documenter
import FinancialDSL

makedocs(
    sitename = "FinancialDSL.jl",
    modules = [ FinancialDSL ],
    pages = [ "Home" => "index.md",
              "API Reference" => "api.md" ]
)

deploydocs(
    repo = "github.com/FinancialDSL/FinancialDSL.jl.git",
    target = "build",
)
