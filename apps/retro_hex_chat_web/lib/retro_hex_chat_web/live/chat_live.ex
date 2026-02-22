defmodule RetroHexChatWeb.ChatLive do
  @moduledoc """
  Main chat interface with MDI layout: conversations sidebar, chat area, nicklist, status bar.
  """
  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, Session}
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.{Motd, Queries}

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    CapturedURL,
    CustomMenus,
    DisplayPreferences,
    DuplicateTracker,
    EmojiData,
    FloodTracker,
    Formatter,
    HighlightWords,
    IgnoreList,
    KeyBindings,
    LogFilter,
    PerformList,
    URLDetector
  }

  alias RetroHexChat.Presence.{NotifyList, WhowasCache}
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.Helpers
  alias RetroHexChatWeb.Timezone

  @impl true
  def mount(_params, http_session, socket) do
    nickname = http_session["chat_nickname"]

    case validate_session_nickname(nickname) do
      :ok ->
        session = Session.new(nickname)
        pre_identified = http_session["chat_pre_identified"] == true
        join_channel = http_session["chat_join_channel"]

        if connected?(socket) do
          # Kick any existing sessions for this nick BEFORE subscribing
          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "user:#{nickname}",
            {:force_disconnect, %{reason: "Session ended — logged in from another window"}}
          )

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

          timezone = resolve_timezone(http_session, socket)
          client_info = parse_client_info(get_connect_params(socket))

          socket =
            socket
            |> attach_all_hooks()
            |> assign_defaults(session)
            |> assign(timezone: timezone, client_info: client_info, connection_ready: true)
            |> Helpers.join_channel(
              Application.get_env(:retro_hex_chat, :default_channel, "#lobby"),
              session
            )
            |> Helpers.maybe_join_channel(join_channel)
            |> Helpers.maybe_start_nickserv_timer(nickname, pre_identified)
            |> Helpers.maybe_trigger_perform()
            |> Helpers.play_event_sound(:connect, session)
            |> maybe_show_motd()
            |> show_welcome_message()
            |> show_chanserv_announcement()
            |> show_nickserv_announcement()
            |> push_initial_preferences()

          {:ok, socket}
        else
          {:ok,
           assign_defaults(socket, session)
           |> assign(
             timezone: Timezone.validate(http_session["chat_timezone"]),
             client_info: %{},
             connection_progress_step: 1
           )}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/connect")}
    end
  end

  @spec validate_session_nickname(String.t() | nil) :: :ok | {:error, String.t()}
  defp validate_session_nickname(nil), do: {:error, "No nickname in session"}

  defp validate_session_nickname(nickname), do: NicknameValidator.validate(nickname)

  @spec resolve_timezone(map(), Phoenix.LiveView.Socket.t()) :: String.t()
  defp resolve_timezone(http_session, socket) do
    session_tz = http_session["chat_timezone"]
    connect_params = get_connect_params(socket)
    params_tz = Map.get(connect_params || %{}, "timezone")

    tz =
      cond do
        session_tz && session_tz != "" && session_tz != "Etc/UTC" ->
          session_tz

        params_tz && params_tz != "" ->
          params_tz

        true ->
          "Etc/UTC"
      end

    Timezone.validate(tz)
  end

  @allowed_client_keys %{
    "browser" => :browser,
    "os" => :os,
    "language" => :language,
    "screen" => :screen,
    "color_depth" => :color_depth,
    "touch" => :touch,
    "cores" => :cores,
    "timezone" => :timezone
  }
  @max_string_length 100

  @spec parse_client_info(map() | nil) :: map()
  defp parse_client_info(nil), do: %{}

  defp parse_client_info(params) do
    case params["client_info"] do
      json when is_binary(json) -> decode_client_json(json)
      _ -> %{}
    end
  end

  defp decode_client_json(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) ->
        Map.new(@allowed_client_keys, fn {str_key, atom_key} ->
          {atom_key, sanitize_client_value(data[str_key])}
        end)

      _ ->
        %{}
    end
  end

  defp sanitize_client_value(val) when is_binary(val),
    do: String.slice(val, 0, @max_string_length)

  defp sanitize_client_value(val) when is_integer(val), do: val
  defp sanitize_client_value(val) when is_boolean(val), do: val
  defp sanitize_client_value(_), do: nil

  defp attach_all_hooks(socket) do
    event_hooks = [
      {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
      {:options_events, &ChatLive.OptionsEvents.handle_event/3},
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
      {:conversations_events, &ChatLive.ConversationsEvents.handle_event/3},
      {:conversations_context_menu_events,
       &ChatLive.ConversationsContextMenuEvents.handle_event/3},
      {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
      {:log_viewer_events, &ChatLive.LogViewerEvents.handle_event/3},
      {:navigation_events, &ChatLive.NavigationEvents.handle_event/3},
      {:search_events, &ChatLive.SearchEvents.handle_event/3},
      {:perform_autojoin_events, &ChatLive.PerformAutojoinEvents.handle_event/3},
      {:channel_list_events, &ChatLive.ChannelListEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:hover_events, &ChatLive.HoverEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:notification_events, &ChatLive.NotificationEvents.handle_event/3},
      {:tip_events, &ChatLive.TipEvents.handle_event/3},
      {:kick_events, &ChatLive.KickEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:connection_events, &ChatLive.ConnectionEvents.handle_event/3},
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
      autocomplete_command: nil,
      autocomplete_filter: "",
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0,
      autocomplete_visible: false,
      recent_commands: [],
      contacts_selected: nil,
      chat_context_menu: %{
        visible: false,
        type: nil,
        x: 0,
        y: 0,
        target_nick: nil,
        target_url: nil,
        target_channel: nil,
        target_message: nil,
        has_selection: false,
        is_target_registered: false
      },
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil, is_target_registered: false},
      nick_color_fn: build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      hover_card: ChatLive.HoverEvents.default_hover_card(),
      input: "",
      link_previews: %{},
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: "RetroHexChat",
      search_case_sensitive: false,
      search_current_index: 0,
      search_error: nil,
      search_history: false,
      search_history_count: 0,
      search_last_query: "",
      search_my_mentions: false,
      search_query: "",
      search_regex: false,
      search_result_count: 0,
      search_results: [],
      search_visible: false,
      session: session,
      tips_suppressed: false,
      cheatsheet_visible: false,
      show_about: false,
      show_address_book: false,
      show_context_color_picker: false,
      show_contact_add_dialog: false,
      show_contact_edit_dialog: false,
      address_book_tab: "contacts",
      show_nick_color_add_dialog: false,
      show_nick_color_edit_dialog: false,
      show_status_tab: false,
      status_unread: false,
      show_notify_add_dialog: false,
      show_notify_edit_dialog: false,
      show_notify_list: false,
      highlight_channels: MapSet.new(),
      highlight_selected: nil,
      show_highlight_add_dialog: false,
      show_highlight_dialog: false,
      show_highlight_edit_dialog: false,
      current_topic: nil,
      current_modes: nil,
      show_conversations: true,
      channel_user_counts: %{},
      popular_channels: [],
      popular_channels_loaded: false,
      conversations_sections: %{channels: true, pms: true, popular: false},
      show_url_catcher: false,
      show_whois: false,
      unread_counts: %{},
      kick_queue: [],
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
      nick_palette_editing_index: nil,
      muted: false,
      muted_channels: MapSet.new(),
      flash_channels: MapSet.new(),
      pm_typing_from: nil,
      pm_typing_timer: nil,
      conversations_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
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
      command_help_level: :beginner,
      timestamp_format: :dd_mm_hh_mm,
      connection_ready: false,
      connection_state: :connected,
      connection_progress_step: 1,
      connection_timeout: false,
      lag_ms: nil,
      lag_status: :normal,
      loading_channel: nil,
      notification_entries: [],
      notification_count: 0,
      show_notification_center: false,
      dnd_enabled: session.user_preferences.notifications.dnd_enabled,
      reply_to: nil,
      edit_mode_message_id: nil,
      edit_original_input: nil,
      delete_confirm: nil,
      nick_change_dialog: nil,
      nick_change_target: nil,
      nick_change_token: nil,
      show_channel_list: false,
      channel_list_channels: [],
      channel_list_filtered: [],
      channel_list_search: "",
      channel_list_loading: false,
      channel_list_count: 0
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

      Queries.update_last_seen_by_nickname(session.nickname)

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

  defp quit_reason_for(socket, _session) do
    socket.assigns[:quit_reason] || "Leaving"
  end

  defp maybe_show_motd(socket) do
    case Motd.get() do
      nil -> socket
      content -> Helpers.push_status_message(socket, content, :motd)
    end
  end

  defp show_welcome_message(socket) do
    lines = [
      "Welcome to RetroHexChat!",
      "A real-time chat platform with a retro look and feel.",
      "",
      "Useful commands:",
      "  /join #channel   — Join a channel",
      "  /msg nick text   — Send a private message",
      "  /nick new_nick   — Change your nickname",
      "  /help            — View full help",
      "  /help commands   — List all commands",
      "",
      "Tip: Go to Help > Help Topics for the full documentation, or open /chat/help in a new tab."
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      Helpers.push_status_message(acc, line, :system)
    end)
  end

  defp show_chanserv_announcement(socket) do
    lines = [
      "",
      "[ChanServ] Channel Services Online",
      "ChanServ manages channel registration and access control.",
      "Register your channel to protect it when no operators are online.",
      "",
      "Quick start:",
      "  /cs register #channel          — Register a channel you operate",
      "  /cs sop #channel add <nick>    — Add a Super Operator",
      "  /cs aop #channel add <nick>    — Add an Auto Operator",
      "  /cs vop #channel add <nick>    — Add an Auto Voice user",
      "  /cs info #channel              — View channel registration info",
      "",
      "Access hierarchy: Owner > SOP > AOP > VOP",
      "",
      "Rules:",
      "  • Channels expire after 7 days of inactivity",
      "  • If a founder's nick expires, the next ranked user is promoted",
      "",
      "Type /help chanserv or /help channel-permissions for full details."
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp show_nickserv_announcement(socket) do
    lines = [
      "",
      "[NickServ] Nickname Services Online",
      "NickServ protects your nickname with a password so nobody else can use it.",
      "",
      "Quick start:",
      "  /ns register <password>   — Register your current nickname",
      "  /ns identify <password>   — Identify (log in) for this session",
      "  /ns info [nickname]       — Look up registration info",
      "  /ns ghost <nick>          — Disconnect a ghost session",
      "  /ns drop <password>       — Permanently unregister your nickname",
      "",
      "Rules:",
      "  • Nicks are case sensitive — \"Alice\" and \"alice\" are different",
      "  • Nicks expire after 7 days of inactivity",
      "  • Switching to a registered nick gives you 60s to identify",
      "",
      "Type /help nickserv for full details."
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp push_initial_preferences(socket) do
    socket
    |> push_event("update_bindings", %{
      bindings: KeyBindings.to_persistable(KeyBindings.defaults())
    })
  end

  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, target_nick) do
    IgnoreList.get_entry(session.ignore_list, target_nick) != nil
  end

  defp chat_context_target_ignored?(_session, %{target_nick: nil}), do: false

  defp chat_context_target_ignored?(session, %{target_nick: nick}) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
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
        "Type a command — / for list"

      assigns.session.active_pm != nil ->
        "Message to #{assigns.session.active_pm} — / for commands"

      assigns.session.active_channel != nil ->
        "Message to #{assigns.session.active_channel} — / for commands"

      true ->
        "Type a command — / for list"
    end
  end

  defp filtered_url_catcher_entries(assigns) do
    assigns.url_catcher_entries
    |> CapturedURL.filter_by_source(assigns.url_catcher_filter_channel)
    |> CapturedURL.filter_by_url(assigns.url_catcher_search_query)
    |> CapturedURL.sort_by(assigns.url_catcher_sort_column, assigns.url_catcher_sort_direction)
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

  # All colors ≥4.5:1 contrast on white (WCAG AA)
  @nick_colors ~w(#c0392b #2471a3 #1e8449 #b9770e #7d3c98 #148f77 #b7950b #c2185b #00838f #558b2f #d84315 #455a64)

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

  defp format_time(%DateTime{} = dt, :hh_mm, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")}]"

  defp format_time(%DateTime{} = dt, :hh_mm_ss, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M:%S")}]"

  defp format_time(%DateTime{} = dt, :dd_mm_hh_mm, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%d/%m %H:%M")}]"

  defp format_time(_, :none, _tz), do: ""

  defp format_time(%DateTime{} = dt, _, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")}]"

  defp format_time(_, _, _tz), do: "[--:--]"

  @spec format_edit_timestamp(DateTime.t() | any(), String.t()) :: String.t()
  defp format_edit_timestamp(%DateTime{} = dt, tz) do
    dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M %d/%m/%Y")
  end

  defp format_edit_timestamp(_, _tz), do: "--:--"

  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end

  @spec extract_p2p_label(String.t()) :: String.t()
  defp extract_p2p_label(content) when is_binary(content) do
    case String.split(content, ". Join the lobby:") do
      [label | _] -> label
      _ -> content
    end
  end

  @spec extract_p2p_link(String.t()) :: String.t()
  defp extract_p2p_link(content) when is_binary(content) do
    case Regex.run(~r{(/p2p/[^\s]+)}, content) do
      [_, path] -> path
      _ -> "#"
    end
  end
end
