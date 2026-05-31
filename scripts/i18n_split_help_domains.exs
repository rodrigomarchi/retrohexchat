#!/usr/bin/env elixir

defmodule I18nSplitHelpDomains do
  @moduledoc false

  @help_content "apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/**/*.{ex,heex}"

  @command_pages ~w(
    commands_overview
  )

  @channel_pages ~w(
    channel_modes_overview channel_permissions channels chanserv nickserv
  )

  @ui_pages ~w(
    empty_states formatting_colors formatting_overview keyboard_shortcuts
    ui_context_menu ui_conversations ui_nicklist ui_overview ui_status_tab
    ui_tab_bar ui_toolbar ui_topic_bar
  )

  @p2p_pages ~w(
    cmd_call cmd_p2p cmd_sendfile feature_audio_call feature_call_quality
    feature_file_transfer feature_media_devices feature_p2p_sessions
    feature_video_call
  )

  @game_pages ~w(
    cmd_game cmd_singleplayer feature_block_breakers feature_debris_field
    feature_gravity_well feature_light_trails feature_p2p_games
    feature_pixel_tanks feature_single_session feature_star_duel
  )

  @general_pages ~w(
    connect_authentication connecting private_messages welcome
  )

  @known_help_domains ~w(
    help help_arcade help_bots help_channels help_commands help_features
    help_games help_p2p help_ui
  )

  def main(args) do
    files =
      case args do
        [] -> Path.wildcard(@help_content)
        paths -> Enum.flat_map(paths, &Path.wildcard/1)
      end
      |> Enum.sort()

    {rewritten, unchanged} =
      Enum.reduce(files, {0, 0}, fn file, {rewritten, unchanged} ->
        domain = domain_for(file)
        source = File.read!(file)
        updated = replace_domain(source, domain)

        if updated == source do
          {rewritten, unchanged + 1}
        else
          File.write!(file, updated)
          {rewritten + 1, unchanged}
        end
      end)

    IO.puts("rewritten=#{rewritten} unchanged=#{unchanged} scanned=#{length(files)}")
  end

  defp replace_domain(source, domain) do
    Enum.reduce(@known_help_domains, source, fn old_domain, source ->
      source
      |> String.replace(~s(dgettext("#{old_domain}",), ~s(dgettext("#{domain}",))
      |> String.replace(~s(dngettext("#{old_domain}",), ~s(dngettext("#{domain}",))
      |> String.replace(~s(dpgettext("#{old_domain}",), ~s(dpgettext("#{domain}",))
      |> String.replace(~s(dgettext_noop("#{old_domain}",), ~s(dgettext_noop("#{domain}",))
      |> String.replace(~s(dngettext_noop("#{old_domain}",), ~s(dngettext_noop("#{domain}",))
      |> String.replace(~s(dpgettext_noop("#{old_domain}",), ~s(dpgettext_noop("#{domain}",))
    end)
  end

  defp domain_for(file) do
    page = file |> Path.basename() |> Path.rootname() |> Path.rootname()

    cond do
      page in @general_pages -> "help"
      page in @command_pages or String.starts_with?(page, "cmd_") -> "help_commands"
      page in @channel_pages or String.starts_with?(page, "mode_") -> "help_channels"
      page == "botservice" or String.starts_with?(page, "bot_") -> "help_bots"
      String.starts_with?(page, "feature_arcade") -> "help_arcade"
      page in @p2p_pages -> "help_p2p"
      page in @game_pages or String.starts_with?(page, "feature_hex_") -> "help_games"
      page in @ui_pages -> "help_ui"
      String.starts_with?(page, "feature_") -> "help_features"
      true -> "help"
    end
  end
end

I18nSplitHelpDomains.main(System.argv())
