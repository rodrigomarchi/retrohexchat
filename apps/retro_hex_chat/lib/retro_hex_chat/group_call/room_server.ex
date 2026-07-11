defmodule RetroHexChat.GroupCall.RoomServer do
  @moduledoc """
  Runtime owner for one persisted group-call room.

  The room process serializes joins/leaves, starts per-participant
  `PeerServer`s, records cold lifecycle changes and keeps RTP forwarding out of
  the database hot path.
  """

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Channels
  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.GroupCall.{Config, PeerServer, PeerSupervisor, Policy, Queries}
  alias RetroHexChat.GroupCall.Registry, as: GroupRegistry
  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}

  @pubsub RetroHexChat.PubSub

  @type participant_state :: %{
          participant: Participant.t(),
          peer_pid: pid() | nil,
          channel_pid: pid() | nil,
          ready?: boolean(),
          timer_ref: reference() | nil
        }

  @type state :: %{
          room: Room.t(),
          participants: %{integer() => participant_state()},
          pending_participants: %{integer() => participant_state()},
          peer_pid_to_participant_id: %{pid() => integer()},
          tracks: %{integer() => Track.t()},
          peerless_timer_ref: reference() | nil,
          config: Config.t()
        }

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(room_token) do
    GenServer.start_link(__MODULE__, room_token,
      name: GroupRegistry.room_via_tuple({:room, room_token})
    )
  end

  @spec child_spec(String.t()) :: Supervisor.child_spec()
  def child_spec(room_token) do
    %{
      id: {__MODULE__, room_token},
      start: {__MODULE__, :start_link, [room_token]},
      restart: :transient
    }
  end

  @spec join(String.t(), map(), pid(), map(), map()) ::
          {:ok, map()} | {:error, atom() | String.t()}
  def join(room_token, actor, signal_pid, client_info \\ %{}, media_constraints \\ %{}) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:join, actor, signal_pid, client_info, media_constraints}
    )
  end

  @spec apply_answer(String.t(), integer(), String.t()) :: :ok | {:error, term()}
  def apply_answer(room_token, participant_id, sdp) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:apply_answer, participant_id, sdp}
    )
  end

  @spec add_ice_candidate(String.t(), integer(), map()) :: :ok | {:error, term()}
  def add_ice_candidate(room_token, participant_id, candidate) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:add_ice_candidate, participant_id, candidate}
    )
  end

  @spec set_media_state(String.t(), integer(), map()) :: :ok | {:error, term()}
  def set_media_state(room_token, participant_id, media_state) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_media_state, participant_id, media_state}
    )
  end

  @spec close(String.t(), map(), String.t()) :: :ok | {:error, term()}
  def close(room_token, actor, reason \\ "moderation") do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:close, actor, reason}
    )
  end

  @spec kick_participant(String.t(), map(), integer()) :: :ok | {:error, term()}
  def kick_participant(room_token, actor, participant_id) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:kick_participant, actor, participant_id}
    )
  end

  @spec set_participant_audio(String.t(), map(), integer(), boolean()) ::
          {:ok, Participant.t()} | {:error, term()}
  def set_participant_audio(room_token, actor, participant_id, enabled?) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_participant_audio, actor, participant_id, enabled?}
    )
  end

  @spec leave(String.t(), integer(), String.t()) :: :ok | {:error, term()}
  def leave(room_token, participant_id, reason \\ "left") do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:leave, participant_id, reason}
    )
  end

  @spec mark_ready(pid(), integer()) :: :ok
  def mark_ready(room_pid, participant_id) do
    GenServer.cast(room_pid, {:mark_ready, participant_id})
  end

  @spec track_added(pid(), integer(), map()) :: :ok
  def track_added(room_pid, participant_id, track_info) do
    GenServer.cast(room_pid, {:track_added, participant_id, track_info})
  end

  @spec summary(String.t()) :: {:ok, map()} | {:error, :not_found}
  def summary(room_token) do
    case GroupRegistry.lookup_room({:room, room_token}) do
      {:ok, pid} -> GenServer.call(pid, :summary)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @impl true
  def init(room_token) do
    case Queries.get_room_by_token(room_token) do
      nil ->
        :ignore

      %Room{} = room ->
        if Room.terminal?(room.status) do
          :ignore
        else
          Elixir.Registry.register(
            GroupRegistry.room_registry_name(),
            {:channel, room.channel_name},
            room.id
          )

          config = Config.from_application_env()

          state = %{
            room: room,
            participants: %{},
            pending_participants: %{},
            peer_pid_to_participant_id: %{},
            tracks: %{},
            peerless_timer_ref: nil,
            config: config
          }

          {:ok, state}
        end
    end
  end

  @impl true
  def handle_call({:join, actor, signal_pid, client_info, _media_constraints}, _from, state) do
    with :ok <- check_enabled(state),
         {:ok, channel_state} <- Channels.Server.get_state(state.room.channel_name),
         membership = membership_from_channel_state(channel_state),
         :ok <-
           Policy.can_join?(actor.user_id, actor.nickname, state.room, membership) do
      join_authorized_participant(state, actor, signal_pid, client_info, membership)
    else
      {:error, reason} = error ->
        Logger.info("Group call join denied",
          room_token: state.room.token,
          reason: inspect(reason)
        )

        telemetry(:join, %{count: 1}, %{result: :denied, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call({:apply_answer, participant_id, sdp}, _from, state) do
    reply = PeerServer.apply_sdp_answer(state.room.id, participant_id, sdp)
    {:reply, reply, state}
  end

  def handle_call({:add_ice_candidate, participant_id, candidate}, _from, state) do
    reply = PeerServer.add_ice_candidate(state.room.id, participant_id, candidate)
    {:reply, reply, state}
  end

  def handle_call({:set_media_state, participant_id, media_state}, _from, state) do
    case participant_data(state, participant_id) do
      {:ok, data, bucket} ->
        current_media_state = normalize_media_state(data.participant.media_state)

        media_state =
          media_state
          |> normalize_media_state(current_media_state)
          |> enforce_server_media_policy(current_media_state)

        attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

        case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
          {:ok, participant} ->
            state =
              state
              |> put_in([bucket, participant_id, :participant], participant)
              |> update_tracks_for_media(participant_id, media_state)

            broadcast(state, "group_call_media_state", %{
              participant: participant_payload(participant)
            })

            telemetry(:media_state, %{count: 1}, %{result: :ok})
            {:reply, :ok, state}

          {:error, reason} ->
            telemetry(:media_state, %{count: 1}, %{result: :error, reason: inspect(reason)})
            {:reply, {:error, reason}, state}
        end

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:close, actor, reason}, _from, state) do
    with {:ok, membership} <- current_membership(state),
         :ok <- Policy.can_close?(actor.nickname, state.room, membership) do
      state =
        close_room(state, %{
          status: "closed",
          reason: reason,
          participant_status: "left",
          participant_reason: "room_closed"
        })

      {:stop, :normal, :ok, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:kick_participant, actor, participant_id}, _from, state) do
    with {:ok, target, _bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <-
           Policy.can_kick_participant?(
             membership,
             actor.nickname,
             target.participant.nickname
           ) do
      state = leave_participant(state, participant_id, "kicked", "kicked")
      telemetry(:participant_kicked, %{count: 1}, %{result: :ok})
      {:reply, :ok, state}
    else
      {:error, reason} = error ->
        telemetry(:participant_kicked, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call({:set_participant_audio, actor, participant_id, enabled?}, _from, state) do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <-
           Policy.can_moderate_media?(
             membership,
             actor.nickname,
             data.participant.nickname
           ) do
      media_state =
        data.participant.media_state
        |> normalize_media_state()
        |> Map.merge(%{
          "audio" => enabled?,
          "server_audio_muted" => !enabled?,
          "muted_by" => if(enabled?, do: nil, else: actor.nickname),
          "muted_at" => if(enabled?, do: nil, else: DateTime.utc_now() |> DateTime.to_iso8601())
        })

      attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

      case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
        {:ok, participant} ->
          state =
            state
            |> put_in([bucket, participant_id, :participant], participant)
            |> update_tracks_for_media(participant_id, media_state)

          send_channel_event(data.channel_pid, "group_call_set_media_state", %{
            audio: enabled?,
            video: Map.get(media_state, "video", true)
          })

          broadcast(state, "group_call_media_state", %{
            participant: participant_payload(participant)
          })

          telemetry(:media_moderated, %{count: 1}, %{result: :ok, enabled: enabled?})
          {:reply, {:ok, participant}, state}

        {:error, reason} ->
          telemetry(:media_moderated, %{count: 1}, %{result: :error, reason: inspect(reason)})
          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} = error ->
        telemetry(:media_moderated, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call({:leave, participant_id, reason}, _from, state) do
    {:reply, :ok, leave_participant(state, participant_id, reason)}
  end

  def handle_call(:summary, _from, state) do
    {:reply, {:ok, summary_payload(state)}, state}
  end

  defp join_authorized_participant(state, actor, signal_pid, client_info, membership) do
    case disconnected_participant(state, actor.nickname) do
      {:ok, participant_id, data} ->
        reconnect_authorized_participant(state, participant_id, data, signal_pid, client_info)

      :not_found ->
        join_new_participant(state, actor, signal_pid, client_info, membership)
    end
  end

  defp reconnect_authorized_participant(state, participant_id, data, signal_pid, client_info) do
    case reconnect_participant(state, participant_id, data, signal_pid, client_info) do
      {:ok, participant, state} ->
        telemetry(:join, %{count: 1}, %{result: :reconnect})
        {:reply, {:ok, join_payload(state, participant)}, state}

      {:error, reason} = error ->
        telemetry(:join, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  defp join_new_participant(state, actor, signal_pid, client_info, membership) do
    with :ok <- check_capacity(state),
         :ok <- check_not_already_joined(state, actor.nickname),
         {:ok, participant} <-
           insert_participant(state.room, actor, membership, client_info),
         {:ok, participant, state} <-
           put_participant_pending(state, participant, signal_pid) do
      telemetry(:join, %{count: 1}, %{result: :ok})
      {:reply, {:ok, join_payload(state, participant)}, state}
    else
      {:error, reason} = error ->
        telemetry(:join, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:mark_ready, participant_id}, state) do
    case pop_in(state, [:pending_participants, participant_id]) do
      {nil, state} ->
        {:noreply, state}

      {data, state} ->
        cancel_timer(data.timer_ref)

        now = DateTime.utc_now()

        {:ok, participant} =
          Queries.update_participant_status(data.participant, "connected", %{
            connected_at: now,
            last_seen_at: now
          })

        room = mark_room_active(state.room, now)
        data = %{data | participant: participant, ready?: true, timer_ref: nil}

        state =
          state
          |> cancel_peerless_timer()
          |> Map.put(:room, room)
          |> put_in([:participants, participant_id], data)

        notify_existing_peers_of_join(state, participant_id)

        broadcast(state, "group_call_peer_joined", %{
          participant: participant_payload(participant)
        })

        {:noreply, state}
    end
  end

  def handle_cast({:track_added, participant_id, track_info}, state) do
    case participant_data(state, participant_id) do
      {:ok, _data, _bucket} ->
        source = source_for_kind(track_info.kind)
        now = DateTime.utc_now()

        attrs = %{
          room_id: state.room.id,
          participant_id: participant_id,
          kind: Atom.to_string(track_info.kind),
          source: source,
          webrtc_track_id: track_info.webrtc_track_id,
          stream_id: track_info.stream_id,
          status: "active",
          codec: track_info.codec,
          announced_at: now,
          activated_at: now
        }

        state =
          case upsert_active_track(state.room.id, participant_id, track_info.kind, source, attrs) do
            {:ok, track} ->
              broadcast(state, "group_call_track_added", %{
                track: track_payload(track),
                participant_id: participant_id
              })

              telemetry(:track_added, %{count: 1}, %{kind: track.kind, source: track.source})
              put_in(state, [:tracks, track.id], track)

            {:error, changeset} ->
              Logger.debug("Ignoring group call track persistence error",
                room_token: state.room.token,
                participant_id: participant_id,
                errors: inspect(changeset.errors)
              )

              state
          end

        {:noreply, state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:peer_ready_timeout, participant_id}, state) do
    if Map.has_key?(state.pending_participants, participant_id) do
      Logger.warning("Group call participant did not become ready in time",
        room_token: state.room.token,
        participant_id: participant_id
      )

      PeerSupervisor.terminate_peer(state.room.id, participant_id)
      {:noreply, leave_participant(state, participant_id, "ready_timeout", "failed")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:reconnect_timeout, participant_id}, state) do
    case state.participants[participant_id] do
      %{participant: %{status: "disconnected"}} ->
        {:noreply, leave_participant(state, participant_id, "reconnect_timeout", "failed")}

      _other ->
        {:noreply, state}
    end
  end

  def handle_info(:peerless_timeout, state) do
    if room_empty?(state) do
      state =
        close_room(state, %{
          status: "closed",
          reason: "empty",
          participant_status: "left",
          participant_reason: "room_empty"
        })

      {:stop, :normal, state}
    else
      {:noreply, %{state | peerless_timer_ref: nil}}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Map.fetch(state.peer_pid_to_participant_id, pid) do
      {:ok, participant_id} ->
        participant_reason = peer_down_reason(reason)

        Logger.info("Group call peer down",
          room_token: state.room.token,
          participant_id: participant_id,
          reason: inspect(reason),
          participant_reason: participant_reason
        )

        state =
          state
          |> update_in([:peer_pid_to_participant_id], &Map.delete(&1, pid))
          |> leave_participant(participant_id, participant_reason, "disconnected")

        {:noreply, state}

      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, %{participants: participants, pending_participants: pending} = state) do
    participants
    |> Map.keys()
    |> Enum.concat(Map.keys(pending))
    |> Enum.each(&PeerSupervisor.terminate_peer(state.room.id, &1))

    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp check_enabled(%{config: %{enabled?: true}}), do: :ok
  defp check_enabled(_state), do: {:error, "Group calls are disabled"}

  defp check_capacity(state) do
    active_count = map_size(state.participants) + map_size(state.pending_participants)
    max_participants = min(state.room.max_participants, state.config.max_participants)

    if active_count < max_participants do
      :ok
    else
      {:error, "Group call is full"}
    end
  end

  defp check_not_already_joined(state, nickname) do
    normalized = String.downcase(nickname)

    exists? =
      state.participants
      |> Map.values()
      |> Enum.concat(Map.values(state.pending_participants))
      |> Enum.any?(&(&1.participant.normalized_nickname == normalized))

    if exists? do
      {:error, "Already joined"}
    else
      :ok
    end
  end

  defp disconnected_participant(state, nickname) do
    normalized = String.downcase(nickname)

    state.participants
    |> Enum.find(fn {_id, data} ->
      data.participant.normalized_nickname == normalized and
        data.participant.status == "disconnected"
    end)
    |> case do
      {participant_id, data} -> {:ok, participant_id, data}
      nil -> :not_found
    end
  end

  defp reconnect_participant(state, participant_id, data, signal_pid, client_info) do
    cancel_timer(data.timer_ref)

    now = DateTime.utc_now()

    case Queries.update_participant_status(data.participant, "joining", %{
           client_info: client_info,
           disconnected_at: nil,
           last_seen_at: now,
           reason: nil
         }) do
      {:ok, participant} ->
        state = update_in(state.participants, &Map.delete(&1, participant_id))
        put_participant_pending(state, participant, signal_pid)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_participant_pending(state, participant, signal_pid) do
    state = cancel_peerless_timer(state)

    with {:ok, peer_pid} <- start_peer(state, participant, signal_pid),
         {:ok, participant} <-
           Queries.update_participant_status(participant, participant.status, %{
             peer_ref: inspect(peer_pid),
             last_seen_at: DateTime.utc_now()
           }) do
      Process.monitor(peer_pid)

      timer_ref =
        Process.send_after(
          self(),
          {:peer_ready_timeout, participant.id},
          state.config.ready_timeout_ms
        )

      participant_state = %{
        participant: participant,
        peer_pid: peer_pid,
        channel_pid: signal_pid,
        ready?: false,
        timer_ref: timer_ref
      }

      state =
        state
        |> put_in([:pending_participants, participant.id], participant_state)
        |> put_in([:peer_pid_to_participant_id, peer_pid], participant.id)

      {:ok, participant, state}
    end
  end

  defp insert_participant(room, actor, membership, client_info) do
    role =
      case Membership.role(membership, actor.nickname) do
        {:ok, role} -> Atom.to_string(role)
        {:error, :not_member} -> "regular"
      end

    now = DateTime.utc_now()

    Queries.insert_participant(%{
      room_id: room.id,
      registered_nick_id: actor.user_id,
      nickname: actor.nickname,
      channel_role_snapshot: role,
      status: "joining",
      client_info: client_info,
      joined_at: now,
      last_seen_at: now
    })
  end

  defp start_peer(state, participant, signal_pid) do
    peer_ids = active_participant_ids(state)

    PeerSupervisor.start_child(%{
      room_pid: self(),
      room_id: state.room.id,
      room_token: state.room.token,
      participant: participant,
      signal_pid: signal_pid,
      peer_ids: peer_ids,
      config: state.config
    })
  end

  defp mark_room_active(%{status: "active"} = room, _now), do: room

  defp mark_room_active(room, now) do
    {:ok, room} =
      Queries.update_room_status(room, "active", %{
        activated_at: room.activated_at || now,
        opened_at: room.opened_at || now,
        last_activity_at: now
      })

    room
  end

  defp participant_data(state, participant_id) do
    cond do
      data = state.participants[participant_id] ->
        {:ok, data, :participants}

      data = state.pending_participants[participant_id] ->
        {:ok, data, :pending_participants}

      true ->
        {:error, :not_found}
    end
  end

  defp current_membership(state) do
    with {:ok, channel_state} <- Channels.Server.get_state(state.room.channel_name) do
      {:ok, membership_from_channel_state(channel_state)}
    end
  end

  defp leave_participant(state, participant_id, reason, terminal_status \\ "left") do
    {data, bucket, state} =
      cond do
        data = state.participants[participant_id] ->
          {data, :participants, update_in(state.participants, &Map.delete(&1, participant_id))}

        data = state.pending_participants[participant_id] ->
          {data, :pending_participants,
           update_in(state.pending_participants, &Map.delete(&1, participant_id))}

        true ->
          {nil, nil, state}
      end

    if data do
      cancel_timer(data.timer_ref)

      if is_pid(data.peer_pid) and Process.alive?(data.peer_pid) do
        PeerSupervisor.terminate_peer(state.room.id, participant_id)
      end

      status = if terminal_status == "disconnected", do: "disconnected", else: terminal_status
      now = DateTime.utc_now()

      attrs =
        if status in Participant.terminal_statuses() do
          %{left_at: now, reason: reason}
        else
          %{disconnected_at: now, reason: reason}
        end

      {:ok, participant} = Queries.update_participant_status(data.participant, status, attrs)

      state =
        state
        |> update_in([:peer_pid_to_participant_id], &Map.delete(&1, data.peer_pid))
        |> end_participant_tracks(participant_id, reason)
        |> maybe_put_participant(bucket, participant_id, participant, status, data)

      notify_existing_peers_of_leave(state, participant_id)

      broadcast(state, "group_call_peer_left", %{
        participant_id: participant_id,
        reason: reason
      })

      telemetry(:leave, %{count: 1}, %{status: status, reason: reason})

      state
      |> maybe_schedule_reconnect_timeout(participant_id, status)
      |> maybe_schedule_peerless_timeout()
    else
      state
    end
  end

  defp maybe_put_participant(state, _bucket, _participant_id, _participant, "left", _data),
    do: state

  defp maybe_put_participant(state, _bucket, _participant_id, _participant, "kicked", _data),
    do: state

  defp maybe_put_participant(state, _bucket, _participant_id, _participant, "failed", _data),
    do: state

  defp maybe_put_participant(state, _bucket, participant_id, participant, "disconnected", data) do
    put_in(state, [:participants, participant_id], %{
      data
      | participant: participant,
        peer_pid: nil,
        channel_pid: nil,
        ready?: false,
        timer_ref: nil
    })
  end

  defp maybe_put_participant(state, _bucket, participant_id, participant, _status, data) do
    put_in(state, [:participants, participant_id], %{
      data
      | participant: participant,
        ready?: false
    })
  end

  defp notify_existing_peers_of_join(state, participant_id) do
    state
    |> peer_states()
    |> Enum.reject(fn {id, _data} -> id == participant_id end)
    |> Enum.each(fn {_id, data} ->
      if is_pid(data.peer_pid) do
        PeerServer.notify(data.peer_pid, {:peer_added, participant_id})
      end
    end)
  end

  defp maybe_schedule_reconnect_timeout(state, participant_id, "disconnected") do
    timer_ref =
      Process.send_after(
        self(),
        {:reconnect_timeout, participant_id},
        state.config.reconnect_timeout_ms
      )

    put_in(state, [:participants, participant_id, :timer_ref], timer_ref)
  end

  defp maybe_schedule_reconnect_timeout(state, _participant_id, _status), do: state

  defp maybe_schedule_peerless_timeout(state) do
    cond do
      not room_empty?(state) ->
        state

      is_reference(state.peerless_timer_ref) ->
        state

      true ->
        timer_ref =
          Process.send_after(self(), :peerless_timeout, state.config.peerless_timeout_ms)

        %{state | peerless_timer_ref: timer_ref}
    end
  end

  defp cancel_peerless_timer(%{peerless_timer_ref: nil} = state), do: state

  defp cancel_peerless_timer(state) do
    cancel_timer(state.peerless_timer_ref)
    %{state | peerless_timer_ref: nil}
  end

  defp room_empty?(state) do
    map_size(state.participants) == 0 and map_size(state.pending_participants) == 0
  end

  defp close_room(state, opts) do
    reason = Map.fetch!(opts, :reason)
    participant_status = Map.fetch!(opts, :participant_status)
    participant_reason = Map.fetch!(opts, :participant_reason)

    telemetry(:room_closed, %{count: 1}, %{reason: reason})

    broadcast(state, "group_call_closed", %{
      room: room_payload(state.room),
      reason: reason
    })

    state =
      state
      |> cancel_peerless_timer()
      |> close_all_participants(participant_status, participant_reason)
      |> end_all_tracks(reason)

    now = DateTime.utc_now()

    {:ok, room} =
      Queries.update_room_status(state.room, Map.fetch!(opts, :status), %{
        closed_at: now,
        closed_reason: reason,
        last_activity_at: now
      })

    broadcast_channel_call_ended(room, reason)

    %{state | room: room, participants: %{}, pending_participants: %{}, tracks: %{}}
  end

  defp close_all_participants(state, status, reason) do
    state
    |> peer_states()
    |> Enum.each(fn {participant_id, data} ->
      cancel_timer(data.timer_ref)

      if is_pid(data.peer_pid) and Process.alive?(data.peer_pid) do
        PeerSupervisor.terminate_peer(state.room.id, participant_id)
      end

      if data.participant.status not in Participant.terminal_statuses() do
        _ =
          Queries.update_participant_status(data.participant, status, %{
            left_at: DateTime.utc_now(),
            reason: reason
          })
      end
    end)

    %{state | participants: %{}, pending_participants: %{}, peer_pid_to_participant_id: %{}}
  end

  defp upsert_active_track(room_id, participant_id, kind, source, attrs) do
    kind = Atom.to_string(kind)

    case Queries.get_active_track_by_source(room_id, participant_id, kind, source) do
      nil ->
        Queries.insert_track(attrs)

      track ->
        Queries.update_track_status(track, "active", %{
          activated_at: DateTime.utc_now(),
          ended_at: nil,
          ended_reason: nil,
          muted_at: nil,
          codec: attrs.codec,
          metadata: Map.get(attrs, :metadata, track.metadata)
        })
    end
  end

  defp broadcast_channel_call_ended(room, reason) do
    Phoenix.PubSub.broadcast(@pubsub, "channel:#{room.channel_name}", {
      :group_call_ended,
      %{channel: room.channel_name, token: room.token, reason: reason}
    })
  end

  defp update_tracks_for_media(state, participant_id, media_state) do
    media_state = normalize_media_state(media_state)

    state
    |> tracks_for_participant(participant_id)
    |> Enum.reduce(state, fn track, acc ->
      target_status =
        case {track.kind, Map.get(media_state, track.kind, true)} do
          {"audio", false} -> "muted"
          {"video", false} -> "muted"
          _other -> "active"
        end

      attrs =
        case target_status do
          "muted" -> %{muted_at: DateTime.utc_now()}
          "active" -> %{activated_at: DateTime.utc_now(), muted_at: nil}
        end

      case Queries.update_track_status(track, target_status, attrs) do
        {:ok, updated} ->
          broadcast(acc, "group_call_track_updated", %{
            track: track_payload(updated),
            participant_id: participant_id
          })

          put_in(acc, [:tracks, updated.id], updated)

        {:error, reason} ->
          Logger.debug("Ignoring group call track state update error",
            room_token: state.room.token,
            participant_id: participant_id,
            reason: inspect(reason)
          )

          acc
      end
    end)
  end

  defp end_participant_tracks(state, participant_id, reason) do
    state
    |> tracks_for_participant(participant_id)
    |> Enum.reduce(state, fn track, acc ->
      case Queries.update_track_status(track, "ended", %{
             ended_at: DateTime.utc_now(),
             ended_reason: reason
           }) do
        {:ok, ended} ->
          broadcast(acc, "group_call_track_removed", %{track_id: ended.id})
          update_in(acc.tracks, &Map.delete(&1, ended.id))

        {:error, update_reason} ->
          Logger.debug("Ignoring group call track end error",
            room_token: state.room.token,
            participant_id: participant_id,
            reason: inspect(update_reason)
          )

          acc
      end
    end)
  end

  defp peer_down_reason({:shutdown, :ice_connection_failed}), do: "ice_connection_failed"
  defp peer_down_reason({:shutdown, :peer_connection_closed}), do: "peer_connection_closed"
  defp peer_down_reason(_reason), do: "peer_down"

  defp end_all_tracks(state, reason) do
    state.tracks
    |> Map.values()
    |> Enum.reduce(state, fn track, acc ->
      _ =
        Queries.update_track_status(track, "ended", %{
          ended_at: DateTime.utc_now(),
          ended_reason: reason
        })

      acc
    end)
  end

  defp tracks_for_participant(state, participant_id) do
    state.tracks
    |> Map.values()
    |> Enum.filter(&(&1.participant_id == participant_id))
  end

  defp notify_existing_peers_of_leave(state, participant_id) do
    state
    |> peer_states()
    |> Enum.each(fn {_id, data} ->
      if is_pid(data.peer_pid) do
        PeerServer.notify(data.peer_pid, {:peer_removed, participant_id})
      end
    end)
  end

  defp active_participant_ids(state) do
    state
    |> peer_states()
    |> Enum.map(fn {id, _data} -> id end)
  end

  defp peer_states(state) do
    Map.merge(state.participants, state.pending_participants)
  end

  defp broadcast(state, event, payload) do
    state
    |> peer_states()
    |> Map.values()
    |> Enum.each(fn data ->
      send_channel_event(data.channel_pid, event, payload)
    end)
  end

  defp send_channel_event(channel_pid, event, payload) do
    if is_pid(channel_pid) and Process.alive?(channel_pid) do
      GenServer.cast(channel_pid, {:group_call_push, event, payload})
    end
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref)

  defp join_payload(state, participant) do
    %{
      room: room_payload(state.room),
      participant: participant_payload(participant),
      participants:
        state.participants
        |> Map.values()
        |> Enum.map(&participant_payload(&1.participant)),
      pending_participants:
        state.pending_participants
        |> Map.values()
        |> Enum.map(&participant_payload(&1.participant)),
      tracks: state.tracks |> Map.values() |> Enum.map(&track_payload/1),
      server_stats: server_stats_payload(state)
    }
  end

  defp summary_payload(state) do
    %{
      room: room_payload(state.room),
      participants:
        state.participants
        |> Map.values()
        |> Enum.map(&participant_payload(&1.participant)),
      pending_participants:
        state.pending_participants
        |> Map.values()
        |> Enum.map(&participant_payload(&1.participant)),
      tracks: state.tracks |> Map.values() |> Enum.map(&track_payload/1),
      server_stats: server_stats_payload(state)
    }
  end

  defp server_stats_payload(state) do
    peers =
      state
      |> peer_states()
      |> Enum.map(fn {_participant_id, data} -> peer_stats_payload(data) end)

    %{
      updated_at_ms: System.os_time(:millisecond),
      room: %{
        status: state.room.status,
        max_participants: state.room.max_participants,
        participant_count: map_size(state.participants),
        pending_count: map_size(state.pending_participants),
        track_count: map_size(state.tracks),
        audio_track_count: track_count(state, "audio"),
        video_track_count: track_count(state, "video")
      },
      peers: peers,
      totals: server_totals(peers)
    }
  end

  defp peer_stats_payload(%{participant: participant, peer_pid: peer_pid}) do
    base = peer_stats_base(participant)

    if is_pid(peer_pid) and Process.alive?(peer_pid) do
      safe_peer_stats(base, peer_pid)
    else
      base
    end
  end

  defp safe_peer_stats(base, peer_pid) do
    Map.merge(base, PeerServer.stats(peer_pid))
  catch
    :exit, _reason -> base
  end

  defp peer_stats_base(participant) do
    %{
      participant_id: participant.id,
      nickname: participant.nickname,
      connection_state: "unknown",
      ice_connection_state: "unknown",
      signaling_state: "unknown",
      inbound_track_count: 0,
      outbound_peer_count: 0,
      subscriber_count: 0,
      inbound_rtp: empty_rtp_summary(),
      outbound_rtp: empty_rtp_summary(),
      candidate_pairs: empty_candidate_pair_summary()
    }
  end

  defp server_totals(peers) do
    %{
      peer_count: length(peers),
      connected_peer_count: count_connection_state(peers, "connected"),
      connecting_peer_count: count_connection_state(peers, "connecting"),
      failed_peer_count: count_connection_state(peers, "failed"),
      inbound_track_count: sum(peers, :inbound_track_count),
      outbound_peer_count: sum(peers, :outbound_peer_count),
      subscriber_count: sum(peers, :subscriber_count),
      inbound_packets: sum_nested(peers, [:inbound_rtp, :packets]),
      inbound_bytes: sum_nested(peers, [:inbound_rtp, :bytes]),
      outbound_packets: sum_nested(peers, [:outbound_rtp, :packets]),
      outbound_bytes: sum_nested(peers, [:outbound_rtp, :bytes]),
      nack_count:
        sum_nested(peers, [:inbound_rtp, :nack_count]) +
          sum_nested(peers, [:outbound_rtp, :nack_count]),
      pli_count:
        sum_nested(peers, [:inbound_rtp, :pli_count]) +
          sum_nested(peers, [:outbound_rtp, :pli_count]),
      candidate_pair_count: sum_nested(peers, [:candidate_pairs, :total]),
      nominated_pair_count: sum_nested(peers, [:candidate_pairs, :nominated]),
      valid_pair_count: sum_nested(peers, [:candidate_pairs, :valid]),
      ice_packets_sent: sum_nested(peers, [:candidate_pairs, :packets_sent]),
      ice_packets_received: sum_nested(peers, [:candidate_pairs, :packets_received]),
      ice_bytes_sent: sum_nested(peers, [:candidate_pairs, :bytes_sent]),
      ice_bytes_received: sum_nested(peers, [:candidate_pairs, :bytes_received])
    }
  end

  defp track_count(state, kind) do
    state.tracks
    |> Map.values()
    |> Enum.count(&(&1.kind == kind))
  end

  defp count_connection_state(peers, state) do
    Enum.count(peers, &(Map.get(&1, :connection_state) == state))
  end

  defp sum(peers, key) do
    Enum.reduce(peers, 0, &(&2 + integer(Map.get(&1, key))))
  end

  defp sum_nested(peers, path) do
    Enum.reduce(peers, 0, &(&2 + integer(get_in(&1, path))))
  end

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)
  defp integer(_value), do: 0

  defp empty_rtp_summary do
    %{track_count: 0, packets: 0, bytes: 0, nack_count: 0, pli_count: 0}
  end

  defp empty_candidate_pair_summary do
    %{
      total: 0,
      nominated: 0,
      valid: 0,
      packets_sent: 0,
      packets_received: 0,
      bytes_sent: 0,
      bytes_received: 0
    }
  end

  defp room_payload(room) do
    %{
      id: room.id,
      token: room.token,
      channel_name: room.channel_name,
      status: room.status,
      max_participants: room.max_participants
    }
  end

  defp participant_payload(participant) do
    %{
      id: participant.id,
      nickname: participant.nickname,
      status: participant.status,
      media_state: participant.media_state,
      channel_role_snapshot: participant.channel_role_snapshot
    }
  end

  defp track_payload(track) do
    %{
      id: track.id,
      participant_id: track.participant_id,
      kind: track.kind,
      source: track.source,
      status: track.status,
      webrtc_track_id: track.webrtc_track_id,
      stream_id: track.stream_id
    }
  end

  defp source_for_kind(:audio), do: "microphone"
  defp source_for_kind(:video), do: "camera"

  defp normalize_media_state(media_state),
    do: normalize_media_state(media_state, %{"audio" => true, "video" => true})

  defp normalize_media_state(nil, fallback), do: fallback

  defp normalize_media_state(media_state, fallback) when is_map(media_state) do
    %{
      "audio" => media_value(media_state, "audio", Map.get(fallback, "audio", true)),
      "video" => media_value(media_state, "video", Map.get(fallback, "video", true))
    }
    |> maybe_put_extra(media_state, "server_audio_muted")
    |> maybe_put_extra(media_state, "muted_by")
    |> maybe_put_extra(media_state, "muted_at")
  end

  defp normalize_media_state(_media_state, fallback), do: fallback

  defp media_value(media_state, key, fallback) do
    atom_key = media_atom_key(key)

    case Map.get(media_state, key, Map.get(media_state, atom_key, fallback)) do
      "true" -> true
      "false" -> false
      value when is_boolean(value) -> value
      nil -> fallback
      _other -> fallback
    end
  end

  defp maybe_put_extra(target, source, key) do
    atom_key = media_atom_key(key)

    case Map.get(source, key, Map.get(source, atom_key)) do
      nil -> target
      value -> Map.put(target, key, value)
    end
  end

  defp enforce_server_media_policy(media_state, current_media_state) do
    if Map.get(current_media_state, "server_audio_muted") == true do
      media_state
      |> Map.put("audio", false)
      |> Map.put("server_audio_muted", true)
      |> copy_current_media_extra(current_media_state, "muted_by")
      |> copy_current_media_extra(current_media_state, "muted_at")
    else
      media_state
    end
  end

  defp copy_current_media_extra(target, current_media_state, key) do
    case Map.get(current_media_state, key) do
      nil -> target
      value -> Map.put(target, key, value)
    end
  end

  defp media_atom_key("audio"), do: :audio
  defp media_atom_key("video"), do: :video
  defp media_atom_key("server_audio_muted"), do: :server_audio_muted
  defp media_atom_key("muted_by"), do: :muted_by
  defp media_atom_key("muted_at"), do: :muted_at

  defp telemetry(event, measurements, metadata) do
    :telemetry.execute([:retro_hex_chat, :group_call, event], measurements, metadata)
  end

  defp membership_from_channel_state(%{members: members}) do
    Enum.reduce(members, Membership.new(), fn {nickname, role}, membership ->
      Membership.add(membership, nickname, role)
    end)
  end
end
