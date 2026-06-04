defmodule Mix.Tasks.Audit.Styles do
  @shortdoc "Diagnostic report of all hardcoded styles in the codebase"
  @moduledoc """
  Scans Elixir, HEEx, and JavaScript files for hardcoded styles that should be
  controlled via CSS. Reports findings organized by risk level (LOW, MEDIUM, HIGH, INFO).

  By default this task prints a diagnostic report and exits zero. With `--strict`,
  it fails when LOW, MEDIUM, or HIGH findings are present. INFO findings remain
  advisory.

  ## Categories

  1. `INLINE-STYLE`  — Any `style=` attribute in .ex/.heex templates
  2. `COLOR-ATTR`    — Hex color values in Elixir module attributes/strings
  3. `STYLE-HELPER`  — Functions named `*_style` that build CSS strings
  4. `JS-STYLE-PROP` — Direct `el.style.*` property assignments in JS
  5. `JS-COLOR`      — Hex color values in JavaScript files

  SVG icon colors (fill/stroke) are excluded — they are illustration data, not layout styles.

  ## Usage

      mix audit.styles
      mix audit.styles --strict

  `make ci` runs this task in strict mode through `make lint.css`.
  """

  use Mix.Task

  @dialyzer [:no_undefined_callbacks]

  @web_lib "apps/retro_hex_chat_web/lib"
  @domain_lib "apps/retro_hex_chat/lib"
  @js_dir "apps/retro_hex_chat_web/assets/js"

  @hex_color_re ~r/#[0-9a-fA-F]{3,8}\b/
  @style_attr_re ~r/\bstyle\s*=/
  @style_helper_re ~r/defp?\s+\w+_style\b/
  @js_style_prop_re ~r/\.style\.(\w+)\s*=/

  @impl Mix.Task
  @spec run(list()) :: :ok
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [strict: :boolean])

    elixir_files =
      list_files(@web_lib, "**/*.ex") ++ list_files(@domain_lib, "**/*.ex")

    heex_files = list_files(@web_lib, "**/*.heex")
    js_files = list_files(@js_dir, "**/*.js")

    template_files = elixir_files ++ heex_files

    findings = %{
      inline_style: scan_inline_styles(template_files),
      color_attr: scan_color_attrs(elixir_files),
      style_helper: scan_style_helpers(elixir_files),
      js_style_prop: scan_js_style_props(js_files),
      js_color: scan_js_colors(js_files)
    }

    groups = build_risk_groups(findings)
    counts = risk_counts(groups)

    print_report(findings, groups, counts)

    if opts[:strict] && blocking_count(counts) > 0 do
      raise RuntimeError, message: strict_error_message(counts)
    end

    :ok
  end

  # ── Scanners ──────────────────────────────────────────────────────────

  defp scan_inline_styles(files) do
    scan_files(files, fn line, _file ->
      Regex.match?(@style_attr_re, line) and not comment_line?(line) and
        not svg_attr?(line)
    end)
  end

  defp scan_color_attrs(files) do
    scan_files(files, fn line, _file ->
      has_hex_color?(line) and color_context?(line) and not comment_line?(line)
    end)
  end

  defp scan_style_helpers(files) do
    scan_files(files, fn line, _file ->
      Regex.match?(@style_helper_re, line)
    end)
  end

  defp scan_js_style_props(files) do
    scan_files(files, fn line, _file ->
      Regex.match?(@js_style_prop_re, line) and not js_comment_line?(line)
    end)
  end

  defp scan_js_colors(files) do
    scan_files(files, fn line, _file ->
      has_hex_color?(line) and not js_comment_line?(line)
    end)
  end

  # ── File scanning ─────────────────────────────────────────────────────

  defp scan_files(files, match_fn) do
    Enum.flat_map(files, fn file ->
      file
      |> File.read!()
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _num} -> match_fn.(line, file) end)
      |> Enum.map(fn {line, num} -> {short_path(file), num, String.trim(line)} end)
    end)
  end

  defp list_files(dir, pattern) do
    Path.wildcard("#{dir}/#{pattern}")
    |> Enum.reject(&String.contains?(&1, "mix/tasks/"))
    |> Enum.reject(&String.contains?(&1, "node_modules"))
    |> Enum.sort()
  end

  # ── Context detection ─────────────────────────────────────────────────

  defp has_hex_color?(line), do: Regex.match?(@hex_color_re, line)

  defp color_context?(line) do
    trimmed = String.trim(line)

    module_attr_with_color?(trimmed) or
      css_style_property?(trimmed) or
      palette_literal?(trimmed) or
      (String.contains?(trimmed, "border:") and has_hex_color?(trimmed))
  end

  defp module_attr_with_color?(trimmed) do
    String.starts_with?(trimmed, "@") and has_hex_color?(trimmed)
  end

  defp css_style_property?(trimmed) do
    String.contains?(trimmed, "color:") or String.contains?(trimmed, "background:") or
      String.contains?(trimmed, "background-color:")
  end

  defp palette_literal?(trimmed) do
    (String.contains?(trimmed, "=>") or String.contains?(trimmed, "{\"")) and
      has_hex_color?(trimmed)
  end

  defp comment_line?(line) do
    trimmed = String.trim(line)
    String.starts_with?(trimmed, "#") or String.starts_with?(trimmed, "<%#")
  end

  defp js_comment_line?(line) do
    trimmed = String.trim(line)
    String.starts_with?(trimmed, "//") or String.starts_with?(trimmed, "/*")
  end

  # Detect SVG-specific attributes like font-style="italic" that are NOT inline styles
  defp svg_attr?(line) do
    Regex.match?(~r/font-style\s*=/, line)
  end

  # ── Risk classification ───────────────────────────────────────────────

  defp classify_inline_style({_file, _line, content}) do
    inline_style_risk(content, String.downcase(content))
  end

  defp inline_style_risk(content, trimmed) do
    cond do
      css_custom_property?(content) -> :info
      position_only?(content, trimmed) -> :info
      dynamic_stacking?(content) -> :info
      static_display_none?(trimmed) -> :low
      static_position_relative?(trimmed) -> :low
      String.contains?(trimmed, "position: fixed") -> :info
      true -> :medium
    end
  end

  defp css_custom_property?(content), do: Regex.match?(~r/style=\{"--/, content)

  defp position_only?(content, trimmed) do
    Regex.match?(~r/style=\{"left:.*top:/, content) and
      not String.contains?(trimmed, "position:")
  end

  defp dynamic_stacking?(content), do: Regex.match?(~r/style=\{"z-index:.*--/, content)

  defp static_display_none?(trimmed) do
    String.contains?(trimmed, "style=\"display: none") or
      String.contains?(trimmed, "style=\"display:none")
  end

  defp static_position_relative?(trimmed) do
    String.contains?(trimmed, "style=\"position: relative") or
      String.contains?(trimmed, "style=\"position:relative")
  end

  defp classify_js_style_prop({file, _line, content}) do
    js_style_risk(file, content)
  end

  defp js_style_risk(file, content) do
    cond do
      String.contains?(content, "style.display") -> :low
      String.contains?(content, "style.position") -> :low
      # RAF animation in p2p diagram hook — data-driven, can't use CSS
      String.contains?(file, "p2p_diagram") -> :info
      js_viewport_property?(file, content) -> :info
      true -> :medium
    end
  end

  defp js_viewport_property?(file, content) do
    (String.contains?(content, "style.height") and String.contains?(file, "input")) or
      String.contains?(content, "style.overflowY") or
      String.contains?(content, "style.left") or
      String.contains?(content, "style.top") or
      String.contains?(content, "style.maxHeight")
  end

  defp classify_js_color({file, _line, _content}) do
    cond do
      String.contains?(file, "favicon_badge") -> :info
      String.contains?(file, "app.js") -> :info
      true -> :medium
    end
  end

  # ── Report printing ───────────────────────────────────────────────────

  defp print_report(findings, groups, counts) do
    IO.puts("\n#{cyan()}=== Style Audit Report ===#{reset()}\n")

    Enum.each([:low, :medium, :high, :info], fn risk ->
      entries = Map.get(groups, risk, [])

      if entries != [] do
        print_risk_section(risk, entries)
      end
    end)

    total = Enum.sum(Enum.map(Map.values(findings), &length/1))

    IO.puts("#{cyan()}Summary:#{reset()}")
    IO.puts("  Total findings: #{total}")

    IO.puts(
      "  #{green()}LOW:#{reset()} #{counts.low}  #{yellow()}MEDIUM:#{reset()} #{counts.medium}  #{red()}HIGH:#{reset()} #{counts.high}  INFO: #{counts.info}"
    )

    if total == 0 do
      IO.puts("\n#{green()}All styles are in CSS!#{reset()}\n")
    else
      IO.puts("")
    end
  end

  defp build_risk_groups(findings) do
    all_entries =
      classify_category(:inline_style, findings.inline_style, &classify_inline_style/1) ++
        classify_category(:color_attr, findings.color_attr, fn _ -> :high end) ++
        classify_category(:style_helper, findings.style_helper, fn _ -> :medium end) ++
        classify_category(:js_style_prop, findings.js_style_prop, &classify_js_style_prop/1) ++
        classify_category(:js_color, findings.js_color, &classify_js_color/1)

    Enum.group_by(all_entries, fn {risk, _cat, _f, _l, _c} -> risk end)
  end

  defp risk_counts(groups) do
    Enum.reduce(Map.values(groups), %{low: 0, medium: 0, high: 0, info: 0}, fn entries, acc ->
      Enum.reduce(entries, acc, fn {risk, _cat, _f, _l, _c}, inner ->
        Map.update!(inner, risk, &(&1 + 1))
      end)
    end)
  end

  defp blocking_count(counts), do: counts.low + counts.medium + counts.high

  defp strict_error_message(counts) do
    "style audit failed with #{blocking_count(counts)} blocking finding(s): " <>
      "#{counts.low} LOW, #{counts.medium} MEDIUM, #{counts.high} HIGH"
  end

  defp classify_category(:color_attr, items, _classifier) do
    Enum.map(items, fn {file, _line, _content} = item ->
      # Log exporter embeds CSS for standalone HTML exports — always INFO
      risk = if String.contains?(file, "log_exporter"), do: :info, else: :high
      {risk, :color_attr, elem(item, 0), elem(item, 1), elem(item, 2)}
    end)
  end

  defp classify_category(category, items, classifier) do
    Enum.map(items, fn {file, line, content} = item ->
      risk = classifier.(item)
      {risk, category, file, line, content}
    end)
  end

  defp print_risk_section(risk, entries) do
    label = risk_label(risk)
    by_category = Enum.group_by(entries, fn {_r, cat, _f, _l, _c} -> cat end)

    Enum.each(by_category, fn {category, items} ->
      IO.puts("#{label} #{category_label(category)} (#{length(items)} findings)")
      IO.puts("  #{suggestion(category)}")
      IO.puts("")

      items
      |> Enum.sort_by(fn {_, _, f, l, _} -> {f, l} end)
      |> Enum.each(fn {_, _, file, line, content} ->
        IO.puts("  #{file}:#{line}")
        IO.puts("    #{content}")
      end)

      IO.puts("")
    end)
  end

  defp risk_label(:low), do: "#{green()}[LOW]#{reset()}"
  defp risk_label(:medium), do: "#{yellow()}[MEDIUM]#{reset()}"
  defp risk_label(:high), do: "#{red()}[HIGH]#{reset()}"
  defp risk_label(:info), do: "[INFO]"

  defp category_label(:inline_style), do: "Inline style= attributes"
  defp category_label(:color_attr), do: "Hardcoded hex colors in Elixir"
  defp category_label(:style_helper), do: "Style helper functions building CSS"
  defp category_label(:js_style_prop), do: "JS el.style.* property assignments"
  defp category_label(:js_color), do: "Hex colors in JavaScript"

  defp suggestion(:inline_style),
    do: "Replace with CSS classes (e.g. class=\"u-hidden\")"

  defp suggestion(:color_attr), do: "Move color palettes to CSS custom properties"

  defp suggestion(:style_helper),
    do: "Eliminate helpers, use dynamic CSS classes instead"

  defp suggestion(:js_style_prop), do: "Replace with classList.toggle() or CSS classes"
  defp suggestion(:js_color), do: "Use CSS custom properties via getComputedStyle()"

  # ── Helpers ───────────────────────────────────────────────────────────

  defp short_path(file) do
    file
    |> String.replace_prefix("apps/retro_hex_chat_web/lib/retro_hex_chat_web/", "web/")
    |> String.replace_prefix("apps/retro_hex_chat_web/assets/js/", "js/")
    |> String.replace_prefix("apps/retro_hex_chat/lib/retro_hex_chat/", "domain/")
  end

  defp cyan, do: IO.ANSI.cyan()
  defp green, do: IO.ANSI.green()
  defp yellow, do: IO.ANSI.yellow()
  defp red, do: IO.ANSI.red()
  defp reset, do: IO.ANSI.reset()
end
