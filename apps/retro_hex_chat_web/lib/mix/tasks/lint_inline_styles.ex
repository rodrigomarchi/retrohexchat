defmodule Mix.Tasks.Lint.InlineStyles do
  @shortdoc "Audit inline styles in LiveView components"
  @moduledoc """
  Scans all `.ex` files under the web app's `lib/` directory for inline `style=`
  attributes. Dynamic styles (containing `\#{`) are permitted. Static styles must
  be listed in `scripts/inline_style_allowlist.txt` or they are reported as violations.

  Also reports `defp.*_style` helper functions as candidates for CSS extraction.

  ## Usage

      mix lint.inline_styles

  Exits non-zero when violations are found.
  """

  use Mix.Task

  # Dialyzer cannot see Mix.Task callbacks or Mix.raise/1 at analysis time.
  @dialyzer [:no_return, :no_undefined_callbacks]

  @web_lib "apps/retro_hex_chat_web/lib"
  @allowlist_path "scripts/inline_style_allowlist.txt"

  @impl Mix.Task
  @spec run(list()) :: :ok
  def run(_args) do
    {inline_allowlist, helper_allowlist} = load_allowlists()

    files =
      Path.wildcard("#{@web_lib}/**/*.ex")
      |> Enum.reject(&String.contains?(&1, "mix/tasks/"))
      |> Enum.sort()

    {total_static, total_dynamic, total_allowed, violations} =
      scan_inline_styles(files, inline_allowlist)

    style_helpers = scan_style_helpers(files, helper_allowlist)

    total = total_static + total_dynamic + total_allowed

    print_report(total, total_dynamic, total_allowed, total_static, style_helpers, violations)

    if total_static > 0 do
      raise "#{total_static} inline style violation(s) found. See above for details."
    end

    if style_helpers != [] do
      count = length(style_helpers)
      raise "#{count} unallowlisted style helper(s) found. See above for details."
    end

    :ok
  end

  defp load_allowlists do
    if File.exists?(@allowlist_path) do
      lines =
        @allowlist_path
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(fn line ->
          trimmed = String.trim(line)
          trimmed == "" or String.starts_with?(trimmed, "#")
        end)
        |> Enum.map(&String.trim/1)

      split_sections(lines)
    else
      {[], []}
    end
  end

  defp split_sections(lines) do
    {inline, helper, _section} =
      Enum.reduce(lines, {[], [], :inline}, fn line, {inl, hlp, section} ->
        case line do
          "[style-helpers]" -> {inl, hlp, :helpers}
          entry when section == :helpers -> {inl, [entry | hlp], :helpers}
          entry -> {[entry | inl], hlp, section}
        end
      end)

    {inline, helper}
  end

  defp scan_inline_styles(files, allowlist) do
    Enum.reduce(files, {0, 0, 0, []}, fn file, acc ->
      file
      |> File.read!()
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _num} -> String.contains?(line, "style=") end)
      |> Enum.reduce(acc, fn {line, line_num}, inner_acc ->
        classify_style(file, line, line_num, allowlist, inner_acc)
      end)
    end)
  end

  defp classify_style(file, line, line_num, allowlist, {static, dynamic, allowed, violations}) do
    if String.contains?(line, "\#{") do
      {static, dynamic + 1, allowed, violations}
    else
      short_file = String.replace_prefix(file, "#{@web_lib}/", "")
      trimmed = String.trim(line)

      if content_allowed?(short_file, trimmed, allowlist) do
        {static, dynamic, allowed + 1, violations}
      else
        {static + 1, dynamic, allowed, [{short_file, line_num, trimmed} | violations]}
      end
    end
  end

  defp content_allowed?(file, trimmed_line, allowlist) do
    Enum.any?(allowlist, fn entry ->
      case String.split(entry, ":", parts: 2) do
        [entry_file, snippet] ->
          entry_file == file and String.contains?(trimmed_line, String.trim(snippet))

        _ ->
          false
      end
    end)
  end

  defp scan_style_helpers(files, helper_allowlist) do
    style_helper_regex = ~r/defp.*_style\b/

    Enum.flat_map(files, fn file ->
      content = File.read!(file)

      content
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _num} -> Regex.match?(style_helper_regex, line) end)
      |> Enum.reject(fn {line, _line_num} ->
        short_file = String.replace_prefix(file, "#{@web_lib}/", "")
        content_allowed?(short_file, String.trim(line), helper_allowlist)
      end)
      |> Enum.map(fn {line, line_num} ->
        short_file = String.replace_prefix(file, "#{@web_lib}/", "")
        {short_file, line_num, String.trim(line)}
      end)
    end)
  end

  defp print_report(total, total_dynamic, total_allowed, total_static, style_helpers, violations) do
    IO.puts(
      "#{IO.ANSI.cyan()}Scanning LiveView components for inline styles...#{IO.ANSI.reset()}"
    )

    IO.puts("")
    IO.puts("#{IO.ANSI.cyan()}Summary:#{IO.ANSI.reset()}")
    IO.puts("   Total inline styles found: #{total}")
    IO.puts("   Dynamic (allowed):         #{total_dynamic}")
    IO.puts("   Allowlisted:               #{total_allowed}")
    IO.puts("   Static (violations):       #{total_static}")
    IO.puts("")

    if style_helpers != [] do
      IO.puts(
        "#{IO.ANSI.red()}Unallowlisted style helpers (add to [style-helpers] section in allowlist or replace with CSS):#{IO.ANSI.reset()}"
      )

      Enum.each(style_helpers, fn {file, line_num, content} ->
        IO.puts("  #{file}:#{line_num}   #{content}")
      end)

      IO.puts("")
    end

    if total_static == 0 and style_helpers == [] do
      IO.puts(
        "#{IO.ANSI.green()}No violations found. All inline styles and helpers are allowed.#{IO.ANSI.reset()}"
      )
    else
      IO.puts("#{IO.ANSI.red()}Violations found:#{IO.ANSI.reset()}")
      IO.puts("")

      violations
      |> Enum.reverse()
      |> Enum.each(fn {file, line_num, content} ->
        IO.puts("  #{file}:#{line_num}")
        IO.puts("    #{content}")
        IO.puts("")
      end)

      IO.puts(
        "Run '#{IO.ANSI.cyan()}make lint.css#{IO.ANSI.reset()}' again after fixing violations."
      )
    end
  end
end
