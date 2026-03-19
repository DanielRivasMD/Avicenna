####################################################################################################

# src/Workflow.jl
module Workflow

####################################################################################################

using SHA
using Serialization
using Dates

####################################################################################################

export Stage, WorkflowConfig, WorkflowResult, Cache, run

####################################################################################################

struct Stage
  name::String
  process::Function
  version::String
end

struct WorkflowConfig
  name::String
  stages::Vector{Stage}
  version::String
end

struct WorkflowResult
  stage_outputs::Dict{String,Any}
  origin::Dict
  cache_hits::Vector{String}
end

struct Cache
  root_dir::String
  enabled::Bool
end

####################################################################################################

function cache_key(stage::Stage, config::Dict, input_hash::String)::String
  content = string(stage.name, stage.version, config, input_hash)
  return bytes2hex(sha256(content))
end

function get_cached(cache::Cache, stage::Stage, key::String)
  cache_file = joinpath(cache.root_dir, stage.name, "$key.jld2")
  return isfile(cache_file) ? Serialization.deserialize(cache_file) : nothing
end

function set_cached(cache::Cache, stage::Stage, key::String, value)
  stage_dir = joinpath(cache.root_dir, stage.name)
  mkpath(stage_dir)
  Serialization.serialize(joinpath(stage_dir, "$key.jld2"), value)
end

####################################################################################################

function run(workflow::WorkflowConfig, config::Dict; cache = Cache("cache", true))
  @info "Starting workflow: $(workflow.name)"

  outputs = Dict{String,Any}()
  cache_hits = String[]
  input_hash = string(hash(config))

  for stage in workflow.stages
    @info "  Stage: $(stage.name)"

    if cache.enabled
      key = cache_key(stage, config, input_hash)
      cached = get_cached(cache, stage, key)
      if !isnothing(cached)
        @info "    → Cache hit"
        outputs[stage.name] = cached
        push!(cache_hits, stage.name)
        continue
      end
    end

    @info "    → Computing fresh"
    result = stage.process(config, outputs)
    outputs[stage.name] = result

    if cache.enabled
      set_cached(cache, stage, key, result)
    end
  end

  origin = Dict(
    "workflow" => workflow.name,
    "version" => workflow.version,
    "config" => config,
    "timestamp" => now(),
    "cache_hits" => cache_hits,
  )

  return WorkflowResult(outputs, origin, cache_hits)
end

####################################################################################################

end

####################################################################################################
