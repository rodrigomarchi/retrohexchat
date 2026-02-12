defmodule RetroHexChat.Chat.LogPageTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.LogFilter
  alias RetroHexChat.Chat.LogPage

  describe "new/3" do
    test "with 0 total_count returns total_pages 0" do
      filter = LogFilter.new()

      page = LogPage.new([], 0, filter)

      assert page.total_pages == 0
    end

    test "with total_count equal to per_page returns total_pages 1" do
      filter = LogFilter.new()

      page = LogPage.new(build_entries(50), 50, filter)

      assert page.total_pages == 1
    end

    test "with total_count one over per_page returns total_pages 2" do
      filter = LogFilter.new()

      page = LogPage.new(build_entries(50), 51, filter)

      assert page.total_pages == 2
    end

    test "with total_count exactly double per_page returns total_pages 2" do
      filter = LogFilter.new()

      page = LogPage.new(build_entries(50), 100, filter)

      assert page.total_pages == 2
    end

    test "with total_count one over double per_page returns total_pages 3" do
      filter = LogFilter.new()

      page = LogPage.new(build_entries(50), 101, filter)

      assert page.total_pages == 3
    end

    test "stores entries, total_count, page from filter, and the filter itself" do
      filter = LogFilter.new(%{page: 3})
      entries = build_entries(5)

      page = LogPage.new(entries, 200, filter)

      assert page.entries == entries
      assert page.total_count == 200
      assert page.page == 3
      assert page.filter == filter
      assert page.total_pages == 4
    end

    test "stores the entries list as provided" do
      filter = LogFilter.new()
      entries = [%{id: 1, content: "hello"}, %{id: 2, content: "world"}]

      page = LogPage.new(entries, 2, filter)

      assert page.entries == entries
      assert length(page.entries) == 2
      assert Enum.at(page.entries, 0) == %{id: 1, content: "hello"}
      assert Enum.at(page.entries, 1) == %{id: 2, content: "world"}
    end
  end

  defp build_entries(count) do
    Enum.map(1..count, fn i -> %{id: i, content: "message #{i}"} end)
  end
end
