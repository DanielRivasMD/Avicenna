# avicenna,

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Overview

A Julia framework for building reproducible data analysis pipelines with
multiple interfaces.

Avicenna provides a clean separation between core logic, workflow orchestration
(with automatic caching), and user interaction (CLI, REPL, document generation).
Designed to be imported as a dependency in other repositories, Avicenna lets you
focus on your analysis while handling the repetitive scaffolding.

# Technical Architecture

Avicenna is organized into three distinct layers, each with a single
responsibility:

1. INTERFACE LAYER (REPL, CLI, Document)
   - Provides entry points for users.
   - Translates user input (commands, function calls) into configuration.
   - Invokes the workflow layer and presents results (printed summaries,
     HTML/PDF reports).

2. WORKFLOW LAYER (Workflow module)
   - Defines composable pipelines as sequences of stages.
   - Implements automatic caching: each stage’s output is stored keyed by
     configuration and input hash; subsequent runs reuse cached results.
   - Returns a structured result containing all stage outputs and metadata
     (origin, cache hits).

3. CORE LAYER (Process module)
   - Contains pure, side‑effect‑free functions that operate on data.
   - Defines canonical data types (Input, Intermediate, Output) that flow
     through the pipeline.
   - Can be extended with domain‑specific logic (e.g., trajectory analysis, DTW,
     statistics) without affecting the upper layers.

## Core Framework

The framework consists of four main modules, all exported by the top‑level
module `Avicenna`:

- `Process` : Fundamental data types and transformation functions. (load_raw,
  transform, analyze)
- `Workflow` : Orchestration with caching. Defines Stage, WorkflowConfig, Cache,
  and the run() function.
- `REPL` : Interactive functions for quick experimentation. (run_demo,
  inspect_stage, clear_cache!)
- `CLI` : Command‑line interface built on ArgParse. (main() – called by
  bin/run.jl)
- `Document` : Report generation from workflow results (Markdown, HTML, and
  easily extensible to PDF).

```
┌─────────────────┐
│   INTERFACE     │  ← How users interact
│  (CLI/REPL/Doc) │    (CLI, REPL, Notebooks)
└────────┬────────┘
         │
┌────────▼────────┐
│    WORKFLOW     │  ← How work gets done
│ (Orchestration) │    (Caching, Pipeline)
└────────┬────────┘
         │
┌────────▼────────┐
│      CORE       │  ← What actually happens
│  (Pure Logic)   │    (Math, Transformations)
└─────────────────┘
```

1. USER INPUT ↓
2. BIN/run.jl (entry point) • Activates environment • Loads Avicenna module •
   Calls Avicenna.CLI.main(ARGS) ↓
3. CLI MODULE (interface layer) • Parses --id and --scale • Creates config Dict
   • Creates cache object • Calls Workflow.run() with config ↓
4. WORKFLOW MODULE (orchestration layer) • Checks cache for each stage • If
   cache miss: calls Processing functions • If cache hit: returns cached result
   • Returns WorkflowResult ↓
5. CORE MODULE (pure logic) • Processing.load_raw() called •
   Processing.transform() called  
   • Processing.analyze() called • Returns pure data structures ↓
6. BACK UP THE LAYERS • Core → Workflow (result packaged with origin) • Workflow
   → CLI (result with cache metadata) • CLI → User (printed summary)

# Usage

Below are examples showing how to integrate Avicenna into your own projects. All
examples assume you have added Avicenna as a dependency (`] add Avicenna`).

---

1. Defining a custom workflow

---

```julia
using Avicenna

# 1. Define your core processing functions (they can be placed in a separate module)
function my_load(config)
    # e.g., read a file, query a database
    return Process.Input(config["id"], config["values"])
end

function my_analyze(input::Process.Input)
    # Your custom analysis
    mean_val = mean(input.values)
    return Process.Output(Dict("mean" => mean_val), input.values)
end

# 2. Create stages
stage_load = Workflow.Stage("load", (cfg, _) -> my_load(cfg), "1.0")
stage_analyze = Workflow.Stage("analyze", (_, prev) -> my_analyze(prev["load"]), "1.0")

# 3. Assemble the workflow
my_workflow = Workflow.WorkflowConfig(
    "my_analysis",
    [stage_load, stage_analyze],
    "1.0"
)

# 4. Run it
config = Dict("id" => "experiment_1", "values" => rand(100))
cache = Workflow.Cache("my_cache", true)   # enable caching
result = Workflow.run(my_workflow, config, cache=cache)

# 5. Inspect results
println(result.stage_outputs["analyze"].summary["mean"])
```

---

2. Using the REPL interface for interactive exploration

---

```julia
using Avicenna

# Run the built‑in demo workflow
res = REPL.run_demo("test", 2.0, no_cache=false)

# Inspect a specific stage
output = REPL.inspect_stage(res, "transform")
println(output.transformed)

# Clear the cache if needed
REPL.clear_cache!()
```

---

3. Generating reports from workflow results

---

```julia
using Avicenna

# Assume `result` is a WorkflowResult from a previous run
md_report = Document.report_markdown(result)   # returns a Markdown.MD object
html_file = Document.report_html(result, outpath="my_report.html")

# For PDF (requires pandoc/LaTeX), you can easily extend:
function report_pdf(result; outpath=nothing)
    # similar to report_html, but with doctype="md2pdf"
    # ...
end
```

---

4. Command‑line interface (for automation)

---

After setting up your package with a bin/run.jl script (like the one in
Avicenna), you can invoke it from the shell:

```julia
$ julia bin/run.jl --id mydata --scale 1.5 --no-cache
```

Or call the CLI programmatically:

```julia
Avicenna.CLI.main([" --id", "abc", "--scale", "2.0"])
```

---

5. Integrating with other methodologies

---

ecause the core logic is separated from orchestration, you can easily wrap your
existing analysis code into stages. For example, if you have a function that
fits a model and returns a DataFrame, just create a stage that calls it. The
caching will automatically skip recomputation when inputs haven’t changed.

For batch processing multiple configurations, write a loop that calls
Workflow.run with different config dicts – the cache will accelerate repeated
runs automatically.

The framework is also compatible with parallel execution: you could use
Distributed or Threads to run multiple workflows concurrently, each with its own
cache instance.
