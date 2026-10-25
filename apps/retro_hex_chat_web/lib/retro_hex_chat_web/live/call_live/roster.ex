defmodule RetroHexChatWeb.CallLive.Roster do
  @moduledoc """
  Who and what is in the conference, as this page holds it in the call map:
  participants and their media, tracks, connection quality and reactions,
  merged from the room's summaries and the browser's reports. Pure functions
  of the call map.
  """

  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.App.GroupCallSummary
  alias RetroHexChatWeb.CallLive.Layout
  alias RetroHexChatWeb.Params

  @doc "Adds or replaces a participant; for this page's own, also takes its media and channel role into the call."
  @spec put_self_participant(map(), map()) :: map()
  def put_self_participant(call, %{id: id, media_state: media} = participant)
      when id == call.participant_id do
    call
    |> put_participant(participant)
    |> Map.put(:media, media)
    |> Map.put(:self_role, participant.channel_role_snapshot || call[:self_role])
  end

  def put_self_participant(call, participant), do: put_participant(call, participant)

  @doc "Whether this page's own participant has a hand up."
  @spec self_hand_raised?(map()) :: boolean()
  def self_hand_raised?(call) do
    case self_participant(call) do
      nil -> Map.get(call.media || %{}, :hand_raised) == true
      participant -> participant_hand_raised?(participant)
    end
  end

  defp self_participant(%{participant_id: participant_id, participants: participants}) do
    Enum.find(participants || [], &(&1.id == participant_id))
  end

  defp self_participant(_call), do: nil

  defp participant_hand_raised?(%{media_state: media}) when is_map(media),
    do: Map.get(media, :hand_raised) == true

  defp participant_hand_raised?(_participant), do: false

  @doc "The call with the room's summary taken in: the participants and pending ones replaced, the room, tracks and server stats kept where the summary has none, and the nick locales refreshed."
  @spec merge_summary(map(), map()) :: map()
  def merge_summary(call, payload) do
    call
    |> Map.put(
      :room,
      GroupCallShape.normalize_room(GroupCallShape.value(payload, :room) || call.room)
    )
    |> Map.put(
      :participants,
      GroupCallShape.normalize_participants(GroupCallShape.value(payload, :participants))
    )
    |> Map.put(
      :pending_participants,
      GroupCallShape.normalize_participants(GroupCallShape.value(payload, :pending_participants))
    )
    |> Map.put(
      :tracks,
      GroupCallShape.normalize_tracks(GroupCallShape.value(payload, :tracks) || call.tracks)
    )
    |> Map.put(
      :server_stats,
      GroupCallShape.normalize_server_stats(
        GroupCallShape.value(payload, :server_stats) || call.server_stats
      )
    )
    |> GroupCallSummary.put_nick_locales()
  end

  @doc "Marks the call connected once this page's own participant shows up as joined."
  @spec maybe_mark_connected(map(), map()) :: map()
  def maybe_mark_connected(call, %{id: id}) when id == call.participant_id do
    %{call | status: :connected}
  end

  def maybe_mark_connected(call, _participant), do: call

  @doc "Adds or replaces a participant, keeping the list ordered by id."
  @spec put_participant(map(), map()) :: map()
  def put_participant(call, %{id: nil}), do: call

  def put_participant(call, participant) do
    participants =
      call.participants
      |> Enum.reject(&(&1.id == participant.id))
      |> Kernel.++([participant])
      |> Enum.sort_by(& &1.id)

    GroupCallSummary.put_nick_locales(%{call | participants: participants})
  end

  @doc "A participant update with the media state already known for them kept where the update says nothing."
  @spec merge_existing_participant_media(map(), map()) :: map()
  def merge_existing_participant_media(%{id: nil} = participant, _call), do: participant

  def merge_existing_participant_media(
        %{id: participant_id, media_state: media} = participant,
        call
      ) do
    existing =
      Enum.find(call.participants || [], &(&1.id == participant_id))

    existing_media =
      case existing do
        %{media_state: existing_media} when is_map(existing_media) -> existing_media
        _missing -> %{}
      end

    %{participant | media_state: Map.merge(existing_media, media)}
  end

  @doc "Drops a participant, their quality and reactions, unpinning and unfocusing them."
  @spec remove_participant(map(), integer()) :: map()
  def remove_participant(call, participant_id) do
    call = %{call | participants: Enum.reject(call.participants, &(&1.id == participant_id))}
    call = remove_participant_quality(call, participant_id)
    call = remove_participant_reactions(call, participant_id)
    layout = Layout.remove_pinned_participant(Layout.layout(call), participant_id)

    if layout.focused_participant_id == participant_id do
      %{call | layout: %{layout | focused_participant_id: nil, mode: :auto}}
    else
      %{call | layout: layout}
    end
  end

  @doc "Drops a track."
  @spec remove_track(map(), integer()) :: map()
  def remove_track(call, track_id) do
    %{call | tracks: Enum.reject(call.tracks, &(&1.id == track_id))}
  end

  @doc "Adds or replaces a track; one without an id (none was sent) leaves the call as it is."
  @spec put_track(map(), map()) :: map()
  def put_track(call, %{id: nil}), do: call

  def put_track(call, track) do
    tracks =
      call.tracks
      |> Enum.reject(&(&1.id == track.id))
      |> Kernel.++([track])
      |> Enum.sort_by(& &1.id)

    %{call | tracks: tracks}
  end

  @doc "Takes in the browser's report of connection quality and the active speaker, for participants still in the call, and keeps the speaker focus in step."
  @spec put_participant_quality(map(), map()) :: map()
  def put_participant_quality(call, payload) do
    valid_ids =
      call.participants
      |> Enum.map(& &1.id)
      |> MapSet.new()

    incoming =
      payload
      |> GroupCallShape.value(:participants)
      |> List.wrap()
      |> Enum.map(&GroupCallShape.normalize_participant_quality/1)
      |> Enum.reject(&is_nil(&1.participant_id))
      |> Enum.map(&{&1.participant_id, &1})
      |> Map.new()

    existing = Map.get(call, :participant_quality) || GroupCallShape.empty_participant_quality()

    by_participant =
      existing.by_participant
      |> Map.merge(incoming)
      |> Map.filter(fn {participant_id, _quality} ->
        MapSet.member?(valid_ids, participant_id)
      end)

    active_speaker_id =
      Params.integer(GroupCallShape.value(payload, :active_speaker_participant_id))

    active_speaker_id =
      if MapSet.member?(valid_ids, active_speaker_id), do: active_speaker_id, else: nil

    call =
      Map.put(call, :participant_quality, %{
        active_speaker_participant_id: active_speaker_id,
        by_participant: by_participant
      })

    Layout.maybe_sync_speaker_focus(call)
  end

  defp remove_participant_quality(call, participant_id) do
    quality = Map.get(call, :participant_quality) || GroupCallShape.empty_participant_quality()
    by_participant = Map.delete(quality.by_participant, participant_id)

    active_speaker_id =
      if quality.active_speaker_participant_id == participant_id,
        do: nil,
        else: quality.active_speaker_participant_id

    Map.put(call, :participant_quality, %{
      active_speaker_participant_id: active_speaker_id,
      by_participant: by_participant
    })
  end

  defp remove_participant_reactions(call, participant_id) do
    Map.update(call, :reactions, [], fn reactions ->
      Enum.reject(reactions || [], &(&1.participant_id == participant_id))
    end)
  end

  @doc "Shows a participant's reaction in place of their previous one, keeping the latest eight."
  @spec put_group_call_reaction(map(), map()) :: map()
  def put_group_call_reaction(call, payload) do
    reaction = GroupCallShape.normalize_group_call_reaction(call, payload)

    if is_nil(reaction.participant_id) do
      call
    else
      reactions =
        call
        |> Map.get(:reactions, [])
        |> Enum.reject(&(&1.participant_id == reaction.participant_id))

      Map.put(call, :reactions, Enum.take([reaction | reactions], 8))
    end
  end

  @doc "Marks a participant as sharing their screen or not, this page's own media included."
  @spec put_screen_share_media(map(), integer(), boolean()) :: map()
  def put_screen_share_media(call, participant_id, active?) do
    call =
      if call.participant_id == participant_id do
        Map.update(call, :media, %{screen: active?}, &Map.put(&1, :screen, active?))
      else
        call
      end

    update_in(call.participants, fn participants ->
      Enum.map(participants || [], fn
        %{id: id, media_state: media_state} = participant when id == participant_id ->
          %{participant | media_state: Map.put(media_state || %{}, :screen, active?)}

        participant ->
          participant
      end)
    end)
  end
end
