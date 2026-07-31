#!/usr/bin/env elixir

Code.require_file("ci_impact.exs", __DIR__)

defmodule CIGitHubPlan do
  @moduledoc false

  @static_checks [
    "format",
    "credo",
    "lint_js",
    "js_tests",
    "lint_css",
    "lint_bundle"
  ]
  @tooling_checks [
    "ci_impact_tests",
    "ci_partition_profile_plan",
    "py_tests",
    "i18n_quality"
  ]
  @test_checks [
    "test",
    "test_feature",
    "test_domain",
    "test_web"
  ]
  @browser_checks [
    "e2e_changed",
    "e2e_smoke_connect",
    "e2e_smoke_chat",
    "e2e_smoke_dialogs",
    "e2e_smoke_i18n",
    "e2e_smoke_calls",
    "e2e_smoke_mobile",
    "e2e"
  ]
  @known_checks [
    "compile",
    "lint_js",
    "js_tests",
    "ci_impact_tests",
    "ci_partition_profile_plan",
    "py_tests",
    "i18n_quality",
    "format",
    "credo",
    "lint_css",
    "lint_bundle",
    "test",
    "test_feature",
    "test_domain",
    "test_web",
    "e2e_changed",
    "e2e_smoke_connect",
    "e2e_smoke_chat",
    "e2e_smoke_dialogs",
    "e2e_smoke_i18n",
    "e2e_smoke_calls",
    "e2e_smoke_mobile",
    "e2e",
    "dialyzer"
  ]

  def main(args) do
    opts = parse_args(args)
    {plan, diff_status} = build_plan(opts)
    outputs = build_outputs(plan, opts, diff_status)

    write_outputs(opts.output_path, outputs)
    write_markdown(opts.markdown_path, plan, opts, diff_status)
    print_summary(plan, opts, diff_status)
  end

  defp parse_args(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          mode: :string,
          base: :string,
          head: :string,
          output: :string,
          markdown: :string
        ]
      )

    mode = opts[:mode] || System.get_env("CI_PLAN_MODE") || "full"

    unless mode in ["full", "changed"] do
      raise ArgumentError, "mode must be full or changed, got: #{inspect(mode)}"
    end

    %{
      mode: mode,
      base: non_empty(opts[:base] || System.get_env("CI_BASE"), "origin/main"),
      head: non_empty(opts[:head] || System.get_env("CI_HEAD"), "HEAD"),
      output_path: opts[:output] || System.get_env("GITHUB_OUTPUT"),
      markdown_path: opts[:markdown] || System.get_env("GITHUB_STEP_SUMMARY")
    }
  end

  defp non_empty(nil, default), do: default
  defp non_empty("", default), do: default
  defp non_empty(value, _default), do: value

  defp build_plan(%{mode: "full"}) do
    {CIImpact.fallback([], "full CI requested"), {:ok, []}}
  end

  defp build_plan(%{mode: "changed", base: base, head: head}) do
    case git_changed_files(base, head) do
      {:ok, files} ->
        {CIImpact.plan(files), {:ok, files}}

      {:error, reason} ->
        {CIImpact.fallback([], reason), {:error, reason}}
    end
  end

  defp git_changed_files(base, head) do
    diff_range = "#{base}...#{head}"

    case System.cmd("git", ["diff", "--name-only", "--diff-filter=ACMRTUXB", diff_range],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()
          |> Enum.sort()

        {:ok, files}

      {output, _code} ->
        {:error, "git diff #{diff_range} failed: #{String.trim(output)}"}
    end
  end

  defp build_outputs(plan, opts, diff_status) do
    checks = MapSet.new(plan.checks)
    static_checks = selected(@static_checks, checks)
    tooling_checks = selected(@tooling_checks, checks)
    test_checks = selected(@test_checks, checks)
    browser_checks = selected(@browser_checks, checks)

    [
      {"mode", opts.mode},
      {"base", opts.base},
      {"head", opts.head},
      {"fallback", fallback_level(plan.fallback)},
      {"fallback_reason", fallback_reason(plan.fallback)},
      {"diff_status", diff_status(diff_status)},
      {"changed_files", join(plan.files)},
      {"surfaces", join(plan.surfaces)},
      {"selected_checks", join(plan.checks)},
      {"skipped_checks", join(plan.skipped)},
      {"static_checks", join(static_checks)},
      {"tooling_checks", join(tooling_checks)},
      {"test_checks", join(test_checks)},
      {"browser_checks", join(browser_checks)},
      {"run_static", bool(static_checks != [])},
      {"run_tooling", bool(tooling_checks != [])},
      {"run_tests", bool(test_checks != [])},
      {"run_browser", bool(browser_checks != [])},
      {"run_dialyzer", bool(MapSet.member?(checks, "dialyzer"))},
      {"has_checks", bool(plan.checks != [])}
    ] ++ Enum.map(@known_checks, fn check -> {check, bool(MapSet.member?(checks, check))} end)
  end

  defp selected(group, checks), do: Enum.filter(group, &MapSet.member?(checks, &1))
  defp bool(true), do: "true"
  defp bool(false), do: "false"
  defp join(values), do: Enum.join(values, ",")

  defp fallback_level(nil), do: "none"
  defp fallback_level(%{level: level}), do: Atom.to_string(level)

  defp fallback_reason(nil), do: ""
  defp fallback_reason(%{reason: reason}), do: reason

  defp diff_status({:ok, _files}), do: "ok"
  defp diff_status({:error, _reason}), do: "fallback"

  defp write_outputs(nil, _outputs), do: :ok

  defp write_outputs(path, outputs) do
    content = Enum.map_join(outputs, "\n", fn {key, value} -> "#{key}=#{output_value(value)}" end)

    File.write!(path, content <> "\n", [:append])
  end

  defp output_value(value) do
    value
    |> to_string()
    |> String.replace(~r/[\r\n]+/, " ")
  end

  defp write_markdown(nil, _plan, _opts, _diff_status), do: :ok

  defp write_markdown(path, plan, opts, diff_status) do
    File.write!(path, render_markdown(plan, opts, diff_status), [:append])
  end

  defp render_markdown(plan, opts, diff_status) do
    """
    ## CI Impact Plan

    Mode: `#{opts.mode}`
    Base: `#{opts.base}`
    Head: `#{opts.head}`
    Diff: `#{diff_status(diff_status)}`
    Fallback: `#{fallback_level(plan.fallback)}`#{fallback_suffix(plan.fallback)}

    ### Changed Files

    #{markdown_list(plan.files, "_No changed files._")}

    ### Selected Checks

    #{markdown_list(plan.checks, "_No technical checks selected._")}

    ### Skipped Full-Guard Checks

    #{markdown_list(plan.skipped, "_None._")}

    ### Surfaces

    #{markdown_list(plan.surfaces, "_None._")}
    """
  end

  defp fallback_suffix(nil), do: ""
  defp fallback_suffix(%{reason: reason}), do: "\nFallback reason: #{reason}"

  defp markdown_list([], empty), do: empty

  defp markdown_list(items, _empty) do
    Enum.map_join(items, "\n", fn item -> "- `#{item}`" end)
  end

  defp print_summary(plan, opts, diff_status) do
    IO.puts("CI impact plan")
    IO.puts("Mode: #{opts.mode}")
    IO.puts("Base: #{opts.base}")
    IO.puts("Head: #{opts.head}")
    IO.puts("Diff: #{diff_status(diff_status)}")
    IO.puts("Fallback: #{fallback_level(plan.fallback)}")
    IO.puts("Changed files: #{length(plan.files)}")
    IO.puts("Selected checks: #{if plan.checks == [], do: "none", else: join(plan.checks)}")
  end
end

CIGitHubPlan.main(System.argv())
