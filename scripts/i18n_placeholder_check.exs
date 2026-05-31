#!/usr/bin/env elixir

defmodule I18nPlaceholderCheck do
  @moduledoc false

  alias Expo.Message.{Plural, Singular}
  alias Expo.PO

  @placeholder ~r/%\{[A-Za-z0-9_]+\}/

  def main(args) do
    {opts, paths, _invalid} =
      OptionParser.parse(args,
        strict: [fail_on_findings: :boolean],
        aliases: [f: :fail_on_findings]
      )

    files =
      case paths do
        [] -> Path.wildcard("apps/*/priv/gettext/*/LC_MESSAGES/*.po")
        _ -> Enum.flat_map(paths, &Path.wildcard/1)
      end
      |> Enum.sort()

    findings = Enum.flat_map(files, &findings/1)

    Enum.each(findings, fn finding ->
      IO.puts(
        "#{finding.path}: msgid=#{inspect(finding.msgid)} expected=#{inspect(finding.expected)} got=#{inspect(finding.got)}"
      )
    end)

    IO.puts("files=#{length(files)} findings=#{length(findings)}")

    if opts[:fail_on_findings] == true and findings != [] do
      System.halt(1)
    end
  end

  defp findings(path) do
    path
    |> PO.parse_file!()
    |> Map.fetch!(:messages)
    |> Enum.reject(& &1.obsolete)
    |> Enum.flat_map(&message_findings(&1, path))
  end

  defp message_findings(%Singular{} = message, path) do
    expected = placeholders(message.msgid)
    got = placeholders(message.msgstr)

    if expected == got do
      []
    else
      [finding(path, message.msgid, expected, got)]
    end
  end

  defp message_findings(%Plural{} = message, path) do
    plural_form_count = map_size(message.msgstr)

    message.msgstr
    |> Enum.flat_map(fn {index, msgstr} ->
      expected = plural_expected_placeholders(message, plural_form_count, index)
      got = placeholders(msgstr)

      if expected == got do
        []
      else
        [finding(path, message.msgid, expected, got)]
      end
    end)
  end

  defp plural_expected_placeholders(message, 1, _index), do: placeholders(message.msgid_plural)
  defp plural_expected_placeholders(message, _plural_form_count, 0), do: placeholders(message.msgid)

  defp plural_expected_placeholders(message, _plural_form_count, _index),
    do: placeholders(message.msgid_plural)

  defp finding(path, msgid, expected, got) do
    %{
      path: path,
      msgid: string(msgid),
      expected: expected |> MapSet.to_list() |> Enum.sort(),
      got: got |> MapSet.to_list() |> Enum.sort()
    }
  end

  defp placeholders(value) do
    @placeholder
    |> Regex.scan(string(value))
    |> List.flatten()
    |> MapSet.new()
  end

  defp string(value), do: IO.iodata_to_binary(value || "")
end

I18nPlaceholderCheck.main(System.argv())
