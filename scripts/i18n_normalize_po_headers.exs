#!/usr/bin/env elixir

defmodule I18nNormalizePoHeaders do
  @moduledoc false

  @po_header ~r/msgid ""\nmsgstr ""\n(?:"(?:\\.|[^"\\])*"\n)*\n/s

  def main(args) do
    files =
      case args do
        [] -> Path.wildcard("apps/*/priv/gettext/{en,pt_BR}/LC_MESSAGES/*.po")
        paths -> Enum.flat_map(paths, &Path.wildcard/1)
      end

    rewritten =
      Enum.reduce(files, 0, fn file, count ->
        source = File.read!(file)
        locale = locale_from_path(file)
        updated = Regex.replace(@po_header, source, header(locale), global: false)

        if updated != source do
          File.write!(file, updated)
          count + 1
        else
          count
        end
      end)

    IO.puts("rewritten=#{rewritten} scanned=#{length(files)}")
  end

  defp locale_from_path(path) do
    path
    |> String.split("/")
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.find_value(fn
      ["gettext", locale, "LC_MESSAGES"] -> locale
      _ -> nil
    end)
  end

  defp header(locale) do
    plural_forms =
      case locale do
        "pt_BR" -> "nplurals=2; plural=(n>1);"
        _ -> "nplurals=2; plural=(n != 1);"
      end

    """
    msgid ""
    msgstr ""
    "Project-Id-Version: RetroHexChat\\n"
    "PO-Revision-Date: 2026-05-30 00:00+0000\\n"
    "Last-Translator: RetroHexChat Team\\n"
    "Language-Team: #{locale}\\n"
    "Language: #{locale}\\n"
    "MIME-Version: 1.0\\n"
    "Content-Type: text/plain; charset=UTF-8\\n"
    "Content-Transfer-Encoding: 8bit\\n"
    "Plural-Forms: #{plural_forms}\\n"

    """
  end
end

I18nNormalizePoHeaders.main(System.argv())
