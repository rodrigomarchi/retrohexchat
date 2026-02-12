defmodule RetroHexChat.Chat.FloodTracker do
  @moduledoc """
  Per-user in-memory state tracking incoming message counts per sender
  within a sliding time window. Used to determine when the flood threshold
  is exceeded and auto-ignore should trigger.

  Lives in LiveView socket assigns. Resets on disconnect.
  """

  @default_max_senders 50

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{senders: %{}, max_senders: @default_max_senders}
  end

  # ---------------------------------------------------------------------------
  # Recording
  # ---------------------------------------------------------------------------

  @spec record_message(map(), String.t()) :: map()
  def record_message(tracker, sender_nickname) do
    key = String.downcase(sender_nickname)
    now = System.monotonic_time(:millisecond)

    case Map.get(tracker.senders, key) do
      nil ->
        tracker
        |> maybe_evict(key)
        |> put_in([Access.key(:senders), key], %{timestamps: [now], added_at: now})

      entry ->
        %{
          tracker
          | senders:
              Map.put(tracker.senders, key, %{entry | timestamps: entry.timestamps ++ [now]})
        }
    end
  end

  # ---------------------------------------------------------------------------
  # Querying
  # ---------------------------------------------------------------------------

  @spec flooded?(map(), String.t(), pos_integer(), pos_integer()) :: boolean()
  def flooded?(tracker, sender_nickname, threshold, window_seconds) do
    key = String.downcase(sender_nickname)
    cutoff = System.monotonic_time(:millisecond) - window_seconds * 1_000

    case Map.get(tracker.senders, key) do
      nil ->
        false

      %{timestamps: timestamps} ->
        recent = Enum.count(timestamps, &(&1 >= cutoff))
        recent >= threshold
    end
  end

  # ---------------------------------------------------------------------------
  # Maintenance
  # ---------------------------------------------------------------------------

  @spec prune_expired(map(), pos_integer()) :: map()
  def prune_expired(tracker, window_seconds) do
    cutoff = System.monotonic_time(:millisecond) - window_seconds * 1_000

    updated_senders =
      tracker.senders
      |> Enum.reduce(%{}, fn {key, entry}, acc ->
        recent = Enum.filter(entry.timestamps, &(&1 >= cutoff))

        if recent == [] do
          acc
        else
          Map.put(acc, key, %{entry | timestamps: recent})
        end
      end)

    %{tracker | senders: updated_senders}
  end

  @spec reset_sender(map(), String.t()) :: map()
  def reset_sender(tracker, sender_nickname) do
    key = String.downcase(sender_nickname)
    %{tracker | senders: Map.delete(tracker.senders, key)}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp maybe_evict(tracker, key) do
    if Map.has_key?(tracker.senders, key) or map_size(tracker.senders) < tracker.max_senders do
      tracker
    else
      oldest_key =
        tracker.senders
        |> Enum.min_by(fn {_k, v} -> v.added_at end)
        |> elem(0)

      %{tracker | senders: Map.delete(tracker.senders, oldest_key)}
    end
  end
end
