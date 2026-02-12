defmodule RetroHexChat.Chat.DuplicateTracker do
  @moduledoc """
  Per-user in-memory state tracking recent message content per sender-target
  pair within a sliding time window. Used to detect exact duplicate messages.

  Target keys are `{:channel, channel_name}` or `{:pm, sender_nick}`.

  Lives in LiveView socket assigns. Resets on disconnect.
  """

  @default_max_senders 50

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{entries: %{}, max_senders: @default_max_senders}
  end

  # ---------------------------------------------------------------------------
  # Recording
  # ---------------------------------------------------------------------------

  @spec record_message(map(), String.t(), tuple(), String.t()) :: map()
  def record_message(tracker, sender, target_key, content) do
    key = {String.downcase(sender), target_key}
    now = System.monotonic_time(:millisecond)
    entry = %{content: content, timestamp: now}

    tracker = maybe_evict_sender(tracker, String.downcase(sender))

    existing = Map.get(tracker.entries, key, [])
    %{tracker | entries: Map.put(tracker.entries, key, existing ++ [entry])}
  end

  # ---------------------------------------------------------------------------
  # Querying
  # ---------------------------------------------------------------------------

  @spec duplicate?(map(), String.t(), tuple(), String.t(), pos_integer(), pos_integer()) ::
          boolean()
  def duplicate?(tracker, sender, target_key, content, threshold, window_seconds) do
    duplicate_count(tracker, sender, target_key, content, window_seconds) >= threshold
  end

  @spec duplicate_count(map(), String.t(), tuple(), String.t(), pos_integer()) ::
          non_neg_integer()
  def duplicate_count(tracker, sender, target_key, content, window_seconds) do
    key = {String.downcase(sender), target_key}
    cutoff = System.monotonic_time(:millisecond) - window_seconds * 1_000

    case Map.get(tracker.entries, key) do
      nil ->
        0

      entries ->
        Enum.count(entries, fn e -> e.content == content and e.timestamp >= cutoff end)
    end
  end

  # ---------------------------------------------------------------------------
  # Maintenance
  # ---------------------------------------------------------------------------

  @spec prune_expired(map(), pos_integer()) :: map()
  def prune_expired(tracker, window_seconds) do
    cutoff = System.monotonic_time(:millisecond) - window_seconds * 1_000

    updated_entries =
      tracker.entries
      |> Enum.reduce(%{}, fn {key, entries}, acc ->
        recent = Enum.filter(entries, &(&1.timestamp >= cutoff))

        if recent == [] do
          acc
        else
          Map.put(acc, key, recent)
        end
      end)

    %{tracker | entries: updated_entries}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp maybe_evict_sender(tracker, sender_key) do
    current_senders =
      tracker.entries
      |> Map.keys()
      |> Enum.map(fn {sender, _target} -> sender end)
      |> Enum.uniq()

    if sender_key in current_senders or length(current_senders) < tracker.max_senders do
      tracker
    else
      evict_oldest_sender(tracker)
    end
  end

  defp evict_oldest_sender(tracker) do
    oldest_sender =
      tracker.entries
      |> Enum.group_by(fn {{sender, _target}, _entries} -> sender end)
      |> Enum.map(fn {sender, entries_list} ->
        oldest_ts =
          entries_list
          |> Enum.flat_map(fn {_key, entries} -> Enum.map(entries, & &1.timestamp) end)
          |> Enum.min()

        {sender, oldest_ts}
      end)
      |> Enum.min_by(fn {_sender, ts} -> ts end)
      |> elem(0)

    updated_entries =
      tracker.entries
      |> Enum.reject(fn {{sender, _target}, _entries} -> sender == oldest_sender end)
      |> Map.new()

    %{tracker | entries: updated_entries}
  end
end
