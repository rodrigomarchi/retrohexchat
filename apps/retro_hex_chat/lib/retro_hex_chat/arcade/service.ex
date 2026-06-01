defmodule RetroHexChat.Arcade.Service do
  @moduledoc """
  Orchestrates solo arcade session operations: policy check → persist → process.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Arcade.{Catalog, Policy, Queries, SoloSessionServer, Supervisor}
  alias RetroHexChat.Arcade.Schema.SoloSession

  @spec create_session(integer()) ::
          {:ok, %{session: SoloSession.t(), token: String.t()}} | {:error, String.t()}
  def create_session(creator_id) do
    with :ok <- Policy.can_create?(creator_id),
         :ok <- close_active_session(creator_id),
         token = generate_token(),
         {:ok, session} <- insert_session(token, creator_id),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.info("Arcade session created: token=#{session.token}, creator=#{creator_id}")
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.info("Arcade session denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  def join_session(token, user_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_join?(user_id, session) do
      SoloSessionServer.join(token, user_id)
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
    case SoloSessionServer.close(token, user_id, reason) do
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
    message in ["Session process not running", dgettext("arcade", "Session process not running")]
  end

  @spec select_game(String.t(), integer(), String.t()) :: :ok | {:error, atom() | String.t()}
  def select_game(token, user_id, game_id) do
    if Catalog.valid_game_id?(game_id) do
      SoloSessionServer.select_game(token, user_id, game_id)
    else
      {:error, :invalid_game_id}
    end
  end

  @spec finish_game(String.t(), integer()) :: :ok | {:error, atom()}
  def finish_game(token, user_id) do
    SoloSessionServer.finish_game(token, user_id)
  end

  # --- Private Helpers ---

  defp close_active_session(creator_id) do
    case Queries.get_active_session(creator_id) do
      nil ->
        :ok

      session ->
        Logger.info(
          "Arcade closing previous session: token=#{session.token}, creator=#{creator_id}"
        )

        close_session(session.token, creator_id, "new_session")
    end
  end

  defp generate_token do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp insert_session(token, creator_id) do
    case Queries.insert_session(%{
           token: token,
           creator_id: creator_id,
           status: "pending"
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert arcade session: #{inspect(changeset.errors)}")
        {:error, dgettext("arcade", "Failed to create session")}
    end
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, dgettext("arcade", "Session not found")}
      session -> {:ok, session}
    end
  end
end
