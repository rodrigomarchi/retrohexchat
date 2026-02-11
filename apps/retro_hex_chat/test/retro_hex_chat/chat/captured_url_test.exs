defmodule RetroHexChat.Chat.CapturedURLTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.CapturedURL

  @moduletag :unit

  describe "new/1" do
    test "creates struct with auto-generated id and nil preview_title" do
      entry =
        CapturedURL.new(%{
          url: "https://example.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: ~U[2026-02-11 14:00:00Z]
        })

      assert entry.url == "https://example.com"
      assert entry.source == "#lobby"
      assert entry.source_type == :channel
      assert entry.posted_by == "Alice"
      assert entry.timestamp == ~U[2026-02-11 14:00:00Z]
      assert entry.preview_title == nil
      assert is_binary(entry.id)
      assert String.length(entry.id) > 0
    end

    test "each new entry gets a unique id" do
      attrs = %{
        url: "https://example.com",
        source: "#lobby",
        source_type: :channel,
        posted_by: "Alice",
        timestamp: DateTime.utc_now()
      }

      entry1 = CapturedURL.new(attrs)
      entry2 = CapturedURL.new(attrs)
      assert entry1.id != entry2.id
    end
  end

  describe "set_preview_title/2" do
    test "updates preview_title" do
      entry =
        CapturedURL.new(%{
          url: "https://example.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: DateTime.utc_now()
        })

      updated = CapturedURL.set_preview_title(entry, "Example Page")
      assert updated.preview_title == "Example Page"
    end

    test "can set preview_title to nil" do
      entry =
        CapturedURL.new(%{
          url: "https://example.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: DateTime.utc_now()
        })

      updated = CapturedURL.set_preview_title(entry, "Title")
      cleared = CapturedURL.set_preview_title(updated, nil)
      assert cleared.preview_title == nil
    end
  end

  describe "filter_by_source/2" do
    setup do
      entries = [
        CapturedURL.new(%{
          url: "https://a.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: DateTime.utc_now()
        }),
        CapturedURL.new(%{
          url: "https://b.com",
          source: "#elixir",
          source_type: :channel,
          posted_by: "Bob",
          timestamp: DateTime.utc_now()
        }),
        CapturedURL.new(%{
          url: "https://c.com",
          source: "Carol",
          source_type: :pm,
          posted_by: "Carol",
          timestamp: DateTime.utc_now()
        }),
        CapturedURL.new(%{
          url: "https://d.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Dave",
          timestamp: DateTime.utc_now()
        })
      ]

      %{entries: entries}
    end

    test "nil returns all entries", %{entries: entries} do
      assert CapturedURL.filter_by_source(entries, nil) == entries
    end

    test "filters by channel name", %{entries: entries} do
      filtered = CapturedURL.filter_by_source(entries, "#lobby")
      assert length(filtered) == 2
      assert Enum.all?(filtered, &(&1.source == "#lobby"))
    end

    test "filters by PM nick", %{entries: entries} do
      filtered = CapturedURL.filter_by_source(entries, "Carol")
      assert length(filtered) == 1
      assert hd(filtered).source == "Carol"
    end

    test "returns empty list for non-matching source", %{entries: entries} do
      assert CapturedURL.filter_by_source(entries, "#nonexistent") == []
    end
  end

  describe "filter_by_url/2" do
    setup do
      entries = [
        CapturedURL.new(%{
          url: "https://example.com/path",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: DateTime.utc_now()
        }),
        CapturedURL.new(%{
          url: "https://hexdocs.pm/phoenix",
          source: "#elixir",
          source_type: :channel,
          posted_by: "Bob",
          timestamp: DateTime.utc_now()
        }),
        CapturedURL.new(%{
          url: "https://EXAMPLE.COM/other",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Carol",
          timestamp: DateTime.utc_now()
        })
      ]

      %{entries: entries}
    end

    test "case-insensitive URL text search", %{entries: entries} do
      filtered = CapturedURL.filter_by_url(entries, "example")
      assert length(filtered) == 2
    end

    test "empty search returns all entries", %{entries: entries} do
      assert CapturedURL.filter_by_url(entries, "") == entries
    end

    test "no match returns empty list", %{entries: entries} do
      assert CapturedURL.filter_by_url(entries, "github") == []
    end

    test "partial URL match", %{entries: entries} do
      filtered = CapturedURL.filter_by_url(entries, "hexdocs")
      assert length(filtered) == 1
      assert hd(filtered).url =~ "hexdocs"
    end
  end

  describe "sort_by/3" do
    setup do
      now = DateTime.utc_now()

      entries = [
        CapturedURL.new(%{
          url: "https://b.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Bob",
          timestamp: DateTime.add(now, -60)
        }),
        CapturedURL.new(%{
          url: "https://a.com",
          source: "#elixir",
          source_type: :channel,
          posted_by: "Alice",
          timestamp: now
        }),
        CapturedURL.new(%{
          url: "https://c.com",
          source: "#lobby",
          source_type: :channel,
          posted_by: "Carol",
          timestamp: DateTime.add(now, -120)
        })
      ]

      %{entries: entries}
    end

    test "sorts by url ascending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :url, :asc)
      urls = Enum.map(sorted, & &1.url)
      assert urls == ["https://a.com", "https://b.com", "https://c.com"]
    end

    test "sorts by url descending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :url, :desc)
      urls = Enum.map(sorted, & &1.url)
      assert urls == ["https://c.com", "https://b.com", "https://a.com"]
    end

    test "sorts by source ascending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :source, :asc)
      sources = Enum.map(sorted, & &1.source)
      assert sources == ["#elixir", "#lobby", "#lobby"]
    end

    test "sorts by posted_by ascending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :posted_by, :asc)
      posters = Enum.map(sorted, & &1.posted_by)
      assert posters == ["Alice", "Bob", "Carol"]
    end

    test "sorts by posted_by descending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :posted_by, :desc)
      posters = Enum.map(sorted, & &1.posted_by)
      assert posters == ["Carol", "Bob", "Alice"]
    end

    test "sorts by timestamp ascending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :timestamp, :asc)
      # Oldest first (most negative offset)
      assert hd(sorted).url == "https://c.com"
    end

    test "sorts by timestamp descending", %{entries: entries} do
      sorted = CapturedURL.sort_by(entries, :timestamp, :desc)
      # Newest first
      assert hd(sorted).url == "https://a.com"
    end

    test "empty list returns empty list" do
      assert CapturedURL.sort_by([], :url, :asc) == []
    end
  end
end
