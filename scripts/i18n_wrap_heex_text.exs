#!/usr/bin/env elixir

defmodule I18nWrapHeexText do
  @moduledoc false

  @extensions [".heex", ".ex"]

  def main(args) do
    files =
      args
      |> Enum.flat_map(&expand_path/1)
      |> Enum.uniq()
      |> Enum.sort()

    rewritten =
      Enum.reduce(files, 0, fn file, count ->
        source = File.read!(file)
        updated = transform(source, Path.extname(file))

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

  defp transform(source, ".ex"), do: transform_heex_sigils(source, [])
  defp transform(source, _ext), do: scan_text(source, [])

  defp transform_heex_sigils("", acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp transform_heex_sigils("~H\"\"\"" <> rest, acc) do
    {body, remaining} = take_until(rest, "\"\"\"")
    transform_heex_sigils(remaining, ["\"\"\"", scan_text(body, []), "~H\"\"\"" | acc])
  end

  defp transform_heex_sigils(<<char::utf8, rest::binary>>, acc) do
    transform_heex_sigils(rest, [<<char::utf8>> | acc])
  end

  defp scan_text("", acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp scan_text("<!--" <> rest, acc) do
    {comment, remaining} = take_until(rest, "-->")
    scan_text(remaining, ["-->", comment, "<!--" | acc])
  end

  defp scan_text("<%" <> rest, acc) do
    {expr, remaining} = take_until(rest, "%>")
    scan_text(remaining, ["%>", expr, "<%" | acc])
  end

  defp scan_text("<.code_example" <> rest, acc) do
    {block, remaining} = take_until(rest, "</.code_example>")
    scan_text(remaining, ["</.code_example>", block, "<.code_example" | acc])
  end

  defp scan_text("<" <> rest, acc) do
    {tag, remaining} = take_tag(rest, [])
    scan_text(remaining, [tag, "<" | acc])
  end

  defp scan_text("{" <> rest, acc) do
    {expr, remaining} = take_braced(rest, 1, ["{"])
    scan_text(remaining, [expr | acc])
  end

  defp scan_text(source, acc) do
    {text, remaining} = take_text(source, [])
    scan_text(remaining, [wrap_segment(text) | acc])
  end

  defp take_text("", acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp take_text(<<"<", _::binary>> = rest, acc),
    do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp take_text(<<"{", _::binary>> = rest, acc),
    do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp take_text(<<char::utf8, rest::binary>>, acc) do
    take_text(rest, [<<char::utf8>> | acc])
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

  defp take_tag("", acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp take_tag(<<">", rest::binary>>, acc) do
    tag = acc |> Enum.reverse() |> IO.iodata_to_binary()
    {tag <> ">", rest}
  end

  defp take_tag(<<"\"", rest::binary>>, acc) do
    {quoted, remaining} = take_quoted(rest, "\"")
    take_tag(remaining, [quoted, "\"" | acc])
  end

  defp take_tag(<<"'", rest::binary>>, acc) do
    {quoted, remaining} = take_quoted(rest, "'")
    take_tag(remaining, [quoted, "'" | acc])
  end

  defp take_tag(<<"{", rest::binary>>, acc) do
    {expr, remaining} = take_braced(rest, 1, ["{"])
    take_tag(remaining, [expr | acc])
  end

  defp take_tag(<<char::utf8, rest::binary>>, acc), do: take_tag(rest, [<<char::utf8>> | acc])

  defp take_quoted("", _quote), do: {"", ""}

  defp take_quoted(<<?\\, char::utf8, rest::binary>>, quote),
    do: take_quoted(rest, quote, [<<?\\, char::utf8>>])

  defp take_quoted(source, quote), do: take_quoted(source, quote, [])

  defp take_quoted("", _quote, acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp take_quoted(source, quote, acc) do
    quote_size = byte_size(quote)

    if String.starts_with?(source, quote) do
      <<_::binary-size(quote_size), rest::binary>> = source
      quoted = acc |> Enum.reverse() |> IO.iodata_to_binary()
      {quoted <> quote, rest}
    else
      <<char::utf8, rest::binary>> = source
      take_quoted(rest, quote, [<<char::utf8>> | acc])
    end
  end

  defp take_braced("", _depth, acc),
    do: acc |> Enum.reverse() |> IO.iodata_to_binary() |> then(&{&1, ""})

  defp take_braced(<<"\"", rest::binary>>, depth, acc),
    do: take_string_in_braces(rest, depth, ["\"" | acc], "\"")

  defp take_braced(<<"'", rest::binary>>, depth, acc),
    do: take_string_in_braces(rest, depth, ["'" | acc], "'")

  defp take_braced(<<"{", rest::binary>>, depth, acc),
    do: take_braced(rest, depth + 1, ["{" | acc])

  defp take_braced(<<"}", rest::binary>>, 1, acc) do
    {["}" | acc] |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp take_braced(<<"}", rest::binary>>, depth, acc),
    do: take_braced(rest, depth - 1, ["}" | acc])

  defp take_braced(<<char::utf8, rest::binary>>, depth, acc),
    do: take_braced(rest, depth, [<<char::utf8>> | acc])

  defp take_string_in_braces("", _depth, acc, _quote),
    do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp take_string_in_braces(<<?\\, char::utf8, rest::binary>>, depth, acc, quote),
    do: take_string_in_braces(rest, depth, [<<?\\, char::utf8>> | acc], quote)

  defp take_string_in_braces(source, depth, acc, quote) do
    quote_size = byte_size(quote)

    if String.starts_with?(source, quote) do
      <<_::binary-size(quote_size), rest::binary>> = source
      take_braced(rest, depth, [quote | acc])
    else
      <<char::utf8, rest::binary>> = source
      take_string_in_braces(rest, depth, [<<char::utf8>> | acc], quote)
    end
  end

  defp wrap_segment(segment) do
    case Regex.run(~r/^(\s*)(.*?)(\s*)$/us, segment, capture: :all_but_first) do
      [prefix, content, suffix] ->
        text =
          content
          |> decode_entities()
          |> String.replace(~r/\s+/u, " ")
          |> String.trim()

        if translatable?(text) do
          prefix <> "{gettext(#{literal(text)})}" <> suffix
        else
          segment
        end

      _ ->
        segment
    end
  end

  defp translatable?(text) do
    text != "" and
      String.length(text) >= 2 and
      Regex.match?(~r/[[:alpha:]]/u, text) and
      not String.starts_with?(text, ["{", "<", "%"]) and
      not Regex.match?(~r/^[.#]?[a-z0-9_-]+$/u, text)
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

I18nWrapHeexText.main(System.argv())
