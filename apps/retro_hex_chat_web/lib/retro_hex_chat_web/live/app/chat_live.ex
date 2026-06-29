defmodule RetroHexChatWeb.App.ChatLive do
  @moduledoc """
  Main chat interface using the app UI components.

  This is a full rewrite — no v1 code reuse. The UI is composed entirely from
  the new component library in `components/ui/`. Backend domain contexts and
  PubSub patterns are used directly.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  # ── Shell components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp

  # ── Chat components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.IrcTabs
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.ChatInput
  import RetroHexChatWeb.Components.UI.FormattingToolbar
  import RetroHexChatWeb.Components.UI.Autocomplete
  import RetroHexChatWeb.Components.UI.ReplyBar
  import RetroHexChatWeb.Components.UI.ConnectionStatus
  import RetroHexChatWeb.Components.UI.HoverCard
  import RetroHexChatWeb.Components.UI.SyntaxTooltip
  import RetroHexChatWeb.Components.UI.ChatContextMenu
  import RetroHexChatWeb.Components.UI.ConversationsContextMenu
  import RetroHexChatWeb.Components.UI.HistorySearch
  import RetroHexChatWeb.Components.UI.TypingIndicator
  import RetroHexChatWeb.Components.UI.NicklistContextMenu

  # ── Dialog components ────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.Components.UI.ChannelCentralDialog
  import RetroHexChatWeb.Components.UI.HighlightDialog

  import RetroHexChatWeb.Components.UI.InviteDialog
  import RetroHexChatWeb.Components.UI.NotifyList

  import RetroHexChatWeb.Components.UI.PerformDialog
  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.BotFormDialog
  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, Session}
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.{Motd, Queries}

  alias RetroHexChat.Chat.{
    AutoJoinList,
    CustomMenus,
    DuplicateTracker,
    FloodTracker,
    HighlightWords,
    IgnoreList,
    KeyBindings,
    PerformList,
    UnreadTracker
  }

  alias RetroHexChat.Presence.{NotifyList, Tracker, WhowasCache}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.ChatContext
  alias RetroHexChatWeb.Timezone

  # ── Mount ─────────────────────────────────────────────────────

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(params, http_session, socket) do
    nickname = http_session["chat_nickname"]

    case validate_session_nickname(nickname) do
      :ok ->
        if ServerBans.banned?(nickname) do
          {:ok, push_navigate(socket, to: ~p"/connect?reason=banned")}
        else
          {:ok, mount_chat_session(params, http_session, socket, nickname)}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/connect")}
    end
  end

  defp mount_chat_session(params, http_session, socket, nickname) do
    session = Session.new(nickname)

    if connected?(socket) do
      mount_connected_chat(params, http_session, socket, session, nickname)
    else
      mount_disconnected_chat(http_session, socket, session)
    end
  end

  defp mount_connected_chat(params, http_session, socket, session, nickname) do
    default_channel = Application.get_env(:retro_hex_chat, :default_channel, "#lobby")
    takeover_expected? = takeover_expected?(default_channel, nickname)
    takeover_ref = make_ref()

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "user:#{nickname}",
      {:force_disconnect,
       %{
         reason: dgettext("chat", "Session ended — logged in from another window"),
         takeover_ack: {self(), takeover_ref}
       }}
    )

    if takeover_expected?, do: wait_for_takeover_cleanup(takeover_ref)

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
    previous_nickname = Map.get(socket.assigns.flash, "nick_changed_from")
    pre_identified = http_session["chat_pre_identified"] == true
    join_channel = params["join"]

    ChatLive.Helpers.safe_track_user("presence:global", nickname)

    socket
    |> attach_all_hooks()
    |> assign_defaults(session)
    |> assign(timezone: timezone, client_info: client_info)
    |> ChatLive.Helpers.join_channel(default_channel, session)
    |> ChatLive.Helpers.maybe_join_channel(join_channel)
    |> maybe_broadcast_nick_changed(previous_nickname, nickname)
    |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, pre_identified)
    |> ChatLive.Helpers.maybe_trigger_perform()
    |> ChatLive.Helpers.play_event_sound(:connect, session)
    |> maybe_show_motd()
    |> show_welcome_message()
    |> show_chanserv_announcement()
    |> show_nickserv_announcement()
    |> push_initial_preferences()
  end

  defp takeover_expected?(default_channel, nickname) do
    Tracker.online?("presence:global", nickname) or channel_has_member?(default_channel, nickname)
  end

  defp channel_has_member?(channel_name, nickname) do
    target = String.downcase(nickname)

    case Server.get_state(channel_name) do
      {:ok, state} ->
        Enum.any?(state.members, fn {member, _role} ->
          String.downcase(member) == target
        end)

      {:error, _} ->
        false
    end
  catch
    :exit, _reason -> false
  end

  defp wait_for_takeover_cleanup(ref) do
    receive do
      {:force_disconnect_ack, ^ref} -> :ok
    after
      1_000 ->
        Logger.warning("Timed out waiting for previous chat session takeover cleanup")
        :ok
    end
  end

  defp mount_disconnected_chat(http_session, socket, session) do
    socket
    |> assign_defaults(session)
    |> assign(
      timezone: Timezone.validate(http_session["chat_timezone"]),
      client_info: %{}
    )
  end

  # ── Terminate ─────────────────────────────────────────────────

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      quit_reason = socket.assigns[:quit_reason] || dgettext("chat", "Leaving")

      Queries.update_last_seen_by_nickname(session.nickname)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: session.nickname}}
      )

      ChatLive.Helpers.safe_untrack_user("presence:global", session.nickname)
      WhowasCache.record(session.nickname, session.channels, quit_reason)

      unless socket.assigns[:skip_channel_cleanup] do
        ChatLive.Helpers.cleanup_channels(session, quit_reason)
      end
    end

    :ok
  end

  # ── Event dispatchers ─────────────────────────────────────────
  # App components use compound action events (on_action="toolbar_action" with
  # phx-value-action), but the shared v1 event handlers expect individual events.
  # These dispatchers translate between the two patterns.
  #
  # IMPORTANT: Dispatchers call dispatch_to_hooks/3 (NOT handle_event/3) because
  # handle_event/3 only matches clauses defined in THIS module. The actual event
  # handlers live in attached hook modules (CoreEvents, MenuToolbarEvents, etc.)
  # which are only invoked for events coming from the client. dispatch_to_hooks/3
  # simulates the hook pipeline for internally-dispatched events.

  @impl true

  # Toolbar actions — components emit v1 event names directly
  def handle_event("toolbar_action", %{"action" => action}, socket) do
    dispatch_to_hooks(action, %{}, socket)
  end

  # Tab bar actions → type-specific v1 events
  def handle_event("switch_tab", %{"type" => type, "label" => label}, socket) do
    case type do
      "status" -> dispatch_to_hooks("switch_to_status", %{}, socket)
      "channel" -> dispatch_to_hooks("switch_channel", %{"channel" => label}, socket)
      "pm" -> dispatch_to_hooks("switch_pm", %{"nickname" => label}, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("close_tab", %{"type" => type, "label" => label}, socket) do
    case type do
      "status" -> dispatch_to_hooks("switch_to_status", %{}, socket)
      "channel" -> dispatch_to_hooks("close_channel_tab", %{"channel" => label}, socket)
      "pm" -> dispatch_to_hooks("close_pm_tab", %{"nickname" => label}, socket)
      _ -> {:noreply, socket}
    end
  end

  # Context menus — components emit v1 event names directly
  def handle_event("chat_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  def handle_event("conversations_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  def handle_event("nicklist_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  def handle_event(event, params, socket) do
    dispatch_to_hooks(event, params, socket)
  end

  # ── Catch-all handle_info ─────────────────────────────────────

  @impl true
  def handle_info({_ref, _result}, socket), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_, socket), do: {:noreply, socket}

  # ── Render ────────────────────────────────────────────────────
  # Template is in chat_live.html.heex (auto-detected by Phoenix)

  # ── Private helpers ───────────────────────────────────────────

  @spec validate_session_nickname(String.t() | nil) :: :ok | {:error, String.t()}
  defp validate_session_nickname(nil), do: {:error, dgettext("chat", "No nickname in session")}
  defp validate_session_nickname(nickname), do: NicknameValidator.validate(nickname)

  @spec resolve_timezone(map(), Phoenix.LiveView.Socket.t()) :: String.t()
  defp resolve_timezone(http_session, socket) do
    session_tz = http_session["chat_timezone"]
    connect_params = get_connect_params(socket)
    params_tz = Map.get(connect_params || %{}, "timezone")

    tz =
      cond do
        session_tz && session_tz != "" && session_tz != "Etc/UTC" -> session_tz
        params_tz && params_tz != "" -> params_tz
        true -> "Etc/UTC"
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

  # ── Hook dispatch ─────────────────────────────────────────────
  # Ordered list of event hook functions. Used by both attach_all_hooks/1
  # (to register LiveView hooks) and dispatch_to_hooks/3 (to simulate the
  # hook pipeline for internally-dispatched events).

  @event_hook_fns [
    &ChatLive.EmojiEvents.handle_event/3,
    &ChatLive.UrlCatcherEvents.handle_event/3,
    &ChatLive.InviteEvents.handle_event/3,
    &ChatLive.PmTypingEvents.handle_event/3,
    &ChatLive.AliasEvents.handle_event/3,
    &ChatLive.CustomMenusEvents.handle_event/3,
    &ChatLive.AutorespondEvents.handle_event/3,
    &ChatLive.TimerEvents.handle_event/3,
    &ChatLive.HighlightEvents.handle_event/3,
    &ChatLive.SettingsDialogsEvents.handle_event/3,
    &ChatLive.AccountEvents.handle_event/3,
    &ChatLive.NotifyEvents.handle_event/3,
    &ChatLive.AddressBookEvents.handle_event/3,
    &ChatLive.ConversationsEvents.handle_event/3,
    &ChatLive.ConversationsContextMenuEvents.handle_event/3,
    &ChatLive.ChannelCentralEvents.handle_event/3,
    &ChatLive.NavigationEvents.handle_event/3,
    &ChatLive.SearchEvents.handle_event/3,
    &ChatLive.PerformAutojoinEvents.handle_event/3,
    &ChatLive.ChannelListEvents.handle_event/3,
    &ChatLive.MenuToolbarEvents.handle_event/3,
    &ChatLive.UserLookupEvents.handle_event/3,
    &ChatLive.HoverEvents.handle_event/3,
    &ChatLive.ContextMenuEvents.handle_event/3,
    &ChatLive.TipEvents.handle_event/3,
    &ChatLive.AdminConsoleEvents.handle_event/3,
    &ChatLive.BotEvents.handle_event/3,
    &ChatLive.KeyboardEvents.handle_event/3,
    &ChatLive.ConnectionEvents.handle_event/3,
    &ChatLive.CoreEvents.handle_event/3
  ]

  @spec dispatch_to_hooks(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp dispatch_to_hooks(event, params, socket) do
    result =
      Enum.reduce_while(@event_hook_fns, socket, fn hook_fn, acc ->
        case hook_fn.(event, params, acc) do
          {:halt, updated_socket} -> {:halt, {:halted, updated_socket}}
          {:cont, updated_socket} -> {:cont, updated_socket}
        end
      end)

    case result do
      {:halted, socket} ->
        {:noreply, socket}

      socket ->
        # No hook in @event_hook_fns claimed this event. Log it in dev/test so
        # unrouted events are discoverable, and return the socket untouched so the
        # user session never crashes.
        Logger.debug("ChatLive: unrouted event #{inspect(event)} (no hook claimed it)")
        {:noreply, socket}
    end
  end

  # ── Hooks ─────────────────────────────────────────────────────

  defp attach_all_hooks(socket) do
    event_hooks = [
      {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
      {:url_catcher_events, &ChatLive.UrlCatcherEvents.handle_event/3},
      {:invite_events, &ChatLive.InviteEvents.handle_event/3},
      {:pm_typing_events, &ChatLive.PmTypingEvents.handle_event/3},
      {:alias_events, &ChatLive.AliasEvents.handle_event/3},
      {:custom_menus_events, &ChatLive.CustomMenusEvents.handle_event/3},
      {:autorespond_events, &ChatLive.AutorespondEvents.handle_event/3},
      {:timer_events, &ChatLive.TimerEvents.handle_event/3},
      {:highlight_events, &ChatLive.HighlightEvents.handle_event/3},
      {:settings_dialogs_events, &ChatLive.SettingsDialogsEvents.handle_event/3},
      {:account_events, &ChatLive.AccountEvents.handle_event/3},
      {:notify_events, &ChatLive.NotifyEvents.handle_event/3},
      {:address_book_events, &ChatLive.AddressBookEvents.handle_event/3},
      {:conversations_events, &ChatLive.ConversationsEvents.handle_event/3},
      {:conversations_context_menu_events,
       &ChatLive.ConversationsContextMenuEvents.handle_event/3},
      {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
      {:navigation_events, &ChatLive.NavigationEvents.handle_event/3},
      {:search_events, &ChatLive.SearchEvents.handle_event/3},
      {:perform_autojoin_events, &ChatLive.PerformAutojoinEvents.handle_event/3},
      {:channel_list_events, &ChatLive.ChannelListEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:user_lookup_events, &ChatLive.UserLookupEvents.handle_event/3},
      {:hover_events, &ChatLive.HoverEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:tip_events, &ChatLive.TipEvents.handle_event/3},
      {:admin_console_events, &ChatLive.AdminConsoleEvents.handle_event/3},
      {:bot_events, &ChatLive.BotEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:connection_events, &ChatLive.ConnectionEvents.handle_event/3},
      {:core_events, &ChatLive.CoreEvents.handle_event/3}
    ]

    info_hooks = [
      {:settings_dialogs_info, &ChatLive.SettingsDialogsEvents.handle_info/2},
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

  # ── Assign defaults ───────────────────────────────────────────

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
      context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        target_nick: nil,
        is_target_registered: false
      },
      nick_color_fn: ChatHelpers.build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      hover_card: ChatLive.HoverEvents.default_hover_card(),
      input: "",
      action_mode: false,
      notice_target: nil,
      input_error: nil,
      chat_clear_token: 0,
      cleared_channel_cutoffs: %{},
      link_previews: %{},
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: dgettext("chat", "RetroHexChat"),
      # Search content state (query/results/filters/index/error) is owned by
      # ChatLive.Components.SearchBar. The parent keeps only `search_visible`
      # for Escape-dismissal/overlay coordination (see SearchEvents).
      search_visible: false,
      session: session,
      cheatsheet_visible: false,
      show_address_book: false,
      show_account_dialog: false,
      account_registered: false,
      account_last_away_message: nil,
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
      highlight_selected_color: nil,
      selected_note: "",
      selected_contact_note: "",
      selected_notify_note: "",
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
      show_user_lookup_dialog: false,
      lookup_result: nil,
      whois_output_mode: :card,
      unread_counts: %{},
      url_catcher_entries: [],
      ignore_timers: %{},
      control_selected: nil,
      show_control_add_dialog: false,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_state: nil,
      channel_central_channel: nil,
      channel_central_operator: false,
      channel_central_owner: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      channel_central_notice: nil,
      channel_central_transfer_error: nil,
      channel_central_registration: nil,
      channel_central_access_tab: "sop",
      channel_central_access_selected: nil,
      channel_central_access_nick: "",
      channel_central_cs_error: nil,
      channel_central_cs_confirm_drop: false,
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false,
      show_cc_transfer_dialog: false,
      show_perform_dialog: false,
      perform_dialog_tab: "commands",
      perform_selected: nil,
      show_perform_add_dialog: false,
      show_perform_edit_dialog: false,
      autojoin_selected: nil,
      show_autojoin_add_dialog: false,
      show_autojoin_edit_dialog: false,
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_active_pm: nil,
      knock_timestamps: %{},
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
      show_flood_protection_dialog: false,
      show_sound_settings_dialog: false,
      show_nicklist: true,
      nick_palette_editing_index: nil,
      muted: false,
      muted_channels: MapSet.new(),
      flash_channels: MapSet.new(),
      pm_typing_from: nil,
      pm_typing_timer: nil,
      conversations_context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        type: :channel,
        channel: nil,
        nick: nil
      },
      last_activity_at: DateTime.utc_now(),
      show_alias_dialog: false,
      user_timers: %{},
      autorespond_cooldowns: %{},
      show_custom_menus_dialog: false,
      show_autorespond_dialog: false,
      show_admin_console: false,
      admin_console_results: [],
      admin_console_tab: "console",
      admin_console_motd: nil,
      admin_console_motd_result: nil,
      admin_console_broadcast_result: nil,
      admin_console_turn_stats: nil,
      admin_console_turn_allocations: nil,
      admin_console_turn_result: nil,
      admin_console_audit_log_text: nil,
      admin_console_audit_log_last: "20",
      admin_console_audit_log_user: "",
      admin_console_audit_log_result: nil,
      admin_console_server_settings_info: nil,
      admin_console_server_settings_text: nil,
      admin_console_server_settings_values: %{},
      admin_console_server_settings_result: nil,
      admin_console_users_text: nil,
      admin_console_users_banlist_text: nil,
      admin_console_users_result: nil,
      admin_console_users_search: "",
      admin_console_users_online_only: false,
      admin_console_users_info_nick: "",
      admin_console_channels_text: nil,
      admin_console_channels_banlist_text: nil,
      admin_console_channels_result: nil,
      admin_console_channels_search: "",
      admin_console_channels_info_channel: "",
      admin_console_channels_create_name: "",
      admin_console_danger_zone_preview: nil,
      admin_console_danger_zone_result: nil,
      admin_console_danger_zone_confirm: "",
      admin_console_danger_zone_server_name: "RetroHexChat",
      show_bot_dialog: false,
      bot_dialog_bots: [],
      bot_dialog_selected: nil,
      bot_dialog_channels: [],
      bot_dialog_commands: [],
      bot_dialog_tab: :general,
      bot_dialog_events: [],
      bot_dialog_stats: nil,
      bot_dialog_editing_field: nil,
      show_new_bot_dialog: false,
      show_add_command_dialog: false,
      away_replied_to: MapSet.new(),
      quit_reason: nil,
      show_emoji_picker: false,
      syntax_tooltip: nil,
      command_help_level: :beginner,
      timestamp_format: :dd_mm_hh_mm,
      lag_ms: nil,
      lag_status: :normal,
      loading_channel: nil,
      reply_to: nil,
      edit_mode_message_id: nil,
      edit_original_input: nil,
      nick_change_target: nil,
      nick_change_token: nil,
      show_invite_channel_picker: false,
      show_knock_request_dialog: false,
      show_channel_list: false,
      channel_list_channels: [],
      channel_list_loading: false
    )
  end

  # ── View helpers ──────────────────────────────────────────────

  defp admin?(session), do: ChatContext.admin?(session)

  defp admin_only?(session), do: ChatContext.admin_only?(session)

  defp root_admin?(session), do: ChatContext.root_admin?(session)

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

  defp chat_context_target_ignored?(_session, %{target_nick: nil}), do: false

  defp chat_context_target_ignored?(session, %{target_nick: nick}) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  defp channel_user_op?(users, nick), do: channel_user_role?(users, nick, [:operator])
  defp channel_user_voiced?(users, nick), do: channel_user_role?(users, nick, [:voiced])

  defp channel_user_muted?(users, nick) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :muted, false)
    end
  end

  defp channel_user_role?(users, nick, roles) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :role) in roles
    end
  end

  defp find_channel_user(_users, nil), do: nil

  defp find_channel_user(users, nick) do
    Enum.find(users, &(Map.get(&1, :nickname) == nick))
  end

  defp conversation_context_key(%{type: :pm, nick: nick}) when is_binary(nick), do: "pm:#{nick}"
  defp conversation_context_key(%{type: "pm", nick: nick}) when is_binary(nick), do: "pm:#{nick}"
  defp conversation_context_key(%{channel: channel}) when is_binary(channel), do: channel
  defp conversation_context_key(_context), do: nil

  defp conversation_context_custom_items(_session, %{type: :pm}), do: []
  defp conversation_context_custom_items(_session, %{type: "pm"}), do: []

  defp conversation_context_custom_items(session, _context) do
    CustomMenus.entries_for(session.custom_menus, :channel)
  end

  defp channel_central_bans(nil), do: []

  defp channel_central_bans(state) do
    state |> Map.get(:bans, []) |> Enum.map(&to_list_entry/1)
  end

  defp channel_central_ban_exceptions(nil), do: []

  defp channel_central_ban_exceptions(state) do
    state |> Map.get(:ban_exceptions, []) |> Enum.map(&to_list_entry/1)
  end

  defp channel_central_invite_exceptions(nil), do: []

  defp channel_central_invite_exceptions(state) do
    state |> Map.get(:invite_exceptions, []) |> Enum.map(&to_list_entry/1)
  end

  defp channel_central_modes(nil), do: %{}
  defp channel_central_modes(state), do: Map.get(state, :modes_detail, %{})

  defp channel_central_welcome_message(nil), do: ""

  defp channel_central_welcome_message(state) do
    state
    |> Map.get(:welcome_message)
    |> case do
      %{message: message} when is_binary(message) -> message
      _ -> ""
    end
  end

  defp channel_central_throttle_seconds(nil), do: 0

  defp channel_central_throttle_seconds(state) do
    state
    |> Map.get(:modes_detail, %{})
    |> Map.get(:join_throttle)
    |> case do
      {_count, seconds} when is_integer(seconds) -> seconds
      _ -> 0
    end
  end

  defp chat_action_enabled?(session, show_status_tab) do
    !show_status_tab and session.active_pm == nil and session.active_channel != nil
  end

  @spec to_list_entry(map() | String.t()) :: map()
  defp to_list_entry(%{mask: _} = map), do: map
  defp to_list_entry(nick) when is_binary(nick), do: %{mask: nick, set_by: "—", set_at: "—"}

  defp channel_central_topic(nil), do: ""
  defp channel_central_topic(state), do: Map.get(state, :topic, "")

  defp channel_central_topic_set_by(nil), do: nil
  defp channel_central_topic_set_by(state), do: Map.get(state, :topic_set_by)

  defp channel_central_topic_set_at(nil, _tz), do: nil

  defp channel_central_topic_set_at(state, timezone) do
    case Map.get(state, :topic_set_at) do
      nil -> nil
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_created_at(nil, _tz), do: nil

  defp channel_central_created_at(state, timezone) do
    case Map.get(state, :created_at) do
      nil -> nil
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_member_count(nil), do: 0
  defp channel_central_member_count(state), do: Map.get(state, :member_count, 0)

  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  defp online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  defp online_buddy_count(_notify_list), do: 0

  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, nick) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  # ── Startup messages ──────────────────────────────────────────

  defp maybe_show_motd(socket) do
    case Motd.get() do
      nil -> socket
      content -> ChatLive.Helpers.push_status_message(socket, content, :motd)
    end
  end

  defp maybe_broadcast_nick_changed(socket, old_nickname, new_nickname)
       when is_binary(old_nickname) and old_nickname != "" and old_nickname != new_nickname do
    Enum.each(socket.assigns.session.channels, fn channel ->
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel}",
        {:nick_changed, %{old_nick: old_nickname, new_nick: new_nickname, channel: channel}}
      )
    end)

    socket
  end

  defp maybe_broadcast_nick_changed(socket, _old_nickname, _new_nickname), do: socket

  defp show_welcome_message(socket) do
    server_name = Queries.get_setting("server_name") || dgettext("chat", "RetroHexChat")

    lines = [
      dgettext("chat", "Welcome to %{server_name}!", server_name: server_name),
      dgettext("chat", "A real-time chat platform with a retro look and feel."),
      "",
      dgettext("chat", "Useful commands:"),
      dgettext("chat", "  /join #channel   — Join a channel"),
      dgettext("chat", "  /msg nick text   — Send a private message"),
      dgettext("chat", "  /nick new_nick   — Change your nickname"),
      dgettext("chat", "  /help            — View full help"),
      dgettext("chat", "  /help commands   — List all commands"),
      "",
      dgettext("chat", "Tip: Go to Help > Help Topics for the full documentation.") <>
        " " <> dgettext("chat", "Open /chat/help in a new tab.")
    ]

    socket =
      Enum.reduce(lines, socket, fn line, acc ->
        ChatLive.Helpers.push_status_message(acc, line, :system)
      end)

    case Queries.get_setting("welcome_message") do
      nil -> socket
      msg -> ChatLive.Helpers.push_status_message(socket, msg, :system)
    end
  end

  defp show_chanserv_announcement(socket) do
    lines = [
      "",
      dgettext("chat", "[ChanServ] Channel Services Online"),
      dgettext("chat", "ChanServ manages channel registration and access control."),
      dgettext("chat", "Register your channel to protect it when no operators are online."),
      "",
      dgettext("chat", "Quick start:"),
      dgettext("chat", "  /cs register #channel          — Register a channel you operate"),
      dgettext("chat", "  /cs sop #channel add <nick>    — Add a Super Operator"),
      dgettext("chat", "  /cs aop #channel add <nick>    — Add an Auto Operator"),
      dgettext("chat", "  /cs vop #channel add <nick>    — Add an Auto Voice user"),
      dgettext("chat", "  /cs info #channel              — View channel registration info"),
      "",
      dgettext("chat", "Access hierarchy: Owner > SOP > AOP > VOP"),
      "",
      dgettext("chat", "Rules:"),
      dgettext("chat", "  • Channels expire after 7 days of inactivity"),
      dgettext("chat", "  • If a founder's nick expires, the next ranked user is promoted"),
      "",
      dgettext("chat", "Type /help chanserv or /help channel-permissions for full details.")
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      ChatLive.Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp show_nickserv_announcement(socket) do
    lines = [
      "",
      dgettext("chat", "[NickServ] Nickname Services Online"),
      dgettext(
        "chat",
        "NickServ protects your nickname with a password so nobody else can use it."
      ),
      "",
      dgettext("chat", "Quick start:"),
      dgettext("chat", "  /ns register <password>   — Register your current nickname"),
      dgettext("chat", "  /ns identify <password>   — Identify (log in) for this session"),
      dgettext("chat", "  /ns info [nickname]       — Look up registration info"),
      dgettext("chat", "  /ns ghost <nick> <pass>   — Disconnect a ghost session"),
      dgettext("chat", "  /ns drop <password>       — Permanently unregister your nickname"),
      "",
      dgettext("chat", "Rules:"),
      dgettext("chat", "  • Nicks are case sensitive — \"Alice\" and \"alice\" are different"),
      dgettext("chat", "  • Nicks expire after 7 days of inactivity"),
      dgettext("chat", "  • Switching to a registered nick gives you 60s to identify"),
      "",
      dgettext("chat", "Type /help nickserv for full details.")
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      ChatLive.Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp push_initial_preferences(socket) do
    socket
    |> push_event("update_bindings", %{
      bindings: KeyBindings.to_persistable(KeyBindings.defaults())
    })
  end
end
