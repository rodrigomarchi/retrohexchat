#!/usr/bin/env elixir

defmodule I18nRehydrateDomainTranslations do
  @moduledoc false

  Code.require_file("scripts/i18n_locale_helpers.exs")

  alias Expo.Message
  alias Expo.Message.{Plural, Singular}
  alias Expo.Messages
  alias Expo.PO

  @apps ~w(apps/retro_hex_chat apps/retro_hex_chat_web)

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

  def main(args) do
    for app <- @apps, locale <- I18nLocaleHelpers.locales_from_args(args) do
      index = translation_index(app, locale.code)

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
      headers: I18nLocaleHelpers.headers(locale),
      top_comments: I18nLocaleHelpers.top_comments(domain, locale),
      messages: messages
    }

    target = Path.join([app, "priv/gettext", locale.code, "LC_MESSAGES", "#{domain}.po"])
    File.mkdir_p!(Path.dirname(target))

    target
    |> File.write!(output |> Messages.rebalance() |> PO.compose() |> IO.iodata_to_binary())

    IO.puts("#{target}: entries=#{length(messages)}")
  end

  defp hydrate_message(%Singular{} = message, locale, index) do
    msgid = string(message.msgid)

    msgstr =
      case lookup(index, message) || manual_translation(locale.code, msgid) do
        nil when locale.code == "en" -> [msgid]
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
        nil -> default_plural_msgstr(locale, msgid, msgid_plural)
        value -> normalize_plural_msgstr(locale, value, msgid, msgid_plural)
      end

    %Plural{message | msgstr: msgstr, previous_messages: [], obsolete: false}
  end

  defp default_plural_msgstr(locale, msgid, msgid_plural) do
    single_form_uses_plural = locale.code in ~w(id ja zh_hans ko vi zh_hant)

    locale
    |> nplurals()
    |> plural_indexes()
    |> Map.new(fn
      0 when single_form_uses_plural -> {0, [msgid_plural]}
      0 -> {0, [msgid]}
      index -> {index, [msgid_plural]}
    end)
  end

  defp normalize_plural_msgstr(locale, value, msgid, msgid_plural) do
    defaults = default_plural_msgstr(locale, msgid, msgid_plural)

    locale
    |> nplurals()
    |> plural_indexes()
    |> Map.new(fn index -> {index, Map.get(value, index, Map.fetch!(defaults, index))} end)
  end

  defp plural_indexes(count), do: Enum.to_list(0..(count - 1)//1)

  defp nplurals(locale) do
    case Regex.run(~r/nplurals=(\d+)/, locale.plural_forms) do
      [_, count] -> String.to_integer(count)
      _missing -> 2
    end
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

end

I18nRehydrateDomainTranslations.main(System.argv())
