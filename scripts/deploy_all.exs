#!/usr/bin/env elixir

# RetroHexChat — CI + Deploy Pipeline
#
# Runs the full CI validation pipeline, then deploys to production (Sun).
#
# Usage:
#   elixir scripts/deploy_all.exs                  # CI + deploy Sun (REF=main)
#   elixir scripts/deploy_all.exs --ref release-tag # deploy specific ref
#   elixir scripts/deploy_all.exs --skip-ci         # skip CI (already validated)
#   elixir scripts/deploy_all.exs --rollout-timeout 600
#
# After the deploy it waits until production answers /version with the new
# release on every backend (DeployRollout), then asks Google to read the
# sitemap again when GOOGLE_SERVICE_ACCOUNT_FILE is configured on this machine.

Code.require_file("deploy_rollout.exs", __DIR__)

defmodule DeployAll do
  @ssh_port String.to_integer(System.get_env("SSH_PORT", "2222"))
  @deploy_user System.get_env("DEPLOY_USER") ||
                 raise("DEPLOY_USER env var is required")
  @targets %{
    "sun" => %{
      label: "Production",
      ip: System.get_env("SUN_IP") || raise("SUN_IP env var is required"),
      version_url: System.get_env("SUN_VERSION_URL", "https://retrohexchat.app/version")
    }
  }
  @default_rollout_timeout_s 300

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

    IO.puts("  #{c(:cyan)}Deploy#{c(:reset)} (REF=#{ref})\n")

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

    unless Enum.all?(Map.values(results), &match?({:ok, _output}, &1)) do
      System.halt(1)
    end

    # Phase 3: only a release confirmed live may be announced.
    timeout_s = opts[:rollout_timeout] || @default_rollout_timeout_s

    unless Enum.all?(results, fn {target, result} ->
             confirm_rollout(target, result, timeout_s)
           end) do
      IO.puts("\n  #{c(:red)}Rollout not confirmed — nothing announced.#{c(:reset)}\n")
      System.halt(1)
    end

    submit_sitemap(project_root)
    System.halt(0)
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
      IO.puts("    #{c(:green)}✓#{c(:reset)} CI passed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n")

      true
    else
      IO.puts("    #{c(:red)}✗#{c(:reset)} CI failed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n")

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
        IO.puts("    #{c(:green)}✓#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}")

        {:ok, ssh_output}
      else
        IO.puts("    #{c(:red)}✗#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}")

        print_failure_output(label, ssh_output)
        :fail
      end
    end
  rescue
    e ->
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{target}: #{Exception.message(e)}")
      :fail
  end

  # --- Rollout ---

  defp confirm_rollout(target, {:ok, deploy_output}, timeout_s) do
    %{label: label, version_url: url} = @targets[target]

    case DeployRollout.expected_version(deploy_output) do
      :error ->
        IO.puts("    #{c(:red)}✗#{c(:reset)} #{label}: deploy.sh printed no version to wait for")
        false

      {:ok, expected} ->
        IO.write("  #{c(:cyan)}Rollout#{c(:reset)} #{label} → #{expected} ")

        result =
          DeployRollout.wait(DeployRollout.curl_fetch(url), expected,
            timeout_ms: timeout_s * 1000,
            on_poll: &IO.write(poll_mark(&1, expected))
          )

        report_rollout(label, result)
    end
  end

  defp poll_mark({:ok, expected}, expected), do: "#{c(:green)}●#{c(:reset)}"
  defp poll_mark(_answer, _expected), do: "#{c(:dim)}·#{c(:reset)}"

  defp report_rollout(label, {:ok, %{version: version, elapsed_ms: ms}}) do
    IO.puts(
      "\n    #{c(:green)}✓#{c(:reset)} #{label} serves #{version} #{c(:dim)}(#{fmt(ms)})#{c(:reset)}\n"
    )

    true
  end

  defp report_rollout(label, {:error, %{last_seen: last_seen, elapsed_ms: ms}}) do
    IO.puts(
      "\n    #{c(:red)}✗#{c(:reset)} #{label} still serves #{last_seen || "no answer"} after #{fmt(ms)}"
    )

    false
  end

  # --- Announce ---

  # Runs here, on the machine that deploys, and only when this machine holds
  # the Google service account: the server never carries that credential. A
  # failure is a warning — the release is live either way.
  defp submit_sitemap(project_root) do
    {output, _exit} = run_cmd("python3", ["scripts/seo_sitemap_submit.py"], project_root)
    line = output |> String.trim() |> String.split("\n") |> List.last()

    icon =
      cond do
        String.starts_with?(line, "sitemap: submitted") -> "#{c(:green)}✓"
        String.starts_with?(line, "sitemap: skipped") -> "#{c(:dim)}○"
        true -> "#{c(:yellow)}⚠"
      end

    IO.puts("  #{c(:cyan)}Google#{c(:reset)}\n    #{icon}#{c(:reset)} #{line}\n")
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
        strict: [ref: :string, skip_ci: :boolean, rollout_timeout: :integer],
        aliases: [r: :ref, s: :skip_ci]
      )

    {opts, rest}
  end

  defp resolve_targets(_opts), do: ["sun"]

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
    passed = Enum.count(results, fn {_, v} -> match?({:ok, _output}, v) end)
    failed = Enum.count(results, fn {_, v} -> v == :fail end)
    total = map_size(results)

    IO.puts("")
    IO.puts("  #{c(:cyan)}───────────────────────────────────────#{c(:reset)}")
    IO.puts("  Deploy: #{passed}/#{total} succeeded #{c(:dim)}(#{fmt(elapsed_ms)})#{c(:reset)}")

    Enum.each(results, fn {target, status} ->
      config = @targets[target]
      icon = if match?({:ok, _output}, status), do: "#{c(:green)}✓", else: "#{c(:red)}✗"
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
