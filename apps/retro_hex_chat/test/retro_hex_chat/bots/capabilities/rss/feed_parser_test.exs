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

  describe "parse/1 — the characters real feeds actually contain" do
    # Every feed in the wild carries a curly apostrophe, an en dash or an
    # ellipsis. Handing xmerl a list of codepoints instead of bytes made each of
    # those an illegal character, and the parser rejected the whole document:
    # BBC, Hacker News, the GitHub blog and Reddit all failed on this alone.
    @typographic """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Notícias — o jornal</title>
        <item>
          <title>It’s here — the “long-awaited” release…</title>
          <link>https://example.com/1</link>
          <guid>urn:example:1</guid>
        </item>
        <item>
          <title>Ação, coração e emoção</title>
          <link>https://example.com/2</link>
          <guid>urn:example:2</guid>
        </item>
      </channel>
    </rss>
    """

    test "reads a feed with curly quotes, dashes and accents" do
      assert {:ok, feed} = FeedParser.parse(@typographic)

      assert feed.title == "Notícias — o jornal"
      assert length(feed.items) == 2

      [first, second] = feed.items
      assert first.title == "It’s here — the “long-awaited” release…"
      assert second.title == "Ação, coração e emoção"
    end

    test "keeps the publisher's own identity for each item" do
      {:ok, feed} = FeedParser.parse(@typographic)

      assert Enum.map(feed.items, & &1.guid) == ["urn:example:1", "urn:example:2"]
    end

    test "reads an Atom entry's id" do
      atom = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Diário</title>
        <entry>
          <title>Está tudo bem — mesmo</title>
          <id>tag:example.com,2026:1</id>
          <link href="https://example.com/a"/>
        </entry>
      </feed>
      """

      assert {:ok, feed} = FeedParser.parse(atom)
      assert [%{guid: "tag:example.com,2026:1", title: "Está tudo bem — mesmo"}] = feed.items
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
