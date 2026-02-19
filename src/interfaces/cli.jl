# src/interfaces/cli.jl
module CLI

using ..Workflow
using ..Processing
using ArgParse

function main(args = ARGS)
  s = ArgParseSettings()
  @add_arg_table! s begin
    "--id"
    required = true

    "--scale"
    arg_type = Float64
    default = 1.0

    "--no-cache"
    action = :store_true
  end

  parsed_args = parse_args(args, s)
  demo_data = [1.0, 2.0, 3.0, 4.0, 5.0]

  config =
    Dict("id" => parsed_args["id"], "data" => demo_data, "scale" => parsed_args["scale"])

  cache = Workflow.Cache("cache/demo", !parsed_args["no-cache"])
  result = Workflow.run(Workflow.demo_workflow, config, cache = cache)

  println("Analysis complete:")
  println("  Mean: ", result.stage_outputs["analyze"].summary["mean"])
  println("  Cache hits: ", join(result.cache_hits, ", "))

  return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end

end
