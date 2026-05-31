#!/usr/bin/env elixir

defmodule I18nRehydrateDomainTranslations do
  @moduledoc false

  alias Expo.Message
  alias Expo.Message.{Plural, Singular}
  alias Expo.Messages
  alias Expo.PO

  @apps ~w(apps/retro_hex_chat apps/retro_hex_chat_web)
  @locales ~w(en pt_BR)

  @manual_translations %{
    "en" => %{
      "Greeting set to '%{greeting}'." => "Greeting set to '%{greeting}'.",
      "Greeting disabled." => "Greeting disabled.",
      "Farewell set to '%{farewell}'." => "Farewell set to '%{farewell}'.",
      "Farewell disabled." => "Farewell disabled."
    },
    "pt_BR" => %{
      "Greeting set to '%{greeting}'." => "Saudação definida como '%{greeting}'.",
      "Greeting disabled." => "Saudação desativada.",
      "Farewell set to '%{farewell}'." => "Despedida definida como '%{farewell}'.",
      "Farewell disabled." => "Despedida desativada."
    }
  }

  def main(_args) do
    for app <- @apps, locale <- @locales do
      index = translation_index(app, locale)

      app
      |> Path.join("priv/gettext/*.pot")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.each(&rehydrate_catalog(&1, app, locale, index))
    end
  end

  defp rehydrate_catalog(pot_path, app, locale, index) do
    pot = PO.parse_file!(pot_path)
    domain = pot_path |> Path.basename() |> Path.rootname()

    messages =
      pot.messages
      |> Enum.reject(& &1.obsolete)
      |> Enum.map(&hydrate_message(&1, locale, index))

    output = %Messages{
      headers: headers(locale),
      top_comments: top_comments(domain),
      messages: messages
    }

    target = Path.join([app, "priv/gettext", locale, "LC_MESSAGES", "#{domain}.po"])
    File.mkdir_p!(Path.dirname(target))

    target
    |> File.write!(output |> Messages.rebalance() |> PO.compose() |> IO.iodata_to_binary())

    IO.puts("#{target}: entries=#{length(messages)}")
  end

  defp hydrate_message(%Singular{} = message, locale, index) do
    msgid = string(message.msgid)

    msgstr =
      case lookup(index, message) || manual_translation(locale, msgid) do
        nil when locale == "en" -> [msgid]
        nil -> [msgid]
        value when is_binary(value) -> [value]
        value when is_list(value) -> value
      end

    %Singular{message | msgstr: msgstr, previous_messages: [], obsolete: false}
  end

  defp hydrate_message(%Plural{} = message, locale, index) do
    msgid = string(message.msgid)
    msgid_plural = string(message.msgid_plural)

    msgstr =
      case lookup(index, message) do
        nil when locale == "en" -> %{0 => [msgid], 1 => [msgid_plural]}
        nil -> %{0 => [msgid], 1 => [msgid_plural]}
        value -> value
      end

    %Plural{message | msgstr: msgstr, previous_messages: [], obsolete: false}
  end

  defp translation_index(app, locale) do
    [working_tree_catalogs(app, locale), git_catalogs(app, locale)]
    |> List.flatten()
    |> Enum.reduce(%{}, fn contents, acc ->
      contents
      |> PO.parse_string!()
      |> Map.fetch!(:messages)
      |> Enum.reject(& &1.obsolete)
      |> Enum.reduce(acc, fn message, acc ->
        if translated?(message) do
          Map.put_new(acc, key(message), translation(message))
        else
          acc
        end
      end)
    end)
  end

  defp working_tree_catalogs(app, locale) do
    app
    |> Path.join("priv/gettext/#{locale}/LC_MESSAGES/*.po")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&File.read!/1)
  end

  defp git_catalogs(app, locale) do
    app
    |> git_catalog_paths(locale)
    |> Enum.flat_map(fn path ->
      case System.cmd("git", ["show", "HEAD:#{path}"], stderr_to_stdout: true) do
        {contents, 0} -> [contents]
        _missing -> []
      end
    end)
  end

  defp git_catalog_paths(app, locale) do
    case System.cmd("git", ["ls-tree", "-r", "--name-only", "HEAD", "#{app}/priv/gettext/#{locale}/LC_MESSAGES"], stderr_to_stdout: true) do
      {paths, 0} ->
        paths
        |> String.split("\n", trim: true)
        |> Enum.filter(&String.ends_with?(&1, ".po"))
        |> then(fn paths ->
          default = "#{app}/priv/gettext/#{locale}/LC_MESSAGES/default.po"

          if default in paths do
            [default | List.delete(paths, default)]
          else
            paths
          end
        end)

      _missing ->
        []
    end
  end

  defp lookup(index, message), do: Map.get(index, key(message))

  defp key(%Singular{} = message), do: {:singular, Message.key(message)}

  defp key(%Plural{} = message) do
    {:plural, Message.key(message), string(message.msgid_plural)}
  end

  defp translation(%Singular{msgstr: msgstr}), do: msgstr
  defp translation(%Plural{msgstr: msgstr}), do: msgstr

  defp translated?(%Singular{msgstr: msgstr}), do: string(msgstr) != ""

  defp translated?(%Plural{msgstr: msgstr}) do
    msgstr
    |> Map.values()
    |> Enum.all?(&(string(&1) != ""))
  end

  defp manual_translation(locale, msgid), do: get_in(@manual_translations, [locale, msgid])

  defp string(nil), do: ""
  defp string(value), do: IO.iodata_to_binary(value)

  defp headers("en") do
    [
      "Project-Id-Version: RetroHexChat\n",
      "PO-Revision-Date: 2026-05-30 00:00+0000\n",
      "Last-Translator: RetroHexChat Team\n",
      "Language-Team: en\n",
      "Language: en\n",
      "MIME-Version: 1.0\n",
      "Content-Type: text/plain; charset=UTF-8\n",
      "Content-Transfer-Encoding: 8bit\n",
      "Plural-Forms: nplurals=2; plural=(n != 1);\n"
    ]
  end

  defp headers("pt_BR") do
    [
      "Project-Id-Version: RetroHexChat\n",
      "PO-Revision-Date: 2026-05-30 00:00+0000\n",
      "Last-Translator: RetroHexChat Team\n",
      "Language-Team: pt_BR\n",
      "Language: pt_BR\n",
      "MIME-Version: 1.0\n",
      "Content-Type: text/plain; charset=UTF-8\n",
      "Content-Transfer-Encoding: 8bit\n",
      "Plural-Forms: nplurals=2; plural=(n>1);\n"
    ]
  end

  defp top_comments(domain) do
    [
      [
        ~s( "msgid"s in this file come from #{domain}.pot.),
        " ",
        " Do not add, change, or remove msgids manually.",
        " Use mix gettext.extract --merge and the i18n scripts to refresh catalogs."
      ]
    ]
  end
end

I18nRehydrateDomainTranslations.main(System.argv())
