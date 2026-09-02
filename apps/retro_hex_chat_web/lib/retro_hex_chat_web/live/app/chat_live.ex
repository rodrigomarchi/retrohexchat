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

  alias RetroHexChatWeb.ChatLive.Components.ChatShell
  import RetroHexChatWeb.ChatLive.Components.ChatTabs

  # ── Chat components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.ConversationToolbarActions
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.ChatTaskbar
  import RetroHexChatWeb.Components.UI.ConnectionStatus
  import RetroHexChatWeb.Components.UI.ActivityIndicator

  # ── Desktop window manager ───────────────────────────────────
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.DesktopLaunchers

  # ── P2P session badges ───────────────────────────────────────
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge
  import RetroHexChatWeb.Components.UI.GroupCall.ChannelBadge
  import RetroHexChatWeb.Components.UI.Space.ConversationEntry

  # ── Solo arcade window body ──────────────────────────────────
  import RetroHexChatWeb.Components.UI.SoloLobby

  # ── Dialog components ────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.AboutDialog

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{NicknameValidator, Session, TrustedDevices}
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.{Motd, Queries}

  alias RetroHexChat.Chat.{
    DuplicateTracker,
    FloodTracker,
    KeyBindings,
    ReconnectState,
    SoundSettings
  }

  alias RetroHexChat.Presence.{Tracker, WhowasCache}
  alias RetroHexChat.Scraper
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.SessionControl
  alias RetroHexChat.Surfaces
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.App.ComposerEvents
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.ChatContext
  alias RetroHexChatWeb.ChatLive.ChatTitle
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel
  alias RetroHexChatWeb.ChatLive.P2PReadModel
  alias RetroHexChatWeb.ChatLive.SpaceReadModel

  alias RetroHexChatWeb.ChatLive.Components.{
    ConversationsContextMenu,
    SystemLogDialog,
    UserContextMenus
  }

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
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

    # Asked before the broadcast, so the answer is about who can receive it. A
    # session that dies afterwards leaves the wait to time out, which is what
    # already happened and is the safe direction.
    takeover_expected? =
      takeover_expected?(default_channel, nickname) and takeover_acker?(nickname)

    takeover_ref = make_ref()
    timezone = resolve_timezone(http_session, socket)
    connect_params = get_connect_params(socket) || %{}
    client_info = SessionHelpers.parse_client_info(connect_params)
    trusted_device_id = normalize_trusted_device_id(http_session["trusted_device_id"])
    chat_device_session = start_chat_device_session(nickname, trusted_device_id, client_info)
    chat_device_session_ref = trusted_device_session_ref(chat_device_session)

    # `:chat` scope on purpose: this ends the previous CHAT session and nothing
    # else. A call or a space the person has open in another tab keeps running —
    # only a ban or a nuke (`:all`) reaches those.
    SessionControl.disconnect(
      nickname,
      %{
        reason: dgettext("chat", "Session ended — logged in from another window"),
        disconnected_by_session_ref: chat_device_session_ref,
        takeover_ack: {self(), takeover_ref}
      },
      :chat
    )

    if takeover_expected?, do: wait_for_takeover_cleanup(takeover_ref)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(nickname))
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.presence())
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")
    Scraper.subscribe()
    subscribe_chat_device_session(chat_device_session_ref)

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      Topics.presence(),
      {:user_connected, %{nickname: nickname}}
    )

    previous_nickname = Map.get(socket.assigns.flash, "nick_changed_from")
    pre_identified = http_session["chat_pre_identified"] == true
    backend_reconnect_state = load_reconnect_state(nickname, pre_identified)
    reconnecting? = backend_reconnect_state != nil
    join_channel = params["join"]

    ChatLive.Helpers.safe_track_user(Topics.presence(), nickname, client_info)

    # The chat is one of this person's surfaces, and a live one owns the
    # lifetime of their channel membership again: whatever departure a previous
    # chat handed over on its way out must not fire under this one.
    Surfaces.open(nickname, __MODULE__)
    # The chat has an address like everything else, and saying it is what lets a
    # surface's `← Chat` go back to this tab instead of opening a second one.
    Surfaces.address(nickname, Paths.chat_path())
    Surfaces.cancel_deferred(nickname)

    socket =
      socket
      |> attach_all_hooks()
      |> OpenSurfaces.attach(nickname)
      |> assign_defaults(session)
      |> assign(
        timezone: timezone,
        client_info: client_info,
        trusted_device_id: trusted_device_id,
        chat_device_session_ref: chat_device_session_ref,
        last_device_session_touch_at: DateTime.utc_now()
      )
      |> ChatLive.Helpers.join_channel(default_channel, session)
      |> ChatLive.Helpers.maybe_join_channel(join_channel)
      |> maybe_broadcast_nick_changed(previous_nickname, nickname)
      |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, pre_identified, reconnecting?)
      |> maybe_restore_reconnect_state(backend_reconnect_state)
      |> ChatLive.Helpers.maybe_trigger_perform()
      |> ChatLive.P2PSessionEvents.rehydrate()
      |> ChatLive.GroupCallEvents.rehydrate()

    # A reconnect (deploy / socket drop) or a reload of a live session restores
    # silently: replaying the connect sound, MOTD, welcome and announcements on
    # every deploy is just noise. Only a fresh first login gets the full greeting.
    if reconnecting? do
      push_initial_preferences(socket)
    else
      socket
      |> ChatLive.Helpers.play_event_sound(:connect, socket.assigns.session)
      |> maybe_show_motd()
      |> show_welcome_message()
      |> show_chanserv_announcement()
      |> show_nickserv_announcement()
      |> push_initial_preferences()
    end
  end

  defp takeover_expected?(default_channel, nickname) do
    Tracker.online?(Topics.presence(), nickname) or
      channel_has_member?(default_channel, nickname)
  end

  # Presence and a channel's member list both answer "was a session here",
  # which is not the same question as "is one here to hand over". A tab that
  # vanished leaves the first true and the second false, and the mount then sat
  # out the whole acknowledgement timeout — 1486 ms measured, against ~50 ms
  # when a previous session really was there.
  #
  # A session subscribed to the nickname's inbox before it could receive the
  # force_disconnect, and Phoenix.PubSub drops a subscriber the moment its
  # process dies. So the subscriber list is the live answer, and the new mount
  # is not on it yet — it subscribes after the handover. Anything unexpected
  # from the lookup falls back to waiting, because being slow is the safe
  # failure and joining ahead of the old session's departure is not.
  defp takeover_acker?(nickname) do
    RetroHexChat.PubSub
    |> Registry.lookup(Topics.inbox(nickname))
    |> Enum.any?(fn {pid, _value} -> Process.alive?(pid) end)
  rescue
    error ->
      Logger.warning(
        "Could not inspect inbox subscribers, waiting for takeover: #{inspect(error)}"
      )

      true
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
      client_info: %{},
      trusted_device_id: normalize_trusted_device_id(http_session["trusted_device_id"]),
      chat_device_session_ref: nil,
      last_device_session_touch_at: nil
    )
  end

  # ── Terminate ─────────────────────────────────────────────────

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      quit_reason = socket.assigns[:quit_reason] || dgettext("chat", "Leaving")

      TrustedDevices.record_session_stop(socket.assigns[:chat_device_session_ref], quit_reason)
      Queries.update_last_seen_by_nickname(session.nickname)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.presence(),
        {:user_disconnected, %{nickname: session.nickname}}
      )

      ChatLive.Helpers.safe_untrack_user(Topics.presence(), session.nickname)

      unless socket.assigns[:skip_whowas_record] do
        WhowasCache.record(session.nickname, session.channels, quit_reason)
      end

      unless socket.assigns[:skip_channel_cleanup] do
        depart_channels(session, quit_reason)
      end

      ChatLive.ArcadeSessionEvents.close_on_terminate(socket)
    end

    :ok
  end

  # The tab closing is not the person leaving any more. A conference at
  # `/call/:token` outlives this window, and the room asks on every rejoin
  # whether they are still a member of the channel — so the channels are left
  # when the LAST surface closes. When this is not it, the departure is handed
  # over and runs when the one that outlived us goes down.
  defp depart_channels(session, quit_reason) do
    if Surfaces.count(session.nickname) > 1 do
      # The one thing that is about this window rather than the membership: no
      # chat is left to be nagged about identifying. (A surface only exists for
      # an identified nickname, so in practice there is no timer to cancel — it
      # is here so the two paths cannot drift.)
      NickServ.cancel_identify_timer(session.nickname)
      Surfaces.defer_part(session.nickname, session.channels, quit_reason)
    else
      ChatLive.Helpers.cleanup_channels(session, quit_reason)
    end
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
  def handle_info({:composer_input_history, input_history}, socket) do
    session = Session.set_input_history(socket.assigns.session, input_history)

    {:noreply,
     socket
     |> assign(session: session)
     |> ChatLive.Helpers.maybe_persist_input_history(session)}
  end

  def handle_info({:composer_dispatch, text, reply_to}, socket) do
    {:noreply, ChatLive.CoreEvents.dispatch_composer_input(socket, text, reply_to)}
  end

  def handle_info({:composer_dispatch, text, reply_to, content_format}, socket) do
    {:noreply,
     ChatLive.CoreEvents.dispatch_composer_input(socket, text, reply_to, content_format)}
  end

  def handle_info({:composer_dispatch, text, reply_to, content_format, attachment_ids}, socket) do
    {:noreply,
     ChatLive.CoreEvents.dispatch_composer_input(
       socket,
       text,
       reply_to,
       content_format,
       attachment_ids
     )}
  end

  def handle_info({:composer_submit_edit, content}, socket) do
    {:noreply, ChatLive.CoreEvents.submit_composer_edit(socket, content)}
  end

  def handle_info({:composer_submit_edit, content, content_format}, socket) do
    {:noreply, ChatLive.CoreEvents.submit_composer_edit(socket, content, content_format)}
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

  # The Live Log window subscribes to the node's log topic, but a
  # LiveComponent owns no process, so the broadcast lands here and is handed
  # on. Only the island that asked for it is subscribed, so an unopened window
  # costs nothing.
  def handle_info({:system_log, entry}, socket) do
    send_update(SystemLogDialog, id: SystemLogDialog.id(), log_entry: entry)

    {:noreply, socket}
  end

  def handle_info({:trusted_terminals_disconnect_current, reason}, socket) do
    path =
      Paths.session_clear_path(socket, reason, forget_device: true)

    {:noreply,
     socket
     |> ChatLive.Helpers.clear_reconnect_state()
     |> Phoenix.LiveView.push_event("intentional_disconnect", %{})
     |> Phoenix.LiveView.redirect(to: path)}
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

  defp start_chat_device_session(nickname, trusted_device_id, client_info) do
    case TrustedDevices.record_session_start(nickname, trusted_device_id, client_info) do
      {:ok, session} -> session
      {:error, _changeset} -> nil
    end
  end

  defp trusted_device_session_ref(%{session_ref: session_ref}), do: session_ref
  defp trusted_device_session_ref(_session), do: nil

  defp subscribe_chat_device_session(nil), do: :ok

  defp subscribe_chat_device_session(session_ref) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "chat_device_session:#{session_ref}")
  end

  defp normalize_trusted_device_id(id) when is_integer(id), do: id

  defp normalize_trusted_device_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_trusted_device_id(_id), do: nil

  defp load_reconnect_state(nickname, true) do
    case ReconnectState.load(nickname) do
      {:ok, snapshot} -> snapshot
      {:error, :not_found} -> nil
    end
  end

  defp load_reconnect_state(_nickname, _pre_identified), do: nil

  defp maybe_restore_reconnect_state(socket, nil), do: socket

  defp maybe_restore_reconnect_state(socket, snapshot) do
    ChatLive.Helpers.restore_session(socket, snapshot)
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
    &ChatLive.TrustedTerminalsEvents.handle_event/3,
    &ChatLive.ProfileEvents.handle_event/3,
    &ChatLive.AwayEvents.handle_event/3,
    &ChatLive.UserModesEvents.handle_event/3,
    &ChatLive.NotifyEvents.handle_event/3,
    &ChatLive.AddressBookEvents.handle_event/3,
    &ChatLive.NickColorsEvents.handle_event/3,
    &ChatLive.IgnoreListEvents.handle_event/3,
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
      {:trusted_terminals_events, &ChatLive.TrustedTerminalsEvents.handle_event/3},
      {:profile_events, &ChatLive.ProfileEvents.handle_event/3},
      {:away_events, &ChatLive.AwayEvents.handle_event/3},
      {:user_modes_events, &ChatLive.UserModesEvents.handle_event/3},
      {:notify_events, &ChatLive.NotifyEvents.handle_event/3},
      {:address_book_events, &ChatLive.AddressBookEvents.handle_event/3},
      {:nick_colors_events, &ChatLive.NickColorsEvents.handle_event/3},
      {:ignore_list_events, &ChatLive.IgnoreListEvents.handle_event/3},
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
      # The call surface reports to its host: what the chat's chrome draws,
      # the notices that belong in the conversation, and the window commands.
      # After PubsubHandlers: it consumes "lobby_invite" first; this one owns
      # the other two sentences a session says on the reader's own topic.
      {:p2p_session_info, &ChatLive.P2PSessionEvents.handle_info/2},
      # Owns the "arcade:#{token}" topic events for the in-chat solo arcade.
      {:arcade_session_info, &ChatLive.ArcadeSessionEvents.handle_info/2},
      # Owns the space-roster topics the conversation's cards subscribe to, and
      # the viewport saying which of them it is still rendering.
      {:share_cards_info, &ChatLive.ShareCards.handle_info/2}
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
      conversation_members: [],
      live_ready: connected?(socket),
      open_windows: MapSet.new(),
      nick_color_fn: ChatHelpers.build_nick_color_fn(session),
      has_more: true,
      notice_active: false,
      chat_clear_token: 0,
      cleared_conversation_cutoffs: %{},
      messages: %{},
      notify_debounce_timers: %{},
      oldest_message_id: nil,
      # The first-paint title, and deliberately not `page_title`: LiveView would
      # then own document.title and overwrite the hook that composes the title
      # with the activity flash (see ChatTitle and the chat root layout).
      initial_title: ChatTitle.document_title(session, false),
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
      channel_activity_order: %{},
      channel_activity_sequence: 0,
      current_topic: nil,
      current_modes: nil,
      show_conversations: true,
      channel_user_counts: %{},
      popular_channels: [],
      conversations_sections: %{
        channels: true,
        pms: true,
        autojoin: true,
        popular: true
      },
      lookup_result: nil,
      cc_window_channel: nil,
      unread_counts: %{},
      url_catcher_entries: [],
      url_catcher_dropped: 0,
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
      muted: SoundSettings.muted?(session.sound_settings),
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
      group_call_channels: MapSet.new(),
      group_call_channel_summaries: %{},
      p2p_pm_sessions: %{},
      arcade_session: nil,
      mobile_viewport: false,
      mobile_panel_restore: nil,
      trusted_device_id: nil,
      chat_device_session_ref: nil,
      last_device_session_touch_at: nil
    )
  end

  # ── View helpers ──────────────────────────────────────────────

  defp admin?(session), do: ChatContext.admin?(session)

  # Static solo-arcade catalog for the in-chat Arcade window body.
  defp arcade_games, do: RetroHexChat.Arcade.list_games()

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
        Topics.channel(channel),
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

  defp channel_group_call_summary(summaries, channel_name)
       when is_map(summaries) and is_binary(channel_name) do
    Map.get(summaries, channel_name)
  end

  defp channel_group_call_summary(_summaries, _channel_name), do: nil

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
