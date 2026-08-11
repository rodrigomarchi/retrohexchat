defmodule RetroHexChat.Chat.PositionsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Positions

  defmodule Entry do
    @moduledoc false
    defstruct [:name, :position]
  end

  defp at(pairs), do: Enum.map(pairs, fn {name, pos} -> %Entry{name: name, position: pos} end)
  defp places(entries), do: Enum.map(entries, &{&1.name, &1.position})

  describe "next/1" do
    test "the first entry goes at zero" do
      assert Positions.next([]) == 0
    end

    test "a new entry goes after everything already there" do
      assert Positions.next(at(a: 0, b: 1, c: 2)) == 3
    end

    test "after the highest, not after the count, so a gap never collides" do
      assert Positions.next(at(a: 0, b: 7)) == 8
    end
  end

  describe "renumber/1" do
    test "closes the gap a removal left" do
      remaining = at(a: 0, c: 2, d: 3)

      assert places(Positions.renumber(remaining)) == [{:a, 0}, {:c, 1}, {:d, 2}]
    end

    test "stamps the order the list is already in, not the numbers it carries" do
      moved = at(c: 2, a: 0, b: 1)

      assert places(Positions.renumber(moved)) == [{:c, 0}, {:a, 1}, {:b, 2}]
    end

    test "an emptied list has nothing to number" do
      assert Positions.renumber([]) == []
    end

    test "leaves the rest of an entry alone" do
      assert [%Entry{name: :a}] = Positions.renumber(at(a: 9))
    end
  end

  describe "in_order/1" do
    test "reads the list back the way the person arranged it" do
      stored = at(c: 2, a: 0, b: 1)

      assert Enum.map(Positions.in_order(stored), & &1.name) == [:a, :b, :c]
    end

    test "an empty list is already in order" do
      assert Positions.in_order([]) == []
    end
  end

  describe "the contiguity a list depends on" do
    # PerformList removes an entry by its position and moves one by its index
    # into the ordered list. Those are the same thing only while numbering runs
    # from zero without gaps, which is what renumbering after a removal keeps
    # true.
    test "after a removal, every position is still its own index" do
      {_removed, rest} = Enum.split_with(at(a: 0, b: 1, c: 2, d: 3), &(&1.position == 1))

      renumbered = Positions.renumber(rest)

      for {entry, index} <- Enum.with_index(Positions.in_order(renumbered)) do
        assert entry.position == index
      end
    end

    test "and the next entry lands right after them" do
      {_removed, rest} = Enum.split_with(at(a: 0, b: 1, c: 2), &(&1.position == 0))
      renumbered = Positions.renumber(rest)

      assert Positions.next(renumbered) == length(renumbered)
    end
  end
end
