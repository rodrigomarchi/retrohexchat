defmodule RetroHexChatWeb.ChatLive.P2PReadModel do
  @moduledoc """
  What the chat knows about the P2P sessions its reader is not inside.

  The rule that decides what belongs here: if the datum exists for someone who
  is only looking at the conversation, it lives in the chat; if it exists only
  while you are inside the session, it belongs to the session's own page. The
  tab-bar entry, the sidebar badge and the status zone are all this side of that
  line, and none of them needs media, devices, stats or a signalling token.

  One assign holds it. `@p2p_pm_sessions` answers "does this private
  conversation have a session, and how far along is it" — keyed by the peer's
  downcased nickname, because that is the question every one of those readers
  asks. An invite the reader has not answered is in there too: it is a card in
  the conversation, not a connection.

  **Everything here is read from the database, and what asks for the re-read is
  the session speaking on the reader's own topic.** It used to be fed by the
  surface the chat rendered inside itself, which meant the chat could only know
  about a session it was hosting. A session lives at its own address now, in a
  tab of its own, and it tells the two people in it — `lobby_invite`,
  `lobby_session_progress`, `lobby_session_ended` on `user:` — rather than the
  chat listening to the room. That is not a detail: the room's topic is where
  the WebRTC negotiation crosses, so a chat subscribed to it would carry every
  ICE candidate of every session its reader has a badge for.

  A person can be in more than one at once — a different peer in each — so this
  is a map and not a single session. What the chat draws about the one whose
  tab this reader already has open is `elsewhere/2`, and that is the only shape
  the status bar has: you end a session from the page that is holding it.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Live.OpenSurfaces

  @doc """
  Rebuild every badge from the database, after a mount or a reconnect.

  Nothing is joined and nothing is opened: a reload is not consent, and the
  session's page is where consent is given.
  """
  @spec refresh_all(Socket.t()) :: Socket.t()
  def refresh_all(%{assigns: %{session: %{nickname: nickname}}} = socket)
      when is_binary(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} ->
        sessions =
          user_id
          |> Lobby.active_sessions_for_user()
          |> Enum.map(&pm_session(&1, user_id))
          |> Enum.filter(&is_binary(&1.peer_nick))
          |> Map.new(&{String.downcase(&1.peer_nick), &1})

        assign(socket, p2p_pm_sessions: sessions)

      _unregistered ->
        socket
    end
  end

  def refresh_all(socket), do: socket

  @doc """
  Refresh the badge for one private conversation, without joining anything.

  This backs the PM header, tab and sidebar pending state. It deliberately
  never joins: a received invite stays consent-free until the reader follows
  its card, and following the card is what mounts the session.
  """
  @spec refresh_pm(Socket.t(), String.t() | nil) :: Socket.t()
  def refresh_pm(%{assigns: %{session: %{nickname: nickname}}} = socket, peer_nick)
      when is_binary(peer_nick) do
    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         %LobbySession{} = db_session <- Lobby.active_session_between_nicks(nickname, peer_nick) do
      put_pm_session(socket, pm_session(db_session, user_id))
    else
      _none -> drop_pm(socket, peer_nick)
    end
  end

  def refresh_pm(socket, _peer_nick), do: socket

  @doc "Forget the badge for one private conversation."
  @spec drop_pm(Socket.t(), String.t() | nil) :: Socket.t()
  def drop_pm(socket, peer_nick) when is_binary(peer_nick) do
    assign(socket, p2p_pm_sessions: Map.delete(pm_sessions(socket), String.downcase(peer_nick)))
  end

  def drop_pm(socket, _peer_nick), do: socket

  @doc "Every private conversation with a session, keyed by downcased nickname."
  @spec pm_sessions(Socket.t()) :: %{String.t() => map()}
  def pm_sessions(socket), do: socket.assigns[:p2p_pm_sessions] || %{}

  @doc """
  The session this reader already has open at its own address, if any.

  The only shape the chat's status zone has. There is nothing to focus here and
  nothing to end from here — a session is ended on the page that holds it — so
  what is left is a way over to the tab that does.

  Takes the two values rather than the socket: inside a template `@socket`
  carries no assigns at all, so a version that read them there would answer
  "nothing is open" forever, in silence, and only where it is actually used.
  """
  @spec elsewhere(%{String.t() => map()}, MapSet.t(String.t())) ::
          %{peer_nick: String.t(), path: String.t()} | nil
  def elsewhere(pm_sessions, open_paths) when is_map(pm_sessions) do
    pm_sessions
    |> Map.values()
    |> Enum.sort_by(& &1.peer_nick)
    |> Enum.find_value(fn %{path: path, peer_nick: peer_nick} ->
      if is_binary(peer_nick) and OpenSurfaces.open?(open_paths, path) do
        %{peer_nick: peer_nick, path: path}
      end
    end)
  end

  def elsewhere(_pm_sessions, _open_paths), do: nil

  @doc "Which role `user_id` plays in `db_session`."
  @spec role_of(LobbySession.t(), integer()) :: :creator | :peer
  def role_of(%LobbySession{creator_id: user_id}, user_id), do: :creator
  def role_of(_db_session, _user_id), do: :peer

  @doc """
  The other person's nickname in `token`, as this `user_id` sees it.

  Read from the domain rather than remembered: the chat can be asked to draw a
  session it has never been inside.
  """
  @spec peer_nick_for(String.t(), integer()) :: String.t() | nil
  def peer_nick_for(token, user_id) do
    with {:ok, summary} <- Lobby.session_summary(token),
         {:ok, db_session} <- Lobby.get_session(token) do
      if db_session.creator_id == user_id, do: summary.peer, else: summary.created_by
    else
      _absent -> nil
    end
  end

  defp put_pm_session(socket, %{peer_nick: peer_nick} = read_model) when is_binary(peer_nick) do
    assign(socket,
      p2p_pm_sessions: Map.put(pm_sessions(socket), String.downcase(peer_nick), read_model)
    )
  end

  defp put_pm_session(socket, _read_model), do: socket

  # A badge, and only a badge: the fields a conversation row reads, and not one
  # more. The full state machine belongs to whoever is actually in the session.
  defp pm_session(%LobbySession{} = db_session, user_id) do
    role = role_of(db_session, user_id)

    %{
      token: db_session.token,
      user_id: user_id,
      role: role,
      peer_nick: peer_nick_for(db_session.token, user_id),
      state: state_for(db_session.status, role),
      path: Paths.p2p_path(db_session.token)
    }
  end

  defp state_for("pending", :peer), do: :pending_received
  defp state_for("pending", :creator), do: :invite_sent
  defp state_for("connected", _role), do: :connected
  defp state_for("lobby", _role), do: :joining
  defp state_for(_status, _role), do: :connecting
end
