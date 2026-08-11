defmodule RetroHexChat.Chat.Positions do
  @moduledoc """
  Where an entry sits in a list the person arranged themselves.

  Aliases, autojoin channels, perform commands, custom menu items, auto-respond
  rules and highlight words are all lists whose order the person chose, so each
  entry carries a `:position` and is read back in that order rather than in
  whatever order the database returned.

  Positions run from zero with no gaps. That is not decoration: `PerformList`
  removes an entry by its position and moves one by its index into the ordered
  list, and those two only mean the same thing while the numbering is
  contiguous. Closing the gap after a removal is what keeps them agreeing.

  `renumber/1` stamps the order the list is already in, because the caller that
  moved an entry has just built the order it wants. Everything that loads a
  list reads it back ordered by position, so list order and position order stay
  the same thing.
  """

  @typedoc "Any entry carrying a place in a list somebody arranged."
  @type entry :: %{required(:position) => non_neg_integer(), optional(any()) => any()}

  @doc "Where the next entry goes: after everything already on the list."
  @spec next([entry()]) :: non_neg_integer()
  def next([]), do: 0
  def next(entries), do: (entries |> Enum.map(& &1.position) |> Enum.max()) + 1

  @doc """
  The entries numbered 0, 1, 2… in the order they are already in.

  Called after removing or moving one, which is what leaves a gap or a stale
  number behind.
  """
  @spec renumber([entry()]) :: [entry()]
  def renumber(entries) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, index} -> %{entry | position: index} end)
  end

  @doc "The entries as the person arranged them."
  @spec in_order([entry()]) :: [entry()]
  def in_order(entries), do: Enum.sort_by(entries, & &1.position)
end
