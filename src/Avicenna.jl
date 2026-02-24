# src/Avicenna.jl
module Avicenna

include("core/processor.jl")
include("workflows/demo.jl")
include("interfaces/repl.jl")
include("interfaces/cli.jl")
include("interfaces/document.jl")

export Core, Workflow, REPL, CLI, Document

function quick(id::String, scale::Float64 = 1.0)
  return REPL.run_demo(id, scale)
end

end
