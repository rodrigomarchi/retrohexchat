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
  alias RetroHexChat.GroupCall.{Audit, Config, PeerServer, PeerSupervisor, Policy, Queries}
  alias RetroHexChat.GroupCall.Registry, as: GroupRegistry
  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub
  @allowed_reactions ~w(heart thumbs_up clap laugh wow)

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
        Logger.debug("Group call join denied",
          room_id: state.room.id,
          reason: inspect(reason)
        )

        telemetry(:join, %{count: 1}, %{result: :denied, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call(
        {:rejoin, actor, previous_participant_id, signal_pid, client_info, _media_constraints},
        _from,
        state
      ) do
    with :ok <- check_enabled(state),
         {:ok, channel_state} <- Channels.Server.get_state(state.room.channel_name),
         membership = membership_from_channel_state(channel_state),
         :ok <-
           Policy.can_join?(actor.user_id, actor.nickname, state.room, membership) do
      rejoin_authorized_participant(
        state,
        actor,
        previous_participant_id,
        signal_pid,
        client_info,
        membership
      )
    else
      {:error, reason} = error ->
        Logger.debug("Group call rejoin denied",
          room_id: state.room.id,
          reason: inspect(reason)
        )

        telemetry(:join, %{count: 1}, %{result: :denied, reason: inspect(reason)})
        {:reply, error, state}
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
      case participant_data(state, participant_id) do
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
      with {:ok, data, _bucket} <- participant_data(state, participant_id),
           :ok <- authorize_reaction_actor(actor, data.participant),
           {:ok, reaction} <- normalize_reaction(reaction) do
        payload = reaction_payload(data.participant, reaction)
        broadcast(state, "group_call_reaction", payload)
        telemetry(:reaction, %{count: 1}, %{reaction: reaction})
        {:ok, payload}
      end

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

  def handle_call({:set_screen_share_state, participant_id, active?, screen_info}, _from, state) do
    case participant_data(state, participant_id) do
      {:ok, data, bucket} ->
        reply_screen_share_state(state, participant_id, data, bucket, active?, screen_info)

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
    with {:ok, target, _bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <-
           Policy.can_kick_participant?(
             membership,
             actor.nickname,
             target.participant.nickname
           ) do
      state =
        state
        |> leave_participant(participant_id, "kicked", "kicked")
        |> record_group_call_audit(:participant_kicked, %{
          actor: actor.nickname,
          target: target.participant.nickname,
          target_participant_id: participant_id,
          reason: "kicked"
        })

      telemetry(:participant_kicked, %{count: 1}, %{result: :ok})
      {:reply, :ok, state}
    else
      {:error, reason} = error ->
        telemetry(:participant_kicked, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call({:force_kick_participant, actor, participant_id, reason}, _from, state) do
    case participant_data(state, participant_id) do
      {:ok, target, _bucket} ->
        state =
          state
          |> leave_participant(participant_id, reason, "kicked")
          |> record_group_call_audit(:participant_kicked, %{
            actor: actor.nickname,
            target: target.participant.nickname,
            target_participant_id: participant_id,
            reason: reason
          })

        telemetry(:participant_kicked, %{count: 1}, %{result: :ok, forced?: true})
        {:reply, :ok, state}

      {:error, :not_found} ->
        telemetry(:participant_kicked, %{count: 1}, %{result: :not_found, forced?: true})
        {:reply, :ok, state}
    end
  end

  def handle_call({:set_participant_audio, actor, participant_id, enabled?}, _from, state) do
    set_participant_media(state, actor, participant_id, :audio, enabled?)
  end

  def handle_call({:set_participant_video, actor, participant_id, enabled?}, _from, state) do
    set_participant_media(state, actor, participant_id, :video, enabled?)
  end

  def handle_call({:set_participant_screen_share, actor, participant_id, allowed?}, _from, state) do
    set_participant_screen_share_state(state, actor, participant_id, allowed?)
  end

  def handle_call({:set_all_participants_media, actor, kind, enabled?}, _from, state)
      when kind in [:audio, :video] do
    apply_all_participants_media(state, actor, kind, enabled?)
  end

  def handle_call({:set_locked, actor, locked?}, _from, state) do
    with {:ok, membership} <- current_membership(state),
         :ok <- Policy.can_close?(actor.nickname, state.room, membership),
         {:ok, room} <- update_room_lock(state.room, actor.nickname, locked?) do
      state = %{state | room: room}
      summary = summary_payload(state)

      broadcast_channel_call_updated(state, "lock_changed")
      broadcast_lock_summary(room, actor.nickname, locked?)

      telemetry(:lock_changed, %{count: 1}, %{result: :ok, locked: locked? == true})

      {:reply,
       {:ok,
        %{
          locked: locked? == true,
          room: room_payload(room),
          summary: summary
        }}, state}
    else
      {:error, reason} = error ->
        telemetry(:lock_changed, %{count: 1}, %{
          result: :error,
          locked: locked? == true,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:set_hand_raised, actor, participant_id, raised?}, _from, state) do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         :ok <- can_set_hand_raised?(state, actor, data.participant, raised?),
         {:ok, state, participant} <-
           update_participant_media_state(state, data, bucket, fn media_state ->
             put_hand_raised(media_state, raised? == true, actor.nickname)
           end) do
      broadcast_channel_call_updated(state, "hand_raised")
      telemetry(:hand_raised, %{count: 1}, %{result: :ok, raised: raised? == true})
      {:reply, {:ok, participant}, state}
    else
      {:error, reason} = error ->
        telemetry(:hand_raised, %{count: 1}, %{
          result: :error,
          raised: raised? == true,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  def handle_call({:allow_participant_speak, actor, participant_id}, _from, state) do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <- Policy.can_moderate_media?(membership, actor.nickname, data.participant.nickname),
         {:ok, state, participant} <-
           update_participant_media_state(
             state,
             data,
             bucket,
             fn media_state ->
               media_state
               |> put_server_media_moderation(:audio, true, actor.nickname)
               |> put_hand_raised(false, actor.nickname)
             end,
             force_client?: true
           ) do
      state =
        record_group_call_audit(state, :participant_speak_allowed, %{
          actor: actor.nickname,
          target: participant.nickname,
          target_participant_id: participant.id
        })

      broadcast_channel_call_updated(state, "speak_allowed")
      telemetry(:speak_allowed, %{count: 1}, %{result: :ok})
      {:reply, {:ok, participant}, state}
    else
      {:error, reason} = error ->
        telemetry(:speak_allowed, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, error, state}
    end
  end

  def handle_call({:leave, participant_id, reason}, _from, state) do
    {:reply, :ok, leave_participant(state, participant_id, reason)}
  end

  def handle_call({:disconnect, participant_id, signal_pid, reason}, _from, state) do
    state =
      case participant_data(state, participant_id) do
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
    {:reply, {:ok, summary_payload(state)}, state}
  end

  defp reply_screen_share_state(state, participant_id, data, bucket, active?, screen_info) do
    current_media_state = normalize_media_state(data.participant.media_state)

    if active? == true and Map.get(current_media_state, "server_screen_blocked") == true do
      deny_screen_share(state)
    else
      persist_screen_share_state(
        state,
        participant_id,
        data,
        bucket,
        active?,
        screen_info,
        current_media_state
      )
    end
  end

  defp deny_screen_share(state) do
    reason = "Screen sharing was disabled by a moderator"
    telemetry(:screen_share, %{count: 1}, %{result: :denied, reason: reason})
    {:reply, {:error, reason}, state}
  end

  defp persist_screen_share_state(
         state,
         participant_id,
         data,
         bucket,
         active?,
         screen_info,
         current_media_state
       ) do
    active = active? == true

    media_state =
      current_media_state
      |> Map.put("screen", active)
      |> put_screen_media_metadata(active, screen_info)

    attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

    case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
      {:ok, participant} ->
        {state, payload} =
          state
          |> put_in([bucket, participant_id, :participant], participant)
          |> update_screen_share_success(
            participant_id,
            participant,
            media_state,
            screen_info,
            active,
            current_media_state
          )

        {:reply, {:ok, payload}, state}

      {:error, reason} ->
        telemetry(:screen_share, %{count: 1}, %{result: :error, reason: inspect(reason)})
        {:reply, {:error, reason}, state}
    end
  end

  defp update_screen_share_success(
         state,
         participant_id,
         participant,
         media_state,
         screen_info,
         active,
         previous_media_state
       ) do
    {state, track} = update_screen_share_track(state, participant_id, active, screen_info)
    state = update_tracks_for_media(state, participant_id, media_state)
    payload = screen_share_payload(participant_id, participant, active, track)

    state =
      maybe_record_screen_share_lifecycle(
        state,
        participant,
        previous_media_state,
        active
      )

    broadcast(state, "group_call_screen_share_state", payload)
    broadcast(state, "group_call_media_state", %{participant: participant_payload(participant)})
    telemetry(:screen_share, %{count: 1}, %{result: :ok, active: active})

    {state, payload}
  end

  defp screen_share_payload(participant_id, participant, active, track) do
    %{
      active: active,
      participant_id: participant_id,
      participant: participant_payload(participant),
      track: maybe_track_payload(track)
    }
  end

  defp set_participant_media(state, actor, participant_id, kind, enabled?)
       when kind in [:audio, :video] do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <-
           Policy.can_moderate_media?(
             membership,
             actor.nickname,
             data.participant.nickname
           ) do
      case update_moderated_participant_media(state, data, bucket, actor.nickname, kind, enabled?) do
        {:ok, state, participant} ->
          state =
            record_media_moderation_audit(state, actor.nickname, participant, kind, enabled?)

          telemetry(:media_moderated, %{count: 1}, %{
            result: :ok,
            kind: kind,
            enabled: enabled?
          })

          {:reply, {:ok, participant}, state}

        {:error, reason} ->
          telemetry(:media_moderated, %{count: 1}, %{
            result: :error,
            kind: kind,
            reason: inspect(reason)
          })

          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} = error ->
        telemetry(:media_moderated, %{count: 1}, %{
          result: :error,
          kind: kind,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  defp set_participant_screen_share_state(state, actor, participant_id, allowed?) do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         {:ok, membership} <- current_membership(state),
         :ok <-
           Policy.can_moderate_media?(
             membership,
             actor.nickname,
             data.participant.nickname
           ) do
      case update_moderated_participant_screen_share(
             state,
             data,
             bucket,
             actor.nickname,
             allowed?
           ) do
        {:ok, state, participant} ->
          state =
            record_screen_share_moderation_audit(state, actor.nickname, participant, allowed?)

          telemetry(:screen_share_moderated, %{count: 1}, %{
            result: :ok,
            allowed: allowed? == true
          })

          {:reply, {:ok, participant}, state}

        {:error, reason} ->
          telemetry(:screen_share_moderated, %{count: 1}, %{
            result: :error,
            reason: inspect(reason)
          })

          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} = error ->
        telemetry(:screen_share_moderated, %{count: 1}, %{
          result: :error,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  defp apply_all_participants_media(state, actor, kind, enabled?) when kind in [:audio, :video] do
    with {:ok, membership} <- current_membership(state),
         :ok <- Policy.can_close?(actor.nickname, state.room, membership) do
      participant_ids =
        state.participants
        |> Map.keys()
        |> Kernel.++(Map.keys(state.pending_participants))
        |> Enum.uniq()

      {state, changed, skipped_count} =
        Enum.reduce(participant_ids, {state, [], 0}, fn participant_id, acc ->
          moderate_bulk_participant(
            participant_id,
            acc,
            membership,
            actor.nickname,
            kind,
            enabled?
          )
        end)

      changed = Enum.reverse(changed)

      summary = %{
        kind: kind,
        enabled: enabled?,
        action: bulk_media_action(kind, enabled?),
        changed_count: length(changed),
        skipped_count: skipped_count,
        participants: Enum.map(changed, &participant_payload/1)
      }

      state = maybe_record_bulk_media_moderation_audit(state, actor.nickname, summary)

      telemetry(:media_moderated_bulk, %{count: summary.changed_count}, %{
        result: :ok,
        kind: kind,
        enabled: enabled?,
        skipped_count: skipped_count
      })

      {:reply, {:ok, summary}, state}
    else
      {:error, reason} = error ->
        telemetry(:media_moderated_bulk, %{count: 0}, %{
          result: :error,
          kind: kind,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  defp moderate_bulk_participant(
         participant_id,
         {state, changed, skipped_count},
         membership,
         actor_nickname,
         kind,
         enabled?
       ) do
    with {:ok, data, bucket} <- participant_data(state, participant_id),
         :ok <- Policy.can_moderate_media?(membership, actor_nickname, data.participant.nickname),
         {:ok, state, participant} <-
           update_moderated_participant_media(
             state,
             data,
             bucket,
             actor_nickname,
             kind,
             enabled?
           ) do
      {state, [participant | changed], skipped_count}
    else
      _skip -> {state, changed, skipped_count + 1}
    end
  end

  defp update_moderated_participant_media(state, data, bucket, actor_nickname, kind, enabled?) do
    update_participant_media_state(
      state,
      data,
      bucket,
      fn media_state ->
        put_server_media_moderation(media_state, kind, enabled?, actor_nickname)
      end,
      force_client?: true
    )
  end

  defp update_moderated_participant_screen_share(state, data, bucket, actor_nickname, allowed?) do
    update_participant_media_state(
      state,
      data,
      bucket,
      fn media_state -> put_server_screen_moderation(media_state, allowed?, actor_nickname) end,
      force_client?: true,
      after_update: fn state, participant, media_state ->
        if allowed? == false do
          send_channel_event(data.channel_pid, "group_call_stop_screen_share", %{
            reason: "moderation",
            server_screen_blocked: true
          })
        end

        {state, track} =
          if allowed? == false do
            update_screen_share_track(state, participant.id, false, %{})
          else
            {state, nil}
          end

        state = update_tracks_for_media(state, participant.id, media_state)

        broadcast(state, "group_call_screen_share_state", %{
          active: false,
          participant_id: participant.id,
          participant: participant_payload(participant),
          track: maybe_track_payload(track)
        })

        state
      end
    )
  end

  defp update_participant_media_state(state, data, bucket, update_fun, opts \\ []) do
    participant_id = data.participant.id

    media_state =
      data.participant.media_state
      |> normalize_media_state()
      |> update_fun.()

    attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

    case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
      {:ok, participant} ->
        state =
          state
          |> put_in([bucket, participant_id, :participant], participant)
          |> update_tracks_for_media(participant_id, media_state)

        if Keyword.get(opts, :force_client?, false) do
          send_channel_event(
            data.channel_pid,
            "group_call_set_media_state",
            forced_media_payload(media_state)
          )
        end

        state =
          case Keyword.get(opts, :after_update) do
            fun when is_function(fun, 3) -> fun.(state, participant, media_state)
            _none -> state
          end

        broadcast(state, "group_call_media_state", %{
          participant: participant_payload(participant)
        })

        {:ok, state, participant}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp can_set_hand_raised?(_state, %{nickname: actor_nickname}, %{nickname: nickname}, _raised?)
       when actor_nickname == nickname,
       do: :ok

  defp can_set_hand_raised?(state, actor, participant, false) do
    with {:ok, membership} <- current_membership(state) do
      Policy.can_moderate_media?(membership, actor.nickname, participant.nickname)
    end
  end

  defp can_set_hand_raised?(_state, _actor, _participant, true),
    do: {:error, "Cannot raise another participant's hand"}

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

        broadcast_channel_call_updated(state, "participant_joined")

        {:noreply, state}
    end
  end

  def handle_cast({:track_added, participant_id, track_info}, state) do
    case participant_data(state, participant_id) do
      {:ok, data, _bucket} ->
        source = source_for_track(track_info, data.participant)
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
          metadata: track_metadata(track_info),
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

  defp authorized_rejoin_participant(state, actor, participant_id)
       when is_integer(participant_id) do
    case participant_data(state, participant_id) do
      {:ok, %{participant: participant} = data, _bucket}
      when participant.registered_nick_id == actor.user_id ->
        normalized = String.downcase(actor.nickname)

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
      |> end_participant_tracks(participant_id, "rejoin")

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

      broadcast_channel_call_updated(state, reason)

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
    actor = Map.get(opts, :actor)

    telemetry(:room_closed, %{count: 1}, %{reason: reason})

    room_before_audit = state.room

    state =
      put_room_audit_event(state, :conference_ended, %{
        actor: actor,
        reason: reason
      })

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

  defp update_screen_share_track(state, participant_id, true, screen_info) do
    track =
      find_active_video_track(state, participant_id, "camera") ||
        find_active_video_track(state, participant_id, "screen")

    update_video_track_source(state, participant_id, track, "screen", screen_info)
  end

  defp update_screen_share_track(state, participant_id, false, screen_info) do
    track = find_active_video_track(state, participant_id, "screen")
    update_video_track_source(state, participant_id, track, "camera", screen_info)
  end

  defp find_active_video_track(state, participant_id, source) do
    state
    |> tracks_for_participant(participant_id)
    |> Enum.find(&(&1.kind == "video" and &1.source == source and &1.status != "ended"))
  end

  defp update_video_track_source(state, _participant_id, nil, _source, _screen_info),
    do: {state, nil}

  defp update_video_track_source(state, participant_id, track, source, screen_info) do
    now = DateTime.utc_now()

    attrs = %{
      source: source,
      status: "active",
      activated_at: now,
      muted_at: nil,
      metadata: screen_track_metadata(track, source, screen_info)
    }

    case Queries.update_track(track, attrs) do
      {:ok, updated} ->
        broadcast(state, "group_call_track_updated", %{
          track: track_payload(updated),
          participant_id: participant_id
        })

        {put_in(state, [:tracks, updated.id], updated), updated}

      {:error, reason} ->
        Logger.debug("Ignoring group call screen-share track source update",
          room_id: state.room.id,
          participant_id: participant_id,
          reason: inspect(reason)
        )

        {state, nil}
    end
  end

  defp screen_track_metadata(track, "screen", screen_info) do
    track
    |> existing_metadata()
    |> Map.merge(%{
      "screen_shared_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "screen_track_id" => clean_string(screen_info_value(screen_info, "track_id")),
      "screen_stream_id" => clean_string(screen_info_value(screen_info, "stream_id"))
    })
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp screen_track_metadata(track, _source, _screen_info) do
    track
    |> existing_metadata()
    |> Map.delete("screen_track_id")
    |> Map.delete("screen_stream_id")
  end

  defp existing_metadata(%{metadata: metadata}) when is_map(metadata), do: metadata
  defp existing_metadata(_track), do: %{}

  defp track_metadata(%{metadata: metadata}) when is_map(metadata), do: metadata
  defp track_metadata(_track_info), do: %{}

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
        summary: summary_payload(state)
      }
    })
  end

  defp put_room_audit_event(state, event_type, attrs) do
    attrs = Map.put_new(attrs, :channel, state.room.channel_name)
    metadata = Audit.append(state.room.metadata, event_type, attrs)
    %{state | room: %{state.room | metadata: metadata}}
  end

  defp record_group_call_audit(state, event_type, attrs) do
    attrs = Map.put_new(attrs, :channel, state.room.channel_name)
    metadata = Audit.append(state.room.metadata, event_type, attrs)

    case Queries.update_room_status(state.room, state.room.status, %{
           metadata: metadata,
           last_activity_at: DateTime.utc_now()
         }) do
      {:ok, room} ->
        event = Audit.last_event(room.metadata)
        broadcast_group_call_audit_event(room, event_type, event)
        %{state | room: room}

      {:error, reason} ->
        Logger.debug("Ignoring group call audit persistence error",
          room_id: state.room.id,
          event_type: event_type,
          reason: inspect(reason)
        )

        state
    end
  end

  defp broadcast_group_call_audit_event(room, action, event) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(room.channel_name), {
      :group_call_moderation,
      %{
        channel: room.channel_name,
        token: room.token,
        actor: Map.get(event || %{}, "actor"),
        target: Map.get(event || %{}, "target"),
        action: action,
        kind: Map.get(event || %{}, "kind"),
        changed_count: Map.get(event || %{}, "changed_count"),
        skipped_count: Map.get(event || %{}, "skipped_count"),
        event: event
      }
    })
  end

  defp maybe_record_screen_share_lifecycle(state, participant, previous_media_state, active?) do
    previous_active? = Map.get(previous_media_state, "screen", false) == true

    cond do
      active? and not previous_active? ->
        record_group_call_audit(state, :screen_share_started, %{
          actor: participant.nickname,
          target: participant.nickname,
          participant_id: participant.id
        })

      not active? and previous_active? ->
        record_group_call_audit(state, :screen_share_stopped, %{
          actor: participant.nickname,
          target: participant.nickname,
          participant_id: participant.id
        })

      true ->
        state
    end
  end

  defp record_media_moderation_audit(state, actor_nickname, participant, kind, enabled?) do
    action =
      case {kind, enabled? == true} do
        {:audio, false} -> :participant_muted
        {:audio, true} -> :participant_unmuted
        {:video, false} -> :participant_camera_blocked
        {:video, true} -> :participant_camera_unblocked
      end

    record_group_call_audit(state, action, %{
      actor: actor_nickname,
      target: participant.nickname,
      target_participant_id: participant.id,
      kind: kind
    })
  end

  defp record_screen_share_moderation_audit(state, actor_nickname, participant, allowed?) do
    action = if allowed? == true, do: :screen_share_unblocked, else: :screen_share_blocked

    record_group_call_audit(state, action, %{
      actor: actor_nickname,
      target: participant.nickname,
      target_participant_id: participant.id,
      kind: :screen
    })
  end

  defp maybe_record_bulk_media_moderation_audit(state, _actor_nickname, %{changed_count: 0}),
    do: state

  defp maybe_record_bulk_media_moderation_audit(state, actor_nickname, summary) do
    record_group_call_audit(state, summary.action, %{
      actor: actor_nickname,
      kind: summary.kind,
      changed_count: summary.changed_count,
      skipped_count: summary.skipped_count,
      metadata: %{
        participants: Enum.map(summary.participants, &Map.take(&1, [:id, :nickname]))
      }
    })
  end

  defp broadcast_lock_summary(room, actor_nickname, true) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(room.channel_name), {
      :group_call_moderation,
      %{
        channel: room.channel_name,
        token: room.token,
        actor: actor_nickname,
        action: :lock_call,
        changed_count: 1,
        skipped_count: 0,
        event: Audit.last_event(room.metadata)
      }
    })
  end

  defp broadcast_lock_summary(room, actor_nickname, false) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(room.channel_name), {
      :group_call_moderation,
      %{
        channel: room.channel_name,
        token: room.token,
        actor: actor_nickname,
        action: :unlock_call,
        changed_count: 1,
        skipped_count: 0,
        event: Audit.last_event(room.metadata)
      }
    })
  end

  defp update_room_lock(room, actor_nickname, locked?) do
    action = if locked? == true, do: :conference_locked, else: :conference_unlocked

    metadata =
      room.metadata
      |> normalize_room_metadata()
      |> Map.put("locked", locked? == true)
      |> Map.put("admission_locked", locked? == true)
      |> maybe_put_lock_actor(actor_nickname, locked?)
      |> Audit.append(action, %{
        actor: actor_nickname,
        channel: room.channel_name
      })

    Queries.update_room_status(room, room.status, %{metadata: metadata})
  end

  defp normalize_room_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_room_metadata(_metadata), do: %{}

  defp maybe_put_lock_actor(metadata, actor_nickname, true) do
    metadata
    |> Map.put("locked_by", actor_nickname)
    |> Map.put("locked_at", DateTime.utc_now() |> DateTime.to_iso8601())
  end

  defp maybe_put_lock_actor(metadata, _actor_nickname, false) do
    metadata
    |> Map.delete("locked_by")
    |> Map.delete("locked_at")
  end

  defp update_tracks_for_media(state, participant_id, media_state) do
    media_state = normalize_media_state(media_state)

    state
    |> tracks_for_participant(participant_id)
    |> Enum.reduce(state, fn track, acc ->
      update_track_for_media(track, acc, participant_id, media_state)
    end)
  end

  defp update_track_for_media(track, state, participant_id, media_state) do
    target_status = track_status_for_media(track, media_state)
    attrs = track_status_attrs(target_status)

    case Queries.update_track_status(track, target_status, attrs) do
      {:ok, updated} ->
        broadcast(state, "group_call_track_updated", %{
          track: track_payload(updated),
          participant_id: participant_id
        })

        put_in(state, [:tracks, updated.id], updated)

      {:error, reason} ->
        Logger.debug("Ignoring group call track state update error",
          room_id: state.room.id,
          participant_id: participant_id,
          reason: inspect(reason)
        )

        state
    end
  end

  defp track_status_for_media(%{kind: "audio"}, media_state) do
    if Map.get(media_state, "audio", true), do: "active", else: "muted"
  end

  defp track_status_for_media(%{kind: "video", source: "screen"}, media_state) do
    if Map.get(media_state, "screen", false), do: "active", else: "muted"
  end

  defp track_status_for_media(%{kind: "video"}, media_state) do
    if Map.get(media_state, "video", true), do: "active", else: "muted"
  end

  defp track_status_for_media(_track, _media_state), do: "active"

  defp track_status_attrs("muted"), do: %{muted_at: DateTime.utc_now()}
  defp track_status_attrs("active"), do: %{activated_at: DateTime.utc_now(), muted_at: nil}

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
            room_id: state.room.id,
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

  defp authorize_reaction_actor(%{user_id: user_id}, %{registered_nick_id: user_id}), do: :ok
  defp authorize_reaction_actor(_actor, _participant), do: {:error, :not_allowed}

  defp normalize_reaction(reaction) when is_binary(reaction) do
    reaction = String.trim(reaction)

    if reaction in @allowed_reactions do
      {:ok, reaction}
    else
      {:error, :invalid_reaction}
    end
  end

  defp normalize_reaction(_reaction), do: {:error, :invalid_reaction}

  defp reaction_payload(participant, reaction) do
    %{
      id: reaction_id(participant.id),
      participant_id: participant.id,
      nickname: participant.nickname,
      reaction: reaction,
      emoji: reaction_emoji(reaction),
      occurred_at_ms: System.os_time(:millisecond)
    }
  end

  defp reaction_id(participant_id) do
    unique = System.unique_integer([:positive])
    "#{participant_id}-#{System.os_time(:millisecond)}-#{unique}"
  end

  defp reaction_emoji("heart"), do: "❤️"
  defp reaction_emoji("thumbs_up"), do: "👍"
  defp reaction_emoji("clap"), do: "👏"
  defp reaction_emoji("laugh"), do: "😄"
  defp reaction_emoji("wow"), do: "✨"

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
        video_track_count: track_count(state, "video"),
        screen_track_count: screen_track_count(state)
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

  defp screen_track_count(state) do
    state.tracks
    |> Map.values()
    |> Enum.count(&(&1.kind == "video" and &1.source == "screen"))
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
      max_participants: room.max_participants,
      metadata: room.metadata,
      inserted_at: room.inserted_at,
      opened_at: room.opened_at,
      activated_at: room.activated_at
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
      stream_id: track.stream_id,
      metadata: existing_metadata(track)
    }
  end

  defp maybe_track_payload(nil), do: nil
  defp maybe_track_payload(track), do: track_payload(track)

  defp source_for_track(track_info, participant) do
    source =
      track_info
      |> Map.get(:source)
      |> normalize_source(track_info.kind)

    cond do
      is_binary(source) ->
        source

      track_info.kind == :video and
          normalize_media_state(participant.media_state)["screen"] == true ->
        "screen"

      true ->
        source_for_kind(track_info.kind)
    end
  end

  defp normalize_source(source, :audio) when source in ["microphone"], do: source
  defp normalize_source(source, :video) when source in ["camera", "screen"], do: source
  defp normalize_source(_source, _kind), do: nil

  defp source_for_kind(:audio), do: "microphone"
  defp source_for_kind(:video), do: "camera"

  defp normalize_media_state(media_state),
    do: normalize_media_state(media_state, %{"audio" => true, "video" => true})

  defp normalize_media_state(nil, fallback), do: fallback

  defp normalize_media_state(media_state, fallback) when is_map(media_state) do
    %{
      "audio" => media_value(media_state, "audio", Map.get(fallback, "audio", true)),
      "video" => media_value(media_state, "video", Map.get(fallback, "video", true)),
      "screen" => media_value(media_state, "screen", Map.get(fallback, "screen", false)),
      "hand_raised" =>
        media_value(media_state, "hand_raised", Map.get(fallback, "hand_raised", false))
    }
    |> maybe_put_extra(media_state, "server_audio_muted")
    |> maybe_put_extra(media_state, "muted_by")
    |> maybe_put_extra(media_state, "muted_at")
    |> maybe_put_extra(media_state, "server_video_blocked")
    |> maybe_put_extra(media_state, "video_blocked_by")
    |> maybe_put_extra(media_state, "video_blocked_at")
    |> maybe_put_extra(media_state, "server_screen_blocked")
    |> maybe_put_extra(media_state, "screen_blocked_by")
    |> maybe_put_extra(media_state, "screen_blocked_at")
    |> maybe_put_extra(media_state, "screen_track_id")
    |> maybe_put_extra(media_state, "screen_stream_id")
    |> maybe_put_extra(media_state, "hand_raised_at")
    |> maybe_put_extra(media_state, "hand_raised_by")
  end

  defp normalize_media_state(_media_state, fallback), do: fallback

  defp put_server_media_moderation(media_state, :audio, enabled?, actor_nickname) do
    Map.merge(media_state, %{
      "audio" => enabled?,
      "server_audio_muted" => !enabled?,
      "muted_by" => if(enabled?, do: nil, else: actor_nickname),
      "muted_at" => if(enabled?, do: nil, else: moderation_timestamp())
    })
  end

  defp put_server_media_moderation(media_state, :video, enabled?, actor_nickname) do
    Map.merge(media_state, %{
      "video" => enabled?,
      "server_video_blocked" => !enabled?,
      "video_blocked_by" => if(enabled?, do: nil, else: actor_nickname),
      "video_blocked_at" => if(enabled?, do: nil, else: moderation_timestamp())
    })
  end

  defp put_server_screen_moderation(media_state, true, _actor_nickname) do
    Map.merge(media_state, %{
      "server_screen_blocked" => false,
      "screen_blocked_by" => nil,
      "screen_blocked_at" => nil
    })
  end

  defp put_server_screen_moderation(media_state, false, actor_nickname) do
    media_state
    |> Map.merge(%{
      "screen" => false,
      "server_screen_blocked" => true,
      "screen_blocked_by" => actor_nickname,
      "screen_blocked_at" => moderation_timestamp()
    })
    |> Map.delete("screen_track_id")
    |> Map.delete("screen_stream_id")
  end

  defp moderation_timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp put_hand_raised(media_state, true, actor_nickname) do
    Map.merge(media_state, %{
      "hand_raised" => true,
      "hand_raised_at" => Map.get(media_state, "hand_raised_at") || moderation_timestamp(),
      "hand_raised_by" => actor_nickname
    })
  end

  defp put_hand_raised(media_state, false, _actor_nickname) do
    media_state
    |> Map.put("hand_raised", false)
    |> Map.delete("hand_raised_at")
    |> Map.delete("hand_raised_by")
  end

  defp forced_media_payload(media_state) do
    %{
      audio: Map.get(media_state, "audio", true),
      video: Map.get(media_state, "video", true),
      screen: Map.get(media_state, "screen", false),
      hand_raised: Map.get(media_state, "hand_raised") == true,
      server_audio_muted: Map.get(media_state, "server_audio_muted") == true,
      server_video_blocked: Map.get(media_state, "server_video_blocked") == true,
      server_screen_blocked: Map.get(media_state, "server_screen_blocked") == true
    }
  end

  defp bulk_media_action(:audio, false), do: :mute_all
  defp bulk_media_action(:video, false), do: :camera_off_all
  defp bulk_media_action(:audio, true), do: :unmute_all
  defp bulk_media_action(:video, true), do: :camera_on_all

  defp put_screen_media_metadata(media_state, true, screen_info) do
    media_state
    |> put_clean_media_string("screen_track_id", screen_info_value(screen_info, "track_id"))
    |> put_clean_media_string("screen_stream_id", screen_info_value(screen_info, "stream_id"))
  end

  defp put_screen_media_metadata(media_state, false, _screen_info) do
    media_state
    |> Map.delete("screen_track_id")
    |> Map.delete("screen_stream_id")
  end

  defp put_clean_media_string(media_state, key, value) do
    case clean_string(value) do
      nil -> media_state
      value -> Map.put(media_state, key, value)
    end
  end

  defp screen_info_value(screen_info, key) when is_map(screen_info) do
    Map.get(screen_info, key, Map.get(screen_info, String.to_existing_atom(key)))
  rescue
    ArgumentError -> Map.get(screen_info, key)
  end

  defp screen_info_value(_screen_info, _key), do: nil

  defp clean_string(value) when is_binary(value) and value != "", do: value
  defp clean_string(_value), do: nil

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
    media_state
    |> enforce_server_audio_policy(current_media_state)
    |> enforce_server_video_policy(current_media_state)
    |> enforce_server_screen_policy(current_media_state)
  end

  defp enforce_server_audio_policy(media_state, current_media_state) do
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

  defp enforce_server_video_policy(media_state, current_media_state) do
    if Map.get(current_media_state, "server_video_blocked") == true do
      media_state
      |> Map.put("video", false)
      |> Map.put("server_video_blocked", true)
      |> copy_current_media_extra(current_media_state, "video_blocked_by")
      |> copy_current_media_extra(current_media_state, "video_blocked_at")
    else
      media_state
    end
  end

  defp enforce_server_screen_policy(media_state, current_media_state) do
    if Map.get(current_media_state, "server_screen_blocked") == true do
      media_state
      |> Map.put("screen", false)
      |> Map.put("server_screen_blocked", true)
      |> copy_current_media_extra(current_media_state, "screen_blocked_by")
      |> copy_current_media_extra(current_media_state, "screen_blocked_at")
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
  defp media_atom_key("screen"), do: :screen
  defp media_atom_key("hand_raised"), do: :hand_raised
  defp media_atom_key("screen_track_id"), do: :screen_track_id
  defp media_atom_key("screen_stream_id"), do: :screen_stream_id
  defp media_atom_key("hand_raised_at"), do: :hand_raised_at
  defp media_atom_key("hand_raised_by"), do: :hand_raised_by
  defp media_atom_key("server_audio_muted"), do: :server_audio_muted
  defp media_atom_key("muted_by"), do: :muted_by
  defp media_atom_key("muted_at"), do: :muted_at
  defp media_atom_key("server_video_blocked"), do: :server_video_blocked
  defp media_atom_key("video_blocked_by"), do: :video_blocked_by
  defp media_atom_key("video_blocked_at"), do: :video_blocked_at
  defp media_atom_key("server_screen_blocked"), do: :server_screen_blocked
  defp media_atom_key("screen_blocked_by"), do: :screen_blocked_by
  defp media_atom_key("screen_blocked_at"), do: :screen_blocked_at
  defp media_atom_key(_key), do: nil

  defp telemetry(event, measurements, metadata) do
    :telemetry.execute([:retro_hex_chat, :group_call, event], measurements, metadata)
  end

  defp membership_from_channel_state(%{members: members}) do
    Enum.reduce(members, Membership.new(), fn {nickname, role}, membership ->
      Membership.add(membership, nickname, role)
    end)
  end
end
