####################################################################################################

# examples/demo/src/wflow/demo.jl
module DemoWorkflow

####################################################################################################

using Avicenna.Workflow
using ..DemoCore

####################################################################################################

const demo = WorkflowConfig(
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

export Cache, Stage, WorkflowConfig, WorkflowResult, run, demo

####################################################################################################

end

####################################################################################################
