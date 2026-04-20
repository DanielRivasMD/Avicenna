####################################################################################################

# src/CLI.jl
module CLI

####################################################################################################

export dispatcher

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

function root_module_from_cli_file(filename::String)::Union{String,Nothing}
  stem = splitext(filename)[1]          # e.g., "cli_deamination"
  if startswith(stem, "cli_")
    root_lower = stem[5:end]          # remove "cli_"
    # Capitalize first letter, keep rest as is
    root_cap = uppercasefirst(root_lower)
    return root_cap
  end
  return nothing  # not match expected pattern
end

function find_available_commands()
  commands = Tuple{String,String,String}[]
  cli_dir = joinpath(pwd(), "src", "inter", "cli")
  isdir(cli_dir) || return commands

  for file in readdir(cli_dir)
    endswith(file, ".jl") || continue

    # Expected pattern: cli_<something>.jl
    if !startswith(file, "cli_")
      continue
    end

    # Derive the root file name (e.g., "cli_deamination.jl" → "Deamination.jl")
    stem = splitext(file)[1]          # "cli_deamination"
    root_stem = uppercasefirst(stem[5:end])   # "Deamination"
    root_file = joinpath(pwd(), "src", "$root_stem.jl")

    # Check if root file exists
    isfile(root_file) || continue

    # Extract actual module name from root file (e.g., "DA")
    root_mod_name = extract_module_name(root_file)
    root_mod_name === nothing && continue

    # Subcommand = lowercase root stem (e.g., "deamination")
    subcmd = lowercase(root_stem)

    # Check CLI file for its module and run/export
    cli_filepath = joinpath(cli_dir, file)
    content = read(cli_filepath, String)

    mod_match = match(r"module\s+(\w+)", content)
    mod_match === nothing && continue
    cli_mod_name = mod_match.captures[1]

    has_run_func = contains(content, r"function\s+run\b")
    has_export_run = contains(content, r"export\s+.*\brun\b")

    if has_run_func && has_export_run
      push!(commands, (subcmd, root_mod_name, cli_mod_name))
      # @info "Found: $subcmd -> root module $root_mod_name, CLI $cli_mod_name"
    else
      @warn "Skipping $file: missing run or export run inside $cli_mod_name"
    end
  end
  return commands
end

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

function dispatcher(args::Vector{String})
  doc = false
  list = false
  completion = ""
  remaining = String[]

  i = 1
  while i <= length(args)
    arg = args[i]
    if arg == "--doc"
      doc = true
      i += 1
    elseif arg == "--list"
      list = true
      i += 1
    elseif arg == "--completion"
      if i + 1 > length(args)
        error("--completion requires an argument (zsh)")
      end
      completion = args[i+1]
      i += 2
    else
      push!(remaining, arg)
      i += 1
    end
  end

  if doc
    println("Avicenna – Unified CLI for analysis modules")
    println()
    println("Usage: avicenna [options] <command> [args...]")
    println()
    println("Options:")
    println("  --doc               Show this help")
    println("  --list              List available commands")
    println("  --completion SHELL  Generate completion script (zsh)")
    println()
    println("Avaliable command modules")
    for (cmd, _, _) in find_available_commands()
      println("  $cmd")
    end
    return 0
  end

  if list
    for (cmd, _, _) in find_available_commands()
      println(cmd)
    end
    return 0
  end

  if completion != ""
    if completion == "zsh"
      print(generate_zsh_completion())
    else
      @warn "Unsupported shell: $completion"
      return 1
    end
    return 0
  end

  if isempty(remaining)
    dispatcher(["--doc"])
    return 0
  end

  subcommand = remaining[1]
  cmd_args = remaining[2:end]

  commands = find_available_commands()
  cmd_map =
    Dict(cmd => (mod_name, cli_mod_name) for (cmd, mod_name, cli_mod_name) in commands)

  if haskey(cmd_map, subcommand)
    root_mod_name, cli_mod_name = cmd_map[subcommand]
    root_file = joinpath(pwd(), "src", "$(uppercasefirst(subcommand)).jl")
    if !isfile(root_file)
      error("Root module file not found: $root_file")
    end

    if !isdefined(Main, Symbol(root_mod_name))
      Base.include(Main, root_file)
    end

    root_mod = Base.invokelatest(() -> getproperty(Main, Symbol(root_mod_name)))
    cli_mod = Base.invokelatest(() -> getproperty(root_mod, Symbol(cli_mod_name)))
    run_func = Base.invokelatest(() -> getproperty(cli_mod, :run))

    result = Base.invokelatest(run_func, cmd_args)
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
