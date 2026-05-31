#!/usr/bin/env elixir

defmodule I18nWrapHeexAttrs do
  @moduledoc false

  @extensions [".heex", ".ex"]
  @attrs ~w(aria-label aria-description aria-valuetext title alt placeholder label legend text confirm data-confirm data-title data-label)
  @attr_pattern Enum.join(@attrs, "|")
  @double_attr ~r/(?<prefix>(?:^|[\s<])(?:#{@attr_pattern})\s*)=\s*"(?<text>(?:\\"|[^"])+)"/u
  @single_attr ~r/(?<prefix>(?:^|[\s<])(?:#{@attr_pattern})\s*)=\s*'(?<text>(?:\\'|[^'])+)'/u

  def main(args) do
    files =
      args
      |> Enum.flat_map(&expand_path/1)
      |> Enum.uniq()
      |> Enum.sort()

    rewritten =
      Enum.reduce(files, 0, fn file, count ->
        source = File.read!(file)
        updated = rewrite_file(source, Path.extname(file))

        if updated != source do
          File.write!(file, updated)
          count + 1
        else
          count
        end
      end)

    IO.puts("rewritten=#{rewritten} scanned=#{length(files)}")
  end

  defp expand_path(path) do
    cond do
      File.dir?(path) ->
        Enum.flat_map(@extensions, fn ext -> Path.wildcard(Path.join(path, "**/*#{ext}")) end)

      File.regular?(path) and Path.extname(path) in @extensions ->
        [path]

      true ->
        []
    end
  end

  defp rewrite_file(source, ".ex"), do: rewrite_heex_sigils(source, [])
  defp rewrite_file(source, _ext), do: rewrite(source)

  defp rewrite_heex_sigils("", acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp rewrite_heex_sigils("~H\"\"\"" <> rest, acc) do
    {body, remaining} = take_until(rest, "\"\"\"")
    rewrite_heex_sigils(remaining, ["\"\"\"", rewrite(body), "~H\"\"\"" | acc])
  end

  defp rewrite_heex_sigils(<<char::utf8, rest::binary>>, acc) do
    rewrite_heex_sigils(rest, [<<char::utf8>> | acc])
  end

  defp take_until(source, delimiter) do
    case :binary.match(source, delimiter) do
      {index, _len} ->
        <<chunk::binary-size(index), _delimiter::binary-size(byte_size(delimiter)), rest::binary>> =
          source

        {chunk, rest}

      :nomatch ->
        {source, ""}
    end
  end

  defp rewrite(source) do
    source =
      Regex.replace(@double_attr, source, fn _match, prefix, text ->
        rewrite_attr(prefix, text)
      end)

    Regex.replace(@single_attr, source, fn _match, prefix, text -> rewrite_attr(prefix, text) end)
  end

  defp rewrite_attr(prefix, text) do
    normalized =
      text
      |> decode_entities()
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if translatable?(normalized) do
      "#{prefix}={gettext(#{literal(normalized)})}"
    else
      "#{prefix}=\"#{text}\""
    end
  end

  defp translatable?(text) do
    text != "" and
      String.length(text) >= 2 and
      Regex.match?(~r/[[:alpha:]]/u, text) and
      not Regex.match?(~r/^[.#]?[a-z0-9_-]+$/u, text) and
      not Regex.match?(~r/^https?:\/\//u, text)
  end

  defp decode_entities(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
  end

  defp literal(text), do: inspect(text, binaries: :as_strings, printable_limit: :infinity)
end

I18nWrapHeexAttrs.main(System.argv())
