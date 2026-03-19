####################################################################################################

# examples/demo/src/wflow/demo.jl
module DemoWorkflow

####################################################################################################

using Avicenna.Workflow
using ..DemoLogic

####################################################################################################

const demo = WorkflowConfig(
  "demo_analysis",
  [
    Stage("load", (config, _) -> DemoLogic.load_raw(config["id"], config["data"]), "1.0"),
    Stage(
      "transform",
      (config, prev) -> DemoLogic.transform(prev["load"], Dict("scale" => config["scale"])),
      "1.0",
    ),
    Stage("analyze", (_, prev) -> DemoLogic.analyze(prev["transform"]), "1.0"),
  ],
  "1.0",
)

export Cache, Stage, WorkflowConfig, WorkflowResult, run, demo

####################################################################################################

end

####################################################################################################
