####################################################################################################

# src/util/process.jl
module Process

####################################################################################################

struct Input
  id::String
  values::Vector{Float64}
end

struct Intermediate
  source_id::String
  transformed::Vector{Float64}
  metadata::Dict
end

struct Output
  summary::Dict
  details::Vector
end

####################################################################################################

function load_raw(id::String, raw_data::Vector{Float64})::Input
  return Input(id, raw_data)
end

function transform(input::Input, params::Dict)::Intermediate
  scale = get(params, "scale", 1.0)
  transformed = [x * scale for x in input.values]
  return Intermediate(input.id, transformed, Dict("params" => params))
end

function analyze(intermediate::Intermediate)::Output
  summary = Dict(
    "mean" => sum(intermediate.transformed) / length(intermediate.transformed),
    "length" => length(intermediate.transformed),
  )
  return Output(summary, intermediate.transformed)
end

####################################################################################################

end

####################################################################################################
