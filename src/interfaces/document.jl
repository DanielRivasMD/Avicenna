# src/interfaces/document.jl
module Document

using ..Workflow
using Markdown

function generate_report(result)
  if !haskey(result, :stage_outputs) && !haskey(result, "stage_outputs")
    output = result.stage_outputs["analyze"]

    md = """
    # Analysis Report

    ## Summary
    - Mean: $(output.summary["mean"])
    - Data points: $(output.summary["length"])

    ## Provenance
    - Workflow: $(result.provenance["workflow"])
    - Version: $(result.provenance["version"])
    - Time: $(result.provenance["timestamp"])
    - Cache hits: $(join(result.provenance["cache_hits"], ", "))

    ## Configuration
    ```
    $(result.provenance["config"])
    ```
    """

    return Markdown.parse(md)
  else
    return Markdown.parse("# Error: Invalid result format")
  end
end

end
