defmodule RetroHexChat.Lobby.SessionServer do
  @moduledoc """
  GenServer managing a single P2P lobby session.

  The connection is *persistent*: the state machine
  `pending → lobby → connected → terminal` tracks only the
  WebRTC link, never a single feature. Once `connected`, the session hosts
  audio, video, file transfer and games **concurrently**, and ending any one
  feature never closes the session — only an explicit leave/close or
  inactivity does.

  Feature state lives client-side; the server keeps just enough to render the
  shared UI and arbitrate game consent:

    * `media`  — each peer's own mic/camera toggle (self-controlled, no consent)
    * `game`   — the single shared game slot + its bilateral consent request
  """
  use Gettext, backend: RetroHexChat.Gettext

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Lobby.{Queries, Registry}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @pending_timeout :timer.minutes(5)
  @lobby_warning_timeout :timer.minutes(10)
  @lobby_expiry_timeout :timer.minutes(15)
  @connecting_timeout :timer.seconds(30)
  @game_request_timeout :timer.seconds(60)
  @rejoin_grace_timeout :timer.seconds(30)

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

  @spec join(String.t(), integer()) :: :ok | {:error, String.t() | :already_joined}
  def join(token, user_id) do
    call(token, {:join, user_id})
  end

  @doc """
  Marks the user as disconnected and starts the rejoin grace window.

  Leaving is NOT terminal: the session only closes if the user does not
  rejoin within the grace period (a page refresh or LiveView reconnect lands
  well inside it). Explicit teardown goes through `close/3` instead.
  """
  @spec leave(String.t(), integer()) :: :ok
  def leave(token, user_id) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.cast(pid, {:leave, user_id})
      {:error, :not_found} -> :ok
    end
  end

  @doc """
  Resets the pre-connection inactivity timers. No-op outside the `lobby`
  status (once connected there is no inactivity timeout).
  """
  @spec record_activity(String.t()) :: :ok
  def record_activity(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.cast(pid, :record_activity)
      {:error, :not_found} -> :ok
    end
  end

  @spec mark_webrtc_ready(String.t(), integer()) :: :ok | {:error, atom()}
  def mark_webrtc_ready(token, user_id) do
    call(token, {:webrtc_ready, user_id})
  end

  @spec close(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close(token, user_id, reason) do
    case Registry.lookup(token) do
      {:ok, pid} -> call_close(pid, user_id, reason)
      {:error, :not_found} -> {:error, dgettext("lobby", "Session process not running")}
    end
  end

  @spec transition(String.t(), atom()) :: :ok | {:error, String.t()}
  def transition(token, new_status) do
    call(token, {:transition, new_status})
  end

  @spec set_media(String.t(), integer(), boolean(), boolean()) :: :ok | {:error, atom()}
  def set_media(token, user_id, audio?, video?) do
    call(token, {:set_media, user_id, audio?, video?})
  end

  @spec propose_game(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
  def propose_game(token, user_id, proposer_nick, game_id) do
    call(token, {:propose_game, user_id, proposer_nick, game_id})
  end

  @spec respond_game(String.t(), integer(), String.t(), boolean()) :: :ok | {:error, atom()}
  def respond_game(token, user_id, responder_nick, accepted?) do
    call(token, {:respond_game, user_id, responder_nick, accepted?})
  end

  @spec end_game(String.t(), integer()) :: :ok | {:error, atom()}
  def end_game(token, user_id) do
    call(token, {:end_game, user_id})
  end

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  def finish_game(token, user_id, result) do
    call(token, {:finish_game, user_id, result})
  end

  defp call(token, message) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, message)
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
            connections: %{creator: nil, peer: nil},
            webrtc_ready: %{creator: false, peer: false},
            signaling_started: false,
            media: %{
              creator: %{audio: false, video: false},
              peer: %{audio: false, video: false}
            },
            game: %{status: "idle", game_id: nil, host_id: nil},
            game_request: nil,
            timers: %{}
          }

          state = schedule_timeout(state, :pending_expiry, pending_timeout())

          Logger.info("Lobby SessionServer started: token=#{token}")
          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join, user_id}, {caller_pid, _tag}, state) do
    case role_of(state, user_id) do
      nil ->
        {:reply, {:error, dgettext("lobby", "Not a participant")}, state}

      role ->
        case attach_connection(state, role, caller_pid) do
          {:ok, state} ->
            Logger.info("Lobby join: user=#{user_id}, role=#{role}, token=#{state.token}")
            state = set_joined(state, role, true)
            broadcast(state.token, "lobby_peer_joined", %{user_id: user_id})
            {:reply, :ok, maybe_transition_to_lobby(state)}

          {:error, :already_joined} ->
            {:reply, {:error, :already_joined}, state}
        end
    end
  end

  def handle_call({:webrtc_ready, user_id}, _from, state) do
    case role_of(state, user_id) do
      nil ->
        {:reply, {:error, :not_participant}, state}

      role ->
        state = put_in(state, [:webrtc_ready, role], true)
        {:reply, :ok, maybe_start_signaling(state)}
    end
  end

  def handle_call({:close, _user_id, reason}, _from, state) do
    state = do_close(state, reason, "user")
    {:stop, :normal, :ok, state}
  end

  def handle_call({:transition, new_status}, _from, state) do
    new_status_str = to_string(new_status)

    if valid_transition?(state.session.status, new_status_str) do
      {:reply, :ok, do_transition(state, new_status_str)}
    else
      {:reply,
       {:error,
        dgettext("lobby", "Invalid transition from %{from} to %{to}",
          from: state.session.status,
          to: new_status_str
        )}, state}
    end
  end

  def handle_call({:set_media, user_id, audio?, video?}, _from, state) do
    case role_of(state, user_id) do
      nil ->
        {:reply, {:error, :not_participant}, state}

      role ->
        media = Map.put(state.media, role, %{audio: audio?, video: video?})

        broadcast(state.token, "lobby_media_changed", %{
          user_id: user_id,
          role: role,
          audio: audio?,
          video: video?
        })

        {:reply, :ok, %{state | media: media}}
    end
  end

  def handle_call({:propose_game, _user_id, _nick, _game_id}, _from, %{game_request: %{}} = state) do
    {:reply, {:error, :request_pending}, state}
  end

  def handle_call(
        {:propose_game, _user_id, _nick, _game_id},
        _from,
        %{game: %{status: "playing"}} = state
      ) do
    {:reply, {:error, :game_in_progress}, state}
  end

  def handle_call(
        {:propose_game, _user_id, _nick, _game_id},
        _from,
        %{session: %{status: s}} = state
      )
      when s != "connected" do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:propose_game, user_id, proposer_nick, game_id}, _from, state) do
    if role_of(state, user_id) do
      {:reply, :ok, handle_propose_game(state, user_id, proposer_nick, game_id)}
    else
      {:reply, {:error, :not_participant}, state}
    end
  end

  def handle_call(
        {:respond_game, _user_id, _nick, _accepted},
        _from,
        %{game_request: nil} = state
      ) do
    {:reply, {:error, :no_pending_request}, state}
  end

  def handle_call({:respond_game, user_id, responder_nick, accepted?}, _from, state) do
    if user_id == state.game_request.proposer_id do
      {:reply, {:error, :cannot_respond_own}, state}
    else
      {:reply, :ok, handle_respond_game(state, user_id, responder_nick, accepted?)}
    end
  end

  def handle_call({:end_game, user_id}, _from, state) do
    if role_of(state, user_id) do
      {:reply, :ok, handle_end_game(state)}
    else
      {:reply, {:error, :not_participant}, state}
    end
  end

  # Only the game host reports the authoritative result (the guest engine never
  # fires onGameEnd), so the server relays it to both peers.
  def handle_call({:finish_game, user_id, result}, _from, %{game: %{status: "playing"}} = state) do
    if user_id == state.game.host_id do
      {:reply, :ok, handle_finish_game(state, result)}
    else
      {:reply, {:error, :not_host}, state}
    end
  end

  def handle_call({:finish_game, _user_id, _result}, _from, state) do
    {:reply, {:error, :no_game_in_progress}, state}
  end

  @impl true
  def handle_cast({:leave, user_id}, state) do
    case role_of(state, user_id) do
      nil ->
        {:noreply, state}

      role ->
        Logger.info("Lobby leave: user=#{user_id}, role=#{role}, token=#{state.token}")
        {:noreply, begin_disconnect(state, role)}
    end
  end

  def handle_cast(:record_activity, state) do
    if state.session.status == "lobby" do
      {:noreply, reset_lobby_timers(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:timeout, :pending_expiry}, state) do
    if state.session.status == "pending" do
      {:stop, :normal, do_expire(state, "pending_timeout")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :lobby_warning}, state) do
    if state.session.status == "lobby" do
      broadcast(state.token, "lobby_inactivity_warning", %{expires_in_seconds: 300})
    end

    {:noreply, state}
  end

  def handle_info({:timeout, :lobby_expiry}, state) do
    if state.session.status == "lobby" do
      {:stop, :normal, do_expire(state, "lobby_inactivity")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :connecting_timeout}, state) do
    # Safety net: if the WebRTC link never reports `connected`, fail the session.
    if state.session.status == "lobby" do
      {:stop, :normal, do_fail(state, "connecting_timeout")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :game_request_expiry}, state) do
    if state.game_request do
      state = cancel_timer(state, :game_request_expiry)
      broadcast(state.token, "lobby_game_response", %{accepted: false, reason: "expired"})
      {:noreply, %{state | game_request: nil}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, {:rejoin_grace, role}}, state) do
    if state.connections[role] == nil do
      {:stop, :normal, do_close(state, "peer_left", "system")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case connection_role_by_ref(state, ref) do
      nil -> {:noreply, state}
      role -> {:noreply, begin_disconnect(state, role)}
    end
  end

  # --- Private helpers ---

  defp maybe_transition_to_lobby(state) do
    if state.creator_joined and state.peer_joined and state.session.status == "pending" do
      do_transition(state, "lobby")
    else
      state
    end
  end

  # Signaling only begins once BOTH peers' WebRTC hooks have reported ready AND the
  # session has reached "lobby". This guarantees the answerer's hook has registered
  # its "lobby_signal" handler before the initiator's offer is broadcast — otherwise
  # the very first offer can be delivered to a not-yet-listening client and dropped,
  # leaving the connection stuck until `connecting_timeout`.
  #
  # `connected` is also accepted: a peer disconnect resets `signaling_started` and
  # that peer's readiness, so once the rejoined hook reports ready again the same
  # gate re-broadcasts `lobby_start_signaling` to rebuild the WebRTC link.
  defp maybe_start_signaling(state) do
    if not state.signaling_started and state.session.status in ~w(lobby connected) and
         state.webrtc_ready.creator and state.webrtc_ready.peer do
      broadcast(state.token, "lobby_start_signaling", %{})
      %{state | signaling_started: true}
    else
      state
    end
  end

  # A user's LiveView going away (crash, refresh, tab close) or an explicit
  # `leave` both land here: drop the connection, reset that side's WebRTC
  # readiness so a rejoin can re-signal, and give the user the grace window
  # before the session turns terminal.
  defp begin_disconnect(state, role) do
    case state.connections[role] do
      nil ->
        state

      %{ref: ref} ->
        Process.demonitor(ref, [:flush])
        user_id = user_id_for(state, role)
        Logger.info("Lobby peer disconnected: role=#{role}, token=#{state.token}")

        state =
          state
          |> put_in([:connections, role], nil)
          |> set_joined(role, false)
          |> put_in([:webrtc_ready, role], false)
          |> Map.put(:signaling_started, false)

        broadcast(state.token, "lobby_peer_disconnected", %{user_id: user_id, role: role})
        schedule_timeout(state, {:rejoin_grace, role}, rejoin_grace_timeout())
    end
  end

  defp attach_connection(state, role, pid) do
    case state.connections[role] do
      nil ->
        {:ok, monitor_connection(state, role, pid)}

      %{pid: ^pid} ->
        {:ok, cancel_timer(state, {:rejoin_grace, role})}

      %{pid: old_pid, ref: old_ref} ->
        if Process.alive?(old_pid) do
          {:error, :already_joined}
        else
          Process.demonitor(old_ref, [:flush])
          {:ok, monitor_connection(state, role, pid)}
        end
    end
  end

  defp monitor_connection(state, role, pid) do
    ref = Process.monitor(pid)

    state
    |> put_in([:connections, role], %{pid: pid, ref: ref})
    |> cancel_timer({:rejoin_grace, role})
  end

  defp connection_role_by_ref(state, ref) do
    Enum.find_value(state.connections, fn
      {role, %{ref: ^ref}} -> role
      _ -> nil
    end)
  end

  defp set_joined(state, :creator, joined?), do: %{state | creator_joined: joined?}
  defp set_joined(state, :peer, joined?), do: %{state | peer_joined: joined?}

  defp user_id_for(state, :creator), do: state.session.creator_id
  defp user_id_for(state, :peer), do: state.session.peer_id

  defp do_transition(state, "lobby") do
    Logger.info("Lobby transition: #{state.session.status} → lobby, token=#{state.token}")
    state = cancel_timer(state, :pending_expiry)

    {:ok, session} =
      Queries.update_status(state.session, "lobby", %{accepted_at: DateTime.utc_now()})

    state = %{state | session: session}
    state = schedule_timeout(state, :lobby_warning, lobby_warning_timeout())
    state = schedule_timeout(state, :lobby_expiry, lobby_expiry_timeout())
    state = schedule_timeout(state, :connecting_timeout, connecting_timeout())

    broadcast(state.token, "lobby_status_changed", %{status: "lobby", reason: nil})
    maybe_start_signaling(state)
  end

  defp do_transition(state, "connected") do
    Logger.info("Lobby transition: #{state.session.status} → connected, token=#{state.token}")
    state = cancel_timer(state, :lobby_warning)
    state = cancel_timer(state, :lobby_expiry)
    state = cancel_timer(state, :connecting_timeout)

    {:ok, session} =
      Queries.update_status(state.session, "connected", %{connected_at: DateTime.utc_now()})

    state = %{state | session: session}
    broadcast(state.token, "lobby_status_changed", %{status: "connected", reason: nil})
    state
  end

  defp do_close(state, reason, closed_by) do
    Logger.info("Lobby close: token=#{state.token}, reason=#{reason}, by=#{closed_by}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "closed", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_session_closed", %{reason: reason, closed_by: closed_by})
    notify_chat_participants(session, reason)
    %{state | session: session}
  end

  defp do_expire(state, reason) do
    Logger.info("Lobby expired: token=#{state.token}, reason=#{reason}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "expired", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_status_changed", %{status: "expired", reason: reason})
    notify_chat_participants(session, reason)
    %{state | session: session}
  end

  defp do_fail(state, reason) do
    Logger.warning("Lobby failed: token=#{state.token}, reason=#{reason}")
    state = cancel_all_timers(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "failed", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_status_changed", %{status: "failed", reason: reason})
    notify_chat_participants(session, reason)
    %{state | session: session}
  end

  defp handle_propose_game(state, user_id, proposer_nick, game_id) do
    Logger.info("Lobby game proposed: token=#{state.token}, game=#{game_id}, by=#{proposer_nick}")

    request = %{
      proposer_id: user_id,
      proposer_nick: proposer_nick,
      game_id: game_id,
      requested_at: DateTime.utc_now()
    }

    state = %{state | game_request: request}
    state = schedule_timeout(state, :game_request_expiry, game_request_timeout())
    broadcast(state.token, "lobby_game_request", request)
    state
  end

  defp handle_respond_game(state, responder_id, responder_nick, true) do
    request = state.game_request
    state = cancel_timer(state, :game_request_expiry)

    game = %{status: "playing", game_id: request.game_id, host_id: request.proposer_id}

    broadcast(state.token, "lobby_game_response", %{
      accepted: true,
      responder_id: responder_id,
      responder_nick: responder_nick,
      game_id: request.game_id
    })

    broadcast(state.token, "lobby_game_status_changed", %{
      status: "playing",
      game_id: request.game_id,
      host_id: request.proposer_id
    })

    %{state | game: game, game_request: nil}
  end

  defp handle_respond_game(state, responder_id, responder_nick, false) do
    request = state.game_request
    state = cancel_timer(state, :game_request_expiry)

    broadcast(state.token, "lobby_game_response", %{
      accepted: false,
      responder_id: responder_id,
      responder_nick: responder_nick,
      game_id: request.game_id
    })

    %{state | game_request: nil}
  end

  defp handle_end_game(state) do
    game = %{status: "idle", game_id: nil, host_id: nil}
    broadcast(state.token, "lobby_game_status_changed", %{status: "idle", game_id: nil})
    %{state | game: game, game_request: nil}
  end

  defp handle_finish_game(state, result) do
    Logger.info("Lobby game finished: token=#{state.token}, game=#{state.game.game_id}")

    game = %{
      status: "finished",
      game_id: state.game.game_id,
      host_id: state.game.host_id,
      result: result
    }

    broadcast(state.token, "lobby_game_status_changed", %{
      status: "finished",
      game_id: state.game.game_id,
      result: result
    })

    %{state | game: game, game_request: nil}
  end

  defp role_of(state, user_id) do
    cond do
      user_id == state.session.creator_id -> :creator
      user_id == state.session.peer_id -> :peer
      true -> nil
    end
  end

  defp notify_chat_participants(session, reason) do
    creator_nick = registered_nick(session.creator_id)
    peer_nick = registered_nick(session.peer_id)

    if creator_nick && peer_nick do
      notify_chat_user(creator_nick, peer_nick, session, reason)
      notify_chat_user(peer_nick, creator_nick, session, reason)
    end
  end

  defp notify_chat_user(nickname, peer_nick, session, reason) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "user:#{nickname}",
      %{
        event: "lobby_session_ended",
        payload: %{
          peer_nick: peer_nick,
          reason: reason,
          duration_seconds: session.duration_seconds
        }
      }
    )
  end

  defp registered_nick(id) do
    case Repo.get(RegisteredNick, id) do
      nil -> nil
      nick -> nick.nickname
    end
  end

  @spec compute_duration(DateTime.t() | nil, DateTime.t()) :: integer() | nil
  defp compute_duration(nil, _now), do: nil
  defp compute_duration(start_time, now), do: DateTime.diff(now, start_time, :second)

  defp call_close(pid, user_id, reason) do
    GenServer.call(pid, {:close, user_id, reason})
  catch
    :exit, :normal -> {:error, dgettext("lobby", "Session process not running")}
    :exit, {:normal, _call} -> {:error, dgettext("lobby", "Session process not running")}
    :exit, {:noproc, _call} -> {:error, dgettext("lobby", "Session process not running")}
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

  # The envelope carries the token so a subscriber holding session state can
  # drop stale events from a previous session (extra keys don't break the
  # existing %{event:, payload:} matches).
  defp broadcast(token, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "lobby:#{token}", %{
      event: event,
      payload: payload,
      token: token
    })
  end

  @valid_transitions %{
    "pending" => ~w(lobby expired closed),
    "lobby" => ~w(connected expired failed closed),
    "connected" => ~w(closed)
  }

  defp valid_transition?(from, to) do
    to in Map.get(@valid_transitions, from, [])
  end

  # Configurable timeouts (overridable in tests)
  defp pending_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_pending_timeout, @pending_timeout)

  defp lobby_warning_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_warning_timeout, @lobby_warning_timeout)

  defp lobby_expiry_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_expiry_timeout, @lobby_expiry_timeout)

  defp connecting_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_connecting_timeout, @connecting_timeout)

  defp game_request_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_game_request_timeout, @game_request_timeout)

  defp rejoin_grace_timeout,
    do: Application.get_env(:retro_hex_chat, :lobby_rejoin_grace_timeout, @rejoin_grace_timeout)
end
