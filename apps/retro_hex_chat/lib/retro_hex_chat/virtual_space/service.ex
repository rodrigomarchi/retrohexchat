defmodule RetroHexChat.VirtualSpace.Service do
  @moduledoc """
  Orchestrates virtual space operations: policy check → persist → process →
  notify. Errors are atoms (see `RetroHexChat.VirtualSpace.Policy`) except
  the rate limit, which carries the retry delay.
  """

  require Logger

  alias RetroHexChat.P2P.RateLimiter
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.VirtualSpace.Policy
  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChat.VirtualSpace.Schema.Session
  alias RetroHexChat.VirtualSpace.SessionServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @default_ttl :timer.hours(2)
  @max_ttl :timer.hours(8)
  @default_max_participants 20
  @max_participants_ceiling 50

  @type create_opts :: %{optional(:title) => String.t() | nil, optional(:ttl_ms) => pos_integer()}

  @spec create_session(Policy.actor(), String.t(), create_opts()) ::
          {:ok, %{session: Session.t(), token: String.t()}}
          | {:error,
             Policy.error() | :ttl_too_long | :create_failed | {:rate_limited, pos_integer()}}
  def create_session(actor, channel_name, opts) do
    with :ok <- check_rate_limit(actor.user_id),
         :ok <- Policy.can_create?(actor, channel_name),
         {:ok, ttl_ms} <- validate_ttl(Map.get(opts, :ttl_ms)),
         {:ok, session} <- insert_session(actor, channel_name, Map.get(opts, :title), ttl_ms),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.info(
        "VirtualSpace created: token=#{session.token}, channel=#{channel_name}, " <>
          "creator=#{actor.nickname}"
      )

      {:ok, %{session: session, token: session.token}}
    end
  end

  @spec join_session(String.t(), Policy.actor()) ::
          {:ok,
           %{participant: SessionServer.participant(), snapshot: map(), session: Session.t()}}
          | {:error, Policy.error() | :not_found}
  def join_session(token, actor) do
    with {:ok, session} <- fetch_session(token),
         {:ok, session} <- expire_if_overdue(session),
         :ok <- Policy.can_join?(actor, session),
         {:ok, _pid} <- ensure_process(token),
         {:ok, result} <-
           SessionServer.join(token, %{user_id: actor.user_id, nickname: actor.nickname}) do
      {:ok, Map.put(result, :session, session)}
    end
  end

  @spec leave(String.t(), String.t()) :: :ok
  def leave(token, participant_key) do
    SessionServer.leave(token, participant_key)
  end

  @spec close_session(String.t(), Policy.actor(), String.t()) ::
          {:error, Policy.error() | :not_found} | :ok
  def close_session(token, actor, reason) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_close?(actor, session) do
      case SessionServer.close(token, reason) do
        :ok ->
          :ok

        {:error, :not_found} ->
          mark_closed(session, reason)
          :ok
      end
    end
  end

  @doc """
  Advisory capacity check for the pre-join screen. The authoritative check
  runs inside `SessionServer.join/2`; without a live process the space is
  empty, so a newcomer always fits.
  """
  @spec check_capacity(Session.t(), integer()) :: :ok | {:error, :space_full}
  def check_capacity(session, user_id) do
    case SessionServer.get_state(session.token) do
      {:ok, state} ->
        key = "registered:#{user_id}"
        returning? = Map.has_key?(state.participants, key)
        active = state.participants |> Map.values() |> Enum.count(& &1.online?)
        Policy.check_capacity(session, active, returning?)

      {:error, :not_found} ->
        :ok
    end
  end

  @spec session_summary(String.t()) :: {:ok, map()} | {:error, :not_found}
  def session_summary(token) do
    case SessionServer.session_summary(token) do
      {:ok, summary} -> {:ok, summary}
      {:error, :not_found} -> db_summary(token)
    end
  end

  # --- Private helpers ---

  defp check_rate_limit(user_id) do
    case RateLimiter.check_session_rate(user_id) do
      :ok -> :ok
      {:error, {:rate_limited, _seconds}} = error -> error
    end
  end

  defp validate_ttl(nil), do: {:ok, default_ttl()}

  defp validate_ttl(ttl_ms) when is_integer(ttl_ms) and ttl_ms > 0 do
    if ttl_ms <= max_ttl() do
      {:ok, ttl_ms}
    else
      {:error, :ttl_too_long}
    end
  end

  defp validate_ttl(_), do: {:error, :ttl_too_long}

  defp insert_session(actor, channel_name, title, ttl_ms) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    expires_at = DateTime.add(DateTime.utc_now(), ttl_ms, :millisecond)

    case Queries.insert_session(%{
           token: token,
           channel_name: channel_name,
           creator_id: actor.user_id,
           creator_nick: actor.nickname,
           title: title,
           max_participants: max_participants(),
           expires_at: expires_at
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert virtual space: #{inspect(changeset.errors)}")
        {:error, :create_failed}
    end
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp expire_if_overdue(session) do
    overdue? =
      not Session.terminal?(session.status) and session.expires_at != nil and
        DateTime.compare(session.expires_at, DateTime.utc_now()) == :lt

    if overdue? do
      case Registry.lookup(session.token) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end

      {:ok, expired} = Queries.expire_session(Queries.get_session_by_token(session.token))
      {:ok, expired}
    else
      {:ok, session}
    end
  end

  defp ensure_process(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> {:ok, pid}
      {:error, :not_found} -> Supervisor.start_child(token)
    end
  end

  defp mark_closed(session, reason) do
    Queries.update_status(session, "closed", %{
      closed_at: DateTime.utc_now(),
      closed_reason: reason
    })
  end

  defp db_summary(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:error, :not_found}

      session ->
        {:ok,
         %{
           kind: :space,
           token: session.token,
           status: session.status,
           terminal?: Session.terminal?(session.status),
           title: session.title,
           map_id: session.map_id,
           channel_name: session.channel_name,
           creator_nick: session.creator_nick,
           participant_count: session.last_participant_count,
           max_participants: session.max_participants,
           created_at: session.inserted_at,
           expires_at: session.expires_at,
           closed_at: session.closed_at,
           closed_reason: session.closed_reason
         }}
    end
  end

  @doc """
  Runtime participant limit: the `"space_max_participants"` server setting,
  falling back to #{@default_max_participants} and capped at the
  `:virtual_space_max_participants_ceiling` config.
  """
  @spec max_participants() :: pos_integer()
  def max_participants do
    limit =
      case ServiceQueries.get_setting("space_max_participants") do
        nil -> @default_max_participants
        value -> String.to_integer(value)
      end

    min(limit, participants_ceiling())
  rescue
    _ -> @default_max_participants
  end

  defp participants_ceiling do
    Application.get_env(
      :retro_hex_chat,
      :virtual_space_max_participants_ceiling,
      @max_participants_ceiling
    )
  end

  defp default_ttl,
    do: Application.get_env(:retro_hex_chat, :virtual_space_default_ttl, @default_ttl)

  defp max_ttl,
    do: Application.get_env(:retro_hex_chat, :virtual_space_max_ttl, @max_ttl)
end
