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

  # ── Shell + tab glue (compose the design-system shell/tab components) ─────────
  import RetroHexChatWeb.ChatLive.Components.ChatShell
  import RetroHexChatWeb.ChatLive.Components.ChatTabs

  # ── Chat components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.ChatMobileActions
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.ChatTaskbar
  import RetroHexChatWeb.Components.UI.ChannelViewSwitcher
  import RetroHexChatWeb.Components.UI.ConnectionStatus
  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.SpaceCharacterSelect
  import RetroHexChatWeb.Components.UI.SpaceFullscreenToggle
  import RetroHexChatWeb.Components.UI.SpaceVirtualPad

  # ── Desktop window manager ───────────────────────────────────
  import RetroHexChatWeb.Components.UI.Desktop

  # ── P2P session setup + console ──────────────────────────────
  import RetroHexChatWeb.Components.UI.P2P.SetupDialog
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge
  import RetroHexChatWeb.Components.UI.GroupCall.PreJoinDialog

  # ── Solo arcade window body ──────────────────────────────────
  import RetroHexChatWeb.Components.UI.SoloLobby

  # ── Dialog components ────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.AboutDialog

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{NicknameValidator, Session}
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.{Motd, Queries}
  alias RetroHexChat.VirtualSpace.{ChannelJoinToken, DirectMessageSpace}

  alias RetroHexChat.Chat.{
    DuplicateTracker,
    FloodTracker,
    KeyBindings
  }

  alias RetroHexChat.Presence.{Tracker, WhowasCache}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.App.ComposerEvents
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.ChatContext
  alias RetroHexChatWeb.ChatLive.Components.{ConversationsContextMenu, UserContextMenus}
  alias RetroHexChatWeb.Icons
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
    connect_params = get_connect_params(socket) || %{}
    client_info = SessionHelpers.parse_client_info(connect_params)
    reconnecting? = connect_params["reconnect"] == true
    previous_nickname = Map.get(socket.assigns.flash, "nick_changed_from")
    pre_identified = http_session["chat_pre_identified"] == true
    join_channel = params["join"]

    ChatLive.Helpers.safe_track_user("presence:global", nickname)

    socket =
      socket
      |> attach_all_hooks()
      |> assign_defaults(session)
      |> assign(timezone: timezone, client_info: client_info)
      |> ChatLive.Helpers.join_channel(default_channel, session)
      |> ChatLive.Helpers.maybe_join_channel(join_channel)
      |> maybe_broadcast_nick_changed(previous_nickname, nickname)
      |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, pre_identified, reconnecting?)
      |> ChatLive.Helpers.maybe_trigger_perform()
      |> ChatLive.P2PSessionEvents.rehydrate()

    # A reconnect (deploy / socket drop) or a reload of a live session restores
    # silently: replaying the connect sound, MOTD, welcome and announcements on
    # every deploy is just noise. Only a fresh first login gets the full greeting.
    if reconnecting? do
      push_initial_preferences(socket)
    else
      socket
      |> ChatLive.Helpers.play_event_sound(:connect, session)
      |> maybe_show_motd()
      |> show_welcome_message()
      |> show_chanserv_announcement()
      |> show_nickserv_announcement()
      |> push_initial_preferences()
    end
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

      ChatLive.ArcadeSessionEvents.close_on_terminate(socket)
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
  def handle_event("toolbar_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
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

  def handle_event("switch_channel_view", %{"view" => view}, socket)
      when view in ["chat", "space"] do
    channel_view = if view == "space", do: :space, else: :chat
    # Entering the space always shows the character picker first (space_avatar
    # nil gates the canvas mount); leaving it drops back to chat.
    {:noreply, assign(socket, channel_view: channel_view, space_avatar: nil)}
  end

  def handle_event("space_select_avatar", %{"avatar" => avatar}, socket) do
    if avatar in socket.assigns.space_avatars do
      {:noreply, assign(socket, space_avatar: avatar, space_last_avatar: avatar)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_all_context_menus", _params, socket) do
    {:noreply, close_all_context_menus(socket)}
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

  # Desktop window manager: the WindowManagerHook asks the host to mount a
  # server-managed window it doesn't know ("window_open") and reports a
  # client-side close of one ("window_closed"). Non-managed ids are no-ops.
  def handle_event("window_open", %{"id" => id}, socket) do
    {:noreply, ChatLive.Windows.open_window(socket, id)}
  end

  def handle_event(
        "window_closed",
        %{"id" => id} = params,
        %{assigns: %{group_call: %{}}} = socket
      )
      when id == "group-call" do
    dispatch_to_hooks("group_call_window_close", params, socket)
  end

  def handle_event("window_closed", %{"id" => id}, socket) do
    {:noreply, ChatLive.Windows.close_window(socket, id)}
  end

  def handle_event(event, params, socket) do
    dispatch_to_hooks(event, params, socket)
  end

  # ── Composer bubbles ──────────────────────────────────────────
  # The Composer LiveComponent owns the input flow and bubbles semantic
  # commands here so the privileged Parser/CommandDispatch/Service work runs
  # on this LiveView.

  @impl true
  def handle_info({:composer_dispatch, text, reply_to}, socket) do
    {:noreply, ChatLive.CoreEvents.dispatch_composer_input(socket, text, reply_to)}
  end

  def handle_info({:composer_submit_edit, content}, socket) do
    {:noreply, ChatLive.CoreEvents.submit_composer_edit(socket, content)}
  end

  def handle_info(:composer_empty_edit, socket) do
    {:noreply, ChatLive.CoreEvents.empty_composer_edit(socket)}
  end

  def handle_info({:composer_notice_active, active}, socket) do
    {:noreply, assign(socket, notice_active: active)}
  end

  # System lines deferred out of a form-submit ack cycle: a stream insert that
  # rides the same ack diff that closes the submitting modal is dropped
  # client-side, so the line must travel in its own diff.
  def handle_info({:deferred_system_event, message}, socket) do
    {:noreply, ChatLive.Helpers.system_event(socket, message)}
  end

  # Channel Central bubbles errors that belong to the chat surface (system lines).
  def handle_info({:cc_system_error, message}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, message)}
  end

  # Admin Console bubbles the same way.
  def handle_info({:admin_system_error, message}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, message)}
  end

  # Perform and Auto-Join bubble validation errors to the chat surface.
  def handle_info({:perform_system_error, message}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, message)}
  end

  def handle_info({:autojoin_system_error, message}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, message)}
  end

  # Perform/Auto-Join list mutations: the dialog owns the work; the parent owns the
  # session read-model and the fire-and-forget persistence.
  def handle_info({:perform_dialog_session, session}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_perform_list(session)}
  end

  def handle_info({:autojoin_dialog_session, session}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_autojoin_list(session)}
  end

  # Invite queue dialog: the island renders the queue + routes the Join/Ignore
  # clicks here; the parent owns `pending_invites` (the Escape-priority read-model
  # + the per-invite expiration timers fire into this process's handle_info).
  def handle_info({:invite_accept, channel}, socket) do
    {:noreply, ChatLive.InviteEvents.accept(socket, channel)}
  end

  def handle_info({:invite_ignore, channel}, socket) do
    {:noreply, ChatLive.InviteEvents.ignore(socket, channel)}
  end

  # Highlight dialog: the dialog owns the work; the parent owns the session
  # read-model + persistence and the status-bar surface.
  def handle_info({:highlight_dialog_session, session}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_highlight_words(session)}
  end

  def handle_info({:highlight_status_error, message}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, message, :error)}
  end

  # Notify List dialog: the island owns the work; the parent owns the session
  # read-model + persistence, the status bar, and the notify debounce timers.
  def handle_info({:notify_dialog_session, session}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_notify_list(session)}
  end

  def handle_info({:notify_dialog_status, message}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, message, :system)}
  end

  def handle_info({:notify_dialog_cancel_timer, nick}, socket) do
    {:noreply, ChatLive.Helpers.cancel_notify_timer(socket, nick)}
  end

  # Address Book dialog: the island owns the UI + runs the domain mutations; the
  # parent owns the session read-model, persistence, the nick-color render fn, the
  # status surface and the ignore debounce timers.
  def handle_info({:ab_session, session, :contacts}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_contacts(session)}
  end

  def handle_info({:ab_session, session, :nick_colors}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.rebuild_nick_color_fn(session)
     |> ChatLive.Helpers.refresh_active_message_stream(session)
     |> ChatLive.Helpers.maybe_persist_nick_colors(session)}
  end

  def handle_info({:ab_session, session, :ignore}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_ignore_list(session)}
  end

  def handle_info({:ab_session, session, :notify}, socket) do
    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_notify_list(session)}
  end

  def handle_info({:ab_status, :system, msg}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, msg, :system)}
  end

  def handle_info({:ab_status, :error, msg}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, msg, :error)}
  end

  def handle_info({:ab_status, :system_event, msg}, socket) do
    {:noreply, ChatLive.Helpers.system_event(socket, msg)}
  end

  def handle_info({:ab_status, :error_event, msg}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, msg)}
  end

  def handle_info({:ab_ignore_timer, :restart, nick, duration}, socket) do
    {:noreply,
     socket
     |> ChatLive.Helpers.cancel_ignore_timer(nick)
     |> ChatLive.Helpers.maybe_start_ignore_timer(nick, duration)}
  end

  def handle_info({:ab_ignore_timer, :remove, nick}, socket) do
    {:noreply,
     socket
     |> ChatLive.Helpers.cancel_ignore_timer(nick)
     |> ChatLive.Helpers.cancel_auto_ignore_with_cooldown(nick)}
  end

  # Islands drive their own server-managed window lifecycle with these messages:
  # the host mounts/unmounts a managed window by toggling @open_windows.
  def handle_info({:open_window, id}, socket),
    do: {:noreply, ChatLive.Windows.open_window(socket, id)}

  def handle_info({:close_window, id}, socket),
    do: {:noreply, ChatLive.Windows.close_window(socket, id)}

  # Channel Central mirrors its open channel up for the window title/taskbar.
  def handle_info({:cc_window_channel, channel}, socket),
    do: {:noreply, assign(socket, cc_window_channel: channel)}

  # Deferred island directive from ChatLive.Windows.open_with/4 — runs one
  # message hop after the mount so the client can patch the component.
  def handle_info({:window_send_update, module, assigns}, socket) do
    send_update(module, assigns)
    {:noreply, socket}
  end

  # ── Catch-all handle_info ─────────────────────────────────────

  def handle_info({_ref, _result}, socket), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_, socket), do: {:noreply, socket}

  # ── Render ────────────────────────────────────────────────────
  # Template is in chat_live.html.heex (auto-detected by Phoenix)

  # ── Private helpers ───────────────────────────────────────────

  defp close_all_context_menus(socket) do
    send_update(UserContextMenus,
      id: UserContextMenus.id(),
      chat_context_menu: UserContextMenus.chat_closed(),
      context_menu: UserContextMenus.nick_closed(),
      show_context_color_picker: false
    )

    send_update(ConversationsContextMenu,
      id: ConversationsContextMenu.id(),
      visible: false,
      x: 0,
      y: 0,
      type: :channel,
      channel: nil,
      nick: nil
    )

    socket
  end

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

  # ── Hook dispatch ─────────────────────────────────────────────
  # Ordered list of event hook functions. Used by both attach_all_hooks/1
  # (to register LiveView hooks) and dispatch_to_hooks/3 (to simulate the
  # hook pipeline for internally-dispatched events).

  @event_hook_fns [
    &ChatLive.EmojiEvents.handle_event/3,
    &ChatLive.UrlCatcherEvents.handle_event/3,
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
    &ChatLive.PerformEvents.handle_event/3,
    &ChatLive.AutojoinEvents.handle_event/3,
    &ChatLive.ChannelListEvents.handle_event/3,
    &ChatLive.MenuToolbarEvents.handle_event/3,
    &ChatLive.UserLookupEvents.handle_event/3,
    &ChatLive.HoverEvents.handle_event/3,
    &ChatLive.ContextMenuEvents.handle_event/3,
    &ChatLive.TipEvents.handle_event/3,
    &ChatLive.AdminEvents.handle_event/3,
    &ChatLive.BotEvents.handle_event/3,
    &ChatLive.KeyboardEvents.handle_event/3,
    &ChatLive.ConnectionEvents.handle_event/3,
    &ChatLive.GroupCallEvents.handle_event/3,
    &ChatLive.P2PSessionEvents.handle_event/3,
    &ChatLive.ArcadeSessionEvents.handle_event/3,
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
      {:perform_events, &ChatLive.PerformEvents.handle_event/3},
      {:autojoin_events, &ChatLive.AutojoinEvents.handle_event/3},
      {:channel_list_events, &ChatLive.ChannelListEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:composer_events, &ComposerEvents.handle_event/3},
      {:user_lookup_events, &ChatLive.UserLookupEvents.handle_event/3},
      {:hover_events, &ChatLive.HoverEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:tip_events, &ChatLive.TipEvents.handle_event/3},
      {:admin_events, &ChatLive.AdminEvents.handle_event/3},
      {:bot_events, &ChatLive.BotEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:connection_events, &ChatLive.ConnectionEvents.handle_event/3},
      {:group_call_events, &ChatLive.GroupCallEvents.handle_event/3},
      {:p2p_session_events, &ChatLive.P2PSessionEvents.handle_event/3},
      {:arcade_session_events, &ChatLive.ArcadeSessionEvents.handle_event/3},
      {:core_events, &ChatLive.CoreEvents.handle_event/3}
    ]

    info_hooks = [
      {:settings_dialogs_info, &ChatLive.SettingsDialogsEvents.handle_info/2},
      {:timer_handlers, &ChatLive.TimerHandlers.handle_info/2},
      {:pubsub_handlers, &ChatLive.PubsubHandlers.handle_info/2},
      # After PubsubHandlers: it consumes "lobby_invite" (user topic) first;
      # this one owns the session-topic "lobby_*" events.
      {:p2p_session_info, &ChatLive.P2PSessionEvents.handle_info/2},
      # Owns the "arcade:#{token}" topic events for the in-chat solo arcade.
      {:arcade_session_info, &ChatLive.ArcadeSessionEvents.handle_info/2}
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
      live_ready: connected?(socket),
      open_windows: MapSet.new(),
      nick_color_fn: ChatHelpers.build_nick_color_fn(session),
      has_more: true,
      notice_active: false,
      chat_clear_token: 0,
      cleared_channel_cutoffs: %{},
      loading_more: false,
      messages: %{},
      notify_debounce_timers: %{},
      oldest_message_id: nil,
      page_title: dgettext("chat", "RetroHexChat"),
      # Search content state (query/results/filters/index/error) is owned by
      # ChatLive.Components.SearchBar. The parent keeps only `search_visible`
      # for Escape-dismissal/overlay coordination (see SearchEvents).
      search_visible: false,
      session: session,
      account_registered: false,
      account_last_away_message: nil,
      show_status_tab: false,
      open_pm_tabs: [],
      status_unread: false,
      highlight_channels: MapSet.new(),
      current_topic: nil,
      current_modes: nil,
      show_conversations: true,
      channel_user_counts: %{},
      popular_channels: [],
      popular_channels_loaded: false,
      conversations_sections: %{channels: true, pms: true, popular: false},
      lookup_result: nil,
      cc_window_channel: nil,
      unread_counts: %{},
      url_catcher_entries: [],
      ignore_timers: %{},
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_active_pm: nil,
      reconnect_open_pm_tabs: [],
      knock_timestamps: %{},
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
      show_nicklist: true,
      muted: false,
      muted_channels: MapSet.new(),
      flash_channels: MapSet.new(),
      disconnected_channels: MapSet.new(),
      pm_typing_from: nil,
      pm_typing_timer: nil,
      last_activity_at: DateTime.utc_now(),
      user_timers: %{},
      autorespond_cooldowns: %{},
      away_replied_to: MapSet.new(),
      quit_reason: nil,
      show_emoji_picker: false,
      timestamp_format: :dd_mm_hh_mm,
      lag_ms: nil,
      lag_status: :normal,
      loading_channel: nil,
      edit_mode_message_id: nil,
      nick_change_target: nil,
      nick_change_token: nil,
      show_invite_channel_picker: false,
      show_knock_request_dialog: false,
      channel_list_channels: [],
      channel_list_loading: false,
      channel_view: :chat,
      space_avatars: RetroHexChat.VirtualSpace.avatars(),
      space_avatar: nil,
      space_last_avatar: hd(RetroHexChat.VirtualSpace.avatars()),
      group_call: nil,
      group_call_channels: MapSet.new(),
      group_call_channel_summaries: %{},
      group_call_pending: nil,
      group_call_prejoin: nil,
      group_call_prejoin_preferences: nil,
      p2p_session: nil,
      p2p_pm_sessions: %{},
      p2p_pending: nil,
      p2p_setup: nil,
      arcade_session: nil,
      mobile_viewport: false,
      mobile_panel_restore: nil
    )
  end

  # ── View helpers ──────────────────────────────────────────────

  defp admin?(session), do: ChatContext.admin?(session)

  # Static solo-arcade catalog for the in-chat Arcade window body.
  defp arcade_games, do: RetroHexChat.Arcade.list_games()

  defp conversation_space(session, show_status_tab) do
    cond do
      show_status_tab ->
        nil

      is_binary(session.active_pm) ->
        direct_message_space(session)

      is_binary(session.active_channel) ->
        channel_space(session)

      true ->
        nil
    end
  end

  defp channel_space(session) do
    %{
      id: space_dom_id(session.active_channel),
      channel: session.active_channel,
      join_token: ChannelJoinToken.sign(session.active_channel, nil, session.nickname),
      mode: "channel"
    }
  end

  defp direct_message_space(session) do
    participants = [session.nickname, session.active_pm]

    with {:ok, [local_nick, peer_nick] = participants} <-
           DirectMessageSpace.normalize_participants(participants) do
      space_id = DirectMessageSpace.space_id(local_nick, peer_nick)

      %{
        id: space_dom_id(space_id),
        channel: space_id,
        join_token:
          ChannelJoinToken.sign_direct_message(space_id, nil, session.nickname, participants),
        mode: "direct_message"
      }
    else
      {:error, :invalid_participants} -> nil
    end
  end

  defp space_dom_id(space_id) when is_binary(space_id) do
    encoded = Base.url_encode64(space_id, padding: false)
    "conversation-space-#{encoded}"
  end

  # The shared Statistics panel speaks the domain status vocabulary; the chat
  # state machine maps onto it (invite pending reads as "pending", both
  # joining phases as "lobby").
  defp p2p_panel_status(%{state: :connected}), do: "connected"
  defp p2p_panel_status(%{state: :invite_sent}), do: "pending"
  defp p2p_panel_status(_p2p), do: "lobby"

  defp p2p_connection_label(%{state: :connected}), do: dgettext("chat", "Connected")

  defp p2p_connection_label(%{state: :invite_sent}),
    do: dgettext("chat", "Waiting for peer...")

  defp p2p_connection_label(_p2p), do: dgettext("chat", "Connecting...")

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

  defp channel_group_call_active?(channels, channel_name) when is_binary(channel_name) do
    MapSet.member?(channels || MapSet.new(), channel_name)
  end

  defp channel_group_call_active?(_channels, _channel_name), do: false

  defp channel_group_call_summary(summaries, group_call, channel_name)
       when is_binary(channel_name) do
    cond do
      is_map(group_call) and group_call.channel_name == channel_name ->
        group_call

      is_map(summaries) ->
        Map.get(summaries, channel_name)

      true ->
        nil
    end
  end

  defp channel_group_call_summary(_summaries, _group_call, _channel_name), do: nil

  defp p2p_session_for_active_pm(%{peer_nick: peer} = p2p, active_pm)
       when is_binary(peer) and is_binary(active_pm) do
    if String.downcase(peer) == String.downcase(active_pm), do: p2p
  end

  defp p2p_session_for_active_pm(_p2p, _active_pm), do: nil

  defp p2p_pm_session_for_active_pm(pm_sessions, active_pm)
       when is_map(pm_sessions) and is_binary(active_pm) do
    Map.get(pm_sessions, String.downcase(active_pm))
  end

  defp p2p_pm_session_for_active_pm(_pm_sessions, _active_pm), do: nil

  defp p2p_idle_session_for_active_pm(%{active_pm: active_pm, identified: true})
       when is_binary(active_pm) and active_pm != "" do
    %{state: :idle, peer_nick: active_pm, role: :idle}
  end

  defp p2p_idle_session_for_active_pm(_session), do: nil
end
