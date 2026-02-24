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

1. USER INPUT
   ↓
2. BIN/run.jl (entry point)
   • Activates environment
   • Loads Avicenna module
   • Calls Avicenna.CLI.main(ARGS)
   ↓
3. CLI MODULE (interface layer)
   • Parses --id and --scale
   • Creates config Dict
   • Creates cache object
   • Calls Workflow.run() with config
   ↓
4. WORKFLOW MODULE (orchestration layer)
   • Checks cache for each stage
   • If cache miss: calls Processing functions
   • If cache hit: returns cached result
   • Returns WorkflowResult
   ↓
5. CORE MODULE (pure logic)
   • Processing.load_raw() called
   • Processing.transform() called  
   • Processing.analyze() called
   • Returns pure data structures
   ↓
6. BACK UP THE LAYERS
   • Core → Workflow (result packaged with origin)
   • Workflow → CLI (result with cache metadata)
   • CLI → User (printed summary)

Avicenna (top-level)
  ├── Processing (core)
  ├── Workflow (orchestration) → depends on Processing
  ├── REPL (interface) → depends on Workflow
  ├── CLI (interface) → depends on Workflow
  └── Document (interface) → depends on Workflow

src/core/
├── processor.jl       # existing basic operations
├── trajectory.jl      # New: trajectory analysis functions
├── dtw.jl            # New: Dynamic Time Warping calculations
├── statistics.jl     # New: statistical tests
└── visualization.jl  # New: data preparation for plots

src/workflows/
├── main_workflow.jl       # existing demo
├── trajectory_workflow.jl # New: analyze trajectories
├── dtw_workflow.jl        # New: pairwise comparisons
└── batch_workflow.jl      # New: process multiple experiments
