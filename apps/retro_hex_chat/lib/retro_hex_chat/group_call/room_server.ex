defmodule RetroHexChat.GroupCall.RoomServer do
  @moduledoc """
  Runtime owner for one persisted group-call room.

  The room process serializes joins/leaves, starts per-participant
  `PeerServer`s, records cold lifecycle changes and keeps RTP forwarding out of
  the database hot path.

  This module holds the process: its API, its callbacks and the lifecycle of a
  seat (join, rejoin, reconnect, leave, close). What it does to a seat or a
  track lives beside it, as functions of its state:

    * `RetroHexChat.GroupCall.RoomModeration` — screen share and moderation of media
    * `RetroHexChat.GroupCall.RoomTracks` — the published tracks
    * `RetroHexChat.GroupCall.MediaState` — a participant's media-state map
    * `RetroHexChat.GroupCall.RoomAudit` — the audit trail and locking
    * `RetroHexChat.GroupCall.RoomPayload` — what members are told
    * `RetroHexChat.GroupCall.RoomFanout` — who hears it
    * `RetroHexChat.GroupCall.RoomState` — lookups on the state, and telemetry
    * `RetroHexChat.GroupCall.Reaction` — reactions
  """

  alias RetroHexChat.Nickname

  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Channels
  alias RetroHexChat.Channels.Membership

  alias RetroHexChat.GroupCall.{
    Audit,
    Config,
    MediaState,
    PeerServer,
    PeerSupervisor,
    Policy,
    Queries,
    Reaction,
    RoomAudit,
    RoomFanout,
    RoomModeration,
    RoomPayload,
    RoomState,
    RoomTracks
  }

  alias RetroHexChat.GroupCall.Registry, as: GroupRegistry
  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}
  alias RetroHexChat.Topics

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

  @spec rejoin(String.t(), map(), integer() | nil, pid(), map(), map()) ::
          {:ok, map()} | {:error, atom() | String.t()}
  def rejoin(
        room_token,
        actor,
        previous_participant_id,
        signal_pid,
        client_info \\ %{},
        media_constraints \\ %{}
      ) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:rejoin, actor, previous_participant_id, signal_pid, client_info, media_constraints}
    )
  end

  @spec disconnect(String.t(), integer(), pid(), String.t()) :: :ok | {:error, term()}
  def disconnect(room_token, participant_id, signal_pid, reason \\ "channel_closed") do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:disconnect, participant_id, signal_pid, reason}
    )
  end

  @spec apply_answer(String.t(), integer(), String.t(), String.t() | nil) ::
          :ok | {:error, term()}
  def apply_answer(room_token, participant_id, sdp, offer_id \\ nil) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:apply_answer, participant_id, sdp, offer_id}
    )
  end

  @spec add_ice_candidate(String.t(), integer(), map()) :: :ok | {:error, term()}
  def add_ice_candidate(room_token, participant_id, candidate) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:add_ice_candidate, participant_id, candidate}
    )
  end

  @spec request_offer(String.t(), integer()) :: :ok | {:error, term()}
  def request_offer(room_token, participant_id) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:request_offer, participant_id}
    )
  end

  @spec set_media_state(String.t(), integer(), map()) :: :ok | {:error, term()}
  def set_media_state(room_token, participant_id, media_state) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_media_state, participant_id, media_state}
    )
  end

  @spec set_screen_share_state(String.t(), integer(), boolean(), map()) ::
          {:ok, map()} | {:error, term()}
  def set_screen_share_state(room_token, participant_id, active?, screen_info \\ %{}) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_screen_share_state, participant_id, active?, screen_info}
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

  @spec force_kick_participant(String.t(), map(), integer(), String.t()) :: :ok | {:error, term()}
  def force_kick_participant(room_token, actor, participant_id, reason \\ "kicked") do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:force_kick_participant, actor, participant_id, reason}
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

  @spec set_participant_video(String.t(), map(), integer(), boolean()) ::
          {:ok, Participant.t()} | {:error, term()}
  def set_participant_video(room_token, actor, participant_id, enabled?) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_participant_video, actor, participant_id, enabled?}
    )
  end

  @spec set_participant_screen_share(String.t(), map(), integer(), boolean()) ::
          {:ok, Participant.t()} | {:error, term()}
  def set_participant_screen_share(room_token, actor, participant_id, allowed?) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_participant_screen_share, actor, participant_id, allowed?}
    )
  end

  @spec set_all_participants_media(String.t(), map(), :audio | :video, boolean()) ::
          {:ok, map()} | {:error, term()}
  def set_all_participants_media(room_token, actor, kind, enabled?)
      when kind in [:audio, :video] do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_all_participants_media, actor, kind, enabled?}
    )
  end

  @spec set_locked(String.t(), map(), boolean()) :: {:ok, map()} | {:error, term()}
  def set_locked(room_token, actor, locked?) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_locked, actor, locked?}
    )
  end

  @spec set_hand_raised(String.t(), map(), integer(), boolean()) ::
          {:ok, Participant.t()} | {:error, term()}
  def set_hand_raised(room_token, actor, participant_id, raised?) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:set_hand_raised, actor, participant_id, raised?}
    )
  end

  @spec allow_participant_speak(String.t(), map(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def allow_participant_speak(room_token, actor, participant_id) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:allow_participant_speak, actor, participant_id}
    )
  end

  @spec send_reaction(String.t(), map(), integer(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_reaction(room_token, actor, participant_id, reaction) do
    GenServer.call(
      GroupRegistry.room_via_tuple({:room, room_token}),
      {:send_reaction, actor, participant_id, reaction}
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
      {:ok, pid} -> ask_summary(pid)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # A room can stop between being found and being asked — the conference was
  # closed a moment ago. That is the room not being there, the answer the
  # registry would have given a moment later, and every chat in the channel
  # asks; crashing them all for it would be the bug. A timeout is not this and
  # still exits.
  defp ask_summary(pid) do
    GenServer.call(pid, :summary)
  catch
    :exit, {reason, {GenServer, :call, _}} when reason in [:noproc, :normal, :shutdown] ->
      {:error, :not_found}

    :exit, {{:shutdown, _}, {GenServer, :call, _}} ->
      {:error, :not_found}
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
         membership = Membership.from_members(channel_state.members),
         :ok <-
           Policy.can_join?(actor.user_id, actor.nickname, state.room, membership,
             seat_held: seat_held?(state, actor, nil)
           ) do
      join_authorized_participant(state, actor, signal_pid, client_info, membership)
    else
      {:error, _reason} = error ->
        deny_join(error, state, "join")
    end
  end

  def handle_call(
        {:rejoin, actor, previous_participant_id, signal_pid, client_info, _media_constraints},
        _from,
        state
      ) do
    with :ok <- check_enabled(state),
         {:ok, channel_state} <- Channels.Server.get_state(state.room.channel_name),
         membership = Membership.from_members(channel_state.members),
         :ok <-
           Policy.can_join?(actor.user_id, actor.nickname, state.room, membership,
             seat_held: seat_held?(state, actor, previous_participant_id)
           ) do
      rejoin_authorized_participant(
        state,
        actor,
        previous_participant_id,
        signal_pid,
        client_info,
        membership
      )
    else
      {:error, _reason} = error ->
        deny_join(error, state, "rejoin")
    end
  end

  def handle_call({:apply_answer, participant_id, sdp, offer_id}, _from, state) do
    reply = PeerServer.apply_sdp_answer(state.room.id, participant_id, sdp, offer_id)
    {:reply, reply, state}
  end

  def handle_call({:add_ice_candidate, participant_id, candidate}, _from, state) do
    reply = PeerServer.add_ice_candidate(state.room.id, participant_id, candidate)
    {:reply, reply, state}
  end

  def handle_call({:request_offer, participant_id}, _from, state) do
    reply =
      case RoomState.participant_data(state, participant_id) do
        {:ok, %{peer_pid: peer_pid}, _bucket} when is_pid(peer_pid) ->
          PeerServer.request_offer(state.room.id, participant_id)

        {:ok, _data, _bucket} ->
          {:error, :peer_not_ready}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, reply, state}
  end

  def handle_call({:send_reaction, actor, participant_id, reaction}, _from, state) do
    reply =
      with {:ok, data, _bucket} <- RoomState.participant_data(state, participant_id),
           :ok <- Reaction.authorize(actor, data.participant),
           {:ok, reaction} <- Reaction.normalize(reaction) do
        payload = Reaction.payload(data.participant, reaction)
        RoomFanout.broadcast(state, "group_call_reaction", payload)
        RoomState.telemetry(:reaction, %{count: 1}, %{reaction: reaction})
        {:ok, payload}
      end

    {:reply, reply, state}
  end

  def handle_call({:set_media_state, participant_id, media_state}, _from, state) do
    case RoomState.participant_data(state, participant_id) do
      {:ok, data, bucket} ->
        current_media_state = MediaState.normalize(data.participant.media_state)

        media_state =
          media_state
          |> MediaState.normalize(current_media_state)
          |> MediaState.enforce_server_policy(current_media_state)

        attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

        case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
          {:ok, participant} ->
            state =
              state
              |> put_in([bucket, participant_id, :participant], participant)
              |> RoomTracks.update_for_media(participant_id, media_state)

            RoomFanout.broadcast(state, "group_call_media_state", %{
              participant: RoomPayload.participant(participant)
            })

            RoomState.telemetry(:media_state, %{count: 1}, %{result: :ok})
            {:reply, :ok, state}

          {:error, reason} ->
            RoomState.telemetry(:media_state, %{count: 1}, %{
              result: :error,
              reason: inspect(reason)
            })

            {:reply, {:error, reason}, state}
        end

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_screen_share_state, participant_id, active?, screen_info}, _from, state) do
    case RoomState.participant_data(state, participant_id) do
      {:ok, data, bucket} ->
        RoomModeration.set_screen_share(state, participant_id, data, bucket, active?, screen_info)

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:close, actor, reason}, _from, state) do
    with {:ok, membership} <- RoomState.current_membership(state),
         :ok <- Policy.can_close?(actor.nickname, state.room, membership) do
      state =
        close_room(state, %{
          status: "closed",
          reason: reason,
          actor: actor.nickname,
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
    with {:ok, target, _bucket} <- RoomState.participant_data(state, participant_id),
         {:ok, membership} <- RoomState.current_membership(state),
         :ok <-
           Policy.can_kick_participant?(
             membership,
             actor.nickname,
             target.participant.nickname
           ) do
      state =
        state
        |> leave_participant(participant_id, "kicked", "kicked")
        |> RoomAudit.record(:participant_kicked, %{
          actor: actor.nickname,
          target: target.participant.nickname,
          target_participant_id: participant_id,
          reason: "kicked"
        })

      RoomState.telemetry(:participant_kicked, %{count: 1}, %{result: :ok})
      {:reply, :ok, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:participant_kicked, %{count: 1}, %{
          result: :error,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:force_kick_participant, actor, participant_id, reason}, _from, state) do
    case RoomState.participant_data(state, participant_id) do
      {:ok, target, _bucket} ->
        state =
          state
          |> leave_participant(participant_id, reason, "kicked")
          |> RoomAudit.record(:participant_kicked, %{
            actor: actor.nickname,
            target: target.participant.nickname,
            target_participant_id: participant_id,
            reason: reason
          })

        RoomState.telemetry(:participant_kicked, %{count: 1}, %{result: :ok, forced?: true})
        {:reply, :ok, state}

      {:error, :not_found} ->
        RoomState.telemetry(:participant_kicked, %{count: 1}, %{result: :not_found, forced?: true})

        {:reply, :ok, state}
    end
  end

  def handle_call({:set_participant_audio, actor, participant_id, enabled?}, _from, state) do
    RoomModeration.set_participant_media(state, actor, participant_id, :audio, enabled?)
  end

  def handle_call({:set_participant_video, actor, participant_id, enabled?}, _from, state) do
    RoomModeration.set_participant_media(state, actor, participant_id, :video, enabled?)
  end

  def handle_call({:set_participant_screen_share, actor, participant_id, allowed?}, _from, state) do
    RoomModeration.set_participant_screen_share(state, actor, participant_id, allowed?)
  end

  def handle_call({:set_all_participants_media, actor, kind, enabled?}, _from, state)
      when kind in [:audio, :video] do
    RoomModeration.set_all_media(state, actor, kind, enabled?)
  end

  def handle_call({:set_locked, actor, locked?}, _from, state) do
    with {:ok, membership} <- RoomState.current_membership(state),
         :ok <- Policy.can_close?(actor.nickname, state.room, membership),
         {:ok, room} <- RoomAudit.update_lock(state.room, actor.nickname, locked?) do
      state = %{state | room: room}
      summary = RoomPayload.summary(state)

      broadcast_channel_call_updated(state, "lock_changed")
      RoomAudit.broadcast_lock(room, actor.nickname, locked?)

      RoomState.telemetry(:lock_changed, %{count: 1}, %{result: :ok, locked: locked? == true})

      {:reply,
       {:ok,
        %{
          locked: locked? == true,
          room: RoomPayload.room(room),
          summary: summary
        }}, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:lock_changed, %{count: 1}, %{
          result: :error,
          locked: locked? == true,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:set_hand_raised, actor, participant_id, raised?}, _from, state) do
    with {:ok, data, bucket} <- RoomState.participant_data(state, participant_id),
         :ok <- RoomModeration.can_set_hand_raised?(state, actor, data.participant, raised?),
         {:ok, state, participant} <-
           RoomModeration.update_media_state(state, data, bucket, fn media_state ->
             MediaState.put_hand_raised(media_state, raised? == true, actor.nickname)
           end) do
      broadcast_channel_call_updated(state, "hand_raised")
      RoomState.telemetry(:hand_raised, %{count: 1}, %{result: :ok, raised: raised? == true})
      {:reply, {:ok, participant}, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:hand_raised, %{count: 1}, %{
          result: :error,
          raised: raised? == true,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:allow_participant_speak, actor, participant_id}, _from, state) do
    with {:ok, data, bucket} <- RoomState.participant_data(state, participant_id),
         {:ok, membership} <- RoomState.current_membership(state),
         :ok <- Policy.can_moderate_media?(membership, actor.nickname, data.participant.nickname),
         {:ok, state, participant} <-
           RoomModeration.update_media_state(
             state,
             data,
             bucket,
             fn media_state ->
               media_state
               |> MediaState.put_server_moderation(:audio, true, actor.nickname)
               |> MediaState.put_hand_raised(false, actor.nickname)
             end,
             force_client?: true
           ) do
      state =
        RoomAudit.record(state, :participant_speak_allowed, %{
          actor: actor.nickname,
          target: participant.nickname,
          target_participant_id: participant.id
        })

      broadcast_channel_call_updated(state, "speak_allowed")
      RoomState.telemetry(:speak_allowed, %{count: 1}, %{result: :ok})
      {:reply, {:ok, participant}, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:speak_allowed, %{count: 1}, %{
          result: :error,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:leave, participant_id, reason}, _from, state) do
    {:reply, :ok, leave_participant(state, participant_id, reason)}
  end

  def handle_call({:disconnect, participant_id, signal_pid, reason}, _from, state) do
    state =
      case RoomState.participant_data(state, participant_id) do
        {:ok, %{channel_pid: ^signal_pid}, _bucket} ->
          leave_participant(state, participant_id, reason, "disconnected")

        {:ok, _data, _bucket} ->
          state

        {:error, _reason} ->
          state
      end

    {:reply, :ok, state}
  end

  def handle_call(:summary, _from, state) do
    {:reply, {:ok, RoomPayload.summary(state)}, state}
  end

  defp join_authorized_participant(state, actor, signal_pid, client_info, membership) do
    case disconnected_participant(state, actor.nickname) do
      {:ok, participant_id, data} ->
        reconnect_authorized_participant(state, participant_id, data, signal_pid, client_info)

      :not_found ->
        join_new_participant(state, actor, signal_pid, client_info, membership)
    end
  end

  defp rejoin_authorized_participant(
         state,
         actor,
         previous_participant_id,
         signal_pid,
         client_info,
         membership
       ) do
    case authorized_rejoin_participant(state, actor, previous_participant_id) do
      {:ok, participant_id, data} ->
        reconnect_authorized_participant(state, participant_id, data, signal_pid, client_info)

      :not_found ->
        join_authorized_participant(state, actor, signal_pid, client_info, membership)
    end
  end

  defp reconnect_authorized_participant(state, participant_id, data, signal_pid, client_info) do
    case reconnect_participant(state, participant_id, data, signal_pid, client_info) do
      {:ok, participant, state} ->
        RoomState.telemetry(:join, %{count: 1}, %{result: :reconnect})
        {:reply, {:ok, RoomPayload.join(state, participant)}, state}

      {:error, reason} = error ->
        RoomState.telemetry(:join, %{count: 1}, %{result: :error, reason: inspect(reason)})
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
      RoomState.telemetry(:join, %{count: 1}, %{result: :ok})
      {:reply, {:ok, RoomPayload.join(state, participant)}, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:join, %{count: 1}, %{result: :error, reason: inspect(reason)})
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

        RoomFanout.broadcast(state, "group_call_peer_joined", %{
          participant: RoomPayload.participant(participant)
        })

        broadcast_channel_call_updated(state, "participant_joined")

        {:noreply, state}
    end
  end

  def handle_cast({:track_added, participant_id, track_info}, state) do
    case RoomState.participant_data(state, participant_id) do
      {:ok, data, _bucket} ->
        source = RoomTracks.source_for(track_info, data.participant)
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
          metadata: RoomTracks.metadata_of(track_info),
          announced_at: now,
          activated_at: now
        }

        state =
          case RoomTracks.upsert_active(
                 state.room.id,
                 participant_id,
                 track_info.kind,
                 source,
                 attrs
               ) do
            {:ok, track} ->
              RoomFanout.broadcast(state, "group_call_track_added", %{
                track: RoomPayload.track(track),
                participant_id: participant_id
              })

              RoomState.telemetry(:track_added, %{count: 1}, %{
                kind: track.kind,
                source: track.source
              })

              put_in(state, [:tracks, track.id], track)

            {:error, changeset} ->
              Logger.debug("Ignoring group call track persistence error",
                room_id: state.room.id,
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
        room_id: state.room.id,
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

        Logger.debug("Group call peer down",
          room_id: state.room.id,
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
    normalized = Nickname.key(nickname)

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

  # A seat the room is still holding for this person: the one they had, or one
  # left disconnected under their nickname inside the reconnect window.
  defp seat_held?(state, actor, previous_participant_id) do
    authorized_rejoin_participant(state, actor, previous_participant_id) != :not_found or
      disconnected_participant(state, actor.nickname) != :not_found
  end

  defp disconnected_participant(state, nickname) do
    normalized = Nickname.key(nickname)

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

  defp authorized_rejoin_participant(state, actor, participant_id)
       when is_integer(participant_id) do
    case RoomState.participant_data(state, participant_id) do
      {:ok, %{participant: participant} = data, _bucket}
      when participant.registered_nick_id == actor.user_id ->
        normalized = Nickname.key(actor.nickname)

        if participant.normalized_nickname == normalized do
          {:ok, participant_id, data}
        else
          :not_found
        end

      _other ->
        :not_found
    end
  end

  defp authorized_rejoin_participant(_state, _actor, _participant_id), do: :not_found

  defp reconnect_participant(state, participant_id, data, signal_pid, client_info) do
    cancel_timer(data.timer_ref)
    old_peer_pid = data.peer_pid

    state =
      state
      |> update_in([:participants], &Map.delete(&1, participant_id))
      |> update_in([:pending_participants], &Map.delete(&1, participant_id))
      |> delete_peer_pid_mapping(old_peer_pid)
      |> RoomTracks.end_for_participant(participant_id, "rejoin")

    if is_pid(old_peer_pid) and Process.alive?(old_peer_pid) do
      PeerSupervisor.terminate_peer(state.room.id, participant_id)
    end

    now = DateTime.utc_now()

    case Queries.update_participant_status(data.participant, "joining", %{
           client_info: client_info,
           disconnected_at: nil,
           last_seen_at: now,
           reason: nil
         }) do
      {:ok, participant} ->
        put_participant_pending(state, participant, signal_pid)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_peer_pid_mapping(state, peer_pid) when is_pid(peer_pid) do
    update_in(state, [:peer_pid_to_participant_id], &Map.delete(&1, peer_pid))
  end

  defp delete_peer_pid_mapping(state, _peer_pid), do: state

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
        |> RoomTracks.end_for_participant(participant_id, reason)
        |> maybe_put_participant(bucket, participant_id, participant, status, data)

      notify_existing_peers_of_leave(state, participant_id)

      RoomFanout.broadcast(state, "group_call_peer_left", %{
        participant_id: participant_id,
        reason: reason
      })

      broadcast_channel_call_updated(state, reason)

      RoomState.telemetry(:leave, %{count: 1}, %{status: status, reason: reason})

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
    |> RoomFanout.peer_states()
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

  # Who ended it, for the people it ended for; nil when nobody did (it emptied).
  defp closed_by(nickname) when is_binary(nickname), do: nickname
  defp closed_by(_actor), do: nil

  defp close_room(state, opts) do
    reason = Map.fetch!(opts, :reason)
    participant_status = Map.fetch!(opts, :participant_status)
    participant_reason = Map.fetch!(opts, :participant_reason)
    actor = Map.get(opts, :actor)

    RoomState.telemetry(:room_closed, %{count: 1}, %{reason: reason})

    room_before_audit = state.room

    state =
      RoomAudit.put_event(state, :conference_ended, %{
        actor: actor,
        reason: reason
      })

    RoomFanout.broadcast(state, "group_call_closed", %{
      room: RoomPayload.room(state.room),
      reason: reason,
      ended_by: closed_by(actor)
    })

    state =
      state
      |> cancel_peerless_timer()
      |> close_all_participants(participant_status, participant_reason)
      |> RoomTracks.end_all(reason)

    now = DateTime.utc_now()

    {:ok, room} =
      Queries.update_room_status(room_before_audit, Map.fetch!(opts, :status), %{
        closed_at: now,
        closed_reason: reason,
        metadata: state.room.metadata,
        last_activity_at: now
      })

    broadcast_channel_call_ended(room, reason)

    %{state | room: room, participants: %{}, pending_participants: %{}, tracks: %{}}
  end

  defp close_all_participants(state, status, reason) do
    state
    |> RoomFanout.peer_states()
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

  defp broadcast_channel_call_ended(room, reason) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(room.channel_name), {
      :group_call_ended,
      %{
        channel: room.channel_name,
        token: room.token,
        reason: reason,
        event: Audit.last_event(room.metadata)
      }
    })
  end

  defp broadcast_channel_call_updated(state, reason) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(state.room.channel_name), {
      :group_call_updated,
      %{
        channel: state.room.channel_name,
        token: state.room.token,
        reason: reason,
        summary: RoomPayload.summary(state)
      }
    })
  end

  defp peer_down_reason({:shutdown, :ice_connection_failed}), do: "ice_connection_failed"
  defp peer_down_reason({:shutdown, :peer_connection_closed}), do: "peer_connection_closed"
  defp peer_down_reason(_reason), do: "peer_down"

  defp notify_existing_peers_of_leave(state, participant_id) do
    state
    |> RoomFanout.peer_states()
    |> Enum.each(fn {_id, data} ->
      if is_pid(data.peer_pid) do
        PeerServer.notify(data.peer_pid, {:peer_removed, participant_id})
      end
    end)
  end

  defp active_participant_ids(state) do
    state
    |> RoomFanout.peer_states()
    |> Enum.map(fn {id, _data} -> id end)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref)

  # A join or rejoin refused: logged, counted, and the refusal handed back.
  defp deny_join({:error, reason} = error, state, label) do
    Logger.debug("Group call #{label} denied", room_id: state.room.id, reason: inspect(reason))
    RoomState.telemetry(:join, %{count: 1}, %{result: :denied, reason: inspect(reason)})
    {:reply, error, state}
  end
end
