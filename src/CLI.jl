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

function is_valid_cli_file(filepath::String)::Bool
  content = read(filepath, String)
  has_run = contains(content, r"function\s+run\b")
  has_export = contains(content, r"export\s+.*\brun\b")
  return has_run && has_export
end

function find_available_commands()
  if !isfile(joinpath(pwd(), "Project.toml"))
    @warn "No Project.toml found – not a Julia project? Skipping command discovery."
    return Tuple{String,String,String,String}[]
  end

  src_dir = joinpath(pwd(), "src")
  cli_dir = joinpath(src_dir, "inter", "cli")
  isdir(src_dir) || return Tuple{String,String,String,String}[]
  isdir(cli_dir) || return Tuple{String,String,String,String}[]

  # root modules
  root_map = Dict{String,Tuple{String,String}}()
  for file in readdir(src_dir)
    endswith(file, ".jl") || continue
    filepath = joinpath(src_dir, file)
    mod_name = extract_module_name(filepath)
    mod_name === nothing && continue
    command = lowercase(splitext(file)[1])
    if haskey(root_map, command)
      @warn "Duplicate command '$command' from $(root_map[command][2]) and $filepath"
    else
      root_map[mod_name] = (command, filepath)
    end
  end

  # cli modules
  commands = Tuple{String,String,String,String}[]
  for file in readdir(cli_dir)
    endswith(file, ".jl") || continue
    filepath = joinpath(cli_dir, file)
    is_valid_cli_file(filepath) || continue
    cli_mod_name = extract_module_name(filepath)
    cli_mod_name === nothing && continue

    root_mod_name = cli_mod_name[1:2]
    if haskey(root_map, root_mod_name)
      command, root_file = root_map[root_mod_name]
      push!(commands, (command, root_mod_name, cli_mod_name, root_file))
    else
      @warn "No root module found for submodule '$cli_mod_name' (from CLI file $file)"
    end
  end
  return commands
end

####################################################################################################

# TODO: add flags to documentation
# TODO: potentially generate flag completion for target modules instead of avicenna flgas
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

  # TODO: add author & version to help
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
  cmd_map = Dict(
    cmd => (root_mod_name, cli_mod_name, root_file) for
    (cmd, root_mod_name, cli_mod_name, root_file) in commands
  )

  if haskey(cmd_map, subcommand)
    root_mod_name, cli_mod_name, root_file = cmd_map[subcommand]

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
