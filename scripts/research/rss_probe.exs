# Fetches every candidate feed with the production fetcher and decodes it with
# the production parser, so a feed only reaches a provisioning script after the
# app itself has proven it can read it.
#
#     mix run scripts/research/rss_probe.exs candidates.txt
#
# One URL per line; blank lines and `#` comments are skipped. A line may carry a
# label after a tab or two spaces, which is echoed back untouched.

alias RetroHexChat.Bots.Capabilities.RSS.FeedParser
alias RetroHexChat.Bots.Capabilities.RSS.Fetcher

[path | _] = System.argv()

urls =
  path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Enum.map(fn line ->
    case String.split(line, ~r/\s{2,}|\t/, parts: 2) do
      [url, label] -> {url, label}
      [url] -> {url, ""}
    end
  end)
  |> Enum.uniq_by(&elem(&1, 0))

probe = fn {url, label} ->
  result =
    case Fetcher.impl().fetch(url, nil, nil) do
      {:ok, body, _headers} ->
        case FeedParser.parse(body) do
          {:ok, %{items: []}} -> {:empty, "parsed, zero items"}
          {:ok, %{title: title, items: items}} -> {:ok, "#{length(items)} items · #{title}"}
          {:error, reason} -> {:unparsable, inspect(reason)}
        end

      {:not_modified} ->
        {:unparsable, "304 on a first fetch"}

      {:error, reason} ->
        {:unreachable, inspect(reason)}
    end

  {url, label, result}
end

results =
  urls
  |> Task.async_stream(probe, max_concurrency: 12, timeout: 60_000, on_timeout: :kill_task)
  |> Enum.map(fn
    {:ok, row} -> row
    {:exit, :timeout} -> {"(timeout)", "", {:unreachable, "task timeout"}}
  end)

Enum.each(results, fn {url, label, {verdict, detail}} ->
  mark =
    case verdict do
      :ok -> "OK  "
      :empty -> "EMPTY"
      :unparsable -> "PARSE"
      :unreachable -> "DEAD"
    end

  IO.puts("#{mark}\t#{url}\t#{label}\t#{detail}")
end)

tally = Enum.frequencies_by(results, fn {_u, _l, {verdict, _d}} -> verdict end)
IO.puts("\n-- #{inspect(tally)} of #{length(results)}")
