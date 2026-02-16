defmodule RetroHexChat.P2P.SessionServer do
  @moduledoc """
  GenServer managing a single P2P session's lifecycle.
  Implements the state machine: pending → lobby → connecting → active → terminal.
  """

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.P2P.{Queries, Registry}
  alias RetroHexChat.P2P.Schema.Session

  @pending_timeout :timer.minutes(5)
  @lobby_warning_timeout :timer.minutes(10)
  @lobby_expiry_timeout :timer.minutes(15)
  @connecting_timeout :timer.seconds(30)
  @action_request_timeout :timer.seconds(60)
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

  @spec request_action(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
  def request_action(token, user_id, requester_nick, action_type) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:request_action, user_id, requester_nick, action_type})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec respond_action(String.t(), integer(), String.t(), boolean()) :: :ok | {:error, atom()}
  def respond_action(token, user_id, responder_nick, accepted?) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, {:respond_action, user_id, responder_nick, accepted?})
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
        if Session.terminal?(session.status) do
          :ignore
        else
          state = %{
            token: token,
            session: session,
            creator_joined: false,
            peer_joined: false,
            messages: [],
            action_request: nil,
            timers: %{}
          }

          state = schedule_timeout(state, :pending_expiry, pending_timeout())

          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join, user_id}, _from, state) do
    cond do
      user_id == state.session.creator_id ->
        state = %{state | creator_joined: true}
        state = maybe_transition_to_lobby(state)
        {:reply, :ok, state}

      user_id == state.session.peer_id ->
        state = %{state | peer_joined: true}
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

  def handle_call(
        {:send_message, _user_id, _nick, _content},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "lobby" do
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

  def handle_call(
        {:request_action, _user_id, _nick, _type},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "lobby" do
    {:reply, {:error, :not_in_lobby}, state}
  end

  def handle_call(
        {:request_action, _user_id, _nick, _type},
        _from,
        %{action_request: %{}} = state
      ) do
    {:reply, {:error, :request_pending}, state}
  end

  def handle_call({:request_action, user_id, requester_nick, action_type}, _from, state) do
    state = handle_request_action(state, user_id, requester_nick, action_type)
    {:reply, :ok, state}
  end

  def handle_call(
        {:respond_action, _user_id, _nick, _accepted},
        _from,
        %{action_request: nil} = state
      ) do
    {:reply, {:error, :no_pending_request}, state}
  end

  def handle_call({:respond_action, user_id, responder_nick, accepted?}, _from, state) do
    if user_id == state.action_request.requester_id do
      {:reply, {:error, :cannot_respond_own}, state}
    else
      state = handle_respond_action(state, responder_nick, accepted?)
      {:reply, :ok, state}
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
    if state.session.status == "pending" do
      state = do_expire(state, "pending_timeout")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_warning}, state) do
    if state.session.status == "lobby" do
      broadcast(state.token, "p2p_inactivity_warning", %{expires_in_seconds: 300})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_expiry}, state) do
    if state.session.status == "lobby" do
      state = do_expire(state, "lobby_inactivity")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :connecting_timeout}, state) do
    if state.session.status == "connecting" do
      state = do_fail(state, "connecting_timeout")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :action_request_expiry}, state) do
    if state.action_request do
      state = cancel_timer(state, :action_request_expiry)
      broadcast(state.token, "p2p_action_expired", %{})
      {:noreply, %{state | action_request: nil}}
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
    state = cancel_timer(state, :pending_expiry)

    {:ok, session} = Queries.update_status(state.session, "lobby")

    state = %{state | session: session}
    state = schedule_timeout(state, :lobby_warning, lobby_warning_timeout())
    state = schedule_timeout(state, :lobby_expiry, lobby_expiry_timeout())

    broadcast(state.token, "p2p_status_changed", %{status: "lobby", reason: nil})
    state
  end

  defp do_transition(state, "connecting") do
    state = cancel_timer(state, :lobby_warning)
    state = cancel_timer(state, :lobby_expiry)

    {:ok, session} = Queries.update_status(state.session, "connecting")

    state = %{state | session: session}
    state = schedule_timeout(state, :connecting_timeout, connecting_timeout())

    broadcast(state.token, "p2p_status_changed", %{status: "connecting", reason: nil})
    state
  end

  defp do_transition(state, "active") do
    state = cancel_timer(state, :connecting_timeout)

    {:ok, session} = Queries.update_status(state.session, "active")

    state = %{state | session: session}
    broadcast(state.token, "p2p_status_changed", %{status: "active", reason: nil})
    state
  end

  defp do_close(state, reason, closed_by) do
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "closed", %{
        closed_at: now,
        closed_reason: reason
      })

    broadcast(state.token, "p2p_session_closed", %{reason: reason, closed_by: closed_by})
    %{state | session: session}
  end

  defp do_expire(state, reason) do
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "expired", %{
        closed_at: now,
        closed_reason: reason
      })

    broadcast(state.token, "p2p_status_changed", %{status: "expired", reason: reason})
    %{state | session: session}
  end

  defp do_fail(state, reason) do
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "failed", %{
        closed_at: now,
        closed_reason: reason
      })

    broadcast(state.token, "p2p_status_changed", %{status: "failed", reason: reason})
    %{state | session: session}
  end

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
    broadcast(state.token, "p2p_lobby_message", msg)
    state
  end

  defp handle_request_action(state, user_id, requester_nick, action_type) do
    request = %{
      requester_id: user_id,
      requester_nick: requester_nick,
      action_type: action_type,
      status: "pending",
      requested_at: DateTime.utc_now()
    }

    state = %{state | action_request: request}
    state = schedule_timeout(state, :action_request_expiry, action_request_timeout())

    broadcast(state.token, "p2p_action_request", request)
    state
  end

  defp handle_respond_action(state, responder_nick, true) do
    request = %{state.action_request | status: "accepted"}
    state = cancel_timer(state, :action_request_expiry)
    state = %{state | action_request: request}

    broadcast(state.token, "p2p_action_response", %{
      accepted: true,
      responder_nick: responder_nick,
      action_type: request.action_type
    })

    do_transition(state, "connecting")
  end

  defp handle_respond_action(state, responder_nick, false) do
    state = cancel_timer(state, :action_request_expiry)

    broadcast(state.token, "p2p_action_response", %{
      accepted: false,
      responder_nick: responder_nick,
      action_type: state.action_request.action_type
    })

    %{state | action_request: nil}
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
    Phoenix.PubSub.broadcast(@pubsub, "p2p:#{token}", %{event: event, payload: payload})
  end

  @valid_transitions %{
    "pending" => ~w(lobby expired closed),
    "lobby" => ~w(connecting expired closed),
    "connecting" => ~w(active failed closed),
    "active" => ~w(closed)
  }

  defp valid_transition?(from, to) do
    to in Map.get(@valid_transitions, from, [])
  end

  # Configurable timeouts for testing
  defp pending_timeout,
    do: Application.get_env(:retro_hex_chat, :p2p_pending_timeout, @pending_timeout)

  defp lobby_warning_timeout,
    do: Application.get_env(:retro_hex_chat, :p2p_lobby_warning_timeout, @lobby_warning_timeout)

  defp lobby_expiry_timeout,
    do: Application.get_env(:retro_hex_chat, :p2p_lobby_expiry_timeout, @lobby_expiry_timeout)

  defp connecting_timeout,
    do: Application.get_env(:retro_hex_chat, :p2p_connecting_timeout, @connecting_timeout)

  defp action_request_timeout,
    do: Application.get_env(:retro_hex_chat, :p2p_action_request_timeout, @action_request_timeout)
end
