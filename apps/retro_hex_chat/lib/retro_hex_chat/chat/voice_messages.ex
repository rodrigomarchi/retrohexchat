defmodule RetroHexChat.Chat.VoiceMessages do
  @moduledoc """
  What a recorded message is allowed to be.

  A voice message is not a new kind of attachment — it is an ordinary upload
  that a browser produced instead of a file picker, so storage, the size ceiling
  and the orphan sweep all apply to it unchanged. The only thing that has to be
  decided here is the shape a recording may arrive in: a container a browser can
  record into, short enough to be a message rather than a file somebody has to
  make time for.

  The ceiling is a minute. Past that it stops being something the listener can
  take in the middle of a conversation, and the person recording it wanted to
  write instead.
  """

  @max_duration_ms 60_000

  # MediaRecorder gives WebM/Opus in Chromium and Firefox and MP4/AAC in Safari;
  # the rest of the list is what somebody attaching a recording made elsewhere
  # would plausibly hand over.
  @content_types ~w(audio/webm audio/ogg audio/mp4 audio/mpeg audio/wav)

  @doc "The longest recording this chat accepts, in milliseconds."
  @spec max_duration_ms() :: pos_integer()
  def max_duration_ms, do: @max_duration_ms

  @doc "The same ceiling in whole seconds, for anything that has to say it out loud."
  @spec max_duration_seconds() :: pos_integer()
  def max_duration_seconds, do: div(@max_duration_ms, 1_000)

  @doc "The audio containers a recording may arrive in."
  @spec content_types() :: [String.t()]
  def content_types, do: @content_types

  @doc """
  Whether a content type names one of those containers.

  The codec parameter a recorder appends (`audio/webm;codecs=opus`) is part of
  the type it produced, not a different format.
  """
  @spec content_type?(String.t() | nil) :: boolean()
  def content_type?(content_type), do: normalize(content_type) in @content_types

  @doc """
  The `preview_metadata` a recording carries, or why it was refused.

  The length is what lets a row say "0:07" before anybody downloads a byte, so
  it is stored beside the file rather than measured on every render. A length
  that cannot be read is simply absent — the player still knows its own
  duration once it loads, and a made-up number would be worse than none.
  """
  @spec metadata(String.t() | nil, term()) :: {:ok, map()} | {:error, :unsupported_content_type}
  def metadata(content_type, duration_ms) do
    if content_type?(content_type) do
      {:ok, put_duration(%{"voice" => true}, duration_ms)}
    else
      {:error, :unsupported_content_type}
    end
  end

  @doc "Whether an attachment payload or uploaded file is a recording."
  @spec voice?(map()) :: boolean()
  def voice?(attachment), do: read(attachment, "voice") == true

  @doc "How long the recording runs, in milliseconds, when it was stored."
  @spec duration_ms(map()) :: non_neg_integer() | nil
  def duration_ms(attachment) do
    case read(attachment, "duration_ms") do
      value when is_integer(value) and value > 0 -> value
      _value -> nil
    end
  end

  defp put_duration(metadata, duration_ms)
       when is_integer(duration_ms) and duration_ms > 0 do
    Map.put(metadata, "duration_ms", min(duration_ms, @max_duration_ms))
  end

  defp put_duration(metadata, _duration_ms), do: metadata

  defp read(attachment, key) do
    attachment
    |> preview_metadata()
    |> case do
      metadata when is_map(metadata) -> Map.get(metadata, key, Map.get(metadata, safe_atom(key)))
      _metadata -> nil
    end
  end

  defp preview_metadata(%{preview_metadata: metadata}), do: metadata
  defp preview_metadata(%{"preview_metadata" => metadata}), do: metadata
  defp preview_metadata(_attachment), do: nil

  defp safe_atom("voice"), do: :voice
  defp safe_atom("duration_ms"), do: :duration_ms

  defp normalize(content_type) when is_binary(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp normalize(_content_type), do: ""
end
