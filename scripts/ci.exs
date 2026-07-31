#!/usr/bin/env elixir

# RetroHexChat CI — Local Runner
#
# Runs all CI checks locally with maximum parallelism.
# No compilation needed — this is a standalone .exs script.
#
# Pipeline:
#   Stage 1: compile + JS lint + JS tests + i18n checks in parallel
#   Stage 2 (parallel, after compile): format + credo + CSS lint + tests + feature tests
#   Stage 3 (isolated, after stage 2): dialyzer (runs alone to avoid protocol consolidation races)
#
# Tests and feature tests are partitioned by default to reduce wall-clock time.
# Each OS process gets a distinct test database via TEST_DB_SUFFIX; MIX_TEST_PARTITION
# remains reserved for ExUnit's own partition selection.
#
# Usage:
#   elixir scripts/ci.exs              # run all 11 checks
#   elixir scripts/ci.exs --quick      # skip dialyzer
#   elixir scripts/ci.exs --only compile,credo
#   CI_TEST_PARTITIONS=1 CI_FEATURE_PARTITIONS=1 elixir scripts/ci.exs

Code.require_file("ci_impact.exs", __DIR__)

defmodule CI do
  @compile_check "compile"
  @stage1_independent [
    "lint_js",
    "js_tests",
    "ci_impact_tests",
    "py_tests",
    "i18n_quality",
    "lint_hooks",
    "lint_bundle"
  ]
  @stage2_after_compile [
    "format",
    "credo",
    "lint_css",
    "test",
    "test_feature",
    "test_domain",
    "test_web",
    "e2e_changed",
    "e2e"
  ]
  @stage3_isolated ["dialyzer"]

  @full_checks CIImpact.full_checks()
  @all_checks Enum.uniq(
                @full_checks ++ @stage1_independent ++ @stage2_after_compile ++ @stage3_isolated
              )

  @check_config %{
    "compile" => %{label: "Compile", cmd: "mix", args: ["compile", "--warnings-as-errors"]},
    "lint_js" => %{label: "JS Lint", cmd: "make", args: ["lint.js"]},
    "lint_css" => %{label: "CSS Lint", cmd: "make", args: ["lint.css"]},
    "js_tests" => %{
      label: "JS Tests",
      cmd: "npm",
      args: ["test", "--prefix", "apps/retro_hex_chat_web/assets"]
    },
    "ci_impact_tests" => %{
      label: "CI Impact Tests",
      cmd: "elixir",
      args: ["scripts/ci_impact_test.exs"]
    },
    "py_tests" => %{
      label: "i18n Tooling Tests",
      cmd: "python3",
      args: ["-m", "unittest", "discover", "-s", "scripts", "-t", "scripts", "-p", "test_*.py"]
    },
    "i18n_quality" => %{
      label: "i18n Quality",
      cmd: "python3",
      args: ["scripts/i18n_quality_check.py", "--fail-on-findings"]
    },
    "lint_hooks" => %{label: "LiveView Hook Contract", cmd: "make", args: ["lint.hooks"]},
    "lint_bundle" => %{label: "Bundle Budget", cmd: "make", args: ["lint.bundle"]},
    "format" => %{label: "Format", cmd: "make", args: ["format.check"]},
    "credo" => %{label: "Credo", cmd: "mix", args: ["credo", "--strict"]},
    "test" => %{label: "Tests", cmd: "mix", args: ["test"], partitions: :test},
    "test_feature" => %{
      label: "Feature Tests",
      cmd: "mix",
      args: ["test", "--only", "liveview_feature"],
      partitions: :feature
    },
    "test_domain" => %{label: "Domain Tests", cmd: "make", args: ["test.domain"]},
    "test_web" => %{label: "Web Tests", cmd: "make", args: ["test.web"]},
    "e2e_changed" => %{label: "Changed E2E Tests", cmd: "make", args: ["e2e.changed"]},
    "e2e" => %{label: "E2E Tests", cmd: "make", args: ["e2e.headless"]},
    "dialyzer" => %{label: "Dialyzer", cmd: "mix", args: ["dialyzer"]}
  }

  def main(args) do
    {opts, _rest} = parse_args(args)
    project_root = find_project_root()
    {checks, changed_plan} = resolve_checks(opts, project_root)
    runner_config = runner_config(opts)
    start_time = System.monotonic_time(:millisecond)

    header()
    print_runner_config(runner_config)
    maybe_print_changed_plan(changed_plan)

    if opts[:explain_only] do
      System.halt(0)
    end

    stage1_results = run_stage1(checks, project_root, runner_config)
    stage2_results = run_stage2(checks, stage1_results, project_root, runner_config)

    stage3_results =
      run_stage3(checks, stage1_results, stage2_results, project_root, runner_config)

    all_results = stage1_results |> Map.merge(stage2_results) |> Map.merge(stage3_results)
    elapsed = System.monotonic_time(:millisecond) - start_time

    summary(all_results, elapsed)

    if Enum.all?(Map.values(all_results), &(&1 == :ok)) do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  # --- stages ---

  defp run_stage1(checks, project_root, runner_config) do
    stage1_checks =
      [@compile_check | @stage1_independent]
      |> Enum.filter(&(&1 in checks))

    if stage1_checks == [] do
      %{}
    else
      run_stage("Stage 1", stage1_checks, project_root, runner_config)
    end
  end

  defp run_stage2(checks, stage1_results, project_root, runner_config) do
    stage2_checks = Enum.filter(@stage2_after_compile, &(&1 in checks))
    compile_passed? = stage1_results[@compile_check] == :ok or @compile_check not in checks

    cond do
      compile_passed? and stage2_checks != [] ->
        run_stage("Stage 2", stage2_checks, project_root, runner_config)

      not compile_passed? ->
        IO.puts("\n  #{c(:red)}Compile failed — skipping Stage 2 checks#{c(:reset)}\n")
        Map.new(stage2_checks, fn check -> {check, :skipped} end)

      true ->
        %{}
    end
  end

  defp run_stage3(checks, stage1_results, stage2_results, project_root, runner_config) do
    stage3_checks = Enum.filter(@stage3_isolated, &(&1 in checks))
    compile_passed? = stage1_results[@compile_check] == :ok or @compile_check not in checks
    any_prior_fail? = Enum.any?(Map.values(stage2_results), &(&1 == :fail))

    cond do
      not compile_passed? ->
        Map.new(stage3_checks, fn check -> {check, :skipped} end)

      any_prior_fail? and stage3_checks != [] ->
        IO.puts("\n  #{c(:yellow)}Skipping Stage 3 — earlier checks failed#{c(:reset)}\n")
        Map.new(stage3_checks, fn check -> {check, :skipped} end)

      stage3_checks != [] ->
        run_stage("Stage 3 (isolated)", stage3_checks, project_root, runner_config)

      true ->
        %{}
    end
  end

  defp run_stage(label, checks, project_root, runner_config) do
    IO.puts("\n  #{c(:cyan)}#{label}#{c(:reset)} (#{length(checks)} checks in parallel)\n")

    checks
    |> Enum.map(fn check ->
      config = @check_config[check]
      task = Task.async(fn -> run_check(check, config, project_root, runner_config) end)
      {check, task}
    end)
    |> Enum.map(fn {check, task} -> {check, Task.await(task, :infinity)} end)
    |> Map.new()
  end

  defp run_check(check, config, project_root, runner_config) do
    if Map.has_key?(config, :partitions) do
      run_partitioned_check(check, config, project_root, runner_config)
    else
      run_single_check(check, config, project_root)
    end
  end

  defp run_single_check(check, config, project_root) do
    %{label: label, cmd: cmd, args: args} = config
    IO.puts("    #{c(:dim)}⟳#{c(:reset)} #{label}...")
    start = System.monotonic_time(:millisecond)

    env = worker_env(check)

    port =
      Port.open(
        {:spawn_executable, System.find_executable(cmd)},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: project_root, env: env]
      )

    {output, exit_code} = collect_port_output(port, [])
    elapsed = System.monotonic_time(:millisecond) - start

    report_result(label, exit_code, output, elapsed)
  rescue
    e ->
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{check}: #{Exception.message(e)}")
      :fail
  end

  defp worker_env(_check), do: []

  defp run_partitioned_check(check, config, project_root, runner_config) do
    %{label: label, cmd: cmd, args: args} = config
    partitions = partition_count(config.partitions, runner_config)

    IO.puts(
      "    #{c(:dim)}⟳#{c(:reset)} #{label} #{c(:dim)}(#{partitions} partition#{plural(partitions)})#{c(:reset)}..."
    )

    start = System.monotonic_time(:millisecond)

    results =
      1..partitions
      |> Enum.map(fn partition ->
        task =
          Task.async(fn ->
            run_partition(check, cmd, args, partition, partitions, project_root, runner_config)
          end)

        {partition, task}
      end)
      |> Enum.map(fn {partition, task} -> {partition, Task.await(task, :infinity)} end)

    elapsed = System.monotonic_time(:millisecond) - start
    failed = Enum.filter(results, fn {_partition, {_output, code}} -> code != 0 end)

    if failed == [] do
      IO.puts(
        "    #{c(:green)}✓#{c(:reset)} #{label} #{c(:dim)}(#{partitions} partition#{plural(partitions)}, #{fmt(elapsed)})#{c(:reset)}"
      )

      :ok
    else
      IO.puts(
        "    #{c(:red)}✗#{c(:reset)} #{label} #{c(:dim)}(#{partitions} partition#{plural(partitions)}, #{fmt(elapsed)})#{c(:reset)}"
      )

      Enum.each(failed, fn {partition, {output, _code}} ->
        print_failure_output("#{label} partition #{partition}/#{partitions}", output)
      end)

      :fail
    end
  rescue
    e ->
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{check}: #{Exception.message(e)}")
      :fail
  end

  defp run_partition(check, cmd, args, partition, partitions, project_root, runner_config) do
    env = partition_env(check, partition, runner_config)
    args = partition_args(args, partition, partitions)

    port =
      Port.open(
        {:spawn_executable, System.find_executable(cmd)},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: project_root, env: env]
      )

    collect_port_output(port, [])
  end

  defp partition_count(:test, runner_config), do: runner_config.test_partitions
  defp partition_count(:feature, runner_config), do: runner_config.feature_partitions

  defp partition_args(args, _partition, 1), do: args

  defp partition_args(args, _partition, partitions),
    do: args ++ ["--partitions", Integer.to_string(partitions)]

  defp partition_env("test", partition, _runner_config) do
    partition_env(partition, partition)
  end

  defp partition_env("test_feature", partition, runner_config) do
    partition_env(partition, runner_config.test_partitions + partition)
  end

  defp partition_env(_check, partition, _runner_config) do
    partition_env(partition, partition)
  end

  defp partition_env(partition, db_suffix) do
    [
      {~c"MIX_ENV", ~c"test"},
      {~c"MIX_TEST_PARTITION", partition |> Integer.to_string() |> String.to_charlist()},
      {~c"TEST_DB_SUFFIX", db_suffix |> Integer.to_string() |> String.to_charlist()}
    ]
  end

  defp report_result(label, 0, _output, elapsed) do
    IO.puts("    #{c(:green)}✓#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}")
    :ok
  end

  defp report_result(label, _code, output, elapsed) do
    IO.puts("    #{c(:red)}✗#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}")
    print_failure_output(label, output)
    :fail
  end

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} -> collect_port_output(port, [data | acc])
      {^port, {:exit_status, code}} -> {acc |> Enum.reverse() |> IO.iodata_to_binary(), code}
    end
  end

  defp print_failure_output(label, output) do
    lines = String.split(output, "\n")
    tail = Enum.take(lines, -40)

    IO.puts("")
    IO.puts("    #{c(:dim)}┌─ #{label} output (last #{length(tail)} lines)#{c(:reset)}")
    Enum.each(tail, fn line -> IO.puts("    #{c(:dim)}│#{c(:reset)} #{line}") end)
    IO.puts("    #{c(:dim)}└─#{c(:reset)}")
    IO.puts("")
  end

  # --- args ---

  defp parse_args(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [
          quick: :boolean,
          only: :string,
          changed: :boolean,
          base: :string,
          head: :string,
          explain_only: :boolean,
          test_partitions: :integer,
          feature_partitions: :integer
        ],
        aliases: [q: :quick]
      )

    {opts, rest}
  end

  defp runner_config(opts) do
    %{
      test_partitions: positive_int(opts[:test_partitions], "CI_TEST_PARTITIONS", 2),
      feature_partitions: positive_int(opts[:feature_partitions], "CI_FEATURE_PARTITIONS", 2)
    }
  end

  defp positive_int(nil, env_name, default) do
    env_name
    |> System.get_env()
    |> positive_int(default)
  end

  defp positive_int(value, _env_name, default), do: positive_int(value, default)

  defp positive_int(nil, default), do: default

  defp positive_int(value, default) when is_integer(value) do
    if value > 0, do: value, else: default
  end

  defp positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp resolve_checks(opts, project_root) do
    {checks, changed_plan} =
      cond do
        opts[:only] ->
          {only_checks(opts[:only]), nil}

        opts[:changed] ->
          plan = changed_plan(project_root, opts)
          {plan.checks, plan}

        true ->
          {@full_checks, nil}
      end

    checks = if opts[:quick], do: Enum.reject(checks, &(&1 == "dialyzer")), else: checks

    {checks, changed_plan}
  end

  defp only_checks(only) do
    only
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @all_checks))
  end

  defp changed_plan(project_root, opts) do
    base = opts[:base] || "origin/main"
    head = opts[:head] || "HEAD"

    case changed_files(project_root, base, head) do
      {:ok, files} -> CIImpact.plan(files)
      {:error, reason} -> CIImpact.fallback([], reason)
    end
  end

  defp changed_files(project_root, base, head) do
    with {:ok, committed} <- git_changed_files(project_root, [base <> "..." <> head]),
         {:ok, staged} <- git_changed_files(project_root, ["--cached"]),
         {:ok, unstaged} <- git_changed_files(project_root, []),
         {:ok, untracked} <- git_untracked_files(project_root) do
      {:ok, Enum.uniq(committed ++ staged ++ unstaged ++ untracked)}
    end
  end

  defp git_changed_files(project_root, diff_args) do
    args = ["diff", "--name-only", "--diff-filter=ACMRTUXB"] ++ diff_args

    case System.cmd("git", args, cd: project_root, stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)

        {:ok, files}

      {output, _code} ->
        {:error, "git #{Enum.join(args, " ")} failed: #{String.trim(output)}"}
    end
  end

  defp git_untracked_files(project_root) do
    case System.cmd("git", ["ls-files", "--others", "--exclude-standard"],
           cd: project_root,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)

        {:ok, files}

      {output, _code} ->
        {:error, "git ls-files --others --exclude-standard failed: #{String.trim(output)}"}
    end
  end

  # --- output ---

  defp header do
    IO.puts("")
    IO.puts("  #{c(:cyan)}╔═══════════════════════════════════════╗#{c(:reset)}")
    IO.puts("  #{c(:cyan)}║     RetroHexChat CI — Local Runner    ║#{c(:reset)}")
    IO.puts("  #{c(:cyan)}╚═══════════════════════════════════════╝#{c(:reset)}")
  end

  defp print_runner_config(runner_config) do
    IO.puts(
      "  #{c(:dim)}Test partitions: #{runner_config.test_partitions} | Feature partitions: #{runner_config.feature_partitions}#{c(:reset)}"
    )
  end

  defp maybe_print_changed_plan(nil), do: :ok

  defp maybe_print_changed_plan(plan) do
    IO.puts("")
    IO.puts("  #{c(:cyan)}Changed plan#{c(:reset)}")
    print_list("Changed files", plan.files)
    print_list("Surfaces", plan.surfaces)

    if plan.fallback do
      IO.puts("    Fallback: #{plan.fallback.level}")
      IO.puts("    Reason: #{plan.fallback.reason}")
    else
      IO.puts("    Fallback: none")
    end

    print_checks("Selected checks", plan.checks, plan.reasons)
    print_checks("Skipped full checks", plan.skipped, %{})
  end

  defp print_list(label, []), do: IO.puts("    #{label}: none")

  defp print_list(label, items) do
    IO.puts("    #{label}:")
    Enum.each(items, &IO.puts("      - #{&1}"))
  end

  defp print_checks(label, [], _reasons), do: IO.puts("    #{label}: none")

  defp print_checks(label, checks, reasons) do
    IO.puts("    #{label}:")

    Enum.each(checks, fn check ->
      check_label = @check_config[check].label
      reason = reasons |> Map.get(check, []) |> Enum.reverse() |> Enum.uniq() |> Enum.join("; ")
      suffix = if reason == "", do: "", else: " - #{reason}"

      IO.puts("      - #{check}: #{check_label}#{suffix}")
    end)
  end

  defp summary(results, elapsed_ms) do
    passed = Enum.count(results, fn {_, v} -> v == :ok end)
    failed = Enum.count(results, fn {_, v} -> v == :fail end)
    skipped = Enum.count(results, fn {_, v} -> v == :skipped end)
    total = map_size(results)

    IO.puts("")
    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")

    IO.puts(
      "  Results: #{passed}/#{total} passed  #{c(:dim)}(#{fmt(elapsed_ms)} total)#{c(:reset)}"
    )

    results
    |> Enum.sort_by(fn {check, _} ->
      Enum.find_index(@all_checks, &(&1 == check)) || 99
    end)
    |> Enum.each(fn {check, status} ->
      config = @check_config[check]
      IO.puts("    #{status_icon(status)} #{config.label}")
    end)

    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")

    cond do
      failed > 0 ->
        skip_msg = if skipped > 0, do: ", #{skipped} skipped", else: ""
        IO.puts("\n  #{c(:red)}#{failed} check(s) failed#{c(:reset)}#{skip_msg}\n")

      skipped > 0 ->
        IO.puts("\n  #{c(:yellow)}#{skipped} check(s) skipped#{c(:reset)}\n")

      true ->
        IO.puts("\n  #{c(:green)}All checks passed!#{c(:reset)}\n")
    end
  end

  defp status_icon(:ok), do: "#{c(:green)}✓#{c(:reset)}"
  defp status_icon(:fail), do: "#{c(:red)}✗#{c(:reset)}"
  defp status_icon(:skipped), do: "#{c(:yellow)}○#{c(:reset)}"

  defp plural(1), do: ""
  defp plural(_count), do: "s"

  defp fmt(ms) when ms < 1000, do: "#{ms}ms"

  defp fmt(ms) do
    seconds = div(ms, 1000)

    if seconds < 60 do
      "#{seconds}.#{div(rem(ms, 1000), 100)}s"
    else
      "#{div(seconds, 60)}m#{rem(seconds, 60)}s"
    end
  end

  defp c(:green), do: "\e[32m"
  defp c(:red), do: "\e[31m"
  defp c(:yellow), do: "\e[33m"
  defp c(:cyan), do: "\e[36m"
  defp c(:dim), do: "\e[2m"
  defp c(:reset), do: "\e[0m"

  defp find_project_root do
    # The script should be invoked from the project root,
    # but handle being called from anywhere
    script_dir = __DIR__
    parent = Path.dirname(script_dir)

    if File.exists?(Path.join(parent, "apps")) do
      parent
    else
      File.cwd!()
    end
  end
end

CI.main(System.argv())
