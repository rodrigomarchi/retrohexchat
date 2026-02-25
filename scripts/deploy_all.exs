#!/usr/bin/env elixir

# RetroHexChat — CI + Deploy Pipeline
#
# Runs the full CI validation pipeline, then deploys to both environments
# in parallel (Sun = production, Moon = staging).
#
# Usage:
#   elixir scripts/deploy_all.exs                  # CI + deploy both (REF=main)
#   elixir scripts/deploy_all.exs --ref sun-tag     # deploy specific ref
#   elixir scripts/deploy_all.exs --skip-ci         # skip CI (already validated)
#   elixir scripts/deploy_all.exs --only sun        # deploy only to production
#   elixir scripts/deploy_all.exs --only moon       # deploy only to staging

defmodule DeployAll do
  @ssh_port String.to_integer(System.get_env("SSH_PORT", "2222"))
  @deploy_user System.get_env("DEPLOY_USER", "rodrigo")
  @targets %{
    "sun" => %{label: "Sun (production)", ip: System.get_env("SUN_IP", "YOUR_PRODUCTION_SERVER_IP")},
    "moon" => %{label: "Moon (staging)", ip: System.get_env("MOON_IP", "YOUR_STAGING_SERVER_IP")}
  }

  def main(args) do
    {opts, _rest} = parse_args(args)
    ref = opts[:ref] || "main"
    skip_ci? = opts[:skip_ci] || false
    targets = resolve_targets(opts)
    project_root = find_project_root()

    header(ref, targets)

    # Phase 1: CI validation
    ci_passed? =
      if skip_ci? do
        IO.puts("  #{c(:yellow)}⚠ CI skipped (--skip-ci)#{c(:reset)}\n")
        true
      else
        run_ci(project_root)
      end

    unless ci_passed? do
      IO.puts("\n  #{c(:red)}Deploy aborted — CI checks failed.#{c(:reset)}\n")
      System.halt(1)
    end

    # Phase 2: Deploy to targets in parallel
    start_time = System.monotonic_time(:millisecond)

    IO.puts(
      "  #{c(:cyan)}Deploy#{c(:reset)} (#{length(targets)} targets in parallel, REF=#{ref})\n"
    )

    results =
      targets
      |> Enum.map(fn target ->
        config = @targets[target]
        task = Task.async(fn -> deploy_target(target, config, ref, project_root) end)
        {target, task}
      end)
      |> Enum.map(fn {target, task} -> {target, Task.await(task, :infinity)} end)
      |> Map.new()

    elapsed = System.monotonic_time(:millisecond) - start_time
    deploy_summary(results, elapsed)

    if Enum.all?(Map.values(results), &(&1 == :ok)) do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  # --- CI ---

  defp run_ci(project_root) do
    IO.puts("  #{c(:cyan)}Phase 1: CI Validation#{c(:reset)}\n")
    IO.puts("    #{c(:dim)}⟳#{c(:reset)} Running make ci...")
    start = System.monotonic_time(:millisecond)

    port =
      Port.open(
        {:spawn_executable, System.find_executable("elixir")},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: ["scripts/ci.exs"],
          cd: project_root
        ]
      )

    {output, exit_code} = collect_port_output(port, [])
    elapsed = System.monotonic_time(:millisecond) - start

    # Print CI output (it has its own formatting)
    IO.write(output)

    if exit_code == 0 do
      IO.puts(
        "    #{c(:green)}✓#{c(:reset)} CI passed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n"
      )

      true
    else
      IO.puts(
        "    #{c(:red)}✗#{c(:reset)} CI failed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n"
      )

      false
    end
  end

  # --- Deploy ---

  defp deploy_target(target, config, ref, project_root) do
    %{label: label, ip: ip} = config
    IO.puts("    #{c(:dim)}⟳#{c(:reset)} #{label} (#{ip})...")
    start = System.monotonic_time(:millisecond)

    # Step 1: scp deploy.sh
    scp_args = [
      "-P",
      to_string(@ssh_port),
      "scripts/deploy.sh",
      "#{@deploy_user}@#{ip}:~/deploy.sh"
    ]

    {scp_output, scp_exit} = run_cmd("scp", scp_args, project_root)

    if scp_exit != 0 do
      elapsed = System.monotonic_time(:millisecond) - start

      IO.puts(
        "    #{c(:red)}✗#{c(:reset)} #{label} (scp failed) #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}"
      )

      print_failure_output(label, scp_output)
      :fail
    else
      # Step 2: ssh deploy
      ssh_args = [
        "-p",
        to_string(@ssh_port),
        "#{@deploy_user}@#{ip}",
        "bash ~/deploy.sh #{ref}"
      ]

      {ssh_output, ssh_exit} = run_cmd("ssh", ssh_args, project_root)
      elapsed = System.monotonic_time(:millisecond) - start

      if ssh_exit == 0 do
        IO.puts(
          "    #{c(:green)}✓#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}"
        )

        :ok
      else
        IO.puts(
          "    #{c(:red)}✗#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}"
        )

        print_failure_output(label, ssh_output)
        :fail
      end
    end
  rescue
    e ->
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{target}: #{Exception.message(e)}")
      :fail
  end

  defp run_cmd(cmd, args, project_root) do
    port =
      Port.open(
        {:spawn_executable, System.find_executable(cmd)},
        [:binary, :exit_status, :stderr_to_stdout, args: args, cd: project_root]
      )

    collect_port_output(port, [])
  end

  # --- Port helpers ---

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} -> collect_port_output(port, [data | acc])
      {^port, {:exit_status, code}} -> {acc |> Enum.reverse() |> IO.iodata_to_binary(), code}
    end
  end

  defp print_failure_output(label, output) do
    lines = String.split(output, "\n")
    tail = Enum.take(lines, -30)

    IO.puts("")
    IO.puts("    #{c(:dim)}┌─ #{label} output (last #{length(tail)} lines)#{c(:reset)}")
    Enum.each(tail, fn line -> IO.puts("    #{c(:dim)}│#{c(:reset)} #{line}") end)
    IO.puts("    #{c(:dim)}└─#{c(:reset)}")
    IO.puts("")
  end

  # --- Args ---

  defp parse_args(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [ref: :string, skip_ci: :boolean, only: :string],
        aliases: [r: :ref, s: :skip_ci]
      )

    {opts, rest}
  end

  defp resolve_targets(opts) do
    case opts[:only] do
      nil -> ["sun", "moon"]
      target when target in ["sun", "moon"] -> [target]
      _ -> ["sun", "moon"]
    end
  end

  # --- Output ---

  defp header(ref, targets) do
    target_list = Enum.map_join(targets, " + ", fn t -> @targets[t].label end)

    IO.puts("")
    IO.puts("  #{c(:cyan)}╔═══════════════════════════════════════╗#{c(:reset)}")
    IO.puts("  #{c(:cyan)}║   RetroHexChat — CI + Deploy Pipeline ║#{c(:reset)}")
    IO.puts("  #{c(:cyan)}╚═══════════════════════════════════════╝#{c(:reset)}")
    IO.puts("")
    IO.puts("  REF:     #{ref}")
    IO.puts("  Targets: #{target_list}")
    IO.puts("")
  end

  defp deploy_summary(results, elapsed_ms) do
    passed = Enum.count(results, fn {_, v} -> v == :ok end)
    failed = Enum.count(results, fn {_, v} -> v == :fail end)
    total = map_size(results)

    IO.puts("")
    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")
    IO.puts("  Deploy: #{passed}/#{total} succeeded #{c(:dim)}(#{fmt(elapsed_ms)})#{c(:reset)}")

    Enum.each(results, fn {target, status} ->
      config = @targets[target]
      icon = if status == :ok, do: "#{c(:green)}✓", else: "#{c(:red)}✗"
      IO.puts("    #{icon}#{c(:reset)} #{config.label}")
    end)

    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")

    if failed > 0 do
      IO.puts("\n  #{c(:red)}#{failed} deploy(s) failed#{c(:reset)}\n")
    else
      IO.puts("\n  #{c(:green)}All deploys succeeded!#{c(:reset)}\n")
    end
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

  defp c(:green), do: "\e[32m"
  defp c(:red), do: "\e[31m"
  defp c(:yellow), do: "\e[33m"
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

DeployAll.main(System.argv())
