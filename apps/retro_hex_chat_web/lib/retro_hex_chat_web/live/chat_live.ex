defmodule RetroHexChatWeb.ChatLive do
  @moduledoc """
  Main chat interface with MDI layout: treebar, chat area, nicklist, status bar.
  """
  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, Session}
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.Motd

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    CapturedURL,
    CustomMenus,
    DisplayPreferences,
    DuplicateTracker,
    EmojiData,
    Favorites,
    FloodTracker,
    Formatter,
    HelpTopics,
    HighlightWords,
    IgnoreList,
    LogFilter,
    PerformList,
    URLDetector,
    UserPreferences
  }

  alias RetroHexChat.Presence.{NotifyList, WhowasCache}
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.Helpers

  @impl true
  def mount(params, _session, socket) do
    nickname = params["nickname"] || "Guest_#{:rand.uniform(99999)}"

    case NicknameValidator.validate(nickname) do
      :ok ->
        session = Session.new(nickname)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "presence:global",
            {:user_connected, %{nickname: nickname}}
          )

          socket =
            socket
            |> attach_all_hooks()
            |> assign_defaults(session)
            |> Helpers.join_channel("#lobby", session)
            |> Helpers.maybe_join_from_params(params)
            |> Helpers.maybe_start_nickserv_timer(nickname)
            |> Helpers.maybe_trigger_perform()
            |> Helpers.play_event_sound(:connect, session)
            |> maybe_show_motd()
            |> push_initial_preferences()

          {:ok, socket}
        else
          {:ok, assign_defaults(socket, session)}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp attach_all_hooks(socket) do
    event_hooks = [
      {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
      {:options_events, &ChatLive.OptionsEvents.handle_event/3},
      {:help_events, &ChatLive.HelpEvents.handle_event/3},
      {:url_catcher_events, &ChatLive.UrlCatcherEvents.handle_event/3},
      {:invite_events, &ChatLive.InviteEvents.handle_event/3},
      {:pm_typing_events, &ChatLive.PmTypingEvents.handle_event/3},
      {:alias_events, &ChatLive.AliasEvents.handle_event/3},
      {:custom_menus_events, &ChatLive.CustomMenusEvents.handle_event/3},
      {:autorespond_events, &ChatLive.AutorespondEvents.handle_event/3},
      {:highlight_events, &ChatLive.HighlightEvents.handle_event/3},
      {:ignore_events, &ChatLive.IgnoreEvents.handle_event/3},
      {:settings_dialogs_events, &ChatLive.SettingsDialogsEvents.handle_event/3},
      {:notify_events, &ChatLive.NotifyEvents.handle_event/3},
      {:address_book_events, &ChatLive.AddressBookEvents.handle_event/3},
      {:favorites_events, &ChatLive.FavoritesEvents.handle_event/3},
      {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
      {:log_viewer_events, &ChatLive.LogViewerEvents.handle_event/3},
      {:search_events, &ChatLive.SearchEvents.handle_event/3},
      {:perform_autojoin_events, &ChatLive.PerformAutojoinEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:core_events, &ChatLive.CoreEvents.handle_event/3}
    ]

    info_hooks = [
      {:timer_handlers, &ChatLive.TimerHandlers.handle_info/2},
      {:pubsub_handlers, &ChatLive.PubsubHandlers.handle_info/2}
    ]

    socket =
      Enum.reduce(event_hooks, socket, fn {name, fun}, acc ->
        attach_hook(acc, name, :handle_event, fun)
      end)

    Enum.reduce(info_hooks, socket, fn {name, fun}, acc ->
      attach_hook(acc, name, :handle_info, fun)
    end)
  end

  defp assign_defaults(socket, session) do
    socket
    |> assign(
      channel_users: [],
      command_history: [],
      autocomplete_filter: "",
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0,
      autocomplete_visible: false,
      recent_commands: [],
      contacts_selected: nil,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil},
      nick_color_fn: build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      input: "",
      link_previews: %{},
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: "RetroHexChat",
      search_current_index: 0,
      search_query: "",
      search_result_count: 0,
      search_results: [],
      search_visible: false,
      session: session,
      show_about: false,
      show_address_book: false,
      show_context_color_picker: false,
      show_contact_add_dialog: false,
      show_contact_edit_dialog: false,
      address_book_tab: "contacts",
      show_nick_color_add_dialog: false,
      show_nick_color_edit_dialog: false,
      show_nicklist: true,
      show_status_tab: false,
      show_notify_add_dialog: false,
      show_notify_edit_dialog: false,
      show_notify_list: false,
      help_active_tab: "contents",
      help_index_filter: "",
      help_search_query: "",
      help_search_results: [],
      help_selected_topic: nil,
      highlight_channels: MapSet.new(),
      highlight_selected: nil,
      show_help_dialog: false,
      show_highlight_add_dialog: false,
      show_highlight_dialog: false,
      show_highlight_edit_dialog: false,
      current_topic: nil,
      current_modes: nil,
      show_treebar: true,
      show_url_catcher: false,
      show_whois: false,
      unread_channels: MapSet.new(),
      url_catcher_entries: [],
      url_catcher_filter_channel: nil,
      url_catcher_search_query: "",
      url_catcher_sort_column: :timestamp,
      url_catcher_sort_direction: :desc,
      whois_target: nil,
      ignore_timers: %{},
      show_ignore_dialog: false,
      ignore_selected: nil,
      show_ignore_add_dialog: false,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_state: nil,
      channel_central_channel: nil,
      channel_central_operator: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false,
      show_perform_dialog: false,
      perform_dialog_tab: "commands",
      perform_selected: nil,
      show_perform_add_dialog: false,
      show_perform_edit_dialog: false,
      autojoin_selected: nil,
      show_autojoin_add_dialog: false,
      show_autojoin_edit_dialog: false,
      show_log_viewer: false,
      log_filter: LogFilter.new(),
      log_source_options: [],
      log_page: nil,
      log_loading: false,
      log_preferences: DisplayPreferences.new(),
      log_exporting: false,
      log_error: nil,
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_active_pm: nil,
      ctcp_pending: %{},
      ctcp_rate_limits: %{},
      knock_timestamps: %{},
      show_ctcp_settings_dialog: false,
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
      ctcp_reply_tracker: %{timestamps: []},
      show_flood_protection_dialog: false,
      show_sound_settings_dialog: false,
      sound_settings_draft: nil,
      show_options_dialog: false,
      options_panel: "display",
      options_draft: nil,
      show_toolbar: true,
      show_switchbar: true,
      show_statusbar: true,
      compact_mode: false,
      line_shading: false,
      nick_palette_editing_index: nil,
      keybinding_editing: nil,
      keybinding_warning: nil,
      muted: false,
      favorite_dialog_channel: nil,
      favorite_dialog_data: nil,
      favorite_dialog_is_duplicate: false,
      favorite_dialog_mode: :add,
      flash_channels: MapSet.new(),
      organize_favorites_selected: nil,
      pm_typing_from: nil,
      pm_typing_timer: nil,
      show_favorite_dialog: false,
      show_organize_favorites: false,
      treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
      last_activity_at: DateTime.utc_now(),
      show_alias_dialog: false,
      alias_dialog_selected: nil,
      alias_dialog_editing: false,
      alias_dialog_draft_name: "",
      alias_dialog_draft_expansion: "",
      alias_dialog_warning: nil,
      alias_dialog_error: nil,
      user_timers: %{},
      autorespond_cooldowns: %{},
      show_custom_menus_dialog: false,
      custom_menus_dialog_tab: :nicklist,
      custom_menus_dialog_selected: nil,
      custom_menus_dialog_editing: false,
      custom_menus_dialog_draft_label: "",
      custom_menus_dialog_draft_command: "",
      custom_menus_dialog_error: nil,
      show_autorespond_dialog: false,
      autorespond_dialog_selected: nil,
      autorespond_dialog_editing: false,
      autorespond_dialog_draft_trigger: "on_join",
      autorespond_dialog_draft_channel: "",
      autorespond_dialog_draft_command: "",
      autorespond_dialog_error: nil,
      away_replied_to: MapSet.new(),
      paste_lines: nil,
      paste_flood_warning: false,
      paste_send_disabled: false,
      quit_reason: nil,
      show_emoji_picker: false,
      emoji_search: "",
      emoji_category: "Smileys & Emotion",
      emoji_emojis: EmojiData.by_category("Smileys & Emotion"),
      syntax_tooltip: nil,
      command_help_level: UserPreferences.get_command_help_level(session.user_preferences),
      timestamp_format: UserPreferences.get_timestamp_format(session.user_preferences)
    )
    |> stream(:chat_messages, [])
    |> stream(:status_messages, [])
  end

  @impl true
  def handle_info({_ref, _result}, socket), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      quit_reason = quit_reason_for(socket, session)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: session.nickname}}
      )

      WhowasCache.record(session.nickname, session.channels, quit_reason)

      ChatLive.Helpers.cleanup_channels(session, quit_reason)
    end

    :ok
  end

  defp quit_reason_for(socket, session) do
    socket.assigns[:quit_reason] ||
      UserPreferences.get_quit_message(session.user_preferences)
  end

  defp maybe_show_motd(socket) do
    case Motd.get() do
      nil -> socket
      content -> Helpers.push_status_message(socket, content, :motd)
    end
  end

  defp push_initial_preferences(socket) do
    prefs = socket.assigns.session.user_preferences
    styles = UserPreferences.to_css_styles(prefs)

    socket
    |> push_event("apply_preferences", %{styles: styles})
    |> push_event("reconnect_config", %{
      enabled: prefs.connect.auto_reconnect_enabled,
      max_attempts: prefs.connect.max_retries,
      max_delay: prefs.connect.retry_interval
    })
  end

  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, target_nick) do
    IgnoreList.get_entry(session.ignore_list, target_nick) != nil
  end

  defp viewer_is_op?(session) do
    case session.active_channel do
      nil ->
        false

      channel ->
        case Server.get_state(channel) do
          {:ok, state} ->
            session.nickname in state.operators or
              session.nickname in Map.get(state, :owners, [])

          {:error, _} ->
            false
        end
    end
  rescue
    e ->
      Logger.warning("Failed to check operator status: #{inspect(e)}")
      false
  end

  @spec input_placeholder(map()) :: String.t()
  defp input_placeholder(assigns) do
    cond do
      assigns.show_status_tab ->
        "Digite um comando — / para lista"

      assigns.session.active_pm != nil ->
        "Mensagem para #{assigns.session.active_pm} — / para comandos"

      assigns.session.active_channel != nil ->
        "Mensagem para #{assigns.session.active_channel} — / para comandos"

      true ->
        "Digite um comando — / para lista"
    end
  end

  defp filtered_url_catcher_entries(assigns) do
    assigns.url_catcher_entries
    |> CapturedURL.filter_by_source(assigns.url_catcher_filter_channel)
    |> CapturedURL.filter_by_url(assigns.url_catcher_search_query)
    |> CapturedURL.sort_by(assigns.url_catcher_sort_column, assigns.url_catcher_sort_direction)
  end

  defp filtered_help_keywords(assigns) do
    all = HelpTopics.all_keywords()

    case assigns.help_index_filter do
      "" ->
        all

      filter ->
        Enum.filter(all, fn {kw, _id} ->
          String.contains?(String.downcase(kw), String.downcase(filter))
        end)
    end
  end

  defp url_catcher_channels(assigns) do
    assigns.url_catcher_entries
    |> Enum.map(& &1.source)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec build_nick_color_fn(Session.t()) :: (String.t() -> String.t())
  defp build_nick_color_fn(session) do
    fn nickname ->
      NickColors.color_for(session.nick_colors, nickname) || nick_color(nickname)
    end
  end

  @nick_colors ~w(#e74c3c #3498db #2ecc71 #e67e22 #9b59b6 #1abc9c #f39c12 #e91e63 #00bcd4 #8bc34a #ff5722 #607d8b)

  @spec format_content(String.t(), boolean()) :: String.t()
  defp format_content(content, strip_formatting) do
    html =
      if strip_formatting do
        content |> Formatter.strip() |> URLDetector.linkify()
      else
        {:safe, raw} = Formatter.to_safe_html(content)
        URLDetector.linkify_html(raw)
      end

    linkify_channels(html)
  end

  @channel_name_regex ~r/#[a-zA-Z][a-zA-Z0-9_-]{0,49}/
  defp linkify_channels(html) do
    ~r/(<[^>]+>)/
    |> Regex.split(html, include_captures: true)
    |> Enum.map_join(&linkify_channel_part/1)
  end

  defp linkify_channel_part("<" <> _ = tag), do: tag

  defp linkify_channel_part(text) do
    Regex.replace(@channel_name_regex, text, fn match ->
      ~s(<span class="chat-channel-link" data-channel="#{match}">#{match}</span>)
    end)
  end

  defp format_time(%DateTime{} = dt, :hh_mm), do: "[#{Calendar.strftime(dt, "%H:%M")}]"
  defp format_time(%DateTime{} = dt, :hh_mm_ss), do: "[#{Calendar.strftime(dt, "%H:%M:%S")}]"

  defp format_time(%DateTime{} = dt, :dd_mm_hh_mm),
    do: "[#{Calendar.strftime(dt, "%d/%m %H:%M")}]"

  defp format_time(_, :none), do: ""
  defp format_time(%DateTime{} = dt, _), do: "[#{Calendar.strftime(dt, "%H:%M")}]"
  defp format_time(_, _), do: "[--:--]"

  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end
end
