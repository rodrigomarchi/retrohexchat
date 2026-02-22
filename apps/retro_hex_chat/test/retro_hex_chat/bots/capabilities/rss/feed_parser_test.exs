defmodule RetroHexChat.Bots.Capabilities.RSS.FeedParserTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.RSS.FeedParser

  @rss_xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Test Blog</title>
      <link>https://example.com</link>
      <description>A test blog</description>
      <item>
        <title>First Post</title>
        <link>https://example.com/first</link>
        <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
      </item>
      <item>
        <title>Second Post</title>
        <link>https://example.com/second</link>
        <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
      </item>
    </channel>
  </rss>
  """

  @atom_xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Atom Blog</title>
    <entry>
      <title>Atom Post</title>
      <link href="https://example.com/atom-post"/>
      <published>2024-01-01T00:00:00Z</published>
    </entry>
    <entry>
      <title>Another Post</title>
      <link href="https://example.com/another"/>
      <updated>2024-01-02T00:00:00Z</updated>
    </entry>
  </feed>
  """

  describe "parse/1 — RSS 2.0" do
    test "parses RSS feed title" do
      {:ok, feed} = FeedParser.parse(@rss_xml)
      assert feed.title == "Test Blog"
    end

    test "parses RSS items" do
      {:ok, feed} = FeedParser.parse(@rss_xml)
      assert length(feed.items) == 2
    end

    test "parses RSS item fields" do
      {:ok, feed} = FeedParser.parse(@rss_xml)
      [first | _] = feed.items
      assert first.title == "First Post"
      assert first.link == "https://example.com/first"
      assert first.published =~ "2024"
    end
  end

  describe "parse/1 — Atom" do
    test "parses Atom feed title" do
      {:ok, feed} = FeedParser.parse(@atom_xml)
      assert feed.title == "Atom Blog"
    end

    test "parses Atom entries" do
      {:ok, feed} = FeedParser.parse(@atom_xml)
      assert length(feed.items) == 2
    end

    test "parses Atom entry link from href attribute" do
      {:ok, feed} = FeedParser.parse(@atom_xml)
      [first | _] = feed.items
      assert first.title == "Atom Post"
      assert first.link == "https://example.com/atom-post"
    end

    test "falls back to updated date when published missing" do
      {:ok, feed} = FeedParser.parse(@atom_xml)
      second = Enum.at(feed.items, 1)
      assert second.published =~ "2024"
    end
  end

  describe "parse/1 — errors" do
    test "rejects invalid XML" do
      assert {:error, _} = FeedParser.parse("not xml at all")
    end

    test "rejects unknown root element" do
      xml = """
      <?xml version="1.0"?>
      <html><body>Not a feed</body></html>
      """

      assert {:error, msg} = FeedParser.parse(xml)
      assert msg =~ "Unknown feed format"
    end
  end
end
