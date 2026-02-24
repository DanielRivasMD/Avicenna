####################################################################################################

# src/interfaces/document.jl
module Document

####################################################################################################

using ..Workflow
using Markdown

####################################################################################################

function generate_report(result)
  output = result.stage_outputs["analyze"]

  md = """
  # Analysis Report

  ## Summary
  - Mean: $(output.summary["mean"])
  - Data points: $(output.summary["length"])

  ## Origin
  - Workflow: $(result.origin["workflow"])
  - Version: $(result.origin["version"])
  - Time: $(result.origin["timestamp"])
  - Cache hits: $(join(result.origin["cache_hits"], ", "))

  ## Configuration
  ```
  $(result.origin["config"])
  ```
  """

  return Markdown.parse(md)
end

####################################################################################################

end

####################################################################################################
