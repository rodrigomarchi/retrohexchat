defmodule RetroHexChat.GroupCall.RoomModeration do
  @moduledoc """
  Changes to a group-call participant's media: their own screen share, and a
  moderator's hold on one participant's or everyone's audio, video and screen.
  Each change is persisted, applied to the tracks, told to the room and
  audited; the room process calls these from `handle_call`.
  """

  alias RetroHexChat.GroupCall.{
    MediaState,
    Policy,
    Queries,
    RoomAudit,
    RoomFanout,
    RoomPayload,
    RoomServer,
    RoomState,
    RoomTracks
  }

  alias RetroHexChat.GroupCall.Schema.Participant

  @doc "Turns the participant's own screen share on or off, unless a moderator blocked it; replies for `handle_call`."
  @spec set_screen_share(RoomServer.state(), integer(), map(), atom(), boolean(), map() | nil) ::
          {:reply, term(), RoomServer.state()}
  def set_screen_share(state, participant_id, data, bucket, active?, screen_info) do
    current_media_state = MediaState.normalize(data.participant.media_state)

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
    RoomState.telemetry(:screen_share, %{count: 1}, %{result: :denied, reason: reason})
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
      |> MediaState.put_screen_metadata(active, screen_info)

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
        RoomState.telemetry(:screen_share, %{count: 1}, %{result: :error, reason: inspect(reason)})

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
    {state, track} = RoomTracks.update_screen_share(state, participant_id, active, screen_info)
    state = RoomTracks.update_for_media(state, participant_id, media_state)
    payload = screen_share_payload(participant_id, participant, active, track)

    state =
      RoomAudit.record_screen_share_lifecycle(
        state,
        participant,
        previous_media_state,
        active
      )

    RoomFanout.broadcast(state, "group_call_screen_share_state", payload)

    RoomFanout.broadcast(state, "group_call_media_state", %{
      participant: RoomPayload.participant(participant)
    })

    RoomState.telemetry(:screen_share, %{count: 1}, %{result: :ok, active: active})

    {state, payload}
  end

  defp screen_share_payload(participant_id, participant, active, track) do
    %{
      active: active,
      participant_id: participant_id,
      participant: RoomPayload.participant(participant),
      track: RoomPayload.maybe_track(track)
    }
  end

  @doc "A moderator turns one participant's audio or video on or off; replies for `handle_call`."
  @spec set_participant_media(RoomServer.state(), map(), integer(), :audio | :video, boolean()) ::
          {:reply, term(), RoomServer.state()}
  def set_participant_media(state, actor, participant_id, kind, enabled?)
      when kind in [:audio, :video] do
    with {:ok, data, bucket} <- RoomState.participant_data(state, participant_id),
         {:ok, membership} <- RoomState.current_membership(state),
         :ok <-
           Policy.can_moderate_media?(
             membership,
             actor.nickname,
             data.participant.nickname
           ) do
      case update_moderated_participant_media(state, data, bucket, actor.nickname, kind, enabled?) do
        {:ok, state, participant} ->
          state =
            RoomAudit.record_media_moderation(state, actor.nickname, participant, kind, enabled?)

          RoomState.telemetry(:media_moderated, %{count: 1}, %{
            result: :ok,
            kind: kind,
            enabled: enabled?
          })

          {:reply, {:ok, participant}, state}

        {:error, reason} ->
          RoomState.telemetry(:media_moderated, %{count: 1}, %{
            result: :error,
            kind: kind,
            reason: inspect(reason)
          })

          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} = error ->
        RoomState.telemetry(:media_moderated, %{count: 1}, %{
          result: :error,
          kind: kind,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  @doc "A moderator allows or blocks one participant's screen share; replies for `handle_call`."
  @spec set_participant_screen_share(RoomServer.state(), map(), integer(), boolean()) ::
          {:reply, term(), RoomServer.state()}
  def set_participant_screen_share(state, actor, participant_id, allowed?) do
    with {:ok, data, bucket} <- RoomState.participant_data(state, participant_id),
         {:ok, membership} <- RoomState.current_membership(state),
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
            RoomAudit.record_screen_share_moderation(state, actor.nickname, participant, allowed?)

          RoomState.telemetry(:screen_share_moderated, %{count: 1}, %{
            result: :ok,
            allowed: allowed? == true
          })

          {:reply, {:ok, participant}, state}

        {:error, reason} ->
          RoomState.telemetry(:screen_share_moderated, %{count: 1}, %{
            result: :error,
            reason: inspect(reason)
          })

          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} = error ->
        RoomState.telemetry(:screen_share_moderated, %{count: 1}, %{
          result: :error,
          reason: inspect(reason)
        })

        {:reply, error, state}
    end
  end

  @doc "A moderator turns everyone's audio or video on or off, skipping whom they may not moderate; replies for `handle_call`."
  @spec set_all_media(RoomServer.state(), map(), :audio | :video, boolean()) ::
          {:reply, term(), RoomServer.state()}
  def set_all_media(state, actor, kind, enabled?) when kind in [:audio, :video] do
    with {:ok, membership} <- RoomState.current_membership(state),
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
        participants: Enum.map(changed, &RoomPayload.participant/1)
      }

      state = RoomAudit.record_bulk_media_moderation(state, actor.nickname, summary)

      RoomState.telemetry(:media_moderated_bulk, %{count: summary.changed_count}, %{
        result: :ok,
        kind: kind,
        enabled: enabled?,
        skipped_count: skipped_count
      })

      {:reply, {:ok, summary}, state}
    else
      {:error, reason} = error ->
        RoomState.telemetry(:media_moderated_bulk, %{count: 0}, %{
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
    with {:ok, data, bucket} <- RoomState.participant_data(state, participant_id),
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
    update_media_state(
      state,
      data,
      bucket,
      fn media_state ->
        MediaState.put_server_moderation(media_state, kind, enabled?, actor_nickname)
      end,
      force_client?: true
    )
  end

  defp update_moderated_participant_screen_share(state, data, bucket, actor_nickname, allowed?) do
    update_media_state(
      state,
      data,
      bucket,
      fn media_state ->
        MediaState.put_server_screen_moderation(media_state, allowed?, actor_nickname)
      end,
      force_client?: true,
      after_update: fn state, participant, media_state ->
        if allowed? == false do
          RoomFanout.send_channel_event(data.channel_pid, "group_call_stop_screen_share", %{
            reason: "moderation",
            server_screen_blocked: true
          })
        end

        {state, track} =
          if allowed? == false do
            RoomTracks.update_screen_share(state, participant.id, false, %{})
          else
            {state, nil}
          end

        state = RoomTracks.update_for_media(state, participant.id, media_state)

        RoomFanout.broadcast(state, "group_call_screen_share_state", %{
          active: false,
          participant_id: participant.id,
          participant: RoomPayload.participant(participant),
          track: RoomPayload.maybe_track(track)
        })

        state
      end
    )
  end

  @doc """
  Applies `update_fun` to the participant's media state, persists it, updates
  its tracks and tells the room. `force_client?: true` also pushes the new state
  to the participant; `after_update:` runs before the room is told.
  """
  @spec update_media_state(RoomServer.state(), map(), atom(), (map() -> map()), keyword()) ::
          {:ok, RoomServer.state(), Participant.t()} | {:error, term()}
  def update_media_state(state, data, bucket, update_fun, opts \\ []) do
    participant_id = data.participant.id

    media_state =
      data.participant.media_state
      |> MediaState.normalize()
      |> update_fun.()

    attrs = %{media_state: media_state, last_seen_at: DateTime.utc_now()}

    case Queries.update_participant_status(data.participant, data.participant.status, attrs) do
      {:ok, participant} ->
        state =
          state
          |> put_in([bucket, participant_id, :participant], participant)
          |> RoomTracks.update_for_media(participant_id, media_state)

        if Keyword.get(opts, :force_client?, false) do
          RoomFanout.send_channel_event(
            data.channel_pid,
            "group_call_set_media_state",
            MediaState.forced_payload(media_state)
          )
        end

        state =
          case Keyword.get(opts, :after_update) do
            fun when is_function(fun, 3) -> fun.(state, participant, media_state)
            _none -> state
          end

        RoomFanout.broadcast(state, "group_call_media_state", %{
          participant: RoomPayload.participant(participant)
        })

        {:ok, state, participant}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Anyone may raise or lower their own hand; a moderator may only lower another's."
  @spec can_set_hand_raised?(RoomServer.state(), map(), map(), boolean()) ::
          :ok | {:error, term()}
  def can_set_hand_raised?(_state, %{nickname: actor_nickname}, %{nickname: nickname}, _raised?)
      when actor_nickname == nickname,
      do: :ok

  def can_set_hand_raised?(state, actor, participant, false) do
    with {:ok, membership} <- RoomState.current_membership(state) do
      Policy.can_moderate_media?(membership, actor.nickname, participant.nickname)
    end
  end

  def can_set_hand_raised?(_state, _actor, _participant, true),
    do: {:error, "Cannot raise another participant's hand"}

  defp bulk_media_action(:audio, false), do: :mute_all

  defp bulk_media_action(:video, false), do: :camera_off_all

  defp bulk_media_action(:audio, true), do: :unmute_all

  defp bulk_media_action(:video, true), do: :camera_on_all
end
