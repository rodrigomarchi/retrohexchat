defmodule RetroHexChat.Chat.UnreadTracker do
  @moduledoc """
  Pure domain logic for tracking unread message counts per channel/PM.

  Replaces the boolean `unread_channels` MapSet with a numeric count map.
  All functions are pure — no side effects, no Phoenix dependencies.
  """

  @type counts :: %{String.t() => non_neg_integer()}

  @max_display 99

  @doc """
  Increment the unread count for a channel or PM key.
  """
  @spec increment(counts(), String.t()) :: counts()
  def increment(counts, key) do
    Map.update(counts, key, 1, &(&1 + 1))
  end

  @doc """
  Reset the unread count for a channel or PM key to zero (removes the key).
  """
  @spec reset(counts(), String.t()) :: counts()
  def reset(counts, key) do
    Map.delete(counts, key)
  end

  @doc """
  Get the current unread count for a channel or PM key.
  Returns 0 if the key is not present.
  """
  @spec get_count(counts(), String.t()) :: non_neg_integer()
  def get_count(counts, key) do
    Map.get(counts, key, 0)
  end

  @doc """
  Format a count for display: "" if 0, "99+" if > 99, else the number as string.
  """
  @spec display_count(non_neg_integer()) :: String.t()
  def display_count(0), do: ""
  def display_count(n) when n > @max_display, do: "99+"
  def display_count(n), do: Integer.to_string(n)

  @doc """
  Check if a key has any unread messages.
  """
  @spec unread?(counts(), String.t()) :: boolean()
  def unread?(counts, key) do
    get_count(counts, key) > 0
  end

  @doc """
  Return all keys that have unread messages.
  """
  @spec unread_keys(counts()) :: [String.t()]
  def unread_keys(counts) do
    counts
    |> Enum.filter(fn {_key, count} -> count > 0 end)
    |> Enum.map(fn {key, _count} -> key end)
  end
end
