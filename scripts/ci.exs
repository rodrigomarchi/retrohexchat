#!/usr/bin/env elixir

# RetroHexChat CI — Local Runner
#
# Runs all CI checks locally with maximum parallelism.
# No compilation needed — this is a standalone .exs script.
#
# Pipeline:
#   Stage 1 (parallel): compile + JS lint + JS tests (independent)
#   Stage 2 (parallel, after compile): format + credo + CSS lint + tests + E2E tests + dialyzer
#
# Tests are split into two parallel workers (tests + E2E) to reduce wall-clock time.
# Ecto SQL Sandbox ensures each process gets isolated DB transactions.
#
# Usage:
#   elixir scripts/ci.exs              # run all 9 checks
#   elixir scripts/ci.exs --quick      # skip dialyzer
#   elixir scripts/ci.exs --only compile,credo

defmodule CI do
  @compile_check "compile"
  @stage1_independent ["lint_js", "js_tests"]
  @stage2_after_compile ["format", "credo", "lint_css", "test", "test_e2e", "dialyzer"]

  @all_checks [@compile_check | @stage1_independent] ++ @stage2_after_compile

  @check_config %{
    "compile" => %{label: "Compile", cmd: "mix", args: ["compile", "--warnings-as-errors"]},
    "lint_js" => %{label: "JS Lint", cmd: "make", args: ["lint.js"]},
    "lint_css" => %{label: "CSS Lint", cmd: "make", args: ["lint.css"]},
    "js_tests" => %{
      label: "JS Tests",
      cmd: "npm",
      args: ["test", "--prefix", "apps/retro_hex_chat_web/assets"]
    },
    "format" => %{label: "Format", cmd: "mix", args: ["format", "--check-formatted"]},
    "credo" => %{label: "Credo", cmd: "mix", args: ["credo", "--strict"]},
    "test" => %{label: "Tests", cmd: "mix", args: ["test"]},
    "test_e2e" => %{label: "E2E Tests", cmd: "mix", args: ["test", "--only", "e2e"]},
    "dialyzer" => %{label: "Dialyzer", cmd: "mix", args: ["dialyzer"]}
  }

  def main(args) do
    {opts, _rest} = parse_args(args)
    checks = resolve_checks(opts)
    project_root = find_project_root()
    start_time = System.monotonic_time(:millisecond)

    header()

    stage1_results = run_stage1(checks, project_root)
    stage2_results = run_stage2(checks, stage1_results, project_root)

    all_results = Map.merge(stage1_results, stage2_results)
    elapsed = System.monotonic_time(:millisecond) - start_time

    summary(all_results, elapsed)

    if Enum.all?(Map.values(all_results), &(&1 == :ok)) do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  # --- stages ---

  defp run_stage1(checks, project_root) do
    stage1_compile = if @compile_check in checks, do: [@compile_check], else: []
    stage1_parallel = Enum.filter(@stage1_independent, &(&1 in checks))
    run_stage("Stage 1", stage1_compile ++ stage1_parallel, project_root)
  end

  defp run_stage2(checks, stage1_results, project_root) do
    stage2_checks = Enum.filter(@stage2_after_compile, &(&1 in checks))
    compile_passed? = stage1_results[@compile_check] == :ok or @compile_check not in checks

    cond do
      compile_passed? and stage2_checks != [] ->
        run_stage("Stage 2", stage2_checks, project_root)

      not compile_passed? ->
        IO.puts("\n  #{c(:red)}Compile failed — skipping Stage 2 checks#{c(:reset)}\n")
        Map.new(stage2_checks, fn check -> {check, :skipped} end)

      true ->
        %{}
    end
  end

  defp run_stage(label, checks, project_root) do
    IO.puts("\n  #{c(:cyan)}#{label}#{c(:reset)} (#{length(checks)} checks in parallel)\n")

    checks
    |> Enum.map(fn check ->
      config = @check_config[check]
      task = Task.async(fn -> run_check(check, config, project_root) end)
      {check, task}
    end)
    |> Enum.map(fn {check, task} -> {check, Task.await(task, :infinity)} end)
    |> Map.new()
  end

  defp run_check(check, config, project_root) do
    %{label: label, cmd: cmd, args: args} = config
    IO.puts("    #{c(:dim)}⟳#{c(:reset)} #{label}...")
    start = System.monotonic_time(:millisecond)

    env = if check in ["test", "test_e2e"], do: [{~c"MIX_ENV", ~c"test"}], else: []

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
        strict: [quick: :boolean, only: :string],
        aliases: [q: :quick]
      )

    {opts, rest}
  end

  defp resolve_checks(opts) do
    base =
      if opts[:only] do
        opts[:only]
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 in @all_checks))
      else
        @all_checks
      end

    if opts[:quick], do: Enum.reject(base, &(&1 == "dialyzer")), else: base
  end

  # --- output ---

  defp header do
    IO.puts("")
    IO.puts("  #{c(:cyan)}╔═══════════════════════════════════════╗#{c(:reset)}")
    IO.puts("  #{c(:cyan)}║     RetroHexChat CI — Local Runner    ║#{c(:reset)}")
    IO.puts("  #{c(:cyan)}╚═══════════════════════════════════════╝#{c(:reset)}")
  end

  defp summary(results, elapsed_ms) do
    passed = Enum.count(results, fn {_, v} -> v == :ok end)
    failed = Enum.count(results, fn {_, v} -> v == :fail end)
    skipped = Enum.count(results, fn {_, v} -> v == :skipped end)
    total = map_size(results)

    IO.puts("")
    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")
    IO.puts("  Results: #{passed}/#{total} passed  #{c(:dim)}(#{fmt(elapsed_ms)} total)#{c(:reset)}")

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
