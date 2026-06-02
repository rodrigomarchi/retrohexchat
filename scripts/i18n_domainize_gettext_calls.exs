#!/usr/bin/env elixir

defmodule I18nDomainizeGettextCalls do
  @moduledoc false

  @source_patterns [
    "apps/retro_hex_chat/lib/**/*.{ex,heex}",
    "apps/retro_hex_chat_web/lib/**/*.{ex,heex}"
  ]

  @skip_suffixes [
    "/gettext.ex"
  ]

  def main(args) do
    files =
      case args do
        [] -> Enum.flat_map(@source_patterns, &Path.wildcard/1)
        paths -> Enum.flat_map(paths, &Path.wildcard/1)
      end
      |> Enum.reject(&skip?/1)
      |> Enum.sort()

    {rewritten, unchanged} =
      Enum.reduce(files, {0, 0}, fn file, {rewritten, unchanged} ->
        domain = domain_for(file)
        source = File.read!(file)
        updated = rewrite(source, domain)

        if updated == source do
          {rewritten, unchanged + 1}
        else
          File.write!(file, updated)
          {rewritten + 1, unchanged}
        end
      end)

    IO.puts("rewritten=#{rewritten} unchanged=#{unchanged} scanned=#{length(files)}")
  end

  defp skip?(path), do: Enum.any?(@skip_suffixes, &String.ends_with?(path, &1))

  defp rewrite(source, "default"), do: source

  defp rewrite(source, domain) do
    source
    |> replace_macro(~r/(?<![\w.])pgettext_noop\s*\(/u, ~s(dpgettext_noop("#{domain}", ))
    |> replace_macro(~r/(?<![\w.])ngettext_noop\s*\(/u, ~s(dngettext_noop("#{domain}", ))
    |> replace_macro(~r/(?<![\w.])gettext_noop\s*\(/u, ~s(dgettext_noop("#{domain}", ))
    |> replace_macro(~r/(?<![\w.])pgettext\s*\(/u, ~s(dpgettext("#{domain}", ))
    |> replace_macro(~r/(?<![\w.])ngettext\s*\(/u, ~s(dngettext("#{domain}", ))
    |> replace_macro(~r/(?<![\w.])gettext\s*\(/u, ~s(dgettext("#{domain}", ))
    |> replace_gettext_module_calls(domain)
  end

  defp replace_macro(source, regex, replacement), do: Regex.replace(regex, source, replacement)

  defp replace_gettext_module_calls(source, domain) do
    Regex.replace(
      ~r/Gettext\.gettext\((RetroHexChat(?:Web)?\.Gettext),\s*/u,
      source,
      ~s(Gettext.dgettext(\\1, "#{domain}", )
    )
  end

  defp domain_for("apps/retro_hex_chat/" <> rest), do: core_domain(rest)
  defp domain_for("apps/retro_hex_chat_web/" <> rest), do: web_domain(rest)
  defp domain_for(_path), do: "default"

  defp core_domain(rest) do
    cond do
      String.contains?(rest, "/accounts/") -> "accounts"
      String.ends_with?(rest, "/admin.ex") -> "admin"
      String.contains?(rest, "/admin/") -> "admin"
      String.contains?(rest, "/arcade/") -> "arcade"
      String.contains?(rest, "/bots/") -> "bots"
      String.contains?(rest, "/channels/") -> "channels"
      String.contains?(rest, "/chat/help_topics") -> "help"
      String.contains?(rest, "/chat/emoji_data") -> "emoji"
      String.contains?(rest, "/chat/") -> "chat"
      String.contains?(rest, "/commands/handlers/admin/") -> "admin"
      String.contains?(rest, "/commands/") -> "commands"
      String.contains?(rest, "/games/") -> "games"
      String.contains?(rest, "/p2p/") -> "p2p"
      String.contains?(rest, "/presence/") -> "presence"
      String.contains?(rest, "/services/") -> "services"
      true -> "default"
    end
  end

  defp web_domain(rest) do
    cond do
      String.contains?(rest, "/controllers/help_content") -> web_help_content_domain(rest)
      String.contains?(rest, "/controllers/app/session_controller") -> "connect"
      String.contains?(rest, "/controllers/locale_controller") -> "connect"
      String.contains?(rest, "/components/diagrams/") -> "diagrams"
      String.contains?(rest, "/components/icons/") -> "ui"
      String.contains?(rest, "/components/layouts/landing_live") -> "landing"
      String.contains?(rest, "/components/layouts/help_live") -> "help"
      String.contains?(rest, "/components/layouts/showcase") -> "showcase"
      String.contains?(rest, "/components/layouts/chat") -> "ui"
      String.contains?(rest, "/components/showcase_helpers") -> "showcase"
      String.contains?(rest, "/components/ui/chat/") -> "chat"
      String.contains?(rest, "/components/ui/dialogs/") -> "dialogs"
      String.contains?(rest, "/components/ui/games/") -> "games"
      String.contains?(rest, "/components/ui/p2p/") -> "p2p"
      String.contains?(rest, "/components/ui/primitives/") -> "ui"
      String.contains?(rest, "/components/ui/layout/") -> "ui"
      String.contains?(rest, "/components/ui/shell/") -> "ui"
      String.contains?(rest, "/components/ui/") -> "ui"
      String.contains?(rest, "/components/toast") -> "ui"
      String.contains?(rest, "/live/admin/") -> "admin"
      String.contains?(rest, "/live/chat_live/") -> "chat"
      String.contains?(rest, "/live/help_live/") -> "help"
      String.contains?(rest, "/live/landing_live/") -> "landing"
      String.contains?(rest, "/live/showcase_live/") -> "showcase"
      String.contains?(rest, "/live/app/connect_live") -> "connect"
      String.contains?(rest, "/live/app/chat_live") -> "chat"
      String.contains?(rest, "/live/app/p2p_session") -> "p2p"
      String.contains?(rest, "/live/app/p2_p_session") -> "p2p"
      String.contains?(rest, "/live/app/game_session") -> "games"
      String.contains?(rest, "/live/app/solo_session") -> "games"
      String.contains?(rest, "/live/app/arcade_game") -> "arcade"
      String.contains?(rest, "/live/app/chat_helpers") -> "chat"
      String.contains?(rest, "/live/app/session_helpers") -> "chat"
      String.contains?(rest, "/lib/mix/tasks/") -> "system"
      String.contains?(rest, "/mix/tasks/") -> "system"
      String.contains?(rest, "/telemetry") -> "system"
      String.contains?(rest, "/router") -> "ui"
      true -> "default"
    end
  end

  defp web_help_content_domain(rest) do
    page =
      rest
      |> Path.basename()
      |> Path.rootname()
      |> Path.rootname()

    cond do
      page in ~w(connect_authentication connecting private_messages welcome) ->
        "help"

      page in ~w(commands_overview) or String.starts_with?(page, "cmd_") ->
        "help_commands"

      page in ~w(channel_modes_overview channel_permissions channels chanserv nickserv) or
          String.starts_with?(page, "mode_") ->
        "help_channels"

      page == "botservice" or String.starts_with?(page, "bot_") ->
        "help_bots"

      String.starts_with?(page, "feature_arcade") ->
        "help_arcade"

      page in ~w(cmd_call cmd_p2p cmd_sendfile feature_audio_call feature_call_quality feature_file_transfer feature_media_devices feature_p2p_sessions feature_video_call) ->
        "help_p2p"

      page in ~w(cmd_game cmd_singleplayer feature_block_breakers feature_debris_field feature_gravity_well feature_light_trails feature_p2p_games feature_pixel_tanks feature_single_session feature_star_duel) or
          String.starts_with?(page, "feature_hex_") ->
        "help_games"

      page in ~w(empty_states formatting_colors formatting_overview keyboard_shortcuts ui_context_menu ui_conversations ui_nicklist ui_overview ui_status_tab ui_tab_bar ui_toolbar ui_topic_bar) ->
        "help_ui"

      String.starts_with?(page, "feature_") ->
        "help_features"

      true ->
        "help"
    end
  end
end

I18nDomainizeGettextCalls.main(System.argv())
