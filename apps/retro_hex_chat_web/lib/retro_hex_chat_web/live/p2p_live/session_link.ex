defmodule RetroHexChatWeb.P2PLive.SessionLink do
  @moduledoc """
  This page's link to the session process: taking the seat (and the assign a
  new session starts with), the PubSub subscriptions, what the watchers and
  the other side are told, the lines persisted into the conversation, and
  letting go when the session ends.
  """

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Watchers
  alias RetroHexChat.Lobby
  alias RetroHexChat.P2P
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.P2PLive.Components.P2PGameIsland
  alias RetroHexChatWeb.P2PLive.{SessionStatus, SetupPreferences}
  alias RetroHexChatWeb.SEO

  @pubsub RetroHexChat.PubSub

  defp new_session(socket, token, user_id, role, state, opts) do
    setup_preferences = SetupPreferences.load(socket)
    peer_nick = SessionStatus.peer_nick_for(token, user_id)
    # Both languages in one lookup, kept with the session: the flags beside the
    # two names never ask again unless the peer's name changes.
    locales = NickLocales.for_nicks(Enum.filter([socket.assigns[:nickname], peer_nick], & &1))

    %{
      token: token,
      user_id: user_id,
      role: role,
      # The game this session was created for, or nil for a plain session.
      # It is the difference between a room with devices in it and a room with
      # a game in it, and it is read from the session rather than the address.
      match_game_id: Keyword.get(opts, :match_game_id),
      match_proposed: false,
      peer_nick: peer_nick,
      peer_locale: Map.get(locales, peer_nick),
      self_locale: Map.get(locales, socket.assigns[:nickname]),
      state: state,
      webrtc_started: false,
      # Whether this page's start announces a rebuild. A page that opens into a
      # session already negotiating is one — whatever releases its start, the
      # peer has to be told the connection is new, or it reads this page's first
      # offer as stale for the rest of the session. It is also what makes the
      # resend to a hook that was still loading say the same thing twice.
      webrtc_connection_reset: false,
      # The starting room, in three facts. `room_ready` is the devices chosen,
      # `hook_ready` is the WebRTC hook mounted — `[Ready]` needs both, and the
      # domain's gate is what turns the pair on the other side into
      # `peer_ready`. `session_started` is the host having pressed `[Start]`,
      # which is the only thing that releases the first offer.
      room_ready: false,
      hook_ready: false,
      peer_ready: false,
      session_started: false,
      displaced: false,
      stats: P2PStats.empty(),
      info_open: false,
      peer_online: false,
      peer_info: %{},
      file_summary: nil,
      call_summary: nil,
      game_summary: nil,
      auto_call_started: false,
      recovery: SessionStatus.empty_p2p_recovery(),
      console_section: "call",
      media_mode: SetupPreferences.media_mode(setup_preferences),
      call_mini: false,
      device_preferences: setup_preferences.device_preferences,
      turn_only: setup_preferences.turn_only,
      turn_configured: P2P.turn_configured?()
    }
  end

  @doc """
  The creator of an invite nobody has accepted yet.

  Subscribed and drawn, but not seated: a pending invite is a card, and taking
  a seat would start the rejoin grace on a session with nobody in it.
  """
  @spec new_invite_sent(Socket.t(), String.t(), integer(), keyword()) :: map()
  def new_invite_sent(socket, token, user_id, opts \\ []) do
    new_session(socket, token, user_id, :creator, :invite_sent, opts)
  end

  @doc """
  The device half of the starting room, before the browser has listed anything.

  The person's remembered preferences, not the screen's: the terminal that
  remembered a camera for the chat's setup dialog hands it to the room that
  replaced it.
  """
  @spec initial_setup(Socket.t()) :: map()
  def initial_setup(socket) do
    preferences = SetupPreferences.load(socket)

    %{
      media: preferences.media,
      media_mode: SetupPreferences.media_mode(preferences),
      devices: default_devices(),
      device_preferences: preferences.device_preferences,
      turn_only: preferences.turn_only,
      turn_configured: P2P.turn_configured?()
    }
  end

  @doc """
  Who is in the starting room and what each of them is still waiting on.

  Two seats and never more: a P2P session is one person talking to one person,
  and the empty half is exactly the half the reader is waiting for.
  """
  @spec room(map()) :: map()
  def room(%{p2p_session: %{} = p2p, nickname: nickname}) do
    %{
      nickname: nickname,
      match?: is_binary(p2p.match_game_id),
      peer_nick: p2p.peer_nick,
      peer_locale: Map.get(p2p, :peer_locale),
      self_locale: Map.get(p2p, :self_locale),
      host?: p2p.role == :creator,
      host_nick: if(p2p.role == :creator, do: nickname, else: p2p.peer_nick),
      ready?: p2p.room_ready,
      started?: p2p.session_started,
      peer_present?: p2p.state != :invite_sent,
      peer_ready?: p2p.peer_ready,
      can_start?: room_can_start?(p2p)
    }
  end

  @doc """
  Whether the creator's `[Start]` may be pressed.

  Both sides ready is the domain's own gate, arriving as `lobby_start_signaling`
  and recorded as `peer_ready`; the button is that gate with a face.
  """
  @spec room_can_start?(map()) :: boolean()
  def room_can_start?(%{role: :creator} = p2p),
    do: p2p.room_ready and p2p.hook_ready and p2p.peer_ready and not p2p.session_started

  def room_can_start?(_p2p), do: false

  @spec share_client_info(Socket.t(), map()) :: Socket.t()
  def share_client_info(socket, p2p) do
    Lobby.broadcast(p2p.token, "lobby_client_info", %{
      from: p2p.user_id,
      info: socket.assigns[:client_info] || %{}
    })

    socket
  end

  # A page that is asked to be in this session takes the seat, and the page that
  # held it is told. The alternative is refusing the second window, which spends
  # five backoff attempts and then says "close that window" — a dead end reached
  # by doing something reasonable, and unreachable to fix from the window you are
  # looking at. The most recently opened page is the one the person is looking
  # at, which is the same contract the chat's own takeover has.
  @spec attach_session(Socket.t(), String.t(), integer(), :creator | :peer, keyword()) ::
          Socket.t()
  def attach_session(socket, token, user_id, role, opts \\ []) do
    case Lobby.join_session(token, user_id, takeover: true) do
      :ok ->
        subscribe_session(token)
        p2p = new_session(socket, token, user_id, role, :joining, opts)

        socket
        |> SessionStatus.put_p2p(p2p)
        |> share_client_info(p2p)

      {:error, message} ->
        SessionStatus.p2p_system_event(socket, message)
    end
  end

  @doc """
  This page listens to a session: what it says, and who is watching its
  match. `unsubscribe_session/1` is the way back.
  """
  @spec subscribe_session(String.t()) :: :ok
  def subscribe_session(token) do
    :ok = Phoenix.PubSub.subscribe(@pubsub, Topics.lobby(token))
    Phoenix.PubSub.subscribe(@pubsub, Topics.lobby_watchers(token))
  end

  @spec unsubscribe_session(String.t()) :: :ok
  def unsubscribe_session(token) do
    :ok = Phoenix.PubSub.unsubscribe(@pubsub, Topics.lobby(token))
    Phoenix.PubSub.unsubscribe(@pubsub, Topics.lobby_watchers(token))
  end

  # What the game panel says about the people watching: how many, and the
  # address to hand on — only for a match others may watch.
  @spec send_watchers(String.t()) :: :ok
  def send_watchers(token) do
    watch_url = if Lobby.watch_token(token), do: SEO.site_url(Paths.watch_path(token))

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:watchers, Watchers.count(token), watch_url}
    )
  end

  # A session that ends mid-game ends the game with it: nobody is playing it
  # any more, and nobody can watch it.
  @spec detach_session(Socket.t(), map()) :: Socket.t()
  def detach_session(socket, p2p) do
    unsubscribe_session(p2p.token)
    :ok = Activity.stopped(socket.assigns.nickname)

    SessionStatus.put_p2p(socket, nil)
  end

  # Whatever ended it, this page's status bar says so: it is this page's own
  # line, never written into the private chat, so it duplicates nothing — and
  # without it the bar kept saying the session was connected.
  @spec finish_session(Socket.t(), String.t()) :: Socket.t()
  def finish_session(socket, reason) do
    p2p = socket.assigns.p2p_session

    socket
    |> detach_session(p2p)
    |> Surface.system(SessionStatus.ended_message(p2p.peer_nick, reason))
    |> Phoenix.Component.assign(:ended, %{
      reason: reason,
      peer: p2p.peer_nick,
      started: p2p.session_started
    })
    |> Surface.close()
  end

  defp default_devices, do: MediaDevices.none()

  # Persists a session notice into the PM thread (D2: the PM is the
  # conversation). The PM broadcast delivers it to BOTH sides — hence the
  # single-writer rule everywhere this is called.
  @spec persist_p2p_system(Socket.t(), String.t() | nil, String.t()) :: :ok
  def persist_p2p_system(socket, peer_nick, text) when is_binary(peer_nick) do
    _ =
      ChatService.send_private_message(
        socket.assigns.nickname,
        peer_nick,
        text,
        "p2p_system"
      )

    :ok
  end

  def persist_p2p_system(_socket, _peer_nick, _text), do: :ok
end
