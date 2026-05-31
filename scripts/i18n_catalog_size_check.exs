#!/usr/bin/env elixir

defmodule I18nCatalogSizeCheck do
  @moduledoc false

  @default_max_lines 12_000

  def main(args) do
    {opts, _paths, _invalid} =
      OptionParser.parse(args,
        strict: [max_lines: :integer, fail_on_exceed: :boolean],
        aliases: [m: :max_lines, f: :fail_on_exceed]
      )

    max_lines = Keyword.get(opts, :max_lines, @default_max_lines)

    statuses =
      "apps/*/priv/gettext/*/LC_MESSAGES/*.po"
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&status/1)

    Enum.each(statuses, fn status ->
      marker = if status.lines > max_lines, do: " EXCEEDS", else: ""
      IO.puts("#{status.path}: lines=#{status.lines} max=#{max_lines}#{marker}")
    end)

    if opts[:fail_on_exceed] && Enum.any?(statuses, &(&1.lines > max_lines)) do
      System.halt(1)
    end
  end

  defp status(path) do
    %{path: path, lines: path |> File.stream!() |> Enum.count()}
  end
end

I18nCatalogSizeCheck.main(System.argv())
