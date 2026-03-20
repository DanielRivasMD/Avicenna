####################################################################################################

# examples/demo/src/flow/demo.jl
module DemoFlow

####################################################################################################

using Avicenna.Flow
using ..DemoCore

####################################################################################################

const demo = Config(
  "demo_analysis",
  [
    Stage("load", (config, _) -> DemoCore.load_raw(config["id"], config["data"]), "1.0"),
    Stage(
      "transform",
      (config, prev) -> DemoCore.transform(prev["load"], Dict("scale" => config["scale"])),
      "1.0",
    ),
    Stage("analyze", (_, prev) -> DemoCore.analyze(prev["transform"]), "1.0"),
  ],
  "1.0",
)

export Cache, Stage, Config, Result, run, demo

####################################################################################################

end

####################################################################################################
