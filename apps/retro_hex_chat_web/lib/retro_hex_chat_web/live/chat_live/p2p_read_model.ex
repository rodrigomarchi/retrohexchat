defmodule RetroHexChatWeb.ChatLive.P2PReadModel do
  @moduledoc """
  What the chat knows about a P2P session its reader is not inside.

  The rule that decides what belongs here: if the datum exists for someone who
  is only looking at the conversation, it lives in the chat; if it exists only
  while you are inside the session, it belongs to the session's own surface.
  The tab-bar entry, the sidebar badge, the taskbar button and the status zone
  are all this side of that line, and none of them needs media, devices, stats
  or a signalling token.

  Two assigns hold it. `@p2p_pm_sessions` answers "does this private
  conversation have a session" for a render that only needs a badge — including
  an invite the reader has not accepted, which is a card and not a connection.
  `@p2p_session` is the one session this reader is actually in, narrowed to
  what the chat's own chrome draws, and the surface hands it over as it
  changes.

  It is also what decides whether the chat's P2P window exists at all: the
  window renders the surface, and the surface is what joins the session, so
  something the chat can know without joining has to come first.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.P2P
  alias RetroHexChatWeb.App.SessionHelpers

  @pubsub RetroHexChat.PubSub

  @doc """
  Rebuild what the chat knows about P2P, after a mount or a reconnect.

  A pending invite this person received stays a card: it is drawn, and nothing
  is joined. Anything further along reopens the surface, because the session
  server owns that fact and a reload must not look like an ending.
  """
  @spec refresh_all(Socket.t()) :: Socket.t()
  def refresh_all(%{assigns: %{session: %{nickname: nickname}}} = socket)
      when is_binary(nickname) do
    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         %LobbySession{} = db_session <- Lobby.active_session_for_user(user_id) do
      role = role_of(db_session, user_id)

      case {db_session.status, role} do
        # A match link this person minted is not a session they are in: nobody
        # has taken the seat, there is no conversation it belongs to, and the
        # room for it lives at its own address. `active_sessions_for_user/1`
        # matches it on `creator_id` alone, so without this the chat would open
        # a P2P window onto a session with no peer in it.
        {"open", _role} -> socket
        {"pending", :peer} -> put_pm_session(socket, pm_session(db_session, user_id))
        _joined -> open(socket, db_session.token, user_id, role, db_session.status)
      end
    else
      _none -> socket
    end
  end

  def refresh_all(socket), do: socket

  @doc """
  Record that this reader has a session at `token`, and start listening to it.

  The chat listens for the end of it and nothing else: everything that happens
  *inside* is the surface's, and the surface says what needs saying. What the
  chat needs is to stop drawing a window for a session that is over.
  """
  @spec open(Socket.t(), String.t(), integer(), :creator | :peer, String.t()) :: Socket.t()
  def open(socket, token, user_id, role, status) do
    Phoenix.PubSub.subscribe(@pubsub, topic(token))

    assign(socket,
      p2p_session: %{
        token: token,
        user_id: user_id,
        role: role,
        peer_nick: peer_nick_for(token, user_id),
        state: state_for(status, role),
        turn_configured: P2P.turn_configured?(),
        pid: nil
      }
    )
  end

  @doc "Stop drawing the session, and stop listening to it."
  @spec close(Socket.t()) :: Socket.t()
  def close(%{assigns: %{p2p_session: %{token: token}}} = socket) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(token))
    assign(socket, p2p_session: nil)
  end

  def close(socket), do: socket

  @doc "Merge what the surface says about the session it is holding."
  @spec merge(Socket.t(), pid(), map()) :: Socket.t()
  def merge(%{assigns: %{p2p_session: %{} = current}} = socket, pid, snapshot) do
    assign(socket, p2p_session: current |> Map.merge(snapshot) |> Map.put(:pid, pid))
  end

  def merge(socket, _pid, _snapshot), do: socket

  @doc """
  Refresh the badge for one private conversation, without joining anything.

  This backs the PM header, tab and sidebar pending state. It deliberately
  never joins: a received invite stays consent-free until the reader accepts
  it, and accepting it is what mounts the surface.
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

  @doc "Forget the badge that carries `token`, whoever the peer was."
  @spec drop_pm_by_token(Socket.t(), String.t()) :: Socket.t()
  def drop_pm_by_token(socket, token) when is_binary(token) do
    assign(
      socket,
      p2p_pm_sessions:
        socket |> pm_sessions() |> Enum.reject(&match?({_key, %{token: ^token}}, &1)) |> Map.new()
    )
  end

  def drop_pm_by_token(socket, _token), do: socket

  @doc "Every private conversation with a session, keyed by downcased nickname."
  @spec pm_sessions(Socket.t()) :: %{String.t() => map()}
  def pm_sessions(socket), do: socket.assigns[:p2p_pm_sessions] || %{}

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
    assign(
      socket,
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
      turn_configured: P2P.turn_configured?()
    }
  end

  defp state_for("pending", :peer), do: :pending_received
  defp state_for("pending", :creator), do: :invite_sent
  defp state_for("connected", _role), do: :connected
  defp state_for("lobby", _role), do: :joining
  defp state_for(_status, _role), do: :connecting

  defp topic(token), do: "lobby:#{token}"
end
