####################################################################################################

module DemoREPL

####################################################################################################

using Avicenna.Flow: Cache, run
using ..DemoFlow: demo
using ..DemoCore

####################################################################################################

function get_cache(cache_on::Bool = false)
  return Flow.Cache("cache/demo", cache_on)
end

function run_demo(id::String, scale::Float64 = 1.0; cache_on::Bool = false)
  config = Dict("id" => id, "data" => [1.0, 2.0, 3.0, 4.0, 5.0], "scale" => scale)
  Flow.run(demo, config, cache = get_cache(cache_on))    # <-- pass flag
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
