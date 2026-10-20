defmodule RetroHexChatWeb.ChatLive.Visitor do
  @moduledoc """
  The chat as somebody without an account sees it.

  The desktop opened with no nickname in the session is not sent away: it
  renders the same screen, on `#lobby` or the channel its address names, with the conversation arriving live. A visitor
  can open the public channels and read them, move between them and scroll
  their history — and nothing else. Every action, from sending a line to
  right-clicking a nick, opens the sign-in window instead, and signing in there
  lands them back on the channel they were reading.

  A visitor is a watcher, never a member (`Channels.Server.watch/3`). They get
  a guest name (`Guest` and digits, reserved so no account can take one) that
  belongs to the browser, not the tab — every tab of one browser shares it, and
  no two browsers hold the same one (`Accounts.GuestNames`) — and are listed
  under it in a section of the user list of their own,
  counted beside the channel — but they do not join it, hold no role, announce
  nothing and leave nothing behind when the tab closes. Which
  channels they may open is the channel's own answer — the server refuses a
  room a stranger may not see.

  The gate is a `:handle_event` hook attached before every other one, so it
  sees each event the browser sends before the chat's own handlers do. Three
  outcomes:

    * reading the conversation — scrolling, moving between rooms, the sidebar,
      the user list, search — goes through untouched;
    * opening or closing a room is answered here, by watching instead of
      joining;
    * what the browser reports on its own (permissions, tips, viewport) is
      dropped without a word, and anything the reader did deliberately opens
      the sign-in window.

  The visitor sees the same screen a member does; only what it does differs.
  A live component with events of its own is out of the hook's reach, so the
  composer is drawn but `inert`, under a pane that opens the sign-in window;
  the always-mounted tools in `hidden_windows/0` are left out; and the gate
  mounts no managed window but the sign-in one.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, push_patch: 2]

  alias RetroHexChat.Accounts.GuestNames
  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.ReturnTo
  alias RetroHexChatWeb.ChatLive.ChannelListEvents
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.Address

  # What the sign-in window says the visitor tried to use. `:feature` is the
  # catch-all for an action with no better name.
  @features %{
    "chat" => :chat,
    "games" => :games,
    "calls" => :calls,
    "space" => :space,
    "p2p" => :p2p,
    "links" => :links,
    "feature" => :feature
  }

  @type feature :: :chat | :games | :calls | :space | :p2p | :links | :feature

  # Reading the conversation. These reach the chat's own handlers unchanged.
  @reading_events ~w(
    load_more scroll_to_bottom jump_to_first_unread scroll_to_message_missing
    scroll_to_reply_parent
    window_closed close_all_context_menus close_dialog
    toggle_conversations toggle_nicklist conversations_toggle_section
    conversations_browse_all channel_list toggle_channel_list channel_list_filter
    channel_hover switch_to_status window_next window_prev window_select
    toggle_search close_search search_input search_next search_prev
    search_navigate search_toggle_filter search_highlight_count
    toggle_mute mute_state_sync tab_focused viewport_info desktop_notify_permission
    ping lag_update rum_session help_topics toggle_cheatsheet help_nav_tab help_search
  )

  # What the browser says on its own, not something the reader did. Nothing
  # to ask them about, and nothing a visitor has to keep.
  @background_events ~w(
    tips_seen tips_suppressed_changed restore_session recent_commands_loaded
    push_subscription_created push_subscription_removed push_subscription_state
    push_subscription_failed pm_typing pm_stop_typing channel_joined_flash
    nick_hover nick_hover_dismiss
  )

  # Keyboard actions that only move around what is already on screen.
  @reading_shortcuts ~w(
    window_next window_prev window_1 window_2 window_3 window_4 window_5
    window_6 window_7 window_8 window_9 toggle_search toggle_cheatsheet open_help
  )a

  @doc """
  The always-mounted windows a visitor does not get, button included. Each is a
  tool with events of its own, out of the gate's reach, and a layout saved on
  this browser by somebody signed in would otherwise reopen it.
  """
  @spec hidden_windows() :: [String.t()]
  def hidden_windows, do: ~w(channel-central url-catcher)

  @doc """
  The session a visitor's chat runs on: no nickname, nothing joined, nothing to
  persist. No domain call accepts an empty nickname, so nothing can be done in
  a visitor's name even by a path the gate failed to close.
  """
  @spec session() :: Session.t()
  def session, do: Session.new("")

  @doc "Whether the socket belongs to a visitor."
  @spec visitor?(Phoenix.LiveView.Socket.t() | map()) :: boolean()
  def visitor?(%{assigns: assigns}), do: Map.get(assigns, :visitor?, false) == true
  def visitor?(_socket), do: false

  @doc """
  Puts a connected visitor's chat on screen: the gate, the server-wide topics
  everybody hears, the default channel and the one a link asked for.

  Attach before the chat's own event hooks — the gate has to run first.
  """
  @spec attach_gate(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def attach_gate(socket) do
    attach_hook(socket, :visitor_gate, :handle_event, &gate/3)
  end

  @doc """
  Opens the default channel, then the one the address names (`/c/:channel`),
  when it may be watched.
  """
  @spec enter(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def enter(socket, params) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.announcements())
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.server_settings())
    # Who is playing what is something to read, like the list it is drawn in.
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.games_playing())
    send(self(), :refresh_games_playing)

    default_channel = Server.default_channel()
    guest = GuestNames.claim(socket.assigns.browser_id)

    # What a room's bots say to this visitor alone — a greeting on arrival —
    # is addressed to the guest name. Subscribed before watching, because
    # watching is what makes them speak.
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(guest))

    socket
    |> assign(visitor_nick: guest)
    |> watch_channel(default_channel)
    |> maybe_watch(params["channel"] && Address.channel_name(params["channel"]), default_channel)
  end

  @doc """
  The paths a visitor's links may still follow: the addresses of the one
  desktop — the pages of the site, help, the archive, a channel, an
  invitation, the sign-in window — and the language switch, in the reader's
  language and without it. A path ending in `/` opens everything below it, any
  other only itself. Anything else asks them to sign in (`VisitorLinkGuardHook`).
  """
  @spec open_paths() :: [String.t()]
  def open_paths do
    pages = ["/chat/help", "/c", "/connect", "/join", "/archive", "/watch" | PublicPages.paths()]
    localized = Enum.uniq(pages ++ Enum.map(pages, &PublicPages.localized_path/1))

    Enum.uniq(["/chat", "/locale/" | Enum.flat_map(localized, &with_subpaths/1)])
  end

  defp with_subpaths("/"), do: ["/"]
  defp with_subpaths(path), do: [path, String.trim_trailing(path, "/") <> "/"]

  @doc "The feature a `signup` value names; anything unknown is the generic one."
  @spec feature_named(term()) :: feature()
  def feature_named(name), do: Map.get(@features, name, :feature)

  @doc "What the sign-in window says the visitor was trying to use."
  @spec feature_message(feature()) :: String.t()
  def feature_message(:chat), do: dgettext("chat", "Writing in the chat needs an account.")
  def feature_message(:games), do: dgettext("chat", "Games are for registered players.")
  def feature_message(:calls), do: dgettext("chat", "Calls are for registered members.")
  def feature_message(:space), do: dgettext("chat", "Spaces are for registered members.")

  def feature_message(:p2p),
    do: dgettext("chat", "Private sessions are for registered members.")

  def feature_message(:links), do: dgettext("chat", "You need an account to open links.")
  def feature_message(_feature), do: dgettext("chat", "This feature needs an account.")

  @doc "The icon the sign-in window draws beside `feature_message/1`."
  @spec feature_icon(feature()) :: atom()
  def feature_icon(:chat), do: :icon_chat
  def feature_icon(:games), do: :icon_joystick
  def feature_icon(:calls), do: :icon_toolbar_conference
  def feature_icon(:space), do: :icon_toolbar_community
  def feature_icon(:p2p), do: :icon_p2p
  def feature_icon(:links), do: :icon_link
  def feature_icon(_feature), do: :icon_lock

  defp maybe_watch(socket, channel, default) when is_binary(channel) and channel != default,
    do: watch_channel(socket, channel)

  defp maybe_watch(socket, _channel, _default), do: socket

  @doc """
  Brings a channel on screen without joining it. A channel already open is
  switched to; one the server refuses says so in the conversation.
  """
  @spec watch_channel(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def watch_channel(socket, channel) do
    session = socket.assigns.session

    if channel in session.channels do
      socket
      |> assign(show_status_tab: false)
      |> Conversation.activate_channel(channel)
    else
      start_watching(socket, channel)
    end
  end

  defp start_watching(socket, channel) do
    case Server.watch(channel, self(), socket.assigns.visitor_nick) do
      {:ok, _state} ->
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

        session = Session.add_channel(socket.assigns.session, channel)

        socket
        |> assign(session: session, show_status_tab: false)
        |> ConversationsReadModel.touch_channel_activity(channel)
        |> ChannelHelpers.load_channel_user_count(channel)
        |> Conversation.activate_channel(channel)
        |> then(&ChannelHelpers.maybe_show_welcome(&1, channel, &1.assigns.session))
        |> ConversationsReadModel.load_popular_channels()

      {:error, _reason} ->
        Messages.error_event(
          socket,
          dgettext("chat", "%{channel} cannot be watched without an account.", channel: channel)
        )
    end
  end

  @doc "Closes a channel the visitor was watching and moves to the next one."
  @spec unwatch_channel(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def unwatch_channel(socket, channel) do
    Server.unwatch(channel, self())
    leave(socket, channel)
  end

  @doc """
  The channel stopped being open to visitors — it went secret or locked, or
  its last member left a room nobody registered. Closes it with a line saying
  why.
  """
  @spec watch_closed(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def watch_closed(socket, channel) do
    if channel in socket.assigns.session.channels do
      socket
      |> leave(channel)
      |> Messages.system_event(
        dgettext("chat", "%{channel} is no longer open to visitors.", channel: channel)
      )
    else
      socket
    end
  end

  defp leave(socket, channel) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, Topics.channel(channel))

    session = Session.remove_channel(socket.assigns.session, channel)

    socket =
      assign(socket,
        session: session,
        channel_user_counts: Map.delete(socket.assigns.channel_user_counts, channel),
        channel_guests: Map.delete(socket.assigns.channel_guests, channel)
      )
      |> ConversationsReadModel.drop_channel_activity(channel)
      |> ConversationsReadModel.load_popular_channels()

    case session.active_channel do
      nil -> assign(socket, show_status_tab: true)
      next -> Conversation.activate_channel(socket, next)
    end
  end

  @doc """
  Opens the sign-in window — `/connect` on the desktop — saying which
  `feature` needs an account. Whoever signs in there comes back to
  `return_to` when it is one of ours, and otherwise to the conversation they
  were reading.
  """
  @spec ask_to_sign_in(Phoenix.LiveView.Socket.t(), feature(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def ask_to_sign_in(socket, feature, return_to \\ nil) do
    push_patch(socket, to: Paths.visitor_sign_in_path(feature, way_back(socket, return_to)))
  end

  defp way_back(socket, return_to) do
    case ReturnTo.sanitize(return_to) do
      "/" -> Address.chat_address(socket.assigns)
      path -> path
    end
  end

  # ── The gate ──────────────────────────────────────────────────

  defp gate(event, _params, socket) when event in @reading_events, do: {:cont, socket}
  defp gate(event, _params, socket) when event in @background_events, do: {:halt, socket}

  # The window manager asks for a server-managed window it has to mount — on a
  # restored layout as much as on a click. Every one of them is a tool with
  # events of its own, out of this gate's reach, so a visitor mounts none but
  # the sign-in window. Not asked about: restoring a layout is not something
  # the reader did.
  defp gate("window_open", _params, socket), do: {:halt, socket}

  defp gate(event, %{"channel" => channel}, socket)
       when event in ~w(switch_channel channel_click conversations_join_popular) do
    {:halt, watch_channel(socket, channel)}
  end

  defp gate("channel_list_join", %{"channel" => channel}, socket) do
    {:halt, socket |> ChannelListEvents.close() |> watch_channel(channel)}
  end

  defp gate("switch_tab", %{"type" => "channel", "label" => channel}, socket),
    do: {:halt, watch_channel(socket, channel)}

  defp gate("switch_tab", %{"type" => "status"}, socket), do: {:cont, socket}

  defp gate("close_tab", %{"type" => "channel", "label" => channel}, socket),
    do: {:halt, unwatch_channel(socket, channel)}

  defp gate("close_channel_tab", %{"channel" => channel}, socket),
    do: {:halt, unwatch_channel(socket, channel)}

  defp gate("toolbar_action", %{"action" => action} = params, socket) do
    gate(action, Map.delete(params, "action"), socket)
  end

  defp gate("window_keydown", %{"key" => "Escape"}, socket), do: {:cont, socket}

  defp gate("window_keydown", params, socket),
    do: gate_shortcut(KeyBindings.find_action(KeyBindings.defaults(), params), socket)

  defp gate("shortcut_action", %{"action" => action}, socket) do
    gate_shortcut(
      Enum.find(@reading_shortcuts, &(Atom.to_string(&1) == action)) || :action,
      socket
    )
  end

  # A link of ours names where it led: signing in lands there.
  defp gate("visitor_link", %{"path" => path} = params, socket),
    do: {:halt, ask_to_sign_in(socket, feature_of("visitor_link", params), path)}

  defp gate(event, params, socket), do: {:halt, ask_to_sign_in(socket, feature_of(event, params))}

  # A key with no binding is typing, not an action — there is nothing to ask.
  defp gate_shortcut(nil, socket), do: {:halt, socket}
  defp gate_shortcut(action, socket) when action in @reading_shortcuts, do: {:cont, socket}
  defp gate_shortcut(_action, socket), do: {:halt, ask_to_sign_in(socket, :feature)}

  # Which feature an event belongs to, for the sentence the sign-in window
  # shows. Read from the event's name, the way the chat already groups them.
  defp feature_of("visitor_sign_in", _params), do: :chat
  defp feature_of("visitor_link", %{"feature" => feature}), do: feature_named(feature)
  defp feature_of(event, _params) when event in ~w(visitor_link confirm_open_tab), do: :links
  defp feature_of("open_arcade", _params), do: :games
  defp feature_of("arcade_" <> _rest, _params), do: :games
  defp feature_of("game_" <> _rest, _params), do: :games
  defp feature_of("p2p_" <> _rest, _params), do: :p2p
  defp feature_of("lobby_" <> _rest, _params), do: :p2p
  defp feature_of("group_call" <> _rest, _params), do: :calls
  defp feature_of("space_" <> _rest, _params), do: :space
  defp feature_of(_event, _params), do: :feature
end
