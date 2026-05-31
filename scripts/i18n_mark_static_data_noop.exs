#!/usr/bin/env elixir

# Migration helper for static metadata tables. It marks literals with
# gettext_noop/1 so xgettext extracts them while runtime code can still choose
# the current locale when returning values.

defmodule I18nMarkStaticDataNoop do
  @emoji_path "apps/retro_hex_chat/lib/retro_hex_chat/chat/emoji_data.ex"
  @arcade_path "apps/retro_hex_chat/lib/retro_hex_chat/arcade/catalog.ex"
  @showcase_path "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/showcase_helpers.ex"
  @help_topics_path "apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex"
  @key_bindings_path "apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex"

  @emoji_categories [
    "Smileys & Emotion",
    "People & Body",
    "Animals & Nature",
    "Food & Drink",
    "Travel & Places",
    "Activities",
    "Objects",
    "Symbols"
  ]

  @help_categories [
    "Getting Started",
    "Chat & Messaging",
    "Users & Identity",
    "Contacts & Notify",
    "Channels",
    "Channel Settings",
    "Moderation",
    "Channel Modes",
    "Services & Protocols",
    "Bots",
    "Admin & Server",
    "Server Messages",
    "Automation",
    "Chat Input",
    "Chat Display",
    "Notifications & Sounds",
    "Settings & Preferences",
    "User Interface",
    "Text Formatting",
    "Connection",
    "P2P & Calls",
    "P2P Games: Action",
    "P2P Games: Sports",
    "Solo Arcade: FPS",
    "Solo Arcade: Adventures"
  ]

  def run do
    mark_emoji_data()
    mark_arcade_catalog()
    mark_showcase_nav()
    mark_help_topics()
    mark_key_bindings()
  end

  defp mark_emoji_data do
    source = File.read!(@emoji_path)

    source = wrap_exact_strings(source, @emoji_categories)

    source =
      Regex.replace(
        ~r/name: (?!gettext_noop\()("(?:\\.|[^"\\])*")/u,
        source,
        "name: gettext_noop(\\1)"
      )

    source =
      Regex.replace(~r/keywords: \[(.*?)\]/u, source, fn full, inner ->
        if String.contains?(full, "gettext_noop(") do
          full
        else
          wrapped =
            Regex.replace(~r/"(?:\\.|[^"\\])*"/u, inner, fn literal ->
              "gettext_noop(#{literal})"
            end)

          "keywords: [#{wrapped}]"
        end
      end)

    File.write!(@emoji_path, source)
  end

  defp mark_arcade_catalog do
    source = File.read!(@arcade_path)

    if String.contains?(source, "name: gettext_noop(") do
      :ok
    else
      [_, games_code] = Regex.run(~r/@games\s+(\[.*?\])\n\n  @spec list_games/su, source)
      {games, _binding} = Code.eval_string(games_code)

      games_source =
        games
        |> Enum.map(&arcade_game_source/1)
        |> Enum.join(",\n")

      replacement = "@games [\n#{games_source}\n  ]\n\n  @spec list_games"

      updated =
        Regex.replace(
          ~r/@games\s+\[.*?\]\n\n  @spec list_games/su,
          source,
          replacement
        )

      File.write!(@arcade_path, updated)
    end
  end

  defp arcade_game_source(game) do
    [
      "    %{",
      "      id: #{inspect(game.id)},",
      "      name: gettext_noop(#{inspect(game.name)}),",
      "      tagline: gettext_noop(#{inspect(game.tagline)}),",
      "      description: gettext_noop(#{inspect(game.description)}),",
      "      engine: #{inspect(game.engine)},",
      "      controls: gettext_noop(#{inspect(game.controls)}),",
      "      icon: #{inspect(game.icon)}",
      "    }"
    ]
    |> Enum.join("\n")
  end

  defp mark_showcase_nav do
    source = File.read!(@showcase_path)

    updated =
      Regex.replace(
        ~r/(@nav_items\s+\[)(.*?)(\n  \]\n\n  @spec showcase_layout)/su,
        source,
        fn _full, prefix, body, suffix ->
          body =
            Regex.replace(~r/\{"((?:\\.|[^"\\])*)"/u, body, fn match, label ->
              if String.contains?(match, "gettext_noop(") do
                match
              else
                "{gettext_noop(#{inspect(label)})"
              end
            end)

          prefix <> body <> suffix
        end
      )

    File.write!(@showcase_path, updated)
  end

  defp mark_help_topics do
    @help_topics_path
    |> File.read!()
    |> wrap_exact_strings(@help_categories)
    |> then(&File.write!(@help_topics_path, &1))
  end

  defp mark_key_bindings do
    source = File.read!(@key_bindings_path)

    updated =
      Regex.replace(
        ~r/(\b(?:label|description): )(?!gettext_noop\()("((?:\\.|[^"\\])*)")/u,
        source,
        fn _match, prefix, literal, _text ->
          prefix <> "gettext_noop(#{literal})"
        end
      )

    File.write!(@key_bindings_path, updated)
  end

  defp wrap_exact_strings(source, strings) do
    Enum.reduce(strings, source, fn string, acc ->
      Regex.replace(
        ~r/(?<!gettext_noop\()"#{Regex.escape(string)}"/u,
        acc,
        "gettext_noop(#{inspect(string)})"
      )
    end)
  end
end

I18nMarkStaticDataNoop.run()
