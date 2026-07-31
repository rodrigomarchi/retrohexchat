#!/usr/bin/env elixir

defmodule UmbrellaBoundaryAudit do
  @moduledoc false

  @default_commits 80
  @candidate_prefixes %{
    "accounts" => ["/accounts/"],
    "arcade" => ["/arcade/"],
    "bots" => ["/bots/", "/bot_"],
    "calls" => ["/group_call/", "/p2p/", "/calls/", "/call_"],
    "chat" => ["/chat/"],
    "commands" => ["/commands/"],
    "lobby" => ["/lobby/"],
    "presence" => ["/presence/"],
    "services" => ["/services/"]
  }

  def main(args) do
    opts = parse_args(args)
    project_root = find_project_root()

    with {:ok, commits} <- git_commits(project_root, opts.commits) do
      report = build_report(commits, opts, xref_stats(project_root))
      path = write_report(project_root, report)

      IO.puts("Umbrella boundary audit")
      IO.puts("Commits analyzed: #{length(commits)}")
      IO.puts("Report: #{path}")
    else
      {:error, reason} ->
        IO.puts(:stderr, "Umbrella boundary audit failed: #{reason}")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          commits: :integer
        ]
      )

    %{commits: positive_int(opts[:commits], @default_commits)}
  end

  defp positive_int(value, _default) when is_integer(value) and value > 0, do: value
  defp positive_int(_value, default), do: default

  defp git_commits(project_root, count) do
    case System.cmd(
           "git",
           ["log", "--name-only", "--pretty=format:--COMMIT--", "-n", to_string(count)],
           cd: project_root,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        commits =
          output
          |> String.split("--COMMIT--", trim: true)
          |> Enum.map(&changed_files/1)
          |> Enum.reject(&(&1 == []))

        {:ok, commits}

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  defp changed_files(chunk) do
    chunk
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp xref_stats(project_root) do
    case System.cmd("mix", ["xref", "graph", "--format", "stats"],
           cd: project_root,
           stderr_to_stdout: true
         ) do
      {output, 0} -> String.trim(output)
      {output, _code} -> "xref stats unavailable: #{String.trim(output)}"
    end
  end

  defp build_report(commits, opts, xref_stats) do
    commit_surfaces = Enum.map(commits, &surfaces_for_commit/1)
    candidate_counts = count_candidates(commit_surfaces)
    pair_counts = count_pairs(commit_surfaces)
    cross_app = Enum.count(commit_surfaces, &cross_app?/1)
    global = Enum.count(commit_surfaces, &("global" in &1))

    """
    # Umbrella boundary audit

    Commits analyzed: #{length(commits)}
    Requested commits: #{opts.commits}

    ## Summary

    - Cross-app commits: #{cross_app}
    - Global/config/CI commits: #{global}

    ## Xref Stats

    ```text
    #{xref_stats}
    ```

    ## Candidate Frequency

    #{candidate_table(candidate_counts)}

    ## Top Co-change Pairs

    #{pair_table(pair_counts)}

    ## Decision Rule

    Do not extract a new umbrella app from this report alone. A candidate needs
    repeated high frequency, low cross-app co-change, a clear public API, no
    prohibited xref cycle, isolated tests, and an explicit CI gain estimate.
    """
  end

  defp surfaces_for_commit(files) do
    files
    |> Enum.flat_map(&surfaces_for_file/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp surfaces_for_file(file) do
    base_surfaces =
      cond do
        String.starts_with?(file, ".github/") or
          file in ["Makefile", "mix.exs", "mix.lock", ".formatter.exs", ".credo.exs"] or
            String.starts_with?(file, "config/") ->
          ["global"]

        String.starts_with?(file, "docs/") or String.ends_with?(file, ".md") ->
          ["docs"]

        String.starts_with?(file, "e2e/") ->
          ["e2e"]

        String.starts_with?(file, "scripts/i18n") or String.contains?(file, "/priv/gettext/") ->
          ["i18n"]

        String.starts_with?(file, "apps/retro_hex_chat_web/assets/css/") ->
          ["assets_css", "web"]

        String.starts_with?(file, "apps/retro_hex_chat_web/assets/js/") or
            String.starts_with?(file, "apps/retro_hex_chat_web/assets/test/") ->
          ["assets_js", "web"]

        String.starts_with?(file, "apps/retro_hex_chat_web/") ->
          ["web"]

        String.starts_with?(file, "apps/retro_hex_chat/") ->
          ["domain"]

        true ->
          ["unknown"]
      end

    candidate_surfaces =
      @candidate_prefixes
      |> Enum.flat_map(fn {candidate, patterns} ->
        if Enum.any?(patterns, &String.contains?(file, &1)),
          do: ["candidate:#{candidate}"],
          else: []
      end)

    Enum.uniq(base_surfaces ++ candidate_surfaces)
  end

  defp count_candidates(commit_surfaces) do
    commit_surfaces
    |> Enum.flat_map(fn surfaces ->
      Enum.filter(surfaces, &String.starts_with?(&1, "candidate:"))
    end)
    |> frequencies()
  end

  defp count_pairs(commit_surfaces) do
    commit_surfaces
    |> Enum.flat_map(&pairs/1)
    |> frequencies()
  end

  defp frequencies(items) do
    items
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_item, count} -> count end, :desc)
  end

  defp pairs(surfaces) do
    for left <- surfaces,
        right <- surfaces,
        left < right,
        do: "#{left} + #{right}"
  end

  defp cross_app?(surfaces), do: "domain" in surfaces and "web" in surfaces

  defp candidate_table([]), do: "_No candidate surfaces found._"

  defp candidate_table(rows) do
    rows
    |> Enum.map_join("\n", fn {candidate, count} ->
      "| `#{String.replace_prefix(candidate, "candidate:", "")}` | #{count} |"
    end)
    |> then(fn body ->
      """
      | Candidate | Commits |
      |---|---:|
      #{body}
      """
    end)
  end

  defp pair_table([]), do: "_No co-change pairs found._"

  defp pair_table(rows) do
    rows
    |> Enum.take(20)
    |> Enum.map_join("\n", fn {pair, count} -> "| `#{pair}` | #{count} |" end)
    |> then(fn body ->
      """
      | Pair | Commits |
      |---|---:|
      #{body}
      """
    end)
  end

  defp write_report(project_root, report) do
    timestamp =
      DateTime.utc_now()
      |> Calendar.strftime("%Y%m%dT%H%M%SZ")

    dir = Path.join([project_root, "tmp", "umbrella-boundary-audit", timestamp])
    File.mkdir_p!(dir)

    path = Path.join(dir, "report.md")
    File.write!(path, report)
    Path.relative_to(path, project_root)
  end

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

UmbrellaBoundaryAudit.main(System.argv())
