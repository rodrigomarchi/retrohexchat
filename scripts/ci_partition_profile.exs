#!/usr/bin/env elixir

defmodule CIPartitionProfile do
  @moduledoc false

  @suites %{
    "test" => %{
      label: "Tests",
      args: ["test"],
      db_offset: 0
    },
    "test_feature" => %{
      label: "Feature Tests",
      args: ["test", "--only", "liveview_feature"],
      db_offset: 100
    }
  }

  def main(args) do
    opts = parse_args(args)
    project_root = find_project_root()

    header(opts)
    print_plan(opts)

    if opts.dry_run do
      System.halt(0)
    end

    started_at = timestamp()

    results =
      for run <- 1..opts.runs, suite <- opts.suites, count <- opts.counts do
        profile_suite(project_root, suite, count, run, opts.runs, started_at)
      end

    report_path = write_report(project_root, started_at, opts, results)
    print_summary(results, report_path)

    if Enum.all?(results, &(&1.status == :ok)) do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  defp parse_args(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          counts: :string,
          suites: :string,
          runs: :integer,
          dry_run: :boolean
        ]
      )

    counts = opts[:counts] |> parse_csv_ints([1, 2, 3, 4])
    suites = opts[:suites] |> parse_csv_strings(["test", "test_feature"]) |> known_suites()
    runs = positive_int(opts[:runs], 1)
    test_db_pool_size = System.get_env("CI_TEST_DB_POOL_SIZE") |> positive_int(6)

    %{
      counts: counts,
      suites: suites,
      runs: runs,
      test_db_pool_size: test_db_pool_size,
      dry_run: Keyword.get(opts, :dry_run, false)
    }
  end

  defp parse_csv_ints(nil, default), do: default

  defp parse_csv_ints(value, default) do
    ints =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&Integer.parse/1)
      |> Enum.flat_map(fn
        {int, ""} when int > 0 -> [int]
        _ -> []
      end)
      |> Enum.uniq()
      |> Enum.sort()

    if ints == [], do: default, else: ints
  end

  defp parse_csv_strings(nil, default), do: default

  defp parse_csv_strings(value, default) do
    strings =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if strings == [], do: default, else: strings
  end

  defp known_suites(suites) do
    known = Enum.filter(suites, &Map.has_key?(@suites, &1))

    if known == [] do
      ["test", "test_feature"]
    else
      known
    end
  end

  defp positive_int(nil, default), do: default
  defp positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp positive_int(_value, default), do: default

  defp profile_suite(project_root, suite, count, run, total_runs, started_at) do
    config = @suites[suite]
    IO.puts("")

    IO.puts(
      "  #{c(:cyan)}#{config.label}#{c(:reset)} run #{run}/#{total_runs} with #{count} partition#{plural(count)}"
    )

    print_partition_envs(suite, count, config, test_db_pool_size())

    started = System.monotonic_time(:millisecond)

    partition_results =
      1..count
      |> Enum.map(fn partition ->
        task =
          Task.async(fn ->
            run_partition(
              project_root,
              started_at,
              suite,
              config,
              count,
              partition,
              test_db_pool_size()
            )
          end)

        {partition, task}
      end)
      |> Enum.map(fn {partition, task} -> {partition, Task.await(task, :infinity)} end)

    elapsed = System.monotonic_time(:millisecond) - started
    failed = Enum.filter(partition_results, fn {_partition, result} -> result.exit_code != 0 end)

    max_partition_ms =
      partition_results |> Enum.map(fn {_partition, r} -> r.elapsed_ms end) |> Enum.max()

    status = if failed == [], do: :ok, else: :fail

    if status == :ok do
      IO.puts("    #{c(:green)}✓#{c(:reset)} #{config.label} #{fmt(elapsed)} wall-clock")
    else
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{config.label} #{fmt(elapsed)} wall-clock")

      Enum.each(failed, fn {partition, result} ->
        print_tail("#{config.label} partition #{partition}/#{count}", result.output)
        IO.puts("    #{c(:dim)}Full partition log: #{result.log_path}#{c(:reset)}")
      end)
    end

    %{
      suite: suite,
      label: config.label,
      count: count,
      run: run,
      status: status,
      elapsed_ms: elapsed,
      max_partition_ms: max_partition_ms,
      partitions:
        Enum.map(partition_results, fn {partition, result} ->
          Map.put(result, :partition, partition)
        end)
    }
  end

  defp run_partition(project_root, started_at, suite, config, count, partition, test_db_pool_size) do
    started = System.monotonic_time(:millisecond)
    db_suffix = db_suffix(config.db_offset, partition)
    env = partition_env(partition, db_suffix, test_db_pool_size)
    args = partition_args(config.args, count)

    port =
      Port.open(
        {:spawn_executable, System.find_executable("mix")},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: project_root, env: env]
      )

    {output, exit_code} = collect_port_output(port, [])
    elapsed = System.monotonic_time(:millisecond) - started
    log_path = write_partition_log(project_root, started_at, suite, count, partition, output)

    %{
      exit_code: exit_code,
      elapsed_ms: elapsed,
      db_suffix: db_suffix,
      log_path: log_path,
      output: output
    }
  end

  defp partition_args(args, 1), do: args
  defp partition_args(args, count), do: args ++ ["--partitions", Integer.to_string(count)]

  defp partition_env(partition, db_suffix, test_db_pool_size) do
    [
      {~c"MIX_ENV", ~c"test"},
      {~c"MIX_TEST_PARTITION", partition |> Integer.to_string() |> String.to_charlist()},
      {~c"TEST_DB_SUFFIX", db_suffix |> String.to_charlist()},
      {~c"TEST_DB_POOL_SIZE", test_db_pool_size |> Integer.to_string() |> String.to_charlist()}
    ]
  end

  defp db_suffix(offset, partition), do: Integer.to_string(offset + partition)

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} -> collect_port_output(port, [data | acc])
      {^port, {:exit_status, code}} -> {acc |> Enum.reverse() |> IO.iodata_to_binary(), code}
    end
  end

  defp write_partition_log(project_root, started_at, suite, count, partition, output) do
    log_dir = Path.join([project_root, "tmp/ci-partition-profile", started_at, "logs"])
    File.mkdir_p!(log_dir)

    path = Path.join(log_dir, "#{suite}-#{count}-partition-#{partition}.log")
    File.write!(path, output)
    Path.relative_to(path, project_root)
  end

  defp write_report(project_root, started_at, opts, results) do
    profile_dir = Path.join([project_root, "tmp/ci-partition-profile", started_at])
    File.mkdir_p!(profile_dir)

    report_path = Path.join(profile_dir, "report.md")
    File.write!(report_path, render_report(opts, results))
    Path.relative_to(report_path, project_root)
  end

  defp render_report(opts, results) do
    rows =
      results
      |> Enum.map(fn result ->
        "| #{result.suite} | #{result.count} | #{result.run} | #{result.status} | #{fmt(result.elapsed_ms)} | #{fmt(result.max_partition_ms)} |"
      end)
      |> Enum.join("\n")

    """
    # CI partition profile

    Counts: #{Enum.join(opts.counts, ", ")}
    Suites: #{Enum.join(opts.suites, ", ")}
    Runs: #{opts.runs}
    Test DB pool per partition: #{opts.test_db_pool_size}

    | Suite | Partitions | Run | Status | Wall-clock | Slowest partition |
    |---|---:|---:|---|---:|---:|
    #{rows}

    Coverage policy: partition profiling does not run coverage. Coverage remains
    available through `make test.cover` and `make test.cover.all`, which run as
    separate explicit checks because umbrella coverage consolidation across
    concurrent partition processes is not part of the fast guard.
    """
  end

  defp print_plan(opts) do
    IO.puts("  Counts: #{Enum.join(opts.counts, ", ")}")
    IO.puts("  Suites: #{Enum.join(opts.suites, ", ")}")
    IO.puts("  Runs: #{opts.runs}")
    IO.puts("  Test DB pool per partition: #{opts.test_db_pool_size}")
    IO.puts("  Dry run: #{opts.dry_run}")
  end

  defp print_partition_envs(_suite, count, config, test_db_pool_size) do
    dbs =
      1..count
      |> Enum.map(fn partition ->
        "#{partition}:TEST_DB_SUFFIX=#{db_suffix(config.db_offset, partition)},TEST_DB_POOL_SIZE=#{test_db_pool_size}"
      end)
      |> Enum.join(" ")

    IO.puts("    #{c(:dim)}#{dbs}#{c(:reset)}")
  end

  defp print_summary(results, report_path) do
    IO.puts("")
    IO.puts("  #{c(:cyan)}Partition profile summary#{c(:reset)}")

    Enum.each(results, fn result ->
      icon =
        if result.status == :ok,
          do: c(:green) <> "✓" <> c(:reset),
          else: c(:red) <> "✗" <> c(:reset)

      IO.puts(
        "    #{icon} #{result.label} #{result.count} partition#{plural(result.count)} run #{result.run}: #{fmt(result.elapsed_ms)} wall-clock, #{fmt(result.max_partition_ms)} slowest partition"
      )
    end)

    IO.puts("  #{c(:dim)}Report: #{report_path}#{c(:reset)}")
  end

  defp print_tail(label, output) do
    lines = String.split(output, "\n")
    tail = Enum.take(lines, -40)

    IO.puts("")
    IO.puts("    #{c(:dim)}┌─ #{label} output (last #{length(tail)} lines)#{c(:reset)}")
    Enum.each(tail, fn line -> IO.puts("    #{c(:dim)}│#{c(:reset)} #{line}") end)
    IO.puts("    #{c(:dim)}└─#{c(:reset)}")
    IO.puts("")
  end

  defp header(opts) do
    mode = if opts.dry_run, do: "dry run", else: "execute"

    IO.puts("")
    IO.puts("  #{c(:cyan)}╔═══════════════════════════════════════╗#{c(:reset)}")
    IO.puts("  #{c(:cyan)}║  RetroHexChat CI Partition Profiler   ║#{c(:reset)}")
    IO.puts("  #{c(:cyan)}╚═══════════════════════════════════════╝#{c(:reset)}")
    IO.puts("  #{c(:dim)}Mode: #{mode}#{c(:reset)}")
  end

  defp fmt(ms) when ms < 1000, do: "#{ms}ms"

  defp fmt(ms) do
    seconds = div(ms, 1000)

    if seconds < 60 do
      "#{seconds}.#{div(rem(ms, 1000), 100)}s"
    else
      "#{div(seconds, 60)}m#{rem(seconds, 60)}s"
    end
  end

  defp plural(1), do: ""
  defp plural(_count), do: "s"

  defp timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp test_db_pool_size do
    System.get_env("CI_TEST_DB_POOL_SIZE") |> positive_int(6)
  end

  defp c(:green), do: "\e[32m"
  defp c(:red), do: "\e[31m"
  defp c(:cyan), do: "\e[36m"
  defp c(:dim), do: "\e[2m"
  defp c(:reset), do: "\e[0m"

  defp find_project_root do
    script_dir = __DIR__
    parent = Path.dirname(script_dir)

    if File.exists?(Path.join(parent, "apps")) do
      parent
    else
      File.cwd!()
    end
  end
end

CIPartitionProfile.main(System.argv())
