#!/usr/bin/env elixir

# RetroHexChat — CI + Deploy Pipeline
#
# Runs the full CI validation pipeline, builds one Linux release artifact on
# Moon (staging), then promotes that artifact to Sun (production).
#
# Usage:
#   elixir scripts/deploy_all.exs                  # CI + deploy both (REF=main)
#   elixir scripts/deploy_all.exs --ref sun-tag     # deploy specific ref
#   elixir scripts/deploy_all.exs --skip-ci         # skip CI (already validated)
#   elixir scripts/deploy_all.exs --only sun        # deploy only to production
#   elixir scripts/deploy_all.exs --only moon       # deploy only to staging

defmodule DeployAll do
  @ssh_port String.to_integer(System.get_env("SSH_PORT", "2222"))
  @app_name "retro_hex_chat"
  @deploy_user System.get_env("DEPLOY_USER") ||
                 raise("DEPLOY_USER env var is required")
  @targets %{
    "sun" => %{
      label: "Production",
      ip: System.get_env("SUN_IP") || raise("SUN_IP env var is required")
    },
    "moon" => %{
      label: "Staging",
      ip: System.get_env("MOON_IP") || raise("MOON_IP env var is required")
    }
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

    start_time = System.monotonic_time(:millisecond)
    results = deploy_targets(targets, ref, project_root)
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
      IO.puts("    #{c(:green)}✓#{c(:reset)} CI passed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n")

      true
    else
      IO.puts("    #{c(:red)}✗#{c(:reset)} CI failed #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}\n")

      false
    end
  end

  # --- Deploy ---

  defp deploy_targets(targets, ref, project_root) do
    if "sun" in targets do
      deploy_with_staging_artifact(targets, ref, project_root)
    else
      deploy_targets_in_parallel(targets, ref, project_root)
    end
  end

  defp deploy_targets_in_parallel(targets, ref, project_root) do
    IO.puts(
      "  #{c(:cyan)}Deploy#{c(:reset)} (#{length(targets)} targets in parallel, REF=#{ref})\n"
    )

    targets
    |> Enum.map(fn target ->
      config = @targets[target]
      task = Task.async(fn -> deploy_target(target, config, ref, project_root) end)
      {target, task}
    end)
    |> Enum.map(fn {target, task} -> {target, Task.await(task, :infinity)} end)
    |> Map.new()
  end

  defp deploy_with_staging_artifact(targets, ref, project_root) do
    IO.puts(
      "  #{c(:cyan)}Deploy#{c(:reset)} (build once on Staging, promote artifact, REF=#{ref})\n"
    )

    moon_status = deploy_target("moon", @targets["moon"], ref, project_root)

    results =
      if "moon" in targets do
        %{"moon" => moon_status}
      else
        %{}
      end

    sun_status =
      if moon_status == :ok do
        promote_artifact_to_target(@targets["sun"], @targets["moon"], project_root)
      else
        IO.puts("    #{c(:red)}✗#{c(:reset)} Production skipped because Staging build failed")
        :fail
      end

    Map.put(results, "sun", sun_status)
  end

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

        :ok
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

  defp promote_artifact_to_target(target_config, builder_config, project_root) do
    %{label: label, ip: ip} = target_config
    %{label: builder_label} = builder_config
    IO.puts("    #{c(:dim)}⟳#{c(:reset)} #{label} (#{ip}) from #{builder_label} artifact...")
    start = System.monotonic_time(:millisecond)

    with {:ok, current_json} <- fetch_builder_current_json(builder_config, project_root),
         {:ok, version} <- current_json_version(current_json),
         {:ok, paths} <-
           fetch_builder_artifact(builder_config, version, current_json, project_root),
         :ok <- install_artifact(target_config, paths, version, project_root) do
      elapsed = System.monotonic_time(:millisecond) - start

      IO.puts("    #{c(:green)}✓#{c(:reset)} #{label} #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}")

      cleanup_artifact_tmp(paths)
      :ok
    else
      {:error, step, output} ->
        elapsed = System.monotonic_time(:millisecond) - start

        IO.puts(
          "    #{c(:red)}✗#{c(:reset)} #{label} (#{step}) #{c(:dim)}(#{fmt(elapsed)})#{c(:reset)}"
        )

        print_failure_output(label, output)
        :fail
    end
  rescue
    e ->
      fallback_label = Map.get(target_config, :label, "target")
      IO.puts("    #{c(:red)}✗#{c(:reset)} #{fallback_label}: #{Exception.message(e)}")
      :fail
  end

  defp fetch_builder_current_json(builder_config, project_root) do
    remote_current_json = "~/releases/versions/#{@app_name}/local/current.json"

    {output, exit_code} =
      run_cmd(
        "ssh",
        [
          "-p",
          to_string(@ssh_port),
          remote(builder_config),
          "cat #{remote_current_json}"
        ],
        project_root
      )

    if exit_code == 0 do
      {:ok, output}
    else
      {:error, "fetch current.json", output}
    end
  end

  defp current_json_version(current_json) do
    case Regex.run(~r/"version"\s*:\s*"([^"]+)"/, current_json) do
      [_, version] -> {:ok, version}
      _ -> {:error, "parse current.json", current_json}
    end
  end

  defp fetch_builder_artifact(builder_config, version, current_json, project_root) do
    tmp_dir =
      Path.join(System.tmp_dir!(), "retro_hex_chat_deploy_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    tarball = "#{@app_name}-#{version}.tar.gz"
    local_tarball = Path.join(tmp_dir, tarball)
    local_current_json = Path.join(tmp_dir, "current.json")
    File.write!(local_current_json, current_json)

    remote_tarball = "#{remote(builder_config)}:~/releases/dist/#{@app_name}/#{tarball}"

    {output, exit_code} =
      run_cmd("scp", ["-P", to_string(@ssh_port), remote_tarball, local_tarball], project_root)

    if exit_code == 0 do
      {:ok,
       %{
         tmp_dir: tmp_dir,
         tarball: local_tarball,
         current_json: local_current_json,
         tarball_name: tarball
       }}
    else
      File.rm_rf(tmp_dir)
      {:error, "fetch artifact", output}
    end
  end

  defp install_artifact(target_config, paths, version, project_root) do
    remote_dist_dir = "~/releases/dist/#{@app_name}"
    remote_versions_dir = "~/releases/versions/#{@app_name}/local"
    remote_tarball = "#{remote_dist_dir}/#{paths.tarball_name}"
    remote_current_json = "#{remote_versions_dir}/current.json"

    with :ok <-
           run_install_step(
             target_config,
             "mkdir",
             "mkdir -p #{remote_dist_dir} #{remote_versions_dir}",
             project_root
           ),
         :ok <- scp_to_target(target_config, paths.tarball, remote_tarball, project_root),
         :ok <-
           scp_to_target(target_config, paths.current_json, remote_current_json, project_root),
         :ok <-
           run_install_step(
             target_config,
             "chmod dirs",
             "chmod o+rx #{remote_dist_dir} #{remote_versions_dir}",
             project_root
           ),
         :ok <-
           run_install_step(
             target_config,
             "chmod files",
             "chmod o+r #{remote_tarball} #{remote_current_json}",
             project_root
           ) do
      IO.puts("      #{c(:dim)}Artifact version promoted: #{version}#{c(:reset)}")
      :ok
    end
  end

  defp run_install_step(target_config, step, command, project_root) do
    {output, exit_code} =
      run_cmd(
        "ssh",
        [
          "-p",
          to_string(@ssh_port),
          remote(target_config),
          command
        ],
        project_root
      )

    if exit_code == 0, do: :ok, else: {:error, step, output}
  end

  defp scp_to_target(target_config, local_path, remote_path, project_root) do
    {output, exit_code} =
      run_cmd(
        "scp",
        [
          "-P",
          to_string(@ssh_port),
          local_path,
          "#{remote(target_config)}:#{remote_path}"
        ],
        project_root
      )

    if exit_code == 0, do: :ok, else: {:error, "copy artifact", output}
  end

  defp cleanup_artifact_tmp(%{tmp_dir: tmp_dir}), do: File.rm_rf(tmp_dir)

  defp remote(%{ip: ip}), do: "#{@deploy_user}@#{ip}"

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
