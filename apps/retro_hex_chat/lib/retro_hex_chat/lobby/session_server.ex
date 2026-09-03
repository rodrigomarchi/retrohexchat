defmodule RetroHexChat.Lobby.SessionServer do
  @moduledoc """
  GenServer managing a single P2P lobby session.

  The connection is *persistent*: the state machine
  `open → pending → lobby → connected → terminal` tracks only the
  WebRTC link, never a single feature. Once `connected`, the session hosts
  audio, video, file transfer and games **concurrently**, and ending any one
  feature never closes the session — only an explicit leave/close or
  inactivity does.

  There is no process while a session is `open`: that status is a match link
  with an empty seat, and it costs a row and a deadline rather than a
  GenServer. The process starts on the claim, which has already written
  `pending`.

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
  alias RetroHexChat.NamedTimers
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  @pending_timeout :timer.minutes(5)
  @lobby_warning_timeout :timer.minutes(10)
  @lobby_expiry_timeout :timer.minutes(15)
  @connecting_timeout :timer.seconds(30)
  @game_request_timeout :timer.seconds(60)
  @rejoin_grace_timeout :timer.seconds(30)
  @max_signaling_candidates 64

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

  @doc """
  Whether this session has already released its first offer.

  A session sits at `lobby` from the moment both sides arrive until the media
  is up, so the DB status cannot tell "waiting in the starting room" apart from
  "negotiating". This can: it is set the first time the readiness gate opens
  and never cleared, so a page that comes back mid-negotiation knows it is
  returning to something already running.
  """
  @spec signaling_released?(String.t()) :: boolean()
  def signaling_released?(token) do
    case get_state(token) do
      {:ok, %{signaling_ran: released?}} -> released?
      _error -> false
    end
  end

  @spec join(String.t(), integer(), keyword()) :: :ok | {:error, String.t() | :already_joined}
  def join(token, user_id, opts \\ []) do
    call(token, {:join, user_id, Keyword.get(opts, :takeover, false)})
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

  @spec record_signaling_event(String.t(), integer(), String.t(), map()) :: :ok | {:error, atom()}
  def record_signaling_event(token, user_id, event, payload)
      when event in ["lobby_signal", "lobby_renegotiate"] and is_map(payload) do
    call(token, {:record_signaling_event, user_id, event, payload})
  end

  @spec signaling_replay(String.t(), integer()) :: {:ok, [map()]} | {:error, atom()}
  def signaling_replay(token, user_id) do
    call(token, {:signaling_replay, user_id})
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
            # Read once, here, and never again: the two people in a session do
            # not change, and every notification below would otherwise put a
            # query inside the server on a path that runs while the caller who
            # owns the connection may already be gone.
            nicks: %{
              creator: registered_nick(session.creator_id),
              peer: registered_nick(session.peer_id)
            },
            creator_joined: false,
            peer_joined: false,
            connections: %{creator: nil, peer: nil},
            webrtc_ready: %{creator: false, peer: false},
            signaling_started: false,
            signaling_ran: false,
            signaling_seq: 0,
            signaling_replay: empty_signaling_replay(),
            media: %{
              creator: %{audio: false, video: false},
              peer: %{audio: false, video: false}
            },
            game: %{status: "idle", game_id: nil, host_id: nil},
            game_request: nil,
            timers: %{}
          }

          state = NamedTimers.schedule(state, :pending_expiry, pending_timeout())

          Logger.debug("Lobby SessionServer started: session_id=#{session.id}")
          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join, user_id, takeover?}, {caller_pid, _tag}, state) do
    case role_of(state, user_id) do
      nil ->
        {:reply, {:error, dgettext("lobby", "Not a participant")}, state}

      role ->
        case attach_connection(state, role, caller_pid, takeover?) do
          {:ok, state} ->
            Logger.debug(
              "Lobby join: user=#{user_id}, role=#{role}, session_id=#{state.session.id}"
            )

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

  def handle_call({:record_signaling_event, user_id, event, payload}, _from, state) do
    case role_of(state, user_id) do
      nil ->
        {:reply, {:error, :not_participant}, state}

      role ->
        {:reply, :ok, do_record_signaling_event(state, role, event, payload)}
    end
  end

  def handle_call({:signaling_replay, user_id}, _from, state) do
    case role_of(state, user_id) do
      nil -> {:reply, {:error, :not_participant}, state}
      role -> {:reply, {:ok, signaling_replay_events(state, role)}, state}
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
        Logger.debug("Lobby leave: user=#{user_id}, role=#{role}, session_id=#{state.session.id}")
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
      state = NamedTimers.cancel(state, :game_request_expiry)
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

  # Why a session server went away, whenever the reason is not one this module
  # chose. `:normal` and `:shutdown` are the ordinary exits — an expiry, a peer
  # leaving, the supervisor taking a child down — and logging those would bury
  # the one line that matters.
  #
  # It matters because of how the failure arrives: enough abnormal exits in one
  # burst (`max_restarts: 50` in `max_seconds: 5`) take the DynamicSupervisor
  # down and every live session with it, and what a test then sees is a
  # `:noproc` from a session that did nothing wrong. That has been observed and
  # never explained; the next time it happens, this says what died first.
  @impl true
  def terminate(reason, state) when reason not in [:normal, :shutdown] do
    Logger.warning(
      "Lobby SessionServer died: reason=#{inspect(reason)}, " <>
        "session_id=#{inspect(state[:session] && state.session.id)}, " <>
        "status=#{inspect(state[:session] && state.session.status)}"
    )

    :ok
  end

  def terminate(_reason, _state), do: :ok

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
      broadcast(state.token, "lobby_start_signaling", start_signaling_payload(state))
      %{state | signaling_started: true, signaling_ran: true}
    else
      state
    end
  end

  defp start_signaling_payload(state) do
    if signaling_restart_required?(state) do
      %{
        restart: true,
        reason: "signaling_snapshot_lost"
      }
    else
      %{}
    end
  end

  # The gate opening a second time is a rebuild, not a continuation. Whoever
  # stayed is holding a peer connection that is negotiating with a page that no
  # longer exists, and an empty replay is the proof the snapshot went with it —
  # so the payload has to say `restart`, or the side that stayed reads the
  # second `start` as the first one and returns without offering anything.
  #
  # The DB status is not the test. A peer that reloads while the initial offer
  # is still being applied leaves the session at `lobby`, and its peer is
  # exactly as stale as one that reloads after `connected`.
  defp signaling_restart_required?(state) do
    negotiated_before?(state) and not signaling_replay_negotiable?(state.signaling_replay)
  end

  # "This is not the session's first negotiation." Either this process has
  # opened the gate before, or the session reached `connected` — which it can
  # only have done by negotiating, including under a server process that has
  # since been restarted and remembers none of it.
  defp negotiated_before?(%{session: %{status: "connected"}}), do: true
  defp negotiated_before?(state), do: state.signaling_ran

  # A replay can only rebuild a returning page if it still holds a negotiation:
  # a description to apply, or a renegotiation request to answer. Loose ICE
  # candidates are the debris of one, not one — and the side that stayed keeps
  # trickling candidates into the snapshot after a disconnect wiped it, so
  # "not empty" would read as "recoverable" for a replay that can rebuild
  # nothing at all.
  defp signaling_replay_negotiable?(replay) when is_map(replay) do
    replay
    |> Map.values()
    |> Enum.any?(fn role_state ->
      not is_nil(role_state.description) or not is_nil(role_state.renegotiate)
    end)
  end

  defp signaling_replay_negotiable?(_replay), do: false

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
        Logger.debug("Lobby peer disconnected: role=#{role}, session_id=#{state.session.id}")

        state =
          state
          |> put_in([:connections, role], nil)
          |> set_joined(role, false)
          |> put_in([:webrtc_ready, role], false)
          |> Map.put(:signaling_started, false)
          |> reset_signaling_replay()

        broadcast(state.token, "lobby_peer_disconnected", %{user_id: user_id, role: role})
        NamedTimers.schedule(state, {:rejoin_grace, role}, rejoin_grace_timeout())
    end
  end

  # A second window asking for a seat this person already occupies is a
  # takeover, never a second seat: the same nickname is one participant, and
  # the WebRTC link belongs to whichever page is actually on screen. The old
  # page is told, and the slot is released exactly the way a disconnect
  # releases it — readiness reset, replay dropped, the peer notified — so the
  # gate that rebuilds the media after a dropped socket rebuilds it here too.
  # Without that reset the new page would join a session whose signalling had
  # already started and sit there with no media at all.
  defp attach_connection(state, role, pid, takeover?) do
    case state.connections[role] do
      nil ->
        {:ok, monitor_connection(state, role, pid)}

      %{pid: ^pid} ->
        {:ok, NamedTimers.cancel(state, {:rejoin_grace, role})}

      %{pid: old_pid, ref: old_ref} ->
        cond do
          not Process.alive?(old_pid) ->
            Process.demonitor(old_ref, [:flush])
            {:ok, monitor_connection(state, role, pid)}

          takeover? ->
            send(old_pid, {:lobby_slot_taken, state.token})
            {:ok, monitor_connection(begin_disconnect(state, role), role, pid)}

          true ->
            {:error, :already_joined}
        end
    end
  end

  defp monitor_connection(state, role, pid) do
    ref = Process.monitor(pid)

    state
    |> put_in([:connections, role], %{pid: pid, ref: ref})
    |> NamedTimers.cancel({:rejoin_grace, role})
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

  defp do_record_signaling_event(state, role, event, payload) do
    {state, payload} = next_signaling_payload(state, payload)
    role_state = Map.get(state.signaling_replay, role, empty_signaling_role())

    role_state =
      case event do
        "lobby_signal" -> record_signal_payload(role_state, payload)
        "lobby_renegotiate" -> %{role_state | renegotiate: payload}
      end

    put_in(state, [:signaling_replay, role], role_state)
  end

  defp next_signaling_payload(state, payload) do
    seq = state.signaling_seq + 1
    {%{state | signaling_seq: seq}, Map.put(payload, :server_seq, seq)}
  end

  defp record_signal_payload(role_state, %{type: type} = payload)
       when type in ["offer", "answer"] do
    epoch = signal_epoch(payload)

    candidates =
      role_state.candidates
      |> Enum.filter(fn candidate ->
        candidate_epoch = signal_epoch(candidate)
        epoch && candidate_epoch && candidate_epoch >= epoch
      end)

    %{role_state | description: payload, candidates: candidates, renegotiate: nil}
  end

  defp record_signal_payload(role_state, %{type: "ice-candidate"} = payload) do
    if stale_candidate_for_description?(payload, role_state.description) do
      role_state
    else
      %{role_state | candidates: append_signaling_candidate(role_state.candidates, payload)}
    end
  end

  defp record_signal_payload(role_state, _payload), do: role_state

  defp append_signaling_candidate(candidates, payload) do
    candidates
    |> Kernel.++([payload])
    |> Enum.uniq_by(&candidate_key/1)
    |> Enum.take(-@max_signaling_candidates)
  end

  defp stale_candidate_for_description?(_candidate, nil), do: false

  defp stale_candidate_for_description?(candidate, description) do
    candidate_epoch = signal_epoch(candidate)
    description_epoch = signal_epoch(description)

    candidate_epoch && description_epoch && candidate_epoch < description_epoch
  end

  defp signaling_replay_events(state, role) do
    remote_role = other_role(role)
    remote = Map.get(state.signaling_replay, remote_role, empty_signaling_role())

    []
    |> maybe_add_replay_event("lobby_signal", remote.description)
    |> add_replay_candidates(remote.candidates)
    |> maybe_add_replay_event_for_role(role, "lobby_renegotiate", remote.renegotiate)
    |> Enum.sort_by(&server_seq/1)
  end

  defp maybe_add_replay_event(events, _event, nil), do: events

  defp maybe_add_replay_event(events, event, payload) do
    [%{event: event, payload: Map.put(payload, :replay, true)} | events]
  end

  defp add_replay_candidates(events, candidates) do
    Enum.reduce(candidates, events, fn candidate, acc ->
      maybe_add_replay_event(acc, "lobby_signal", candidate)
    end)
  end

  defp maybe_add_replay_event_for_role(events, :creator, event, payload),
    do: maybe_add_replay_event(events, event, payload)

  defp maybe_add_replay_event_for_role(events, _role, _event, _payload), do: events

  defp server_seq(%{payload: %{server_seq: seq}}) when is_integer(seq), do: seq
  defp server_seq(_event), do: 0

  defp candidate_key(payload) do
    candidate = Map.get(payload, :candidate) || Map.get(payload, "candidate") || %{}

    {
      signal_epoch(payload),
      Map.get(candidate, "candidate") || Map.get(candidate, :candidate),
      Map.get(candidate, "sdpMid") || Map.get(candidate, :sdpMid),
      Map.get(candidate, "sdpMLineIndex") || Map.get(candidate, :sdpMLineIndex)
    }
  end

  defp signal_epoch(payload) do
    case Map.get(payload, :epoch) || Map.get(payload, "epoch") do
      epoch when is_integer(epoch) and epoch > 0 -> epoch
      _ -> nil
    end
  end

  defp other_role(:creator), do: :peer
  defp other_role(:peer), do: :creator

  defp reset_signaling_replay(state) do
    %{state | signaling_seq: 0, signaling_replay: empty_signaling_replay()}
  end

  defp empty_signaling_replay do
    %{creator: empty_signaling_role(), peer: empty_signaling_role()}
  end

  defp empty_signaling_role do
    %{description: nil, candidates: [], renegotiate: nil}
  end

  defp do_transition(state, "lobby") do
    Logger.debug(
      "Lobby transition: #{state.session.status} → lobby, session_id=#{state.session.id}"
    )

    state = NamedTimers.cancel(state, :pending_expiry)

    {:ok, session} =
      Queries.update_status(state.session, "lobby", %{accepted_at: DateTime.utc_now()})

    state = %{state | session: session}
    state = NamedTimers.schedule(state, :lobby_warning, lobby_warning_timeout())
    state = NamedTimers.schedule(state, :lobby_expiry, lobby_expiry_timeout())
    state = NamedTimers.schedule(state, :connecting_timeout, connecting_timeout())

    broadcast(state.token, "lobby_status_changed", %{status: "lobby", reason: nil})
    notify_chat_progress(state)
    maybe_start_signaling(state)
  end

  defp do_transition(state, "connected") do
    Logger.debug(
      "Lobby transition: #{state.session.status} → connected, session_id=#{state.session.id}"
    )

    state = NamedTimers.cancel(state, :lobby_warning)
    state = NamedTimers.cancel(state, :lobby_expiry)
    state = NamedTimers.cancel(state, :connecting_timeout)

    {:ok, session} =
      Queries.update_status(state.session, "connected", %{connected_at: DateTime.utc_now()})

    state = %{state | session: session}
    broadcast(state.token, "lobby_status_changed", %{status: "connected", reason: nil})
    notify_chat_progress(state)
    state
  end

  defp do_close(state, reason, closed_by) do
    Logger.debug("Lobby close: session_id=#{state.session.id}, reason=#{reason}, by=#{closed_by}")
    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "closed", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_session_closed", %{reason: reason, closed_by: closed_by})
    notify_chat_participants(state.nicks, session, reason)
    %{state | session: session}
  end

  defp do_expire(state, reason) do
    Logger.debug("Lobby expired: session_id=#{state.session.id}, reason=#{reason}")
    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "expired", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_status_changed", %{status: "expired", reason: reason})
    notify_chat_participants(state.nicks, session, reason)
    %{state | session: session}
  end

  defp do_fail(state, reason) do
    Logger.warning("Lobby failed: session_id=#{state.session.id}, reason=#{reason}")
    state = NamedTimers.cancel_all(state)
    now = DateTime.utc_now()

    {:ok, session} =
      Queries.update_status(state.session, "failed", %{
        closed_at: now,
        closed_reason: reason,
        duration_seconds: compute_duration(state.session.connected_at, now)
      })

    broadcast(state.token, "lobby_status_changed", %{status: "failed", reason: reason})
    notify_chat_participants(state.nicks, session, reason)
    %{state | session: session}
  end

  defp handle_propose_game(state, user_id, proposer_nick, game_id) do
    Logger.debug(
      "Lobby game proposed: session_id=#{state.session.id}, game=#{game_id}, by=#{proposer_nick}"
    )

    request = %{
      proposer_id: user_id,
      proposer_nick: proposer_nick,
      game_id: game_id,
      requested_at: DateTime.utc_now()
    }

    state = %{state | game_request: request}
    state = NamedTimers.schedule(state, :game_request_expiry, game_request_timeout())
    broadcast(state.token, "lobby_game_request", request)
    state
  end

  defp handle_respond_game(state, responder_id, responder_nick, true) do
    request = state.game_request
    state = NamedTimers.cancel(state, :game_request_expiry)

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
    state = NamedTimers.cancel(state, :game_request_expiry)

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
    Logger.debug(
      "Lobby game finished: session_id=#{state.session.id}, game=#{state.game.game_id}"
    )

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

  # A conversation hears about the session from the session, never from the
  # room. The room's topic is where the negotiation lives — every ICE candidate
  # and every SDP crosses it — so a chat that subscribed there to learn that a
  # badge had changed colour would be paying for a whole call to draw a dot.
  defp notify_chat_progress(%{nicks: %{creator: creator_nick, peer: peer_nick}, session: session}) do
    if creator_nick && peer_nick do
      notify_chat_progress(creator_nick, peer_nick, session)
      notify_chat_progress(peer_nick, creator_nick, session)
    end
  end

  defp notify_chat_progress(nickname, peer_nick, session) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.inbox(nickname),
      %{
        event: "lobby_session_progress",
        payload: %{peer_nick: peer_nick, token: session.token, status: session.status}
      }
    )
  end

  defp notify_chat_participants(%{creator: creator_nick, peer: peer_nick}, session, reason) do
    if creator_nick && peer_nick do
      notify_chat_user(creator_nick, peer_nick, session, reason)
      notify_chat_user(peer_nick, creator_nick, session, reason)
    end
  end

  defp notify_chat_user(nickname, peer_nick, session, reason) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.inbox(nickname),
      %{
        event: "lobby_session_ended",
        payload: %{
          peer_nick: peer_nick,
          token: session.token,
          reason: reason,
          duration_seconds: session.duration_seconds
        }
      }
    )
  end

  # A session whose peer is still nobody has no second nick to notify. It never
  # reaches here today — an open lobby has no process — and the clause is the
  # difference between that staying true and a `Repo.get(_, nil)` crash the day
  # it stops being.
  defp registered_nick(nil), do: nil

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
    state
    |> NamedTimers.schedule(:lobby_warning, lobby_warning_timeout())
    |> NamedTimers.schedule(:lobby_expiry, lobby_expiry_timeout())
  end

  # The envelope carries the token so a subscriber holding session state can
  # drop stale events from a previous session (extra keys don't break the
  # existing %{event:, payload:} matches).
  defp broadcast(token, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.lobby(token), %{
      event: event,
      payload: payload,
      token: token
    })
  end

  @valid_transitions %{
    # An open lobby has no process — it is a row and a deadline until somebody
    # claims it — so this line exists for the row's sake, not this server's:
    # the claim writes `pending` and the sweep writes `expired`.
    "open" => ~w(pending expired closed),
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
