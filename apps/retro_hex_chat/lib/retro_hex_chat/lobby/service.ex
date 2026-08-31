defmodule RetroHexChat.Lobby.Service do
  @moduledoc """
  Orchestrates P2P lobby operations: policy check → persist → process → notify.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Lobby.{Policy, Queries, SessionServer, Supervisor}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.P2P.RateLimiter

  @pubsub RetroHexChat.PubSub
  @open_lobby_ttl_ms :timer.minutes(15)

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  def create_session(creator_id, peer_id) do
    with :ok <- check_rate_limit(creator_id),
         :ok <- Policy.can_create?(creator_id, peer_id),
         {:ok, session} <- insert_session(creator_id, peer_id),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.debug(
        "Lobby session created: session_id=#{session.id}, creator=#{creator_id}, peer=#{peer_id}"
      )

      notify_peer(peer_id, session.token, creator_id)
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.debug("Lobby session denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @doc """
  Creates a lobby nobody has been named for yet — a match link.

  The direct invite names its peer and reaches one person; this one names
  nobody and reaches whoever follows the link. That is the whole difference,
  and it is why there is no process yet: an unclaimed lobby is a row and a
  deadline, and starting a GenServer for a match that may never happen would
  make a posted link cost a process.

  `expires_at` is short on purpose. An open lobby is an invitation, not an
  address: the longer it stands the longer anybody holding the link can walk
  in, so it dies on its own and `Jobs.OpenLobbyExpiryWorker` is what buries it.
  """
  @spec create_open_session(integer(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  def create_open_session(creator_id, opts \\ []) do
    with :ok <- check_rate_limit(creator_id),
         :ok <- Policy.can_create_open?(creator_id),
         {:ok, session} <- insert_open_session(creator_id, opts) do
      Logger.debug("Open lobby created: session_id=#{session.id}, creator=#{creator_id}")
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.debug("Open lobby denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @doc """
  Takes the empty seat of an open lobby.

  Two steps, and the order is the point: the policy answers whether this person
  may be in this match at all, and then **one conditional write** decides
  whether they got there first. The policy never decides the race — between its
  answer and the write, somebody else may have taken the seat, and the database
  is the only thing that can say so.

  The session's process starts here, once, on the winner's write: before the
  claim there is nobody to talk to, and after it the row is an ordinary pending
  invite that the rest of the lobby already knows how to run.
  """
  @spec claim_open_session(String.t(), integer()) ::
          {:ok, Session.t()} | {:error, String.t() | :already_claimed}
  def claim_open_session(token, claimer_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_claim?(claimer_id, session),
         {:ok, claimed} <- Queries.claim_open_session(token, claimer_id),
         :ok <- ensure_session_server(claimed.token) do
      Logger.debug("Open lobby claimed: session_id=#{claimed.id}, claimer=#{claimer_id}")
      {:ok, claimed}
    end
  end

  @spec can_create_session?(integer(), integer()) :: :ok | {:error, String.t()}
  def can_create_session?(creator_id, peer_id), do: Policy.can_create?(creator_id, peer_id)

  @spec join_session(String.t(), integer(), keyword()) ::
          :ok | {:error, String.t() | :already_joined}
  def join_session(token, user_id, opts \\ []) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_join?(user_id, session) do
      SessionServer.join(token, user_id, opts)
    end
  end

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close_session(token, user_id, reason) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_close?(user_id, session) do
      close_session_server(session, token, user_id, reason)
    end
  end

  @spec decline_session(String.t(), integer()) :: :ok | {:error, String.t()}
  def decline_session(token, user_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_decline?(user_id, session) do
      close_session_server(session, token, user_id, "declined")
    end
  end

  @spec cancel_invite(String.t(), integer()) :: :ok | {:error, String.t()}
  def cancel_invite(token, user_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_cancel_invite?(user_id, session) do
      close_session_server(session, token, user_id, "invite_cancelled")
    end
  end

  @spec close_sessions_between(integer(), integer()) :: :ok
  def close_sessions_between(user_a_id, user_b_id) do
    for session <- Queries.active_sessions_between(user_a_id, user_b_id) do
      close_session_server(session, session.token, user_a_id, "user_blocked")
    end

    :ok
  end

  @spec propose_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def propose_game(token, user_id, game_id) do
    nick = get_nickname(user_id)
    SessionServer.propose_game(token, user_id, nick || "unknown", game_id)
  end

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  def respond_game(token, user_id, accepted?) do
    nick = get_nickname(user_id)
    SessionServer.respond_game(token, user_id, nick || "unknown", accepted?)
  end

  # --- Private helpers ---

  defp close_session_server(session, token, user_id, reason) do
    case SessionServer.close(token, user_id, reason) do
      :ok -> :ok
      {:error, message} -> handle_close_error(session, reason, message)
    end
  end

  defp handle_close_error(session, reason, message) do
    if session_process_not_running?(message) do
      mark_session_closed(session, reason)
      :ok
    else
      {:error, message}
    end
  end

  defp mark_session_closed(session, reason) do
    Queries.update_status(session, "closed", %{
      closed_at: DateTime.utc_now(),
      closed_reason: reason
    })
  end

  defp session_process_not_running?(message) do
    message in ["Session process not running", dgettext("lobby", "Session process not running")]
  end

  defp insert_session(creator_id, peer_id) do
    db_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    case Queries.insert_session(%{
           token: db_token,
           creator_id: creator_id,
           peer_id: peer_id,
           status: "pending"
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert lobby session: #{inspect(changeset.errors)}")
        {:error, dgettext("lobby", "Failed to create lobby")}
    end
  end

  # Winning the write is what owns the seat; the process is a consequence of
  # it. A server that is somehow already up is that consequence having already
  # happened, not a reason to tell the winner they lost.
  defp ensure_session_server(token) do
    case Supervisor.start_child(token) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.warning("Open lobby claimed but process failed: #{inspect(reason)}")
        {:error, dgettext("lobby", "Failed to create lobby")}
    end
  end

  defp insert_open_session(creator_id, opts) do
    db_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    ttl_ms = Keyword.get(opts, :expires_in_ms, open_lobby_ttl_ms())

    case Queries.insert_session(%{
           token: db_token,
           creator_id: creator_id,
           peer_id: nil,
           status: "open",
           expires_at: DateTime.add(now, ttl_ms, :millisecond)
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert open lobby: #{inspect(changeset.errors)}")
        {:error, dgettext("lobby", "Failed to create lobby")}
    end
  end

  defp open_lobby_ttl_ms do
    Application.get_env(:retro_hex_chat, :lobby_open_expiry, @open_lobby_ttl_ms)
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, dgettext("lobby", "Lobby not found")}
      session -> {:ok, session}
    end
  end

  defp notify_peer(peer_id, token, creator_id) do
    peer_nick = get_nickname(peer_id)
    creator_nick = get_nickname(creator_id)

    if peer_nick do
      Phoenix.PubSub.broadcast(@pubsub, "user:#{peer_nick}", %{
        event: "lobby_invite",
        payload: %{token: token, from: creator_nick}
      })
    end
  end

  defp get_nickname(user_id) do
    import Ecto.Query

    from(r in "registered_nicks", where: r.id == ^user_id, select: r.nickname)
    |> RetroHexChat.Repo.one()
  end

  defp check_rate_limit(user_id) do
    case RateLimiter.check_session_rate(user_id) do
      :ok ->
        :ok

      {:error, {:rate_limited, remaining_seconds}} ->
        {:error,
         dgettext("lobby", "Too many lobbies created. Try again in %{minutes} minutes",
           minutes: remaining_seconds
         )}
    end
  end
end
