####################################################################################################

module CLI

####################################################################################################

using TOML

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

####################################################################################################

function extract_module_docstring(filepath::String)::String
  content = read(filepath, String)
  m = match(r"\"\"\"\s*\n(.*?)\n\s*\"\"\"\s*\n\s*module\s"ms, content)
  if m !== nothing
    return strip(m.captures[1])
  end
  return ""
end

####################################################################################################

function is_valid_cli_file(filepath::String)::Bool
  content = read(filepath, String)
  has_run = contains(content, r"function\s+run\b")
  has_export = contains(content, r"export\s+.*\brun\b")
  return has_run && has_export
end

function extract_flags_from_cli_file(filepath::String)::Vector{String}
  content = read(filepath, String)
  flags_with_desc = String[]

  start_idx = findfirst(r"@add_arg_table!\s+\w+\s+begin", content)
  start_idx === nothing && return flags_with_desc

  in_block = false
  lines = split(content, '\n')
  i = 1
  while i <= length(lines)
    line = lines[i]
    if !in_block && occursin(r"@add_arg_table!\s+\w+\s+begin", line)
      in_block = true
      i += 1
      continue
    end
    if in_block
      if occursin(r"\bend\b", line)
        break
      end
      m = match(r"--([a-zA-Z][a-zA-Z0-9_-]*)", line)
      if m !== nothing
        flag = "--" * m.captures[1]
        help_text = ""
        default_val = ""

        function extract_value(text, key)
          patterns = [Regex("$key\\s*=\\s*\"([^\"]*)\""), Regex("$key\\s*=\\s*([^,\\n]*)")]
          for pat in patterns
            m_val = match(pat, text)
            if m_val !== nothing
              return strip(m_val.captures[1])
            end
          end
          return ""
        end

        if occursin(r"help\s*=", line) || occursin(r"default\s*=", line)
          help_text = extract_value(line, "help")
          default_val = extract_value(line, "default")
        else
          j = i + 1
          while j <= length(lines)
            next_line = lines[j]
            if occursin(r"^\s*--", next_line) || occursin(r"\bend\b", next_line)
              break
            end
            if occursin(r"help\s*=", next_line) && isempty(help_text)
              help_text = extract_value(next_line, "help")
            end
            if occursin(r"default\s*=", next_line) && isempty(default_val)
              default_val = extract_value(next_line, "default")
            end
            j += 1
          end
        end

        desc = help_text
        if !isempty(default_val)
          if !isempty(desc)
            desc *= " - default: $default_val"
          else
            desc = "default: $default_val"
          end
        end

        if !isempty(desc)
          push!(flags_with_desc, "$flag:$desc")
        else
          push!(flags_with_desc, flag)
        end
      end
    end
    i += 1
  end
  return flags_with_desc
end

####################################################################################################

function find_available_commands()
  if !isfile(joinpath(pwd(), "Project.toml"))
    @warn "\n\tProject.toml not found\n\tPotentially not Julia project\n\tSkipping command discovery"
    return Tuple{String,String,String,String,String}[]
  end

  src_dir = joinpath(pwd(), "src")
  cli_dir = joinpath(src_dir, "inter", "cli")
  isdir(src_dir) || return Tuple{String,String,String,String,String}[]
  isdir(cli_dir) || return Tuple{String,String,String,String,String}[]

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
  commands = Tuple{String,String,String,String,String}[]
  for file in readdir(cli_dir)
    endswith(file, ".jl") || continue
    filepath = joinpath(cli_dir, file)
    is_valid_cli_file(filepath) || continue
    cli_mod_name = extract_module_name(filepath)
    cli_mod_name === nothing && continue

    root_mod_name = cli_mod_name[1:2]
    if haskey(root_map, root_mod_name)
      command, root_file = root_map[root_mod_name]
      push!(commands, (command, root_mod_name, cli_mod_name, root_file, filepath))
    else
      @warn "No root module found for submodule '$cli_mod_name' (from CLI file $file)"
    end
  end
  return commands
end

####################################################################################################

function print_subcommand_help(command::String, root_file::String, flags::Vector{String})
  # ANSI escape codes
  bold = "\e[1m"
  italic = "\e[3m"
  dim = "\e[2m"
  green = "\e[32m"
  cyan = "\e[36m"
  reset = "\e[0m"

  project_file = joinpath(pwd(), "Project.toml")

  author_name = ""
  author_email = ""
  pkg_name = ""
  pkg_version = ""

  if isfile(project_file)
    try
      data = TOML.parsefile(project_file)
      pkg_version = get(data, "version", "")
      pkg_name = get(data, "name", "")
      authors = get(data, "authors", [])
      if !isempty(authors)
        full_author = authors[1]
        m = match(r"^(.*?)\s*<([^>]+)>", full_author)
        if m !== nothing
          author_name = strip(m.captures[1])
          author_email = m.captures[2]
        else
          author_name = full_author
        end
      end
    catch
    end
  end

  doc = extract_module_docstring(root_file)

  if author_name != ""
    println(
      bold * green * author_name * reset * " " * dim * italic * "<$author_email>" * reset,
    )

  end
  if pkg_version != ""
    println(lowercase(pkg_name) * " " * bold * "v" * pkg_version * reset)
  end
  println()

  if !isempty(doc)
    println(dim * cyan * doc * reset)
    println()
  end

  println("Usage: avicenna $command [options]")
  println()

  if !isempty(flags)
    println("Options:")
    for f in flags
      parts = split(f, ":", limit = 2)
      flag = parts[1]
      desc = length(parts) > 1 ? parts[2] : ""
      if !isempty(desc)
        println(rpad("  $flag", 19), "$desc")
      else
        println("  $flag")
      end
    end
    println(rpad("  --help", 19), "Show this help message and exit")
  else
    println("Options:")
    println(rpad("  --help", 19), "Show this help message and exit")
  end
