defmodule RetroHexChatWeb.App.GroupCallShape do
  @moduledoc """
  The shapes a group call's payloads take once they are inside a LiveView.

  A room, a participant, a track and a set of stats each arrive from three
  places — a database row, a PubSub broadcast, and a browser hook — and each
  spells its fields differently: a struct with atom keys, a map with string
  keys, a partial update with neither. Every reader used to cope with that on
  its own, which is why `value/2` tries both spellings.

  These functions decide nothing and touch no socket. They were private to the
  chat's group-call adapter, which meant the surface that will host a call in
  its own tab could not use them without copying, and it also meant the most
  reused code in the feature had no tests of its own.

  A field the source did not carry becomes `nil` rather than being left out:
  every reader here renders, and a renderer distinguishes "absent" from
  "unknown" nowhere.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.App.GroupCallStats
  alias RetroHexChatWeb.MediaDevices

  @spec normalize_room(map() | nil) :: map() | nil
  def normalize_room(nil), do: nil

  def normalize_room(room) when is_map(room) do
    %{
      id: value(room, :id),
      token: value(room, :token),
      channel_name: value(room, :channel_name),
      status: value(room, :status),
      max_participants: value(room, :max_participants),
      metadata: value(room, :metadata) || %{},
      inserted_at: value(room, :inserted_at),
      opened_at: value(room, :opened_at),
      activated_at: value(room, :activated_at)
    }
  end

  @spec normalize_participants(list() | nil) :: [map()]
  def normalize_participants(nil), do: []
  def normalize_participants(participants), do: Enum.map(participants, &normalize_participant/1)
  @spec normalize_participant(map() | nil) :: map()
  def normalize_participant(nil) do
    %{id: nil, nickname: nil, status: nil, media_state: %{}, channel_role_snapshot: nil}
  end

  def normalize_participant(participant) when is_map(participant) do
    %{
      id: normalize_id(value(participant, :id)),
      nickname: value(participant, :nickname),
      status: value(participant, :status),
      media_state: normalize_media(value(participant, :media_state)),
      channel_role_snapshot: value(participant, :channel_role_snapshot)
    }
  end

  @spec normalize_tracks(list() | nil) :: [map()]
  def normalize_tracks(nil), do: []
  def normalize_tracks(tracks), do: Enum.map(tracks, &normalize_track/1)
  @spec normalize_track(map() | nil) :: map()
  def normalize_track(nil) do
    %{id: nil, participant_id: nil, kind: nil, source: nil, status: nil}
  end

  def normalize_track(track) when is_map(track) do
    %{
      id: normalize_id(value(track, :id)),
      participant_id: normalize_id(value(track, :participant_id)),
      kind: value(track, :kind),
      source: value(track, :source),
      status: value(track, :status),
      webrtc_track_id: value(track, :webrtc_track_id),
      stream_id: value(track, :stream_id)
    }
  end

  @spec normalize_server_stats(map() | nil) :: map()
  def normalize_server_stats(nil), do: GroupCallStats.empty_server()
  def normalize_server_stats(stats), do: GroupCallStats.normalize_server(stats)
  @spec empty_participant_quality() :: map()
  def empty_participant_quality do
    %{active_speaker_participant_id: nil, by_participant: %{}}
  end

  @spec empty_recovery() :: map()
  def empty_recovery do
    %{
      state: nil,
      reason: nil,
      trigger: nil,
      attempt: 0,
      max_attempts: 0,
      next_retry_ms: 0,
      manual_retry: false,
      message: nil
    }
  end

  @spec normalize_recovery(map() | nil) :: map()
  def normalize_recovery(payload) when is_map(payload) do
    %{
      state: normalize_recovery_state(value(payload, :state)),
      reason: value(payload, :reason),
      trigger: value(payload, :trigger),
      attempt: integer_value(value(payload, :attempt)),
      max_attempts: integer_value(value(payload, :max_attempts)),
      next_retry_ms: integer_value(value(payload, :next_retry_ms)),
      manual_retry: truthy?(value(payload, :manual_retry)),
      message: value(payload, :message)
    }
  end

  def normalize_recovery(_payload), do: empty_recovery()
  @spec normalize_recovery_state(term()) :: atom()
  def normalize_recovery_state(value) do
    case to_string(value) do
      "connected" -> :connected
      "connecting" -> :connecting
      "reconnecting" -> :reconnecting
      "rejoining" -> :rejoining
      "negotiating" -> :negotiating
      "failed" -> :failed
      "degraded" -> :degraded
      _other -> nil
    end
  end

  @spec normalize_group_call_reaction(map(), map() | nil) :: map() | nil
  def normalize_group_call_reaction(call, payload) when is_map(payload) do
    participant_id = normalize_id(value(payload, :participant_id))
    participant = Enum.find(call.participants || [], &(&1.id == participant_id))

    %{
      id: value(payload, :id) || "reaction-#{System.unique_integer([:positive])}",
      participant_id: if(participant, do: participant_id),
      nickname: value(payload, :nickname) || participant_nickname(participant),
      reaction: value(payload, :reaction) || "heart",
      emoji: value(payload, :emoji) || reaction_emoji(value(payload, :reaction)),
      occurred_at_ms: integer_value(value(payload, :occurred_at_ms))
    }
  end

  def normalize_group_call_reaction(_call, _payload) do
    %{
      id: nil,
      participant_id: nil,
      nickname: nil,
      reaction: nil,
      emoji: nil,
      occurred_at_ms: 0
    }
  end

  @spec reaction_emoji(term()) :: String.t() | nil
  def reaction_emoji("heart"), do: "❤️"
  def reaction_emoji("thumbs_up"), do: "👍"
  def reaction_emoji("clap"), do: "👏"
  def reaction_emoji("laugh"), do: "😄"
  def reaction_emoji("wow"), do: "✨"
  def reaction_emoji(_reaction), do: "❤️"
  @spec normalize_participant_quality(map() | nil) :: map()
  def normalize_participant_quality(nil) do
    %{
      participant_id: nil,
      level: :unknown,
      speaking: false,
      rtt_ms: 0,
      jitter_ms: 0,
      loss_pct: 0,
      bitrate_kbps: 0,
      fps: 0,
      freeze_count: 0,
      audio_level: 0
    }
  end

  def normalize_participant_quality(quality) when is_map(quality) do
    %{
      participant_id: normalize_id(value(quality, :participant_id)),
      level: normalize_quality_level(value(quality, :level)),
      speaking: truthy?(value(quality, :speaking)),
      rtt_ms: integer_value(value(quality, :rtt_ms)),
      jitter_ms: integer_value(value(quality, :jitter_ms)),
      loss_pct: float_value(value(quality, :loss_pct)),
      bitrate_kbps: integer_value(value(quality, :bitrate_kbps)),
      fps: integer_value(value(quality, :fps)),
      freeze_count: integer_value(value(quality, :freeze_count)),
      audio_level: float_value(value(quality, :audio_level))
    }
  end

  def normalize_participant_quality(_quality), do: normalize_participant_quality(nil)
  @spec normalize_quality_level(term()) :: atom() | nil
  def normalize_quality_level(value) do
    case to_string(value) do
      "excellent" -> :excellent
      "good" -> :good
      "fair" -> :fair
      "poor" -> :poor
      "reconnecting" -> :reconnecting
      _other -> :unknown
    end
  end

  @spec normalize_id(term()) :: integer() | nil
  def normalize_id(id) when is_integer(id), do: id

  def normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} -> value
      _error -> nil
    end
  end

  def normalize_id(_id), do: nil
  @spec normalize_media(map() | nil) :: map()
  def normalize_media(nil), do: %{}

  def normalize_media(media) when is_map(media) do
    %{
      audio: media_value(media, :audio),
      video: media_value(media, :video),
      screen: media_value(media, :screen),
      hand_raised: media_value(media, :hand_raised)
    }
    |> maybe_put_media_extra(media, :server_audio_muted)
    |> maybe_put_media_extra(media, :muted_by)
    |> maybe_put_media_extra(media, :muted_at)
    |> maybe_put_media_extra(media, :server_video_blocked)
    |> maybe_put_media_extra(media, :video_blocked_by)
    |> maybe_put_media_extra(media, :video_blocked_at)
    |> maybe_put_media_extra(media, :server_screen_blocked)
    |> maybe_put_media_extra(media, :screen_blocked_by)
    |> maybe_put_media_extra(media, :screen_blocked_at)
    |> maybe_put_media_extra(media, :hand_raised_at)
    |> maybe_put_media_extra(media, :hand_raised_by)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def normalize_media(_media), do: %{}
  @spec normalize_devices(term()) :: %{String.t() => [map()]}
  def normalize_devices(devices), do: MediaDevices.normalize(devices, unnamed_device())
  @spec unnamed_device() :: String.t()
  def unnamed_device, do: dgettext("group_call", "Default device")
  @spec normalize_console_section(term()) :: atom()
  def normalize_console_section(section) when section in [:call, :people, :stats, :settings],
    do: section

  def normalize_console_section(section) when is_binary(section) do
    case section do
      "call" -> :call
      "people" -> :people
      "stats" -> :stats
      "settings" -> :settings
      _other -> :call
    end
  end

  def normalize_console_section(_section), do: :call
  @spec normalize_pinned_participant_ids(term()) :: [integer()]
  def normalize_pinned_participant_ids(participant_ids) when is_list(participant_ids) do
    participant_ids
    |> Enum.map(&normalize_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.take(4)
  end

  def normalize_pinned_participant_ids(_participant_ids), do: []
  @spec participant_payload(map() | nil) :: map()
  def participant_payload(participant) do
    %{
      id: participant.id,
      nickname: participant.nickname,
      status: participant.status,
      media_state: participant.media_state || %{},
      channel_role_snapshot: participant.channel_role_snapshot
    }
  end

  @spec track_payload(map() | nil) :: map()
  def track_payload(track) do
    %{
      id: track.id,
      participant_id: track.participant_id,
      kind: track.kind,
      source: track.source,
      status: track.status,
      webrtc_track_id: track[:webrtc_track_id],
      stream_id: track[:stream_id]
    }
  end

  @spec media_value(map() | nil, atom()) :: term()
  def media_value(media, key) do
    case value(media, key) do
      nil -> nil
      "true" -> true
      "false" -> false
      value -> value
    end
  end

  @spec integer_value(term()) :: integer() | nil
  def integer_value(value) when is_integer(value), do: value
  def integer_value(value) when is_float(value), do: round(value)

  def integer_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  def integer_value(_value), do: 0
  @spec float_value(term()) :: float() | nil
  def float_value(value) when is_float(value), do: value
  def float_value(value) when is_integer(value), do: value / 1

  def float_value(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  def float_value(_value), do: 0
  @spec truthy?(term()) :: boolean()
  def truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  def truthy?(_value), do: false
  @spec value(map() | nil, atom()) :: term()
  def value(nil, _key), do: nil

  def value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  @spec participant_nickname(map() | nil) :: String.t() | nil
  def participant_nickname(%{nickname: nickname}), do: nickname
  def participant_nickname(_participant), do: nil
  @spec maybe_put_media_extra(map(), map() | nil, atom()) :: map()
  def maybe_put_media_extra(target, source, key) do
    string_key = Atom.to_string(key)

    case Map.get(source, key, Map.get(source, string_key)) do
      nil -> target
      value -> Map.put(target, key, value)
    end
  end
end
