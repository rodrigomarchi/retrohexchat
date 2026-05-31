#!/usr/bin/env elixir

defmodule I18nPoStatus do
  @moduledoc false

  def main(args) do
    {opts, paths, _invalid} =
      OptionParser.parse(args,
        strict: [fail_on_untranslated: :boolean, fail_locale: :string],
        aliases: [f: :fail_on_untranslated]
      )

    files =
      case paths do
        [] -> Path.wildcard("apps/*/priv/gettext/*/LC_MESSAGES/*.po")
        _ -> Enum.flat_map(paths, &Path.wildcard/1)
      end
      |> Enum.sort()

    statuses = Enum.map(files, &status/1)
    fail_locales = fail_locales(opts)

    Enum.each(statuses, fn status ->
      IO.puts(
        "#{status.path}: locale=#{status.locale} entries=#{status.entries} ready=#{status.ready} translated=#{status.translated} empty=#{status.empty} fuzzy=#{status.fuzzy}"
      )
    end)

    statuses_to_check =
      case fail_locales do
        [] -> statuses
        locales -> Enum.filter(statuses, &(&1.locale in locales))
      end

    if opts[:fail_on_untranslated] == true and
         Enum.any?(statuses_to_check, &(&1.empty > 0 or &1.fuzzy > 0)) do
      System.halt(1)
    end
  end

  defp status(path) do
    entries =
      path
      |> File.read!()
      |> String.split(~r/\n{2,}/u)
      |> Enum.filter(&String.contains?(&1, "msgid "))
      |> Enum.reject(&Regex.match?(~r/msgid ""\nmsgstr ""/, &1))

    empty = Enum.count(entries, &empty?/1)
    fuzzy = Enum.count(entries, &fuzzy?/1)
    ready = Enum.count(entries, &(not empty?(&1) and not fuzzy?(&1)))

    %{
      path: path,
      locale: locale(path),
      entries: length(entries),
      ready: ready,
      translated: length(entries) - empty,
      empty: empty,
      fuzzy: fuzzy
    }
  end

  defp fail_locales(opts) do
    opts
    |> Keyword.get(:fail_locale, "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp locale(path) do
    case Regex.run(~r{/priv/gettext/([^/]+)/LC_MESSAGES/}, path) do
      [_, locale] -> locale
      _ -> "unknown"
    end
  end

  defp empty?(entry) do
    entry
    |> msgstr_values()
    |> Enum.any?(&(&1 == ""))
  end

  defp msgstr_values(entry) do
    {_current, values} =
      entry
      |> String.split("\n")
      |> Enum.reduce({nil, %{}}, fn line, {current, values} ->
        case {msgstr_line(line), continuation_line(line)} do
          {{index, value}, _continuation} ->
            key = if index == "", do: "0", else: index
            {key, Map.put(values, key, [value])}

          {nil, value} when current != nil and not is_nil(value) ->
            {current, Map.update!(values, current, &(&1 ++ [value]))}

          _other ->
            {nil, values}
        end
      end)

    values
    |> Map.values()
    |> Enum.map(&Enum.join/1)
  end

  defp msgstr_line(line) do
    case Regex.run(~r/^msgstr(?:\[(\d+)\])? "(.*)"$/, line) do
      [_, index, value] -> {index, value}
      nil -> nil
    end
  end

  defp continuation_line(line) do
    case Regex.run(~r/^"(.*)"$/, line) do
      [_, value] -> value
      nil -> nil
    end
  end

  defp fuzzy?(entry) do
    Regex.match?(~r/^#,.*\bfuzzy\b/m, entry)
  end
end

I18nPoStatus.main(System.argv())
