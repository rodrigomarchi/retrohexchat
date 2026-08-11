defmodule RetroHexChat.Arcade.SoloSessionServer do
  @moduledoc """
  GenServer managing a single solo arcade session's lifecycle.
  Simplified state machine: pending → lobby → playing → terminal (finished/closed/expired).
  No peer, no consent flow, no WebRTC signaling.
  """
  use Gettext, backend: RetroHexChat.Gettext

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Arcade.{Queries, Registry}
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.NamedTimers

  @pending_timeout :timer.minutes(5)
  @lobby_warning_timeout :timer.minutes(10)
  @lobby_expiry_timeout :timer.minutes(15)

  @pubsub RetroHexChat.PubSub

  # --- Public API ---

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(token) do
    GenServer.start_link(__MODULE__, token, name: Registry.via_tuple(token))
  end

  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_state(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> {:ok, GenServer.call(pid, :get_state)}
      error -> error
    end
  end

  @spec join(String.t(), integer()) :: :ok | {:error, String.t()}
  def join(token, user_id) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:join, user_id})
      {:error, :not_found} -> {:error, dgettext("arcade", "Session process not running")}
    end
  end

  @spec close(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close(token, user_id, reason) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:close, user_id, reason})
      {:error, :not_found} -> {:error, dgettext("arcade", "Session process not running")}
    end
  end

  @spec activity(String.t()) :: :ok
  def activity(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.cast(pid, :activity)
      {:error, :not_found} -> :ok
    end
  end

  @spec select_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def select_game(token, user_id, game_id) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:select_game, user_id, game_id})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec finish_game(String.t(), integer()) :: :ok | {:error, atom()}
  def finish_game(token, user_id) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:finish_game, user_id})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:stop, :session_not_found}

      session ->
        if SoloSession.terminal?(session.status) do
          :ignore
        else
          state = %{
            token: token,
            session: session,
            creator_joined: false,
            timers: %{},
            game_started_at: nil
          }

          state = NamedTimers.schedule(state, :pending_expiry, pending_timeout())

          Logger.debug("Arcade SoloSessionServer started: session_id=#{session.id}")
          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join, user_id}, _from, state) do
    if user_id == state.session.creator_id do
      Logger.debug("Arcade join: user=#{user_id}, session_id=#{state.session.id}")
      state = %{state | creator_joined: true}
      state = maybe_transition_to_lobby(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, dgettext("arcade", "Not the session creator")}, state}
    end
  end

  def handle_call({:close, _user_id, reason}, _from, state) do
    state = do_close(state, reason, "user")
    {:stop, :normal, :ok, state}
  end

  # --- Game selection (no consent, immediate transition) ---

  def handle_call(
        {:select_game, _user_id, _game_id},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "lobby" do
    {:reply, {:error, :not_in_lobby}, state}
  end

  def handle_call({:select_game, user_id, game_id}, _from, state) do
    if user_id != state.session.creator_id do
      {:reply, {:error, :not_creator}, state}
    else
      Logger.debug("Arcade select: session_id=#{state.session.id}, game=#{game_id}")
      state = do_transition(state, "playing", game_id)
      {:reply, :ok, state}
    end
  end

  def handle_call({:finish_game, user_id}, _from, state) do
    cond do
      state.session.status != "playing" ->
        {:reply, {:error, :not_playing}, state}

      user_id != state.session.creator_id ->
        {:reply, {:error, :not_creator}, state}

      true ->
        state = do_finish(state)
        {:stop, :normal, :ok, state}
    end
  end

  @impl true
  def handle_cast(:activity, state) do
    if state.session.status == "lobby" do
      state = reset_lobby_timers(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:timeout, :pending_expiry}, state) do
    Logger.debug("Arcade timeout: pending_expiry, session_id=#{state.session.id}")

    if state.session.status == "pending" do
      state = do_expire(state, "pending_timeout")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_warning}, state) do
    Logger.debug("Arcade timeout: lobby_warning, session_id=#{state.session.id}")

    if state.session.status == "lobby" do
      broadcast(state.token, "arcade_inactivity_warning", %{expires_in_seconds: 300})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_expiry}, state) do
    Logger.debug("Arcade timeout: lobby_expiry, session_id=#{state.session.id}")

    if state.session.status == "lobby" do
      state = do_expire(state, "lobby_inactivity")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  # --- Private Helpers ---

  defp maybe_transition_to_lobby(state) do
    if state.session.status == "pending" do
      do_transition(state, "lobby")
    else
      state
    end
  end

  defp do_transition(state, "lobby") do
    Logger.debug(
      "Arcade transition: #{state.session.status} → lobby, session_id=#{state.session.id}"
    )

    state = NamedTimers.cancel(state, :pending_expiry)
    now = DateTime.utc_now()

    {:ok, session} = Queries.update_status(state.session, "lobby", %{lobby_at: now})

    state = %{state | session: session}
    state = NamedTimers.schedule(state, :lobby_warning, lobby_warning_timeout())
    state = NamedTimers.schedule(state, :lobby_expiry, lobby_expiry_timeout())

    broadcast(state.token, "arcade_status_changed", %{status: "lobby"})
    state
  end

  defp do_transition(state, "playing", game_id) do
    Logger.debug(
      "Arcade transition: #{state.session.status} → playing, session_id=#{state.session.id}"
    )

    now = DateTime.utc_now()
    state = NamedTimers.cancel(state, :lobby_warning)
    state = NamedTimers.cancel(state, :lobby_expiry)

    {:ok, session} =
      Queries.update_status(state.session, "playing", %{
        game_id: game_id,
        game_started_at: now
      })

    state = %{state | session: session, game_started_at: now}

    broadcast(state.token, "arcade_status_changed", %{
      status: "playing",
      game_id: game_id,
      started_at: DateTime.to_iso8601(now)
    })

    state
  end

  defp do_finish(state) do
    Logger.debug("Arcade finished: session_id=#{state.session.id}")
    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    duration_seconds =
      if state.game_started_at,
        do: DateTime.diff(now, state.game_started_at),
        else: 0

    {:ok, session} =
      Queries.update_status(state.session, "finished", %{
        closed_at: now,
        closed_reason: "game_over",
        duration_seconds: duration_seconds
      })

    broadcast(state.token, "arcade_status_changed", %{
      status: "finished",
      reason: "game_over",
      duration_seconds: duration_seconds
    })

    %{state | session: session}
  end

  defp do_close(state, reason, closed_by) do
    Logger.debug(
      "Arcade close: session_id=#{state.session.id}, reason=#{reason}, by=#{closed_by}"
    )

    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    duration =
      if state.game_started_at,
        do: DateTime.diff(now, state.game_started_at),
        else: nil

    close_attrs = %{closed_at: now, closed_reason: reason}

    close_attrs =
      if duration, do: Map.put(close_attrs, :duration_seconds, duration), else: close_attrs

    {:ok, session} = Queries.update_status(state.session, "closed", close_attrs)

    broadcast(state.token, "arcade_session_closed", %{reason: reason, closed_by: closed_by})
    %{state | session: session}
  end

  defp do_expire(state, reason) do
    Logger.debug("Arcade expired: session_id=#{state.session.id}, reason=#{reason}")
    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "expired", %{
        closed_at: now,
        closed_reason: reason
      })

    broadcast(state.token, "arcade_status_changed", %{status: "expired", reason: reason})
    %{state | session: session}
  end

  defp reset_lobby_timers(state) do
    state
    |> NamedTimers.schedule(:lobby_warning, lobby_warning_timeout())
    |> NamedTimers.schedule(:lobby_expiry, lobby_expiry_timeout())
  end

  defp broadcast(token, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "arcade:#{token}", %{event: event, payload: payload})
  end

  # Configurable timeouts for testing
  defp pending_timeout,
    do: Application.get_env(:retro_hex_chat, :arcade_pending_timeout, @pending_timeout)

  defp lobby_warning_timeout,
    do:
      Application.get_env(:retro_hex_chat, :arcade_lobby_warning_timeout, @lobby_warning_timeout)

  defp lobby_expiry_timeout,
    do: Application.get_env(:retro_hex_chat, :arcade_lobby_expiry_timeout, @lobby_expiry_timeout)
end
