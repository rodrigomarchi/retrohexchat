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
#   elixir scripts/ci.exs              # run all checks
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
    "ci_partition_profile_plan",
    "py_tests",
    "i18n_quality",
    "lint_hooks",
    "lint_bundle",
    "e2e_catalog"
  ]
  @stage2_after_compile [
    "format",
    "credo",
    "lint_css",
    "i18n_coverage",
    "test",
    "test_feature",
    "test_domain",
    "test_web"
  ]
  @stage3_browser [
    "e2e_changed",
    "e2e_smoke_connect",
    "e2e_smoke_chat",
    "e2e_smoke_dialogs",
    "e2e_smoke_i18n",
    "e2e_smoke_calls",
    "e2e_smoke_mobile",
    "e2e"
  ]
  @stage4_isolated ["dialyzer"]

  @full_checks CIImpact.full_checks()
  @all_checks Enum.uniq(
                @full_checks ++
                  @stage1_independent ++
                  @stage2_after_compile ++ @stage3_browser ++ @stage4_isolated
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
    "ci_partition_profile_plan" => %{
      label: "CI Partition Profile Plan",
      cmd: "elixir",
      args: ["scripts/ci_partition_profile.exs", "--counts", "2", "--suites", "test", "--dry-run"]
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
    "i18n_coverage" => %{
      label: "i18n Catalog Coverage",
      cmd: "make",
      args: ["i18n.gettext.check"]
    },
    "lint_hooks" => %{label: "LiveView Hook Contract", cmd: "make", args: ["lint.hooks"]},
    "e2e_catalog" => %{label: "E2E Catalog Sync", cmd: "make", args: ["e2e.catalog.check"]},
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
    "e2e_smoke_connect" => %{
      label: "E2E Smoke: Connect",
      cmd: "make",
      args: ["e2e.smoke.connect"]
    },
    "e2e_smoke_chat" => %{
      label: "E2E Smoke: Chat Shell",
      cmd: "make",
      args: ["e2e.smoke.chat"]
    },
    "e2e_smoke_dialogs" => %{
      label: "E2E Smoke: Dialogs",
      cmd: "make",
      args: ["e2e.smoke.dialogs"]
    },
    "e2e_smoke_i18n" => %{
      label: "E2E Smoke: i18n",
      cmd: "make",
      args: ["e2e.smoke.i18n"]
    },
    "e2e_smoke_calls" => %{
      label: "E2E Smoke: Calls",
      cmd: "make",
      args: ["e2e.smoke.calls"]
    },
    "e2e_smoke_mobile" => %{
      label: "E2E Smoke: Mobile",
      cmd: "make",
      args: ["e2e.smoke.mobile"]
    },
    "e2e" => %{label: "Full E2E Tests", cmd: "make", args: ["e2e.headless"]},
    "dialyzer" => %{label: "Dialyzer", cmd: "mix", args: ["dialyzer"]}
  }

  def main(args) do
    {opts, _rest} = parse_args(args)
    project_root = find_project_root()
    {checks, changed_plan} = resolve_checks(opts, project_root)

    runner_config =
      opts |> runner_config() |> Map.put(:precompiled_tests?, @compile_check in checks)

    start_time = System.monotonic_time(:millisecond)

    header()
    print_runner_config(runner_config)
    maybe_print_changed_plan(changed_plan)

    if opts[:explain_only] do
      System.halt(0)
    end

    stage1_results = run_stage1(checks, project_root, runner_config)
    stage2_results = run_stage2(checks, stage1_results, project_root, runner_config)
    stage3_results = run_stage3_browser(checks, stage1_results, stage2_results, project_root)

    stage4_results =
      run_stage4_isolated(
        checks,
        stage1_results,
        stage2_results,
        stage3_results,
        project_root,
        runner_config
      )

    all_results =
      stage1_results
      |> Map.merge(stage2_results)
      |> Map.merge(stage3_results)
      |> Map.merge(stage4_results)

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

  defp run_stage3_browser(checks, stage1_results, stage2_results, project_root) do
    stage3_checks = Enum.filter(@stage3_browser, &(&1 in checks))
    compile_passed? = stage1_results[@compile_check] == :ok or @compile_check not in checks
    any_prior_fail? = Enum.any?(Map.values(stage2_results), &(&1 == :fail))

    cond do
      not compile_passed? ->
        Map.new(stage3_checks, fn check -> {check, :skipped} end)

      any_prior_fail? and stage3_checks != [] ->
        IO.puts("\n  #{c(:yellow)}Skipping browser smokes — earlier checks failed#{c(:reset)}\n")

        Map.new(stage3_checks, fn check -> {check, :skipped} end)

      stage3_checks != [] ->
        run_serial_stage("Browser smokes", stage3_checks, project_root)

      true ->
        %{}
    end
  end

  defp run_stage4_isolated(
         checks,
         stage1_results,
         stage2_results,
         stage3_results,
         project_root,
         runner_config
       ) do
    stage4_checks = Enum.filter(@stage4_isolated, &(&1 in checks))
    compile_passed? = stage1_results[@compile_check] == :ok or @compile_check not in checks

    any_prior_fail? =
      [stage2_results, stage3_results]
      |> Enum.flat_map(&Map.values/1)
      |> Enum.any?(&(&1 == :fail))

    cond do
      not compile_passed? ->
        Map.new(stage4_checks, fn check -> {check, :skipped} end)

      any_prior_fail? and stage4_checks != [] ->
        IO.puts("\n  #{c(:yellow)}Skipping isolated checks — earlier checks failed#{c(:reset)}\n")
        Map.new(stage4_checks, fn check -> {check, :skipped} end)

      stage4_checks != [] ->
        run_stage("Stage 3 (isolated)", stage4_checks, project_root, runner_config)

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

  defp run_serial_stage(label, checks, project_root) do
    IO.puts("\n  #{c(:cyan)}#{label}#{c(:reset)} (#{length(checks)} checks in sequence)\n")

    checks
    |> Enum.map(fn check ->
      config = @check_config[check]
      {check, run_single_check(check, config, project_root)}
    end)
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
        log_path = write_partition_failure_log(project_root, check, partition, partitions, output)
        print_failure_output("#{label} partition #{partition}/#{partitions}", output)
        IO.puts("    #{c(:dim)}Full partition log: #{log_path}#{c(:reset)}")
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

    args =
      args
      |> partition_args(partition, partitions)
      |> maybe_add_no_compile(check, runner_config)

    port =
      Port.open(
        {:spawn_executable, System.find_executable(cmd)},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: project_root, env: env]
      )

    collect_port_output(port, [])
  end

  defp write_partition_failure_log(project_root, check, partition, partitions, output) do
    log_dir = Path.join(project_root, "tmp/ci-logs")
    File.mkdir_p!(log_dir)

    path = Path.join(log_dir, "#{check}-partition-#{partition}-of-#{partitions}.log")
    File.write!(path, output)
    Path.relative_to(path, project_root)
  end

  defp partition_count(:test, runner_config), do: runner_config.test_partitions
  defp partition_count(:feature, runner_config), do: runner_config.feature_partitions

  defp partition_args(args, _partition, 1), do: args

  defp partition_args(args, _partition, partitions),
    do: args ++ ["--partitions", Integer.to_string(partitions)]

  defp maybe_add_no_compile(args, check, %{precompiled_tests?: true})
       when check in ["test", "test_feature"] do
    if "--no-compile" in args do
      args
    else
      args ++ ["--no-compile"]
    end
  end

  defp maybe_add_no_compile(args, _check, _runner_config), do: args

  defp partition_env("test", partition, runner_config) do
    partition_worker_env(partition, partition, runner_config)
  end

  defp partition_env("test_feature", partition, runner_config) do
    partition_worker_env(partition, runner_config.test_partitions + partition, runner_config)
  end

  defp partition_env(_check, partition, runner_config) do
    partition_worker_env(partition, partition, runner_config)
  end

  defp partition_worker_env(partition, db_suffix, runner_config) do
    [
      {~c"MIX_ENV", ~c"test"},
      {~c"MIX_TEST_PARTITION", partition |> Integer.to_string() |> String.to_charlist()},
      {~c"TEST_DB_SUFFIX", db_suffix |> Integer.to_string() |> String.to_charlist()},
      {~c"TEST_DB_POOL_SIZE",
       runner_config.test_db_pool_size |> Integer.to_string() |> String.to_charlist()}
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
      test_partitions: positive_int(opts[:test_partitions], "CI_TEST_PARTITIONS", 3),
      feature_partitions: positive_int(opts[:feature_partitions], "CI_FEATURE_PARTITIONS", 4),
      test_db_pool_size: positive_int(nil, "CI_TEST_DB_POOL_SIZE", 6)
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
    checks = maybe_add_compile_for_partitioned_checks(checks)

    {checks, changed_plan}
  end

  defp maybe_add_compile_for_partitioned_checks(checks) do
    if Enum.any?(checks, &(&1 in ["test", "test_feature"])) and @compile_check not in checks do
      [@compile_check | checks]
      |> Enum.uniq()
      |> Enum.sort_by(&(Enum.find_index(@all_checks, fn check -> check == &1 end) || 999))
    else
      checks
    end
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

    IO.puts(
      "  #{c(:dim)}Test DB suffixes: test=#{suffix_range(1, runner_config.test_partitions)} | feature=#{suffix_range(runner_config.test_partitions + 1, runner_config.test_partitions + runner_config.feature_partitions)}#{c(:reset)}"
    )

    IO.puts(
      "  #{c(:dim)}Test DB pool per partition: #{runner_config.test_db_pool_size}#{c(:reset)}"
    )
  end

  defp suffix_range(first, first), do: Integer.to_string(first)
  defp suffix_range(first, last), do: "#{first}..#{last}"

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
