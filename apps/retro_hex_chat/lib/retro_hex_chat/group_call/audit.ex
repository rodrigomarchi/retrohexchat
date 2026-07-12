defmodule RetroHexChat.GroupCall.Audit do
  @moduledoc """
  Structured audit event helpers for channel conferences.

  Events are stored in the room metadata because they describe the lifecycle of
  one room and are useful for support/debugging without introducing another hot
  path table for this roadmap step.
  """

  @max_events 100

  @spec append(map() | nil, atom(), map()) :: map()
  def append(metadata, event_type, attrs \\ %{}) when is_atom(event_type) and is_map(attrs) do
    metadata = normalize_metadata(metadata)
    events = metadata |> Map.get("audit_events", []) |> normalize_events()

    Map.put(
      metadata,
      "audit_events",
      Enum.take(events ++ [event(event_type, attrs)], -@max_events)
    )
  end

  @spec last_event(map() | nil) :: map() | nil
  def last_event(metadata) do
    metadata
    |> normalize_metadata()
    |> Map.get("audit_events", [])
    |> normalize_events()
    |> List.last()
  end

  defp event(event_type, attrs) do
    %{
      "id" => event_id(),
      "type" => Atom.to_string(event_type),
      "occurred_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> put_value("actor", value(attrs, :actor))
    |> put_value("target", value(attrs, :target))
    |> put_value("channel", value(attrs, :channel))
    |> put_value("participant_id", value(attrs, :participant_id))
    |> put_value("target_participant_id", value(attrs, :target_participant_id))
    |> put_value("reason", value(attrs, :reason))
    |> put_value("kind", value(attrs, :kind))
    |> put_value("changed_count", value(attrs, :changed_count))
    |> put_value("skipped_count", value(attrs, :skipped_count))
    |> put_value("metadata", value(attrs, :metadata))
  end

  defp event_id do
    10
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: %{}

  defp normalize_events(events) when is_list(events), do: Enum.filter(events, &is_map/1)
  defp normalize_events(_events), do: []

  defp put_value(map, _key, nil), do: map
  defp put_value(map, _key, ""), do: map
  defp put_value(map, key, value), do: Map.put(map, key, stringify_value(value))

  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(value) when is_map(value), do: Map.new(value, &stringify_pair/1)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp stringify_pair({key, value}) when is_atom(key),
    do: {Atom.to_string(key), stringify_value(value)}

  defp stringify_pair({key, value}), do: {key, stringify_value(value)}

  defp value(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end
end
