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
      {:error, :not_found} -> {:error, gettext("Session process not running")}
    end
  end

  @spec close(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close(token, user_id, reason) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:close, user_id, reason})
      {:error, :not_found} -> {:error, gettext("Session process not running")}
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

          state = schedule_timeout(state, :pending_expiry, pending_timeout())

          Logger.info("Arcade SoloSessionServer started: token=#{token}")
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
      Logger.info("Arcade join: user=#{user_id}, token=#{state.token}")
      state = %{state | creator_joined: true}
      state = maybe_transition_to_lobby(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, gettext("Not the session creator")}, state}
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
      Logger.info("Arcade select: token=#{state.token}, game=#{game_id}")
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
    Logger.info("Arcade timeout: pending_expiry, token=#{state.token}")

    if state.session.status == "pending" do
      state = do_expire(state, "pending_timeout")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_warning}, state) do
    Logger.info("Arcade timeout: lobby_warning, token=#{state.token}")

    if state.session.status == "lobby" do
      broadcast(state.token, "arcade_inactivity_warning", %{expires_in_seconds: 300})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_expiry}, state) do
    Logger.info("Arcade timeout: lobby_expiry, token=#{state.token}")

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
    Logger.info("Arcade transition: #{state.session.status} → lobby, token=#{state.token}")
    state = cancel_timer(state, :pending_expiry)
    now = DateTime.utc_now()

    {:ok, session} = Queries.update_status(state.session, "lobby", %{lobby_at: now})

    state = %{state | session: session}
    state = schedule_timeout(state, :lobby_warning, lobby_warning_timeout())
    state = schedule_timeout(state, :lobby_expiry, lobby_expiry_timeout())

    broadcast(state.token, "arcade_status_changed", %{status: "lobby"})
    state
  end

  defp do_transition(state, "playing", game_id) do
    Logger.info("Arcade transition: #{state.session.status} → playing, token=#{state.token}")
    now = DateTime.utc_now()
    state = cancel_timer(state, :lobby_warning)
    state = cancel_timer(state, :lobby_expiry)

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
    Logger.info("Arcade finished: token=#{state.token}")
    state = cancel_all_timers(state)
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
    Logger.info("Arcade close: token=#{state.token}, reason=#{reason}, by=#{closed_by}")
    state = cancel_all_timers(state)
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
    Logger.info("Arcade expired: token=#{state.token}, reason=#{reason}")
    state = cancel_all_timers(state)
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
    state = cancel_timer(state, :lobby_warning)
    state = cancel_timer(state, :lobby_expiry)
    state = schedule_timeout(state, :lobby_warning, lobby_warning_timeout())
    schedule_timeout(state, :lobby_expiry, lobby_expiry_timeout())
  end

  defp schedule_timeout(state, name, delay) do
    ref = Process.send_after(self(), {:timeout, name}, delay)
    put_in(state, [:timers, name], ref)
  end

  defp cancel_timer(state, name) do
    case Map.get(state.timers, name) do
      nil ->
        state

      ref ->
        Process.cancel_timer(ref)
        put_in(state, [:timers, name], nil)
    end
  end

  defp cancel_all_timers(state) do
    Enum.reduce(Map.keys(state.timers), state, fn name, acc ->
      cancel_timer(acc, name)
    end)
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
