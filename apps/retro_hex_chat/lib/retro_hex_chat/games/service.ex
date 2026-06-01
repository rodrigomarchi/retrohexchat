defmodule RetroHexChat.Games.Service do
  @moduledoc """
  Orchestrates game session operations: policy check → persist → process → notify.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Games.{Catalog, Policy, Queries, RateLimiter, SessionServer, Supervisor}
  alias RetroHexChat.Games.Schema.GameSession

  @pubsub RetroHexChat.PubSub

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: GameSession.t(), token: String.t()}} | {:error, String.t()}
  def create_session(creator_id, peer_id) do
    with :ok <- check_rate_limit(creator_id),
         :ok <- Policy.can_create?(creator_id, peer_id),
         token = generate_token(),
         {:ok, session} <- insert_session(token, creator_id, peer_id),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.info(
        "Game session created: token=#{session.token}, creator=#{creator_id}, peer=#{peer_id}"
      )

      notify_peer(peer_id, session.token, creator_id)
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.info("Game session denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  def join_session(token, user_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_join?(user_id, session) do
      SessionServer.join(token, user_id)
    end
  end

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close_session(token, user_id, reason) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_close?(user_id, session) do
      close_session_server(session, token, user_id, reason)
    end
  end

  defp close_session_server(session, token, user_id, reason) do
    case SessionServer.close(token, user_id, reason) do
      :ok -> :ok
      {:error, message} -> handle_close_error(session, reason, message)
      error -> error
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
    now = DateTime.utc_now()

    Queries.update_status(session, "closed", %{
      closed_at: now,
      closed_reason: reason
    })
  end

  defp session_process_not_running?(message) do
    message in ["Session process not running", dgettext("games", "Session process not running")]
  end

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def send_lobby_message(token, user_id, content) do
    nick = get_nickname(user_id)
    SessionServer.send_message(token, user_id, nick || "unknown", content)
  end

  @spec select_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def select_game(token, user_id, game_id) do
    if Catalog.valid_game_id?(game_id) do
      nick = get_nickname(user_id)
      SessionServer.select_game(token, user_id, nick || "unknown", game_id)
    else
      {:error, :invalid_game_id}
    end
  end

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  def respond_game(token, user_id, accepted?) do
    nick = get_nickname(user_id)
    SessionServer.respond_game(token, user_id, nick || "unknown", accepted?)
  end

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  def finish_game(token, user_id, result) do
    SessionServer.finish_game(token, user_id, result)
  end

  # --- Private Helpers ---

  defp generate_token do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp insert_session(token, creator_id, peer_id) do
    case Queries.insert_session(%{
           token: token,
           creator_id: creator_id,
           peer_id: peer_id,
           status: "pending"
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert game session: #{inspect(changeset.errors)}")
        {:error, dgettext("games", "Failed to create session")}
    end
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, dgettext("games", "Session not found")}
      session -> {:ok, session}
    end
  end

  defp notify_peer(peer_id, token, creator_id) do
    peer_nick = get_nickname(peer_id)
    creator_nick = get_nickname(creator_id)

    if peer_nick do
      Phoenix.PubSub.broadcast(@pubsub, "user:#{peer_nick}", %{
        event: "game_invite",
        payload: %{
          token: token,
          from: creator_nick
        }
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
        {:error, "Too many game sessions created. Try again in #{remaining_seconds} seconds"}
    end
  end
end
