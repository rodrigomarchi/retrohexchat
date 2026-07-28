defmodule RetroHexChat.PageTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Page

  # The cursor function used across these tests: rows are plain maps with an id.
  defp by_id(row), do: row.id

  defp rows(n), do: Enum.map(1..n//1, &%{id: &1})

  describe "new/3 — the limit + 1 contract" do
    test "exactly limit rows fetched means there is nothing more" do
      # The caller asked for limit + 1 = 4 and the database returned 3.
      page = Page.new(rows(3), 3, &by_id/1)

      assert length(page.items) == 3
      refute page.has_more
    end

    test "limit + 1 rows fetched means there is more, and the extra is dropped" do
      page = Page.new(rows(4), 3, &by_id/1)

      assert length(page.items) == 3
      assert Enum.map(page.items, & &1.id) == [1, 2, 3]
      assert page.has_more
    end

    test "fewer than limit rows means there is nothing more" do
      page = Page.new(rows(2), 3, &by_id/1)

      assert length(page.items) == 2
      refute page.has_more
    end

    test "no rows at all" do
      page = Page.new([], 3, &by_id/1)

      assert page.items == []
      refute page.has_more
      assert page.next_cursor == nil
    end
  end

  describe "next_cursor/1" do
    test "is the cursor of the last returned row when there is more" do
      page = Page.new(rows(4), 3, &by_id/1)

      assert page.next_cursor == 3
    end

    test "is nil when there is nothing more" do
      page = Page.new(rows(2), 3, &by_id/1)

      assert page.next_cursor == nil
    end

    test "comes from the last RAW row of the page, not the last visible one" do
      # This is the rule that keeps a filtered page from re-fetching what it
      # already hid: the cursor is decided before any presentation filter runs.
      page = Page.new(rows(4), 3, &by_id/1)
      filtered = Page.filter(page, &(&1.id != 3))

      assert filtered.next_cursor == 3
    end
  end

  describe "filter/2 — the invariant that makes bad pagination inexpressible" do
    test "filtering items does NOT change has_more" do
      page = Page.new(rows(4), 3, &by_id/1)
      assert page.has_more

      filtered = Page.filter(page, &(&1.id == 1))

      assert length(filtered.items) == 1
      assert filtered.has_more, "has_more is a property of the database, not of the visible list"
    end

    test "filtering everything away still preserves has_more" do
      page = Page.new(rows(4), 3, &by_id/1)

      filtered = Page.filter(page, fn _ -> false end)

      assert filtered.items == []
      assert filtered.has_more
    end

    test "filtering a page that had no more still has no more" do
      page = Page.new(rows(2), 3, &by_id/1)

      filtered = Page.filter(page, &(&1.id == 1))

      refute filtered.has_more
    end
  end

  describe "map/2" do
    test "transforms items without touching pagination state" do
      page = Page.new(rows(4), 3, &by_id/1)

      mapped = Page.map(page, &Map.put(&1, :seen, true))

      assert Enum.all?(mapped.items, & &1.seen)
      assert mapped.has_more
      assert mapped.next_cursor == 3
    end
  end

  describe "total" do
    test "defaults to nil so an ordinary page never pays for a COUNT" do
      page = Page.new(rows(4), 3, &by_id/1)

      assert page.total == nil
    end

    test "is carried when the surface displays a counter" do
      page = Page.new(rows(4), 3, &by_id/1)

      assert Page.with_total(page, 5_000).total == 5_000
    end
  end

  describe "empty/0" do
    test "is a page with nothing in it and nothing after it" do
      page = Page.empty()

      assert page.items == []
      refute page.has_more
      assert page.next_cursor == nil
    end
  end

  describe "limit_with_lookahead/1" do
    test "asks the database for one row past the page" do
      assert Page.limit_with_lookahead(50) == 51
    end
  end
end