end

####################################################################################################

function print_help()
  # ANSI escape codes
  bold = "\e[1m"
  italic = "\e[3m"
  dim = "\e[2m"
  green = "\e[32m"
  cyan = "\e[36m"
  reset = "\e[0m"

  avicenna_root = dirname(@__DIR__)
  project_file = joinpath(avicenna_root, "Project.toml")

  author_name = ""
  author_email = ""
  pkg_name = ""
  pkg_version = ""

  if isfile(project_file)
    try
      data = TOML.parsefile(project_file)
      pkg_version = get(data, "version", "")
      pkg_name = get(data, "name", "")
      authors = get(data, "authors", [])
      if !isempty(authors)
        full_author = authors[1]
        m = match(r"^(.*?)\s*<([^>]+)>", full_author)
        if m !== nothing
          author_name = strip(m.captures[1])
          author_email = m.captures[2]
        else
          author_name = full_author
        end
      end
    catch
    end
  end

  desc = "Orchestrate scalable scholar analysis"
  println(
    bold * green * author_name * reset * " " * dim * italic * "<$author_email>" * reset,
  )
  println(lowercase(pkg_name) * " " * bold * "v" * pkg_version * reset)
  println()
  println(dim * cyan * desc * reset)
  println()
  println("Usage: avicenna [options] <command> [args...]")
  println()
  println("Options:")
  println("  --list           List available commands")
  println("  --cache          Remove local cache")
  println("  --completion     Generate shell completion script")
  println()
  println(bold * "Available commands:" * reset)
  for (cmd, _, _, _, _) in find_available_commands()
    println("  ", cmd)
  end
end

####################################################################################################

function generate_zsh_completion()
  return """
  #compdef avicenna
  _avicenna() {
      local -a commands
      if (( CURRENT == 2 )); then
          commands=(\${(f)\"\$(avicenna --list 2>/dev/null)\"})
          _describe 'command' commands
      elif [[ "\$words[CURRENT]" == --* ]]; then
          local cmd=\$words[2]
          local -a flags
          flags=(\${(f)\"\$(avicenna --_completion_flags \$cmd 2>/dev/null)\"})
          _describe -t flags 'flag' flags
      else
          _default
      fi
  }
  compdef _avicenna avicenna
  """
end

####################################################################################################

function clean_cache()
  cache_dir = joinpath(pwd(), "cache")
  if !isdir(cache_dir)
    println("No cache directory found at $cache_dir")
    return 0
  end

  try
    rm(cache_dir; recursive = true, force = true)
    println("Cache cleared: $cache_dir")
    return 0
  catch e
    @error "Failed to clear cache" exception = e
    return 1
  end
end

####################################################################################################

function dispatcher(args::Vector{String})
  if length(args) >= 2 && args[1] == "--_completion_flags"
    subcommand = args[2]
    commands = find_available_commands()
    for (cmd, _, _, _, cli_file) in commands
      if cmd == subcommand
        flags = extract_flags_from_cli_file(cli_file)
        if !("--help" in flags)
          push!(flags, "--help:Show this help message and exit")
        end
        for f in flags
          println(f)
        end
        return 0
      end
    end
    return 1
  end

  list = false
  completion = ""
  cache = false
  remaining = String[]

  i = 1
  while i <= length(args)
    arg = args[i]
    if arg == "--list"
      list = true
      i += 1
    elseif arg == "--completion"
      if i + 1 > length(args)
        error("--completion requires an argument")
      end
      completion = args[i+1]
      i += 2
    elseif arg == "--cache"
      cache = true
      i += 1
    else
      push!(remaining, arg)
      i += 1
    end
  end

  if cache
    return clean_cache()
  end

  if list
    for (cmd, _, _, _, _) in find_available_commands()
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
    print_help()
    return 0
  end

  subcommand = remaining[1]
  cmd_args = remaining[2:end]

  if subcommand != "" && ("--help" in cmd_args || "-h" in cmd_args)
    commands = find_available_commands()
    cmd_map = Dict(
      cmd => (root_mod_name, cli_mod_name, root_file, cli_file) for
      (cmd, root_mod_name, cli_mod_name, root_file, cli_file) in commands
    )
    if haskey(cmd_map, subcommand)
      root_mod_name, cli_mod_name, root_file, cli_file = cmd_map[subcommand]
      flags = extract_flags_from_cli_file(cli_file)
      print_subcommand_help(subcommand, root_file, flags)
      return 0
    end
  end

  commands = find_available_commands()
  cmd_map = Dict(
    cmd => (root_mod_name, cli_mod_name, root_file) for
    (cmd, root_mod_name, cli_mod_name, root_file, _) in commands
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
    println("Available commands:\n  ", join(keys(cmd_map), "\n  "))
    return 1
  end
end

####################################################################################################

end

####################################################################################################
