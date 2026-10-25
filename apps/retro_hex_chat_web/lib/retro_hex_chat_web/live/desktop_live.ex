defmodule RetroHexChatWeb.DesktopLive do
  @moduledoc """
  The one desktop: the chat, and every page of the site as a window over it.

  It answers the home (`/`), a channel's address (`/c/:channel`), every page
  of the site, help, the archive, invitations and the sign-in window — in
  every locale, in one `live_session`. `Site.Documents` opens the page an
  address names (`Site.Registry`) as the windows it declares — a group for a
  page of the site, one window for help, the archive, an invitation or
  sign-in; the chat is composed
  from `components/ui/` and the `ChatLive.*` handlers, and a visitor sees the
  same screen through `ChatLive.Visitor`'s gate.
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

  alias RetroHexChat.Channels.Name
  alias RetroHexChatWeb.ChatLive.Components.ChatShell
  alias RetroHexChatWeb.Params
  import RetroHexChatWeb.ChatLive.Components.ChatTabs

  # ── Chat components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.ConversationToolbarActions
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.GameChannelBar
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

  # ── The pages of the site, as windows ────────────────────────
  import RetroHexChatWeb.Components.UI.Site.Document, only: [site_documents: 1, site_window: 1]
  import RetroHexChatWeb.Components.UI.Site.DesktopFiles

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{NickLocales, Session, TrustedDevices}
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.Queries

  alias RetroHexChat.Chat.{
    DuplicateTracker,
    FloodTracker,
    KeyBindings,
    ReconnectState,
    SoundSettings,
    UnreadTracker
  }

  alias RetroHexChat.Notifications
  alias RetroHexChat.Presence.WhowasCache
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
  alias RetroHexChatWeb.ChatLive.Visitor
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Site

  alias RetroHexChatWeb.ChatLive.Components.{
    ConversationsContextMenu,
    SystemLogDialog,
    UserContextMenus
  }

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionNickname
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.Timezone

  # ── Mount ─────────────────────────────────────────────────────

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(params, http_session, socket) do
    # Before anything else: the window bridge has to sit ahead of the visitor
    # gate, and every address — the chat's or a page's — needs its state.
    socket = Site.Documents.init(socket, http_session)

    case SessionNickname.resolve(http_session) do
      {:ok, nickname} ->
        {:ok, mount_chat_session(params, http_session, socket, nickname)}

      # Seen as a visitor, and sent to the sign-in window saying why
      # (`Site.Documents.handle_params/3`). Sending them to `/connect` from
      # here would mount this same view again, banned again.
      :banned ->
        {:ok, socket |> assign(banned?: true) |> then(&mount_visitor(params, http_session, &1))}

      # Nobody signed in: the same chat, read-only, as a visitor sees it.
      :visitor ->
        {:ok, mount_visitor(params, http_session, socket)}
    end
  end

  defp mount_visitor(params, http_session, socket) do
    session = Visitor.session()

    if connected?(socket) do
      socket
      |> Visitor.attach_gate()
      |> attach_all_hooks()
      |> assign_defaults(session)
      |> assign(browser_context(http_session, socket))
      |> assign(
        visitor?: true,
        hidden_windows: Visitor.hidden_windows(),
        open_surface_paths: MapSet.new(),
        chat_session_id: nil
      )
      |> Visitor.enter(params)
      |> ChatLive.Arrival.visitor()
      |> push_initial_preferences()
    else
      http_session
      |> mount_disconnected_chat(socket, session)
      |> assign(visitor?: true, hidden_windows: Visitor.hidden_windows())
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
    default_channel = Server.default_channel()

    %{
      timezone: timezone,
      client_info: client_info,
      trusted_device_id: trusted_device_id,
      browser_id: browser_id
    } = browser_context(http_session, socket)

    chat_device_session = start_chat_device_session(nickname, trusted_device_id, client_info)
    chat_device_session_ref = trusted_device_session_ref(chat_device_session)

    # Opening the chat no longer ends the chat somebody already has: two screens
    # of one nickname share a channel membership and an inbox, so there is
    # nothing to hand over and nothing to wait for. Only the count is enforced,
    # and the screen that gives way is told to leave the membership behind for
    # the ones that outlive it.
    SessionControl.enforce_limit(nickname, chat_device_session_ref)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(nickname))
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.presence())
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.games_playing())
    # A game's home open on this desktop follows its matches as they end.
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())
    # And an arcade game's home, the players who start it.
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.arcade_plays())
    # After the first render, when the user list exists to be told.
    send(self(), :refresh_games_playing)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.announcements())
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.wallops())
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.server_settings())
    Scraper.subscribe()
    subscribe_chat_device_session(chat_device_session_ref)

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      Topics.presence(),
      {:user_connected, %{nickname: nickname}}
    )

    previous_nickname = Map.get(socket.assigns.flash, "nick_changed_from")
    # The cookie is not the only proof of identity, and it was the only one this
    # asked. `chat_pre_identified` is set by a short-token or trusted-device
    # login; somebody who registered, or typed `/ns identify` inside the chat,
    # never gets it — so every reload replayed their whole login sequence, sound
    # and MOTD and greeting included. NickServ knows who is identified right
    # now — but only for the browser session that did it: an identification
    # is bound to `chat_session_id`, so a sign-in that never proved the
    # nickname cannot borrow one made elsewhere. `maybe_start_nickserv_timer/4`
    # below trusts exactly this answer.
    chat_session_id = http_session["chat_session_id"]
    identified? = SessionNickname.identified?(http_session, nickname)
    # The snapshot is filed under the account; a nickname typed in another case
    # is the same person, so it is looked up by the registered spelling.
    owner = if identified?, do: NickServ.account_for(nickname)
    backend_reconnect_state = load_reconnect_state(owner, browser_id)
    reconnecting? = backend_reconnect_state != nil
    join_channel = channel_param(params)

    # Opened after mount, from the same handler the arcade menu uses: the
    # arcade window is managed and mounts its own state, which a mount-time
    # open would race.
    if connected?(socket) and is_binary(params["arcade"]),
      do: send(self(), {:open_arcade_link, params["arcade"]})

    ChatLive.Helpers.safe_track_user(
      Topics.presence(),
      nickname,
      Map.put(client_info, :locale, socket.assigns[:locale])
    )

    # The flag beside this nickname on every other screen. Written to the row
    # only for somebody who proved the name, so a stranger typing it cannot
    # repaint its owner's.
    NickLocales.remember(nickname, socket.assigns[:locale], store: identified?)

    # The chat is one of this person's surfaces, and a live one owns the
    # lifetime of their channel membership again: whatever departure a previous
    # chat handed over on its way out must not fire under this one.
    Surfaces.open(nickname, __MODULE__)
    # The chat has an address like everything else, and saying it is what lets a
    # surface's `← Chat` go back to this tab instead of opening a second one.
    Surfaces.address(nickname, Paths.chat_path())
    Surfaces.cancel_deferred(nickname)

    # Identity before the first join: a registered channel's access list only
    # seats someone who has proved the nickname, and the default channel is
    # joined a few lines below, before `maybe_start_nickserv_timer/4` runs.
    session = if identified?, do: ChatLive.Helpers.mark_identified(session), else: session

    socket =
      socket
      |> attach_all_hooks()
      |> OpenSurfaces.attach(nickname)
      |> assign_defaults(session)
      |> assign(
        timezone: timezone,
        client_info: client_info,
        trusted_device_id: trusted_device_id,
        chat_session_id: chat_session_id,
        browser_id: browser_id,
        chat_device_session_ref: chat_device_session_ref,
        last_device_session_touch_at: DateTime.utc_now()
      )
      |> ChatLive.Helpers.join_channel(default_channel, session)
      |> ChatLive.Helpers.maybe_join_channel(join_channel)
      |> maybe_broadcast_nick_changed(previous_nickname, nickname)
      |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, identified?, reconnecting?)
      |> maybe_restore_reconnect_state(backend_reconnect_state, join_channel)
      # After the restore, never before it. The snapshot is what tells the
      # *next* mount this session already happened, and until here there was
      # nothing to write it: the channel join runs before identity is
      # established, so the save inside it saw `identified: false` and skipped —
      # somebody who joined, read and reloaded had no snapshot at all, and got
      # the whole login sequence again for their trouble. Writing it before the
      # restore would be worse than not writing it: it would overwrite the
      # conversation they were in with the one the mount happened to open.
      |> ChatLive.Helpers.persist_reconnect_state()
      # The mount began with an empty session, so the suggestions were opened
      # for an arrival; now the rooms are known, they are settled for this one.
      |> ChatLive.ConversationsReadModel.settle_discovery_sections()
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
      |> ChatLive.Arrival.member()
      |> push_initial_preferences()
    end
  end

  # What the browser tells every connected chat about itself, signed in or not.
  defp browser_context(http_session, socket) do
    %{
      timezone: resolve_timezone(http_session, socket),
      client_info: SessionHelpers.parse_client_info(get_connect_params(socket) || %{}),
      trusted_device_id: Params.integer(http_session["trusted_device_id"]),
      browser_id: normalize_browser_id(http_session["browser_id"])
    }
  end

  defp mount_disconnected_chat(http_session, socket, session) do
    socket
    |> assign_defaults(session)
    |> assign(
      timezone: Timezone.validate(http_session["chat_timezone"]),
      client_info: %{},
      trusted_device_id: Params.integer(http_session["trusted_device_id"]),
      browser_id: normalize_browser_id(http_session["browser_id"]),
      chat_device_session_ref: nil,
      last_device_session_touch_at: nil
    )
  end

  # Every move on the desktop is an address: a page of the site opens its
  # window (`Site.Documents`), a channel's comes to the front. What a link asks
  # for once (`?arcade=`) is acted on — in mount for the address the desktop
  # opened at, here for one a link patched to — and then dropped by a patch.
  @impl true
  def handle_params(params, uri, socket) do
    socket =
      params
      |> Site.Documents.handle_params(uri, socket)
      |> enter_channel(params)

    if socket.assigns[:address_ready?] == true and is_binary(params["arcade"]),
      do: send(self(), {:open_arcade_link, params["arcade"]})

    {:noreply, assign(socket, address_ready?: connected?(socket))}
  end

  # The address names a channel: bring it on screen, joining it — or, for a
  # visitor, watching it — when it is not open yet. Mount already did so for
  # the address the desktop was opened at, so this only acts on a change.
  defp enter_channel(%{assigns: %{live_action: :channel, live_ready: true}} = socket, params) do
    channel = channel_param(params)
    session = socket.assigns.session

    cond do
      session.active_channel == channel and not socket.assigns.show_status_tab ->
        socket

      socket.assigns.visitor? ->
        Visitor.watch_channel(socket, channel)

      channel in session.channels ->
        socket
        |> assign(show_status_tab: false)
        |> Conversation.activate_channel(channel)

      true ->
        ChatLive.Helpers.join_channel(socket, channel, session)
    end
  end

  defp enter_channel(socket, _params), do: socket

  defp channel_param(%{"channel" => channel}) when is_binary(channel) and channel != "",
    do: Name.ensure_prefix(channel)

  defp channel_param(_params), do: nil

  # ── Terminate ─────────────────────────────────────────────────

  @impl true
  def terminate(_reason, socket) do
    # A visitor holds nothing to give back: the channels it watched stop
    # counting it when this process goes, by their own monitor.
    session = connected?(socket) && !Visitor.visitor?(socket) && socket.assigns[:session]

    if session do
      quit_reason = socket.assigns[:quit_reason] || dgettext("chat", "Leaving")

      TrustedDevices.record_session_stop(socket.assigns[:chat_device_session_ref], quit_reason)
      Queries.update_last_seen_by_nickname(session.nickname)

      # Closing one screen is not going offline. Being online, and being
      # recorded as having quit, are facts about the person, so they belong to
      # the last chat that closes — a phone still open means they are still
      # here, whatever the desktop just did. The kind matters: a call in a tab
      # of its own is not somebody reading the conversation, so it does not
      # keep them online either.
      if last_chat_session?(session.nickname) do
        announce_departure(socket, session, quit_reason)
      end

      # Untracked either way: presence keeps a meta per process, so dropping
      # this one leaves the other screen's behind and the person stays online
      # by the only means that is actually counted.
      ChatLive.Helpers.safe_untrack_user(Topics.presence(), session.nickname)

      unless socket.assigns[:skip_channel_cleanup] do
        depart_channels(session, quit_reason)
      end

      ChatLive.ArcadeSessionEvents.close_on_terminate(socket)
    end

    :ok
  end

  defp announce_departure(socket, session, quit_reason) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      Topics.presence(),
      {:user_disconnected, %{nickname: session.nickname}}
    )

    unless socket.assigns[:skip_whowas_record] do
      WhowasCache.record(session.nickname, session.channels, quit_reason)
    end
  end

  # `terminate/2` runs before the process is gone, so this surface is still
  # registered and counts itself.
  defp last_chat_session?(nickname) do
    Surfaces.count_kind(nickname, __MODULE__) <= 1
  end

  # The tab closing is not the person leaving any more. A conference at
  # `/call/:token` outlives this window, and so does the same person's chat on
  # another screen; the room asks on every rejoin whether they are still a
  # member of the channel — so the channels are left when the LAST surface
  # closes, of any kind. When this is not it, the departure is handed over and
  # runs when the one that outlived us goes down.
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

  def handle_info({:composer_voice, target, file_id}, socket) do
    {:noreply, ChatLive.CoreEvents.dispatch_composer_voice(socket, target, file_id)}
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

  # What a dialog island says in the chat around it (`DialogIsland.bubble/3`):
  # the status bar, or a line in the conversation.
  def handle_info({:dialog_said, :system, message}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, message, :system)}
  end

  def handle_info({:dialog_said, :error, message}, socket) do
    {:noreply, ChatLive.Helpers.push_status_message(socket, message, :error)}
  end

  def handle_info({:dialog_said, :system_event, message}, socket) do
    {:noreply, ChatLive.Helpers.system_event(socket, message)}
  end

  def handle_info({:dialog_said, :error_event, message}, socket) do
    {:noreply, ChatLive.Helpers.error_event(socket, message)}
  end

  # A settings dialog changed the session: the dialog owns the work; the parent
  # owns the session read-model, its fire-and-forget persistence, and whatever
  # else the change redraws.
  def handle_info({:dialog_session, session, kind}, socket) do
    {:noreply, socket |> assign(session: session) |> after_dialog_session(kind, session)}
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

  # The notify debounce timers stay with the parent.
  def handle_info({:notify_dialog_cancel_timer, nick}, socket) do
    {:noreply, ChatLive.Helpers.cancel_notify_timer(socket, nick)}
  end

  # The Address Book's ignore debounce timers stay with the parent.
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
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.chat_device_session(session_ref))
  end

  defp load_reconnect_state(nil, _browser_id), do: nil

  defp load_reconnect_state(owner, browser_id) do
    case ReconnectState.load(owner, browser_id) do
      {:ok, snapshot} -> snapshot
      {:error, :not_found} -> nil
    end
  end

  defp normalize_browser_id(browser_id) when is_binary(browser_id), do: browser_id
  defp normalize_browser_id(_browser_id), do: ""

  defp maybe_restore_reconnect_state(socket, nil, _address_channel), do: socket

  # An address that names a channel (`/c/hex-pong`) is where this person asked
  # to be: the snapshot still reopens the tabs they had, but the conversation in
  # front is the one the address chose, not the one the last session ended in.
  defp maybe_restore_reconnect_state(socket, snapshot, address_channel)
       when is_binary(address_channel) do
    ChatLive.Helpers.restore_session(
      socket,
      Map.drop(snapshot, [:active_channel, :active_pm, "active_channel", "active_pm"])
    )
  end

  defp maybe_restore_reconnect_state(socket, snapshot, _no_address) do
    ChatLive.Helpers.restore_session(socket, snapshot)
  end

  # ── Hook dispatch ─────────────────────────────────────────────
  # `event_hooks/0` is the one ordered list. `attach_all_hooks/1` registers it
  # with LiveView and `dispatch_to_hooks/3` replays it for events the app
  # dispatches to itself (a compound `toolbar_action`, a tab bar press). It was
  # written twice, and the second copy quietly fell behind by four modules —
  # so a Start-menu entry could be wired, drawn, and do nothing at all.

  @spec dispatch_to_hooks(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp dispatch_to_hooks(event, params, socket) do
    result =
      Enum.reduce_while(event_hooks(), socket, fn {_name, hook_fn}, acc ->
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
        Logger.debug("DesktopLive: unrouted event #{inspect(event)} (no hook claimed it)")
        {:noreply, socket}
    end
  end

  # ── Hooks ─────────────────────────────────────────────────────

  defp event_hooks do
    [
      {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
      {:open_tab_events, &ChatLive.OpenTabEvents.handle_event/3},
      {:window_open_events, &ChatLive.WindowOpenEvents.handle_event/3},
      {:pm_typing_events, &ChatLive.PmTypingEvents.handle_event/3},
      {:alias_events, &ChatLive.AliasEvents.handle_event/3},
      {:custom_menus_events, &ChatLive.CustomMenusEvents.handle_event/3},
      {:autorespond_events, &ChatLive.AutorespondEvents.handle_event/3},
      {:timer_events, &ChatLive.TimerEvents.handle_event/3},
      {:settings_dialogs_events, &ChatLive.SettingsDialogsEvents.handle_event/3},
      {:account_events, &ChatLive.AccountEvents.handle_event/3},
      {:profile_events, &ChatLive.ProfileEvents.handle_event/3},
      {:away_events, &ChatLive.AwayEvents.handle_event/3},
      {:user_modes_events, &ChatLive.UserModesEvents.handle_event/3},
      {:conversations_events, &ChatLive.ConversationsEvents.handle_event/3},
      {:conversations_context_menu_events,
       &ChatLive.ConversationsContextMenuEvents.handle_event/3},
      {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
      {:navigation_events, &ChatLive.NavigationEvents.handle_event/3},
      {:search_events, &ChatLive.SearchEvents.handle_event/3},
      {:channel_list_events, &ChatLive.ChannelListEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:composer_events, &ComposerEvents.handle_event/3},
      {:user_lookup_events, &ChatLive.UserLookupEvents.handle_event/3},
      {:hover_events, &ChatLive.HoverEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:reaction_events, &ChatLive.ReactionEvents.handle_event/3},
      {:mention_events, &ChatLive.MentionEvents.handle_event/3},
      {:pin_events, &ChatLive.PinEvents.handle_event/3},
      {:save_events, &ChatLive.SaveEvents.handle_event/3},
      {:thread_events, &ChatLive.ThreadEvents.handle_event/3},
      {:event_events, &ChatLive.EventEvents.handle_event/3},
      {:game_events, &ChatLive.GameEvents.handle_event/3},
      {:tip_events, &ChatLive.TipEvents.handle_event/3},
      {:admin_events, &ChatLive.AdminEvents.handle_event/3},
      {:bot_events, &ChatLive.BotEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:connection_events, &ChatLive.ConnectionEvents.handle_event/3},
      {:group_call_events, &ChatLive.GroupCallEvents.handle_event/3},
      {:space_events, &ChatLive.SpaceEvents.handle_event/3},
      {:p2p_session_events, &ChatLive.P2PSessionEvents.handle_event/3},
      {:arcade_session_events, &ChatLive.ArcadeSessionEvents.handle_event/3},
      {:core_events, &ChatLive.CoreEvents.handle_event/3}
    ]
  end

  defp attach_all_hooks(socket) do
    event_hooks = event_hooks()

    info_hooks = [
      {:settings_dialogs_info, &ChatLive.SettingsDialogsEvents.handle_info/2},
      {:mention_info, &ChatLive.MentionEvents.handle_info/2},
      {:pin_info, &ChatLive.PinEvents.handle_info/2},
      {:save_info, &ChatLive.SaveEvents.handle_info/2},
      {:thread_info, &ChatLive.ThreadEvents.handle_info/2},
      {:event_info, &ChatLive.EventEvents.handle_info/2},
      {:timer_handlers, &ChatLive.TimerHandlers.handle_info/2},
      {:pubsub_handlers, &ChatLive.PubsubHandlers.handle_info/2},
      # The call surface reports to its host: what the chat's chrome draws,
      # the notices that belong in the conversation, and the window commands.
      # After PubsubHandlers: it consumes "lobby_invite" first; this one owns
      # the other two sentences a session says on the reader's own topic.
      {:p2p_session_info, &ChatLive.P2PSessionEvents.handle_info/2},
      # Owns the `Topics.arcade/1` events for the in-chat solo arcade.
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
      # What the browser last told us about its notification permission. Unknown
      # until the hook reports, which is why "default" is not the starting value:
      # the Sounds window must not offer to ask before it knows whether it can.
      desktop_notify_permission: "unknown",
      # Which message the emoji picker was opened for, when it was opened from a
      # message rather than from the composer. Cleared as soon as it is used.
      reaction_target_id: nil,
      reaction_target_source: nil,
      # Whether this server can send a push at all, and whether this browser has
      # asked it to. The first is the server's configuration and never changes
      # within a session; the second is the browser's own fact, reported by the
      # hook once it has looked.
      push_available: Notifications.enabled?(),
      push_subscribed: false,
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
      pinned_count: 0,
      can_pin: false,
      current_modes: nil,
      # Matches anybody may watch, for a game channel's strip; filled with the
      # user list's "who is playing" from `Games.Activity`.
      live_matches: [],
      # Their players' languages, kept while the same people are playing.
      live_match_locales: nil,
      show_conversations: true,
      channel_user_counts: %{},
      # Each joined channel's language, drawn as a flag beside its name.
      channel_locales: %{},
      # And what each one is about, drawn as a plaque beside the flag.
      channel_categories: %{},
      channel_guests: %{},
      visitor?: false,
      visitor_nick: nil,
      hidden_windows: [],
      # The surfaces this person has open in other tabs; empty until
      # `OpenSurfaces` reads them on the connected mount.
      open_surface_paths: MapSet.new(),
      popular_channels: [],
      featured_channels: [],
      # Suggestions are for somebody who has nowhere to go yet. Expanded they
      # are ten rows in a sidebar of fifteen, so they open for an arrival and
      # stay shut for anybody who already has rooms — until asked for; a
      # member's are settled once the mount knows their rooms. The
      # games are the exception: they are what most people come here for, so
      # their section is open for everybody until somebody closes it.
      conversations_sections: %{
        channels: true,
        pms: true,
        games: true,
        news: ChatLive.ConversationsReadModel.discovery_open?(session),
        popular: ChatLive.ConversationsReadModel.discovery_open?(session)
      },
      lookup_result: nil,
      cc_window_channel: nil,
      unread_counts: %{},
      # Separate from the unread count above: one says there is something new,
      # the other says it is about you.
      mention_counts: %{},
      # Where the reader had got to in each conversation, and the newest line the
      # viewport has actually shown. The second is what the first is set from
      # when the reader looks away.
      read_markers: %{},
      newest_message_id: nil,
      unread_boundary_id: nil,
      url_catcher_entries: [],
      url_catcher_dropped: 0,
      ignore_timers: %{},
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_from: nil,
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
      # What the Channel List was last narrowed to, kept across its closes.
      channel_list_filter: %{search: "", category: nil},
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

  # The arcade under its engines, as the public catalogue shows it.
  defp arcade_groups, do: GameCatalog.arcade_groups()

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

  # What each settings dialog's change asks of the parent beyond the session.
  defp after_dialog_session(socket, :perform, session),
    do: ChatLive.Helpers.maybe_persist_perform_list(socket, session)

  defp after_dialog_session(socket, :autojoin, session),
    do: ChatLive.Helpers.maybe_persist_autojoin_list(socket, session)

  defp after_dialog_session(socket, :highlight, session),
    do: ChatLive.Helpers.maybe_persist_highlight_words(socket, session)

  defp after_dialog_session(socket, :notify, session),
    do: ChatLive.Helpers.maybe_persist_notify_list(socket, session)

  defp after_dialog_session(socket, :contacts, session),
    do: ChatLive.Helpers.maybe_persist_contacts(socket, session)

  defp after_dialog_session(socket, :ignore, session),
    do: ChatLive.Helpers.maybe_persist_ignore_list(socket, session)

  defp after_dialog_session(socket, :nick_colors, session) do
    socket
    |> ChatLive.Helpers.rebuild_nick_color_fn(session)
    |> ChatLive.Helpers.refresh_active_message_stream(session)
    |> ChatLive.Helpers.maybe_persist_nick_colors(session)
  end
end
