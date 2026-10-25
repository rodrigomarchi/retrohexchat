defmodule RetroHexChat.GroupCall.RoomAudit do
  @moduledoc """
  The audit trail of a group-call room — screen shares, moderation, locking —
  appended to the room's metadata through `RetroHexChat.GroupCall.Audit`,
  persisted, and told to the channel on its calls topic.
  """

  require Logger

  alias RetroHexChat.GroupCall.{Audit, Queries, RoomServer}
  alias RetroHexChat.GroupCall.Schema.{Participant, Room}
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

  @doc "Appends an audit event to the room's metadata in its state only."
  @spec put_event(RoomServer.state(), atom(), map()) :: RoomServer.state()
  def put_event(state, event_type, attrs) do
    attrs = Map.put_new(attrs, :channel, state.room.channel_name)
    metadata = Audit.append(state.room.metadata, event_type, attrs)
    %{state | room: %{state.room | metadata: metadata}}
  end

  @doc "Appends an audit event, persists the room's metadata and tells the channel; a failed write leaves the state as it was."
  @spec record(RoomServer.state(), atom(), map()) :: RoomServer.state()
  def record(state, event_type, attrs) do
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

  @doc "Records a screen share starting or stopping, when `active?` differs from the previous media state."
  @spec record_screen_share_lifecycle(RoomServer.state(), Participant.t(), map(), boolean()) ::
          RoomServer.state()
  def record_screen_share_lifecycle(state, participant, previous_media_state, active?) do
    previous_active? = Map.get(previous_media_state, "screen", false) == true

    cond do
      active? and not previous_active? ->
        record(state, :screen_share_started, %{
          actor: participant.nickname,
          target: participant.nickname,
          participant_id: participant.id
        })

      not active? and previous_active? ->
        record(state, :screen_share_stopped, %{
          actor: participant.nickname,
          target: participant.nickname,
          participant_id: participant.id
        })

      true ->
        state
    end
  end

  @doc "Records a moderator turning a participant's audio or video on or off."
  @spec record_media_moderation(
          RoomServer.state(),
          String.t(),
          Participant.t(),
          :audio | :video,
          boolean()
        ) :: RoomServer.state()
  def record_media_moderation(state, actor_nickname, participant, kind, enabled?) do
    action =
      case {kind, enabled? == true} do
        {:audio, false} -> :participant_muted
        {:audio, true} -> :participant_unmuted
        {:video, false} -> :participant_camera_blocked
        {:video, true} -> :participant_camera_unblocked
      end

    record(state, action, %{
      actor: actor_nickname,
      target: participant.nickname,
      target_participant_id: participant.id,
      kind: kind
    })
  end

  @doc "Records a moderator allowing or blocking a participant's screen share."
  @spec record_screen_share_moderation(RoomServer.state(), String.t(), Participant.t(), boolean()) ::
          RoomServer.state()
  def record_screen_share_moderation(state, actor_nickname, participant, allowed?) do
    action = if allowed? == true, do: :screen_share_unblocked, else: :screen_share_blocked

    record(state, action, %{
      actor: actor_nickname,
      target: participant.nickname,
      target_participant_id: participant.id,
      kind: :screen
    })
  end

  @doc "Records a moderator's change to everyone's media, unless it changed nobody."
  @spec record_bulk_media_moderation(RoomServer.state(), String.t(), map()) :: RoomServer.state()
  def record_bulk_media_moderation(state, _actor_nickname, %{changed_count: 0}),
    do: state

  def record_bulk_media_moderation(state, actor_nickname, summary) do
    record(state, summary.action, %{
      actor: actor_nickname,
      kind: summary.kind,
      changed_count: summary.changed_count,
      skipped_count: summary.skipped_count,
      metadata: %{
        participants: Enum.map(summary.participants, &Map.take(&1, [:id, :nickname]))
      }
    })
  end

  @doc "Tells the channel the call was locked or unlocked."
  @spec broadcast_lock(Room.t(), String.t(), boolean()) :: :ok | {:error, term()}
  def broadcast_lock(room, actor_nickname, locked?) do
    Phoenix.PubSub.broadcast(@pubsub, Topics.channel_calls(room.channel_name), {
      :group_call_moderation,
      %{
        channel: room.channel_name,
        token: room.token,
        actor: actor_nickname,
        action: if(locked?, do: :lock_call, else: :unlock_call),
        changed_count: 1,
        skipped_count: 0,
        event: Audit.last_event(room.metadata)
      }
    })
  end

  @doc "Persists the room locked or unlocked, with who did it, and records it."
  @spec update_lock(Room.t(), String.t(), boolean()) :: {:ok, Room.t()} | {:error, term()}
  def update_lock(room, actor_nickname, locked?) do
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
end
