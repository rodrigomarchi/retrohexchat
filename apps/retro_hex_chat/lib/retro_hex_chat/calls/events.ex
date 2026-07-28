defmodule RetroHexChat.Calls.Events do
  @moduledoc """
  Telemetry events for P2P and group-call recovery/signaling.

  Keep metadata low-cardinality. Tokens, user ids, participant ids, nicknames,
  SDP, ICE payloads and free-form messages do not belong in these events.
  """

  @recovery_transition [:retro_hex_chat, :calls, :recovery, :transition]
  @client_error [:retro_hex_chat, :calls, :client_error]
  @signaling_replay [:retro_hex_chat, :calls, :signaling, :replay]

  @safe_optional_keys [
    :attempt,
    :max_attempts,
    :next_retry_ms,
    :event_count,
    :manual_retry,
    :trigger,
    :role,
    :phase,
    :result
  ]

  @spec emit_recovery_transition(atom() | String.t(), term(), term(), map()) :: :ok
  def emit_recovery_transition(surface, state, reason, metadata \\ %{}) do
    metadata =
      metadata
      |> safe_metadata()
      |> Map.merge(%{
        surface: normalize_tag(surface),
        state: normalize_tag(state),
        reason: normalize_tag(reason)
      })

    :telemetry.execute(@recovery_transition, %{count: 1}, metadata)
  end

  @spec emit_client_error(atom() | String.t(), term(), map()) :: :ok
  def emit_client_error(surface, code, metadata \\ %{}) do
    metadata =
      metadata
      |> safe_metadata()
      |> Map.merge(%{
        surface: normalize_tag(surface),
        code: normalize_tag(code)
      })

    :telemetry.execute(@client_error, %{count: 1}, metadata)
  end

  @spec emit_signaling_replay(atom() | String.t(), term(), map()) :: :ok
  def emit_signaling_replay(surface, action, metadata \\ %{}) do
    metadata =
      metadata
      |> safe_metadata()
      |> Map.merge(%{
        surface: normalize_tag(surface),
        action: normalize_tag(action),
        reason: normalize_tag(value(metadata, :reason))
      })

    :telemetry.execute(@signaling_replay, %{count: 1}, metadata)
  end

  @spec recovery_transition_event() :: :telemetry.event_name()
  def recovery_transition_event, do: @recovery_transition

  @spec client_error_event() :: :telemetry.event_name()
  def client_error_event, do: @client_error

  @spec signaling_replay_event() :: :telemetry.event_name()
  def signaling_replay_event, do: @signaling_replay

  defp safe_metadata(metadata) when is_map(metadata) do
    Enum.reduce(@safe_optional_keys, %{}, fn key, acc ->
      case normalize_value(key, value(metadata, key)) do
        nil -> acc
        normalized -> Map.put(acc, key, normalized)
      end
    end)
  end

  defp safe_metadata(_metadata), do: %{}

  defp normalize_value(key, value)
       when key in [:trigger, :role, :phase, :result],
       do: normalize_tag(value)

  defp normalize_value(:manual_retry, value) when is_boolean(value), do: value
  defp normalize_value(:manual_retry, value) when value in ["true", "1", 1, "on"], do: true
  defp normalize_value(:manual_retry, value) when value in ["false", "0", 0, "off"], do: false
  defp normalize_value(:manual_retry, _value), do: nil

  defp normalize_value(key, value)
       when key in [:attempt, :max_attempts, :next_retry_ms, :event_count],
       do: normalize_integer(value)

  defp normalize_value(_key, _value), do: nil

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_tag(nil), do: "unknown"
  defp normalize_tag(""), do: "unknown"

  defp normalize_tag(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_tag()
  end

  defp normalize_tag(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.slice(0, 80)
    |> case do
      "" -> "unknown"
      tag -> tag
    end
  end

  defp normalize_tag(value) when is_boolean(value), do: to_string(value)
  defp normalize_tag(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_tag(_value), do: "unknown"

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp value(_map, _key), do: nil
end
