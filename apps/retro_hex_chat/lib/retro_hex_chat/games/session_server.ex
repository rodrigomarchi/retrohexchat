defmodule RetroHexChat.Games.SessionServer do
  @moduledoc """
  GenServer managing a single game session's lifecycle.
  State machine: pending → lobby → playing → terminal (finished/closed/expired).
  """

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Games.{Queries, Registry}
  alias RetroHexChat.Games.Schema.GameSession

  @pending_timeout :timer.minutes(5)
  @lobby_warning_timeout :timer.minutes(10)
  @lobby_expiry_timeout :timer.minutes(15)
  @game_select_timeout :timer.seconds(60)
  @max_message_length 500
  @max_messages 100

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
      {:error, :not_found} -> {:error, "Session process not running"}
    end
  end

  @spec close(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close(token, user_id, reason) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:close, user_id, reason})
      {:error, :not_found} -> {:error, "Session process not running"}
    end
  end

  @spec activity(String.t()) :: :ok
  def activity(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.cast(pid, :activity)
      {:error, :not_found} -> :ok
    end
  end

  @spec transition(String.t(), atom()) :: :ok | {:error, String.t()}
  def transition(token, new_status) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:transition, new_status})
      {:error, :not_found} -> {:error, "Session process not running"}
    end
  end

  @spec send_message(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
  def send_message(token, user_id, sender_nick, content) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:send_message, user_id, sender_nick, content})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec select_game(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
  def select_game(token, user_id, requester_nick, game_id) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:select_game, user_id, requester_nick, game_id})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec respond_game(String.t(), integer(), String.t(), boolean()) :: :ok | {:error, atom()}
  def respond_game(token, user_id, responder_nick, accepted?) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:respond_game, user_id, responder_nick, accepted?})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  def finish_game(token, user_id, result) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:finish_game, user_id, result})
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
        if GameSession.terminal?(session.status) do
          :ignore
        else
          state = %{
            token: token,
            session: session,
            creator_joined: false,
            peer_joined: false,
            messages: [],
            game_request: nil,
            timers: %{}
          }

          state = schedule_timeout(state, :pending_expiry, pending_timeout())

          Logger.info("Game SessionServer started: token=#{token}")
          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join, user_id}, _from, state) do
    Logger.info("Game join: user=#{user_id}, token=#{state.token}")

    cond do
      user_id == state.session.creator_id ->
        state = %{state | creator_joined: true}
        broadcast(state.token, "game_peer_joined", %{user_id: user_id})
        state = maybe_transition_to_lobby(state)
        {:reply, :ok, state}

      user_id == state.session.peer_id ->
        state = %{state | peer_joined: true}
        broadcast(state.token, "game_peer_joined", %{user_id: user_id})
        state = maybe_transition_to_lobby(state)
        {:reply, :ok, state}

      true ->
        {:reply, {:error, "Not a participant"}, state}
    end
  end

  def handle_call({:close, _user_id, reason}, _from, state) do
    state = do_close(state, reason, "user")
    {:stop, :normal, :ok, state}
  end

  def handle_call({:transition, new_status}, _from, state) do
    new_status_str = to_string(new_status)

    if valid_transition?(state.session.status, new_status_str) do
      state = do_transition(state, new_status_str)
      {:reply, :ok, state}
    else
      {:reply, {:error, "Invalid transition from #{state.session.status} to #{new_status_str}"},
       state}
    end
  end

  # --- Message handling ---

  def handle_call(
        {:send_message, _user_id, _nick, _content},
        _from,
        %{session: %{status: s}} = state
      )
      when s not in ["lobby", "playing"] do
    {:reply, {:error, :not_in_lobby}, state}
  end

  def handle_call({:send_message, _user_id, _nick, ""}, _from, state) do
    {:reply, {:error, :content_empty}, state}
  end

  def handle_call({:send_message, user_id, sender_nick, content}, _from, state) do
    if String.length(content) > @max_message_length do
      {:reply, {:error, :content_too_long}, state}
    else
      state = handle_send_message(state, user_id, sender_nick, content)
      {:reply, :ok, state}
    end
  end

  # --- Game selection (consent) ---

  def handle_call(
        {:select_game, _user_id, _nick, _game_id},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "lobby" do
    {:reply, {:error, :not_in_lobby}, state}
  end

  def handle_call(
        {:select_game, _user_id, _nick, _game_id},
        _from,
        %{game_request: %{}} = state
      ) do
    {:reply, {:error, :request_pending}, state}
  end

  def handle_call({:select_game, user_id, requester_nick, game_id}, _from, state) do
    Logger.info("Game select: token=#{state.token}, game=#{game_id}, by=#{requester_nick}")

    state = handle_select_game(state, user_id, requester_nick, game_id)
    {:reply, :ok, state}
  end

  def handle_call(
        {:respond_game, _user_id, _nick, _accepted},
        _from,
        %{game_request: nil} = state
      ) do
    {:reply, {:error, :no_pending_request}, state}
  end

  def handle_call(
        {:respond_game, _user_id, _nick, _accepted},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "lobby" do
    {:reply, {:error, :not_in_lobby}, state}
  end

  def handle_call({:respond_game, user_id, responder_nick, accepted?}, _from, state) do
    Logger.info(
      "Game response: token=#{state.token}, accepted=#{accepted?}, by=#{responder_nick}"
    )

    if user_id == state.game_request.requester_id do
      {:reply, {:error, :cannot_respond_own}, state}
    else
      state = handle_respond_game(state, user_id, responder_nick, accepted?)
      {:reply, :ok, state}
    end
  end

  def handle_call({:finish_game, user_id, result}, _from, state) do
    cond do
      state.session.status != "playing" ->
        {:reply, {:error, :not_playing}, state}

      user_id != state.session.creator_id ->
        {:reply, {:error, :not_host}, state}

      true ->
        state = do_finish(state, result)
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
    Logger.info("Game timeout: pending_expiry, token=#{state.token}")

    if state.session.status == "pending" do
      state = do_expire(state, "pending_timeout")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_warning}, state) do
    Logger.info("Game timeout: lobby_warning, token=#{state.token}")

    if state.session.status == "lobby" do
      broadcast(state.token, "game_inactivity_warning", %{expires_in_seconds: 300})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_expiry}, state) do
    Logger.info("Game timeout: lobby_expiry, token=#{state.token}")

    if state.session.status == "lobby" do
      state = do_expire(state, "lobby_inactivity")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :game_select_expiry}, state) do
    if state.game_request do
      state = cancel_timer(state, :game_select_expiry)
      broadcast(state.token, "game_select_expired", %{})
      {:noreply, %{state | game_request: nil}}
    else
      {:noreply, state}
    end
  end

  # --- Private Helpers ---

  defp maybe_transition_to_lobby(state) do
    if state.creator_joined and state.peer_joined and state.session.status == "pending" do
      do_transition(state, "lobby")
    else
      state
    end
  end

  defp do_transition(state, "lobby") do
    Logger.info("Game transition: #{state.session.status} → lobby, token=#{state.token}")
    state = cancel_timer(state, :pending_expiry)

    {:ok, session} =
      Queries.update_status(state.session, "lobby", %{lobby_at: DateTime.utc_now()})

    state = %{state | session: session}
    state = schedule_timeout(state, :lobby_warning, lobby_warning_timeout())
    state = schedule_timeout(state, :lobby_expiry, lobby_expiry_timeout())

    broadcast(state.token, "game_status_changed", %{status: "lobby", reason: nil})
    state
  end

  defp do_transition(state, "playing") do
    Logger.info("Game transition: #{state.session.status} → playing, token=#{state.token}")
    state = cancel_timer(state, :lobby_warning)
    state = cancel_timer(state, :lobby_expiry)

    game_id =
      if state.game_request, do: state.game_request.game_id, else: state.session.game_id

    {:ok, session} =
      Queries.update_status(state.session, "playing", %{
        game_id: game_id,
        game_started_at: DateTime.utc_now()
      })

    state = %{state | session: session}
    broadcast(state.token, "game_status_changed", %{status: "playing", game_id: game_id})
    state
  end

  defp do_transition(state, "finished") do
    Logger.info("Game transition: #{state.session.status} → finished, token=#{state.token}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "finished", %{
        closed_at: now,
        closed_reason: "game_over",
        duration_seconds: compute_duration(state.session.game_started_at, now)
      })

    broadcast(state.token, "game_status_changed", %{status: "finished", reason: "game_over"})
    %{state | session: session}
  end

  defp do_finish(state, result) do
    Logger.info("Game finished: token=#{state.token}, result=#{inspect(result)}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "finished", %{
        metadata: %{"result" => result},
        closed_at: now,
        closed_reason: "game_over",
        duration_seconds: compute_duration(state.session.game_started_at, now)
      })

    broadcast(state.token, "game_status_changed", %{
      status: "finished",
      reason: "game_over",
      result: result
    })

    %{state | session: session}
  end

  defp do_close(state, reason, closed_by) do
    Logger.info("Game close: token=#{state.token}, reason=#{reason}, by=#{closed_by}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "closed", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.game_started_at, now)
      })

    broadcast(state.token, "game_session_closed", %{reason: reason, closed_by: closed_by})
    %{state | session: session}
  end

  defp do_expire(state, reason) do
    Logger.info("Game expired: token=#{state.token}, reason=#{reason}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "expired", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.game_started_at, now)
      })

    broadcast(state.token, "game_status_changed", %{status: "expired", reason: reason})
    %{state | session: session}
  end

  @spec compute_duration(DateTime.t() | nil, DateTime.t()) :: integer() | nil
  defp compute_duration(nil, _now), do: nil
  defp compute_duration(start_time, now), do: DateTime.diff(now, start_time, :second)

  defp handle_send_message(state, user_id, sender_nick, content) do
    msg = %{
      id: System.unique_integer([:positive]),
      sender_id: user_id,
      sender_nick: sender_nick,
      content: content,
      type: "message",
      timestamp: DateTime.utc_now()
    }

    messages = state.messages ++ [msg]
    messages = Enum.take(messages, -@max_messages)

    state = reset_lobby_timers(%{state | messages: messages})
    broadcast(state.token, "game_lobby_message", msg)
    state
  end

  defp handle_select_game(state, user_id, requester_nick, game_id) do
    request = %{
      requester_id: user_id,
      requester_nick: requester_nick,
      game_id: game_id,
      status: "pending",
      requested_at: DateTime.utc_now()
    }

    state = %{state | game_request: request}
    state = schedule_timeout(state, :game_select_expiry, game_select_timeout())

    broadcast(state.token, "game_select_request", request)
    state
  end

  defp handle_respond_game(state, responder_id, responder_nick, true) do
    request = %{state.game_request | status: "accepted"}
    state = cancel_timer(state, :game_select_expiry)
    state = %{state | game_request: request}

    broadcast(state.token, "game_select_response", %{
      accepted: true,
      responder_id: responder_id,
      responder_nick: responder_nick,
      game_id: request.game_id
    })

    do_transition(state, "playing")
  end

  defp handle_respond_game(state, responder_id, responder_nick, false) do
    state = cancel_timer(state, :game_select_expiry)

    broadcast(state.token, "game_select_response", %{
      accepted: false,
      responder_id: responder_id,
      responder_nick: responder_nick,
      game_id: state.game_request.game_id
    })

    %{state | game_request: nil}
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
    Phoenix.PubSub.broadcast(@pubsub, "game:#{token}", %{event: event, payload: payload})
  end

  @valid_transitions %{
    "pending" => ~w(lobby expired closed),
    "lobby" => ~w(playing expired closed),
    "playing" => ~w(finished closed)
  }

  defp valid_transition?(from, to) do
    to in Map.get(@valid_transitions, from, [])
  end

  # Configurable timeouts for testing
  defp pending_timeout,
    do: Application.get_env(:retro_hex_chat, :game_pending_timeout, @pending_timeout)

  defp lobby_warning_timeout,
    do: Application.get_env(:retro_hex_chat, :game_lobby_warning_timeout, @lobby_warning_timeout)

  defp lobby_expiry_timeout,
    do: Application.get_env(:retro_hex_chat, :game_lobby_expiry_timeout, @lobby_expiry_timeout)

  defp game_select_timeout,
    do: Application.get_env(:retro_hex_chat, :game_select_timeout, @game_select_timeout)
end
