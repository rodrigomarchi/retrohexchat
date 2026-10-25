defmodule RetroHexChat.GroupCall.MediaState do
  @moduledoc """
  A group-call participant's media state: the map of string keys the room
  keeps for each participant — audio, video, screen and hand, the server's
  holds on each and who placed them — and the changes the room makes to it.
  Pure functions; the room process decides when to apply them.
  """

  # What the server has turned off stays off, whatever the participant asks:
  # each medium, the flag that holds it off, and who held it off and when.
  @server_media_holds [
    {"audio", "server_audio_muted", "muted_by", "muted_at"},
    {"video", "server_video_blocked", "video_blocked_by", "video_blocked_at"},
    {"screen", "server_screen_blocked", "screen_blocked_by", "screen_blocked_at"}
  ]

  @doc """
  A participant's media state with every known key in its string form, the
  booleans defaulted from `fallback` (audio and video on, screen and hand
  down) and the server's holds and screen metadata kept when present.
  """
  @spec normalize(map() | nil) :: map()
  @spec normalize(map() | nil, map()) :: map()
  def normalize(media_state),
    do: normalize(media_state, %{"audio" => true, "video" => true})

  def normalize(nil, fallback), do: fallback

  def normalize(media_state, fallback) when is_map(media_state) do
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

  def normalize(_media_state, fallback), do: fallback

  @doc "Turns audio or video on or off by the server, recording who held it off and when."
  @spec put_server_moderation(map(), :audio | :video, boolean(), String.t()) :: map()
  def put_server_moderation(media_state, :audio, enabled?, actor_nickname) do
    Map.merge(media_state, %{
      "audio" => enabled?,
      "server_audio_muted" => !enabled?,
      "muted_by" => if(enabled?, do: nil, else: actor_nickname),
      "muted_at" => if(enabled?, do: nil, else: moderation_timestamp())
    })
  end

  def put_server_moderation(media_state, :video, enabled?, actor_nickname) do
    Map.merge(media_state, %{
      "video" => enabled?,
      "server_video_blocked" => !enabled?,
      "video_blocked_by" => if(enabled?, do: nil, else: actor_nickname),
      "video_blocked_at" => if(enabled?, do: nil, else: moderation_timestamp())
    })
  end

  @doc "Lifts or imposes the server's block on screen sharing; a block also stops the share."
  @spec put_server_screen_moderation(map(), boolean(), String.t()) :: map()
  def put_server_screen_moderation(media_state, true, _actor_nickname) do
    Map.merge(media_state, %{
      "server_screen_blocked" => false,
      "screen_blocked_by" => nil,
      "screen_blocked_at" => nil
    })
  end

  def put_server_screen_moderation(media_state, false, actor_nickname) do
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

  @doc "Raises or lowers the hand, keeping the time it first went up."
  @spec put_hand_raised(map(), boolean(), String.t()) :: map()
  def put_hand_raised(media_state, true, actor_nickname) do
    Map.merge(media_state, %{
      "hand_raised" => true,
      "hand_raised_at" => Map.get(media_state, "hand_raised_at") || moderation_timestamp(),
      "hand_raised_by" => actor_nickname
    })
  end

  def put_hand_raised(media_state, false, _actor_nickname) do
    media_state
    |> Map.put("hand_raised", false)
    |> Map.delete("hand_raised_at")
    |> Map.delete("hand_raised_by")
  end

  @doc "What a participant is told when the server changed its media."
  @spec forced_payload(map()) :: map()
  def forced_payload(media_state) do
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

  @doc "A non-empty string from the screen-share info under `key` (string or atom), or nil."
  @spec screen_value(map() | nil, String.t()) :: String.t() | nil
  def screen_value(screen_info, key), do: clean_string(screen_info_value(screen_info, key))

  @doc "Records the shared screen's track and stream ids, or drops them when the share ends."
  @spec put_screen_metadata(map(), boolean(), map() | nil) :: map()
  def put_screen_metadata(media_state, true, screen_info) do
    media_state
    |> put_clean_media_string("screen_track_id", screen_value(screen_info, "track_id"))
    |> put_clean_media_string("screen_stream_id", screen_value(screen_info, "stream_id"))
  end

  def put_screen_metadata(media_state, false, _screen_info) do
    media_state
    |> Map.delete("screen_track_id")
    |> Map.delete("screen_stream_id")
  end

  defp put_clean_media_string(media_state, key, value) do
    case value do
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

  @doc "Keeps off what the server turned off in `current`, whatever `media_state` asks for."
  @spec enforce_server_policy(map(), map()) :: map()
  def enforce_server_policy(media_state, current_media_state) do
    Enum.reduce(@server_media_holds, media_state, fn {media, flag, by, at}, state ->
      if Map.get(current_media_state, flag) == true do
        state
        |> Map.put(media, false)
        |> Map.put(flag, true)
        |> copy_current_media_extra(current_media_state, by)
        |> copy_current_media_extra(current_media_state, at)
      else
        state
      end
    end)
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
end
