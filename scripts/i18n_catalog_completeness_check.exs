#!/usr/bin/env elixir

defmodule I18nCatalogCompletenessCheck do
  @moduledoc """
  Every `msgid` in a `.pot` exists in every locale's `.po`.

  The two checks beside this one both pass while a string is missing from a
  catalogue entirely. `gettext.extract --check-up-to-date` compares the `.pot`
  to the code and never opens a `.po`; `i18n_po_status` counts the entries a
  `.po` **has** — and an entry that was never merged is not empty, it does not
  exist. Measured once with both of them green: 48 msgids lived in `.pot` files
  and in no catalogue, and thirteen locales rendered them in English.

  So this asks the third question. It is deliberately about presence and not
  about content: whether the entry says anything useful is what the status and
  quality checks are for.
  """

  def main(args) do
    {opts, _paths, _invalid} =
      OptionParser.parse(args,
        strict: [fail_on_missing: :boolean, locales: :string],
        aliases: [f: :fail_on_missing]
      )

    locales = locales(opts)

    findings =
      "apps/*/priv/gettext/*.pot"
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.flat_map(&missing_for_template(&1, locales))

    Enum.each(findings, fn finding ->
      IO.puts(
        "#{finding.path}: locale=#{finding.locale} missing=#{finding.count} " <>
          "first=#{inspect(String.slice(finding.first, 0, 60))}"
      )
    end)

    IO.puts("findings=#{length(findings)}")

    if opts[:fail_on_missing] && findings != [] do
      IO.puts("""

      A msgid lives in a .pot and in no catalogue, so every locale renders it
      in English. Merge the domain and translate what it brings:

        make i18n.gettext.merge DOMAINS=<domain> APP=web|domain
      """)

      System.halt(1)
    end
  end

  defp missing_for_template(pot_path, locales) do
    app_gettext = Path.dirname(pot_path)
    domain = Path.basename(pot_path, ".pot")
    wanted = msgids(pot_path)

    locales
    |> Enum.map(&{&1, Path.join([app_gettext, &1, "LC_MESSAGES", "#{domain}.po"])})
    |> Enum.filter(fn {_locale, po} -> File.exists?(po) end)
    |> Enum.flat_map(fn {locale, po} ->
      case MapSet.difference(wanted, msgids(po)) |> MapSet.to_list() |> Enum.sort() do
        [] -> []
        [first | _] = missing -> [%{path: po, locale: locale, count: length(missing), first: first}]
      end
    end)
  end

  # The header entry (`msgid ""`) is metadata rather than a string anybody
  # reads, and a `.pot` and a `.po` never agree about it.
  defp msgids(path) do
    path
    |> File.read!()
    |> String.split(~r/\n{2,}/u)
    |> Enum.flat_map(&msgid_of/1)
    |> MapSet.new()
  end

  defp msgid_of(entry) do
    case Regex.run(~r/^msgid ((?:".*"\n?)+)/m, entry) do
      [_, raw] ->
        case Regex.scan(~r/"((?:[^"\\]|\\.)*)"/, raw) |> Enum.map_join(&Enum.at(&1, 1)) do
          "" -> []
          msgid -> [msgid]
        end

      nil ->
        []
    end
  end

  defp locales(opts) do
    case Keyword.get(opts, :locales) do
      nil -> discovered_locales()
      value -> value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    end
  end

  # Every locale that already has catalogues, `en` included: its entries mirror
  # the msgid, and one missing there is the same gap.
  defp discovered_locales do
    "apps/*/priv/gettext/*/LC_MESSAGES"
    |> Path.wildcard()
    |> Enum.map(&(&1 |> Path.dirname() |> Path.basename()))
    |> Enum.uniq()
    |> Enum.sort()
  end
end

I18nCatalogCompletenessCheck.main(System.argv())
