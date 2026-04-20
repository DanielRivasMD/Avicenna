####################################################################################################

# src/CLI.jl
module CLI

####################################################################################################

using ArgParse

####################################################################################################

export dispatcher

####################################################################################################
# Helper: extract the module name from a .jl file (first `module <name>` line)
####################################################################################################

function extract_module_name(filepath::String)::Union{String,Nothing}
  io = open(filepath, "r")
  try
    for line in eachline(io)
      m = match(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", line)
      if m !== nothing
        return String(m.captures[1])
      end
    end
  finally
    close(io)
  end
  return nothing
end

####################################################################################################

# Helper: derive root module name from CLI filename
# Example: "cli_deamination.jl" → "Deamination"
function root_module_from_cli_file(filename::String)::Union{String,Nothing}
  stem = splitext(filename)[1]          # e.g., "cli_deamination"
  if startswith(stem, "cli_")
    root_lower = stem[5:end]          # remove "cli_"
    # Capitalize first letter, keep rest as is
    root_cap = uppercasefirst(root_lower)
    return root_cap
  end
  return nothing  # doesn't match expected pattern
end

function find_available_commands()
  commands = Tuple{String,String,String}[]
  cli_dir = joinpath(pwd(), "src", "inter", "cli")
  isdir(cli_dir) || return commands

  for file in readdir(cli_dir)
    endswith(file, ".jl") || continue
    filepath = joinpath(cli_dir, file)

    # 1. Derive root module name from filename
    root_mod_name = root_module_from_cli_file(file)
    root_mod_name === nothing && continue

    # Subcommand = lowercased root module name
    subcmd = lowercase(root_mod_name)

    # 2. Read file to find CLI submodule and check run/export
    content = read(filepath, String)
    mod_match = match(r"module\s+(\w+)", content)
    mod_match === nothing && continue
    cli_mod_name = mod_match.captures[1]   # e.g., "DeaminationCLI"

    has_run_func = contains(content, r"function\s+run\b")
    has_export_run = contains(content, r"export\s+.*\brun\b")

    if has_run_func && has_export_run
      push!(commands, (subcmd, root_mod_name, cli_mod_name))
      # @info "Found: $subcmd -> root $root_mod_name, CLI $cli_mod_name"
    else
      @warn "Skipping $file: missing run or export run inside $cli_mod_name"
    end
  end
  return commands
end

####################################################################################################
# Generate Zsh completion script
####################################################################################################

function generate_zsh_completion()
  return """
  #compdef avicenna
  _avicenna() {
      local -a commands
      commands=(\${(f)\"\$(avicenna --list 2>/dev/null)\"})
      _describe 'command' commands
  }
  compdef _avicenna avicenna
  """
end

####################################################################################################
# Main dispatcher
####################################################################################################

function dispatcher(args::Vector{String})
  # Parse top-level options
  s = ArgParseSettings()
  @add_arg_table! s begin
    "--doc"
    action = :store_true
    help = "Show this help message"
    "--list"
    action = :store_true
    help = "List available commands"
    "--completion"
    help = "Generate shell completion script (zsh only)"
    arg_type = String
    default = ""
  end
  parsed = parse_args(args, s; as_symbols = true)

  if parsed[:doc]
    println("Avicenna – Unified CLI for analysis modules")
    println()
    println("Usage: avicenna [options] <command> [args...]")
    println()
    println("Options:")
    println("  --doc               Show this help")
    println("  --list              List available commands")
    println("  --completion SHELL  Generate completion script (zsh)")
    println()
    println("Commands (from modules in src/*.jl):")
    for (cmd, _, _) in find_available_commands()
      println("  $cmd")
    end
    return 0
  end

  if parsed[:list]
    for (cmd, _, _) in find_available_commands()
      println(cmd)
    end
    return 0
  end

  if parsed[:completion] != ""
    shell = parsed[:completion]
    if shell == "zsh"
      print(generate_zsh_completion())
    else
      @warn "Unsupported shell: $shell. Only 'zsh' is implemented."
      return 1
    end
    return 0
  end

  # No subcommand given
  if isempty(args)
    @info "no command given"
    dispatcher(["--doc"])
    return 0
  end

  subcommand = args[1]
  cmd_args = args[2:end]

  commands = find_available_commands()
  cmd_map =
    Dict(cmd => (mod_name, cli_mod_name) for (cmd, mod_name, cli_mod_name) in commands)

  if haskey(cmd_map, subcommand)
    root_mod_name, cli_mod_name = cmd_map[subcommand]
    # root module is assumed to be already loaded in Main
    root_mod = getproperty(Main, Symbol(root_mod_name))
    cli_mod = getproperty(root_mod, Symbol(cli_mod_name))
    result = cli_mod.run(cmd_args)
    return result isa Integer ? result : 0
  else
    println("Unknown command: $subcommand")
    println("Available commands: ", join(keys(cmd_map), ", "))
    return 1
  end
end

####################################################################################################

end

####################################################################################################
