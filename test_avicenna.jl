# test_avicenna.jl
println("="^50)
println("TESTING AVICENNA MODULE HIERARCHY")
println("="^50)

# First, load just the core and workflow
include("src/core/processor.jl")
include("src/workflows/main_workflow.jl")

println("\n Core and Workflow loaded")
println("   Core module: ", Processing)
println("   Workflow module: ", Workflow)
println("   Workflow.Cache exists: ", :Cache in names(Workflow))
println("   Workflow.demo_workflow exists: ", :demo_workflow in names(Workflow))

# Test creating a cache instance
cache = Workflow.Cache("test_cache", true)
println("\n Can create Cache: ", cache)

# Test running workflow with mock data
config = Dict("id" => "test", "data" => [1.0, 2.0, 3.0], "scale" => 2.0)
result = Workflow.run(Workflow.demo_workflow, config, cache = cache)
println("\n Can run workflow: ", result)
println("   Result type: ", typeof(result))
println("   Stage outputs: ", keys(result.stage_outputs))

println("\n"^2)
println(" Base modules work correctly!")
