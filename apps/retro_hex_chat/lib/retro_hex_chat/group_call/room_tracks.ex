defmodule RetroHexChat.GroupCall.RoomTracks do
  @moduledoc """
  The published tracks of a group-call room: activating, muting, moving
  between camera and screen, and ending them — in the database, in the room's
  state, and announced to its members.
  """

  require Logger

  alias RetroHexChat.GroupCall.{MediaState, Queries, RoomFanout, RoomPayload, RoomServer}
  alias RetroHexChat.GroupCall.Schema.{Participant, Track}

  @doc "Activates the participant's track for `kind` and `source`, inserting it when there is none."
  @spec upsert_active(integer(), integer(), atom(), String.t(), map()) ::
          {:ok, Track.t()} | {:error, term()}
  def upsert_active(room_id, participant_id, kind, source, attrs) do
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

  @doc "Moves the participant's video track to the screen source, or back to the camera, and tells the room."
  @spec update_screen_share(RoomServer.state(), integer(), boolean(), map() | nil) ::
          {RoomServer.state(), Track.t() | nil}
  def update_screen_share(state, participant_id, true, screen_info) do
    track =
      find_active_video_track(state, participant_id, "camera") ||
        find_active_video_track(state, participant_id, "screen")

    update_video_track_source(state, participant_id, track, "screen", screen_info)
  end

  def update_screen_share(state, participant_id, false, screen_info) do
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
        RoomFanout.broadcast(state, "group_call_track_updated", %{
          track: RoomPayload.track(updated),
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
      "screen_track_id" => MediaState.screen_value(screen_info, "track_id"),
      "screen_stream_id" => MediaState.screen_value(screen_info, "stream_id")
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

  @doc "A published track's metadata map, empty when it carries none."
  @spec metadata_of(map()) :: map()
  def metadata_of(%{metadata: metadata}) when is_map(metadata), do: metadata

  def metadata_of(_track_info), do: %{}

  @doc "Mutes or reactivates each of the participant's tracks to match its media state, and tells the room."
  @spec update_for_media(RoomServer.state(), integer(), map()) :: RoomServer.state()
  def update_for_media(state, participant_id, media_state) do
    media_state = MediaState.normalize(media_state)

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
        RoomFanout.broadcast(state, "group_call_track_updated", %{
          track: RoomPayload.track(updated),
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

  @doc "Ends every track of the participant and tells the room."
  @spec end_for_participant(RoomServer.state(), integer(), String.t()) :: RoomServer.state()
  def end_for_participant(state, participant_id, reason) do
    state
    |> tracks_for_participant(participant_id)
    |> Enum.reduce(state, fn track, acc ->
      case Queries.update_track_status(track, "ended", %{
             ended_at: DateTime.utc_now(),
             ended_reason: reason
           }) do
        {:ok, ended} ->
          RoomFanout.broadcast(acc, "group_call_track_removed", %{track_id: ended.id})
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

  @doc "Ends every track in the room, as it closes."
  @spec end_all(RoomServer.state(), String.t()) :: RoomServer.state()
  def end_all(state, reason) do
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

  @doc "Which source a newly published track comes from: what it says, else the screen while sharing, else the kind's own."
  @spec source_for(map(), Participant.t()) :: String.t()
  def source_for(track_info, participant) do
    source =
      track_info
      |> Map.get(:source)
      |> normalize_source(track_info.kind)

    cond do
      is_binary(source) ->
        source

      track_info.kind == :video and
          MediaState.normalize(participant.media_state)["screen"] == true ->
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
end
