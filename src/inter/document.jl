####################################################################################################

# src/inter/document.jl
module Document

####################################################################################################

using ..Workflow
using Markdown
using Weave
using UUIDs
using Base.Filesystem: mktempdir

####################################################################################################

function report_markdown(result)
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

function report_html(result; outpath = nothing)
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

  tmpdir = mktempdir()
  infile = joinpath(tmpdir, "report.jmd")
  open(infile, "w") do io
    write(io, md)
  end

  outfile = isnothing(outpath) ? joinpath(tmpdir, "report.html") : outpath

  weave(infile; doctype = "md2html", out_path = outfile)

  return outfile
end

####################################################################################################

function report_pdf(result; outpath = nothing)
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

  tmpdir = mktempdir()
  infile = joinpath(tmpdir, "report.jmd")
  write(infile, md)

  outfile = isnothing(outpath) ? joinpath(tmpdir, "report.pdf") : outpath
  # Use Weave with PDF backend
  weave(infile; doctype = "md2pdf", out_path = outfile)

  return outfile
end

####################################################################################################

end

####################################################################################################
