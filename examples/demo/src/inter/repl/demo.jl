####################################################################################################

# examples/demo/src/inter/repl/demo.jl
module DemoREPL

####################################################################################################

using Avicenna.Flow
using ..DemoFlow: demo
using ..DemoCore

####################################################################################################

function get_cache(no_cache::Bool = false)
  return Workflow.Cache("cache/demo", !no_cache)
end

function run_demo(id::String, scale::Float64 = 1.0; no_cache::Bool = false)
  config = Dict("id" => id, "data" => [1.0, 2.0, 3.0, 4.0, 5.0], "scale" => scale)
  Flow.run(demo, config, cache = get_cache(no_cache))
end

function inspect_stage(result, stage::String)
  return result.stage_outputs[stage]
end

function clear_cache!()
  rm("cache/demo", recursive = true, force = true)
  mkpath("cache/demo")
  @info "Cache cleared"
end

####################################################################################################

end

####################################################################################################
