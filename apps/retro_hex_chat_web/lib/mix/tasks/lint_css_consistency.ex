defmodule Mix.Tasks.Lint.CssConsistency do
  @shortdoc "Audit CSS class consistency (unused definitions + missing references)"
  @moduledoc """
  Scans CSS files for defined classes and templates/JS for referenced classes,
  then reports two kinds of violations:

  - **Unused** — classes defined in our CSS but never referenced anywhere
  - **Missing** — classes referenced in templates/JS but never defined in any CSS

  Vendor classes (retro design system) are parsed automatically and count as "known" definitions.
  Phoenix framework classes (phx-*) are hardcoded as known.

  An allowlist file at `scripts/css_consistency_allowlist.txt` supports three sections:
  `[unused]`, `[missing]`, and `[dynamic-prefixes]`. Entries ending with `*` are
  glob patterns. Dynamic prefixes suppress matches in both directions.

  ## Usage

      mix lint.css_consistency

  Exits non-zero when violations are found.
  """

  use Mix.Task

  @dialyzer [:no_return, :no_undefined_callbacks, :no_opaque]

  @web_app_dir "apps/retro_hex_chat_web"
  @domain_app_dir "apps/retro_hex_chat"

  defp css_dir, do: Path.join(web_app_root(), "assets/css")
  defp retro_css_dir, do: Path.join(web_app_root(), "assets/css/retro")
  defp web_lib, do: Path.join(web_app_root(), "lib")
  defp js_dir, do: Path.join(web_app_root(), "assets/js")
  defp domain_lib, do: Path.join(project_root(), "#{@domain_app_dir}/lib")
  defp allowlist_path, do: Path.join(project_root(), "scripts/css_consistency_allowlist.txt")

  defp project_root do
    if File.exists?(@web_app_dir) do
      # Running from umbrella root
      "."
    else
      # Running from web app dir
      "../.."
    end
  end

  defp web_app_root do
    if File.exists?(@web_app_dir) do
      @web_app_dir
    else
      "."
    end
  end

  @phoenix_classes MapSet.new([
                     "phx-click-loading",
                     "phx-change-loading",
                     "phx-submit-loading",
                     "phx-connected",
                     "phx-loading",
                     "phx-error",
                     "phx-no-feedback"
                   ])

  @impl Mix.Task
  @spec run(list()) :: :ok
  def run(_args) do
    {unused_allow, missing_allow, dynamic_prefixes} = load_allowlist()

    defined = extract_defined_classes()
    vendor = extract_vendor_classes()
    referenced = extract_all_references()
    auto_prefixes = extract_auto_prefixes()
    all_prefixes = Enum.uniq(dynamic_prefixes ++ auto_prefixes)

    all_known = MapSet.union(MapSet.union(defined, vendor), @phoenix_classes)

    raw_unused = MapSet.difference(defined, referenced)
    raw_missing = MapSet.difference(referenced, all_known)

    unused = filter_by_allowlist(raw_unused, unused_allow, all_prefixes)
    missing = filter_by_allowlist(raw_missing, missing_allow, all_prefixes)

    print_report(defined, referenced, vendor, unused_allow, missing_allow, unused, missing)

    violation_count = MapSet.size(unused) + MapSet.size(missing)

    if violation_count > 0 do
      raise "#{violation_count} CSS consistency violation(s) found. See above for details."
    end

    :ok
  end

  # -- Phase A: Extract defined CSS classes --

  @doc false
  @spec extract_defined_classes() :: MapSet.t()
  def extract_defined_classes do
    Path.wildcard("#{css_dir()}/**/*.css")
    |> Enum.reject(fn path ->
      String.ends_with?(path, "showcase.css")
    end)
    |> Enum.reduce(%{}, fn file, acc ->
      extract_classes_from_css(File.read!(file), short_css_path(file))
      |> Enum.reduce(acc, fn {class, source}, map ->
        Map.update(map, class, [source], &[source | &1])
      end)
    end)
    |> Map.keys()
    |> MapSet.new()
  end

  @doc false
  @spec extract_classes_from_css(String.t(), String.t()) :: [{String.t(), String.t()}]
  def extract_classes_from_css(content, source) do
    content
    |> remove_css_comments()
    |> String.split("\n")
    |> Enum.reject(&import_line?/1)
    |> Enum.join("\n")
    |> extract_selectors()
    |> Enum.map(&{&1, source})
  end

  defp remove_css_comments(content) do
    Regex.replace(~r/\/\*[\s\S]*?\*\//, content, "")
  end

  defp import_line?(line), do: String.match?(String.trim(line), ~r/^@import\b/)

  defp extract_selectors(content) do
    Regex.scan(~r/\.([a-zA-Z][a-zA-Z0-9_-]*)/, content)
    |> Enum.map(fn [_, class] -> class end)
    |> Enum.uniq()
  end

  # -- Phase A (retro primitives): Extract retro design system classes --

  @doc false
  @spec extract_vendor_classes() :: MapSet.t()
  def extract_vendor_classes do
    dir = retro_css_dir()

    if File.dir?(dir) do
      Path.wildcard("#{dir}/*.css")
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> remove_css_comments()
        |> extract_selectors()
      end)
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  # -- Phase B: Extract referenced classes --

  @doc false
  @spec extract_all_references() :: MapSet.t()
  def extract_all_references do
    template_refs = extract_template_refs()
    js_refs = extract_js_refs()
    domain_refs = extract_domain_refs()

    MapSet.union(MapSet.union(template_refs, js_refs), domain_refs)
  end

  # Paths that use Tailwind CSS (not the retro CSS system) — skip for consistency checks
  @tailwind_paths [
    "components/ui/",
    "showcase_helpers.ex",
    "live/showcase_live/",
    "layouts/showcase.html.heex",
    "live/landing_live/",
    "landing_helpers.ex",
    "layouts/landing_live.html.heex",
    "live/help_live/",
    "layouts/help_live.html.heex",
    "live/v2/",
    "controllers/v2/",
    "layouts/v2.html.heex"
  ]

  @doc false
  @spec extract_template_refs() :: MapSet.t()
  def extract_template_refs do
    ex_files =
      Path.wildcard("#{web_lib()}/**/*.ex")
      |> Enum.reject(&String.contains?(&1, "mix/tasks/"))
      |> Enum.reject(&tailwind_path?/1)

    heex_files =
      Path.wildcard("#{web_lib()}/**/*.heex")
      |> Enum.reject(&tailwind_path?/1)

    (ex_files ++ heex_files)
    |> Enum.flat_map(&extract_refs_from_template/1)
    |> MapSet.new()
  end

  defp tailwind_path?(path) do
    Enum.any?(@tailwind_paths, &String.contains?(path, &1))
  end

  @doc false
  @spec extract_refs_from_template(String.t()) :: [String.t()]
  def extract_refs_from_template(file) do
    content = File.read!(file)
    static_classes(content) ++ dynamic_classes(content) ++ class_helper_classes(content)
  end

  defp static_classes(content) do
    Regex.scan(~r/class="([^"]*)"/, content)
    |> Enum.flat_map(fn [_, classes] -> String.split(classes) end)
    |> Enum.reject(&String.contains?(&1, "\#{"))
  end

  defp dynamic_classes(content) do
    extract_brace_exprs(content, "class={")
    |> Enum.flat_map(fn expr ->
      # 1. Classes from strings after removing interpolation blocks
      cleaned = remove_nested_interpolations(expr)
      plain_classes = extract_string_classes(cleaned)

      # 2. Classes from string literals INSIDE #{...} blocks
      interp_classes = extract_classes_from_interpolations(expr)

      plain_classes ++ interp_classes
    end)
  end

  defp extract_string_classes(text) do
    Regex.scan(~r/"([^"]*)"/, text)
    |> Enum.flat_map(fn [_, str] ->
      String.split(str) |> Enum.filter(&valid_class_name?/1)
    end)
  end

  defp extract_classes_from_interpolations(expr) do
    extract_interpolation_contents(expr)
    |> Enum.flat_map(&extract_string_classes/1)
  end

  defp remove_nested_interpolations(str) do
    do_remove_interpolations(str, "", 0, false)
  end

  defp do_remove_interpolations(<<>>, acc, _depth, _in_interp), do: acc

  defp do_remove_interpolations(<<"#", "{", rest::binary>>, acc, depth, _in_interp) do
    do_remove_interpolations(rest, acc, depth + 1, true)
  end

  defp do_remove_interpolations(<<"{", rest::binary>>, acc, depth, true) do
    do_remove_interpolations(rest, acc, depth + 1, true)
  end

  defp do_remove_interpolations(<<"}", rest::binary>>, acc, 1, true) do
    do_remove_interpolations(rest, acc, 0, false)
  end

  defp do_remove_interpolations(<<"}", rest::binary>>, acc, depth, true) when depth > 1 do
    do_remove_interpolations(rest, acc, depth - 1, true)
  end

  defp do_remove_interpolations(<<_c, rest::binary>>, acc, depth, true) when depth > 0 do
    do_remove_interpolations(rest, acc, depth, true)
  end

  defp do_remove_interpolations(<<c, rest::binary>>, acc, depth, in_interp) do
    do_remove_interpolations(rest, acc <> <<c>>, depth, in_interp)
  end

  # Extract the contents of #{...} blocks from a string (brace-depth aware)
  @doc false
  @spec extract_interpolation_contents(String.t()) :: [String.t()]
  def extract_interpolation_contents(str) do
    do_extract_interp(str, "", [], 0, false)
  end

  defp do_extract_interp(<<>>, _current, blocks, _depth, _in), do: blocks

  defp do_extract_interp(<<"#", "{", rest::binary>>, _current, blocks, 0, false) do
    do_extract_interp(rest, "", blocks, 1, true)
  end

  defp do_extract_interp(<<"{", rest::binary>>, current, blocks, depth, true) do
    do_extract_interp(rest, current <> "{", blocks, depth + 1, true)
  end

  defp do_extract_interp(<<"}", rest::binary>>, current, blocks, 1, true) do
    do_extract_interp(rest, "", [current | blocks], 0, false)
  end

  defp do_extract_interp(<<"}", rest::binary>>, current, blocks, depth, true)
       when depth > 1 do
    do_extract_interp(rest, current <> "}", blocks, depth - 1, true)
  end

  defp do_extract_interp(<<c, rest::binary>>, current, blocks, depth, true) when depth > 0 do
    do_extract_interp(rest, current <> <<c>>, blocks, depth, true)
  end

  defp do_extract_interp(<<_c, rest::binary>>, current, blocks, depth, in_interp) do
    do_extract_interp(rest, current, blocks, depth, in_interp)
  end

  # Auto-detect dynamic prefixes from interpolated class strings
  # e.g., class={"chat-message--#{type}"} → prefix "chat-message--"
  @doc false
  @spec extract_auto_prefixes() :: [String.t()]
  def extract_auto_prefixes do
    ex_files =
      Path.wildcard("#{web_lib()}/**/*.ex")
      |> Enum.reject(&String.contains?(&1, "mix/tasks/"))

    heex_files = Path.wildcard("#{web_lib()}/**/*.heex")
    domain_files = Path.wildcard("#{domain_lib()}/**/*.ex")

    (ex_files ++ heex_files ++ domain_files)
    |> Enum.flat_map(fn file ->
      content = File.read!(file)
      extract_interpolated_prefixes(content)
    end)
    |> Enum.uniq()
  end

  @doc false
  @spec extract_interpolated_prefixes(String.t()) :: [String.t()]
  def extract_interpolated_prefixes(content) do
    # Match prefix-#{...} where prefix ends with - or -- (dynamic suffix)
    # Uses word boundary to work with multi-word class strings
    extract_brace_exprs(content, "class={")
    |> Enum.flat_map(fn expr ->
      Regex.scan(~r/\b([a-zA-Z][a-zA-Z0-9_-]*-)\#\{/, expr)
      |> Enum.map(fn [_, prefix] -> prefix end)
    end)
  end

  @doc false
  @spec extract_brace_exprs(String.t(), String.t()) :: [String.t()]
  def extract_brace_exprs(content, prefix) do
    do_extract_brace_exprs(content, prefix, [])
  end

  defp do_extract_brace_exprs(content, prefix, acc) do
    case :binary.match(content, prefix) do
      :nomatch ->
        acc

      {pos, len} ->
        start = pos + len
        rest = binary_part(content, start, byte_size(content) - start)

        case find_matching_brace(rest, 1, 0) do
          {:ok, end_pos} ->
            expr = binary_part(rest, 0, end_pos)
            after_pos = start + end_pos + 1
            remaining = binary_part(content, after_pos, byte_size(content) - after_pos)
            do_extract_brace_exprs(remaining, prefix, [expr | acc])

          :error ->
            acc
        end
    end
  end

  defp find_matching_brace(<<>>, _depth, _pos), do: :error
  defp find_matching_brace(<<"}", _rest::binary>>, 1, pos), do: {:ok, pos}

  defp find_matching_brace(<<"}", rest::binary>>, depth, pos),
    do: find_matching_brace(rest, depth - 1, pos + 1)

  defp find_matching_brace(<<"{", rest::binary>>, depth, pos),
    do: find_matching_brace(rest, depth + 1, pos + 1)

  defp find_matching_brace(<<_, rest::binary>>, depth, pos),
    do: find_matching_brace(rest, depth, pos + 1)

  defp class_helper_classes(content) do
    # Look for defp.*_class functions and extract string literals
    Regex.scan(~r/defp\s+\w+_class\b.*?(?=\n\s*(?:defp|def|@)\b|\z)/s, content)
    |> Enum.flat_map(fn [body] ->
      Regex.scan(~r/"([a-zA-Z][a-zA-Z0-9_ -]*)"/, body)
      |> Enum.flat_map(fn [_, classes] -> String.split(classes) end)
      |> Enum.filter(&valid_class_name?/1)
    end)
  end

  @doc false
  @spec extract_js_refs() :: MapSet.t()
  def extract_js_refs do
    Path.wildcard("#{js_dir()}/**/*.js")
    |> Enum.reject(&String.contains?(&1, "node_modules"))
    |> Enum.flat_map(&extract_refs_from_js/1)
    |> MapSet.new()
  end

  @doc false
  @spec extract_refs_from_js(String.t()) :: [String.t()]
  def extract_refs_from_js(file) do
    content = File.read!(file)
    classlist_refs(content) ++ queryselector_refs(content) ++ classname_refs(content)
  end

  defp classlist_refs(content) do
    Regex.scan(~r/classList\.\w+\(["']([^"']+)["']/, content)
    |> Enum.flat_map(fn [_, classes] -> String.split(classes, ~r/[,\s]+/) end)
    |> Enum.filter(&valid_class_name?/1)
  end

  defp queryselector_refs(content) do
    # Handles compound selectors like .chat-link[data-url] or a.chat-link
    Regex.scan(~r/querySelector(?:All)?\(["'][^"']*\.([a-zA-Z][a-zA-Z0-9_-]*)/, content)
    |> Enum.map(fn [_, class] -> class end)
  end

  defp classname_refs(content) do
    # className = "name" or className += " name"
    Regex.scan(~r/className\s*\+?=\s*["']([^"']+)["']/, content)
    |> Enum.flat_map(fn [_, classes] -> String.split(classes) end)
    |> Enum.filter(&valid_class_name?/1)
  end

  @doc false
  @spec extract_domain_refs() :: MapSet.t()
  def extract_domain_refs do
    # Domain lib only: use targeted class_builder_refs pattern (e.g., maybe_add in formatter.ex)
    # Avoids false positives from standalone HTML generators like log_exporter.ex
    Path.wildcard("#{domain_lib()}/**/*.ex")
    |> Enum.flat_map(fn file ->
      File.read!(file) |> class_builder_refs()
    end)
    |> MapSet.new()
  end

  defp class_builder_refs(content) do
    # Catches patterns like maybe_add(state, "irc-bold") in formatter.ex
    # Requires hyphen in class name to avoid false positives (e.g., time_formatter "hour")
    Regex.scan(~r/maybe_add\([^,]+,\s*"([a-zA-Z][a-zA-Z0-9]*-[a-zA-Z0-9_-]*)"/, content)
    |> Enum.map(fn [_, class] -> class end)
  end

  # -- Allowlist --

  @doc false
  @spec load_allowlist() :: {MapSet.t(), MapSet.t(), [String.t()]}
  def load_allowlist do
    if File.exists?(allowlist_path()) do
      parse_allowlist(File.read!(allowlist_path()))
    else
      {MapSet.new(), MapSet.new(), []}
    end
  end

  @doc false
  @spec parse_allowlist(String.t()) :: {MapSet.t(), MapSet.t(), [String.t()]}
  def parse_allowlist(content) do
    lines =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line -> line == "" or String.starts_with?(line, "#") end)

    {unused, missing, dynamic, _section} =
      Enum.reduce(lines, {[], [], [], :unused}, fn line, {u, m, d, section} ->
        case line do
          "[unused]" -> {u, m, d, :unused}
          "[missing]" -> {u, m, d, :missing}
          "[dynamic-prefixes]" -> {u, m, d, :dynamic}
          entry when section == :unused -> {[entry | u], m, d, :unused}
          entry when section == :missing -> {u, [entry | m], d, :missing}
          entry when section == :dynamic -> {u, m, [entry | d], :dynamic}
        end
      end)

    {MapSet.new(unused), MapSet.new(missing), dynamic}
  end

  @doc false
  @spec filter_by_allowlist(MapSet.t(), MapSet.t(), [String.t()]) :: MapSet.t()
  def filter_by_allowlist(classes, allowlist, dynamic_prefixes) do
    classes
    |> Enum.reject(fn class ->
      MapSet.member?(allowlist, class) or
        matches_glob?(class, allowlist) or
        matches_dynamic_prefix?(class, dynamic_prefixes)
    end)
    |> MapSet.new()
  end

  defp matches_glob?(class, allowlist) do
    Enum.any?(allowlist, fn pattern ->
      String.ends_with?(pattern, "*") and
        String.starts_with?(class, String.trim_trailing(pattern, "*"))
    end)
  end

  defp matches_dynamic_prefix?(class, prefixes) do
    Enum.any?(prefixes, &String.starts_with?(class, &1))
  end

  # -- Helpers --

  defp valid_class_name?(name) do
    Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_-]*[a-zA-Z0-9]$/, name) or
      Regex.match?(~r/^[a-zA-Z]$/, name)
  end

  defp short_css_path(path) do
    String.replace_prefix(path, "#{css_dir()}/", "")
  end

  # -- Reporting --

  @doc false
  @spec defined_class_sources() :: %{String.t() => [String.t()]}
  def defined_class_sources do
    Path.wildcard("#{css_dir()}/**/*.css")
    |> Enum.reject(&String.ends_with?(&1, "app.css"))
    |> Enum.reduce(%{}, fn file, acc ->
      extract_classes_from_css(File.read!(file), short_css_path(file))
      |> Enum.reduce(acc, &merge_class_source/2)
    end)
  end

  defp merge_class_source({class, source}, map) do
    Map.update(map, class, [source], fn sources ->
      if source in sources, do: sources, else: [source | sources]
    end)
  end

  @doc false
  @spec referenced_class_sources() :: %{String.t() => [String.t()]}
  def referenced_class_sources do
    ex_files =
      Path.wildcard("#{web_lib()}/**/*.ex")
      |> Enum.reject(&String.contains?(&1, "mix/tasks/"))
      |> Enum.reject(&tailwind_path?/1)

    heex_files =
      Path.wildcard("#{web_lib()}/**/*.heex")
      |> Enum.reject(&tailwind_path?/1)

    template_sources =
      (ex_files ++ heex_files)
      |> Enum.reduce(%{}, fn file, acc ->
        refs = extract_refs_from_template(file)
        short = String.replace_prefix(file, "#{web_lib()}/", "")

        Enum.reduce(refs, acc, fn class, map -> Map.update(map, class, [short], &[short | &1]) end)
      end)

    js_sources =
      Path.wildcard("#{js_dir()}/**/*.js")
      |> Enum.reject(&String.contains?(&1, "node_modules"))
      |> Enum.reduce(%{}, fn file, acc ->
        refs = extract_refs_from_js(file)
        short = String.replace_prefix(file, "#{js_dir()}/", "")

        Enum.reduce(refs, acc, fn class, map -> Map.update(map, class, [short], &[short | &1]) end)
      end)

    Map.merge(template_sources, js_sources, fn _k, v1, v2 -> v1 ++ v2 end)
  end

  defp print_report(defined, referenced, vendor, unused_allow, missing_allow, unused, missing) do
    IO.puts("#{IO.ANSI.cyan()}Scanning CSS class consistency...#{IO.ANSI.reset()}")
    IO.puts("")
    IO.puts("#{IO.ANSI.cyan()}Summary:#{IO.ANSI.reset()}")
    IO.puts("  CSS classes defined:      #{MapSet.size(defined)}")
    IO.puts("  Classes referenced:       #{MapSet.size(referenced)}")
    IO.puts("  Retro classes:            #{MapSet.size(vendor)}")
    IO.puts("  Allowlisted (unused):     #{MapSet.size(unused_allow)}")
    IO.puts("  Allowlisted (missing):    #{MapSet.size(missing_allow)}")
    IO.puts("")

    if MapSet.size(unused) == 0 do
      IO.puts("#{IO.ANSI.green()}✓ No unused CSS classes found.#{IO.ANSI.reset()}")
    else
      sources = defined_class_sources()
      IO.puts("#{IO.ANSI.red()}Unused CSS classes (#{MapSet.size(unused)}):#{IO.ANSI.reset()}")

      unused
      |> Enum.sort()
      |> Enum.each(fn class ->
        file = sources |> Map.get(class, ["unknown"]) |> List.first()
        IO.puts("  #{String.pad_trailing(file, 28)} .#{class}")
      end)

      IO.puts("")
    end

    if MapSet.size(missing) == 0 do
      IO.puts("#{IO.ANSI.green()}✓ No missing CSS classes found.#{IO.ANSI.reset()}")
    else
      ref_sources = referenced_class_sources()
      IO.puts("#{IO.ANSI.red()}Missing CSS classes (#{MapSet.size(missing)}):#{IO.ANSI.reset()}")

      missing
      |> Enum.sort()
      |> Enum.each(fn class ->
        file = ref_sources |> Map.get(class, ["unknown"]) |> List.first()
        IO.puts("  #{String.pad_trailing(file, 28)} .#{class}")
      end)

      IO.puts("")
    end

    total = MapSet.size(unused) + MapSet.size(missing)

    if total > 0 do
      IO.puts("#{total} violation(s) found.")
      IO.puts("")

      IO.puts(
        "Run '#{IO.ANSI.cyan()}make lint.css#{IO.ANSI.reset()}' again after fixing violations."
      )
    end
  end
end
