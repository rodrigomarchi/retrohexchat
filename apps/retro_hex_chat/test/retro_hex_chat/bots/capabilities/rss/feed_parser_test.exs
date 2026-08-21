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

    test "reads Media RSS images from items" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel>
          <title>Wire</title>
          <item>
            <title>Story with media</title>
            <link>https://example.com/story</link>
            <media:content
              url="https://cdn.example.com/story.jpg"
              medium="image"
              title="People crossing a flooded street"/>
          </item>
        </channel>
      </rss>
      """

      {:ok, feed} = FeedParser.parse(xml)

      assert [%{image_url: "https://cdn.example.com/story.jpg"} = item] = feed.items
      assert item.image_alt == "People crossing a flooded street"
      assert item.image_source == "media_content"
    end

    test "reads image enclosures from items" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Wire</title>
          <item>
            <title>Story with enclosure</title>
            <link>https://example.com/story</link>
            <enclosure url="https://cdn.example.com/story.webp" type="image/webp"/>
          </item>
        </channel>
      </rss>
      """

      {:ok, feed} = FeedParser.parse(xml)

      assert [%{image_url: "https://cdn.example.com/story.webp", image_source: "enclosure"}] =
               feed.items
    end

    test "reads the first description image when explicit feed media is absent" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Wire</title>
          <item>
            <title>Story with description HTML</title>
            <link>https://example.com/story</link>
            <description><![CDATA[
              <p><img src="https://cdn.example.com/lead.png" alt="Lead photo"></p>
            ]]></description>
          </item>
        </channel>
      </rss>
      """

      {:ok, feed} = FeedParser.parse(xml)

      assert [%{image_url: "https://cdn.example.com/lead.png"} = item] = feed.items
      assert item.image_alt == "Lead photo"
      assert item.image_source == "description_image"
    end

    test "reads rich RSS item text, author and categories" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0"
        xmlns:content="http://purl.org/rss/1.0/modules/content/"
        xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>Wire</title>
          <item>
            <title>Story with rich feed fields</title>
            <link>https://example.com/rich</link>
            <description><![CDATA[
              <p>Short &amp; useful <strong>summary</strong>.</p>
              <script>ignored()</script>
            ]]></description>
            <content:encoded><![CDATA[
              <article>
                <p>First full paragraph from the feed.</p>
                <p>Second full paragraph from the feed.</p>
              </article>
            ]]></content:encoded>
            <dc:creator>Ana Reporter</dc:creator>
            <category>World</category>
            <category>Asia</category>
          </item>
        </channel>
      </rss>
      """

      {:ok, feed} = FeedParser.parse(xml)

      assert [%{} = item] = feed.items
      assert item.description == "Short & useful summary."

      assert item.content_text ==
               "First full paragraph from the feed. Second full paragraph from the feed."

      assert item.author == "Ana Reporter"
      assert item.categories == ["World", "Asia"]
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

    test "keeps Atom enclosure images separate from the article link" do
      atom = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Atom Blog</title>
        <entry>
          <title>Atom Post</title>
          <link rel="alternate" href="https://example.com/atom-post"/>
          <link rel="enclosure" type="image/jpeg" href="https://cdn.example.com/atom.jpg"/>
        </entry>
      </feed>
      """

      {:ok, feed} = FeedParser.parse(atom)

      assert [%{link: "https://example.com/atom-post"} = item] = feed.items
      assert item.image_url == "https://cdn.example.com/atom.jpg"
      assert item.image_source == "atom_link"
    end

    test "reads rich Atom entry text, author and categories" do
      atom = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Atom Blog</title>
        <entry>
          <title>Atom Post</title>
          <link href="https://example.com/atom-post"/>
          <summary type="html">&lt;p&gt;Brief &amp;amp; clear summary.&lt;/p&gt;</summary>
          <content type="xhtml">
            <div xmlns="http://www.w3.org/1999/xhtml">
              <p>First Atom paragraph.</p>
              <p>Second Atom paragraph.</p>
            </div>
          </content>
          <author><name>Bruno Writer</name></author>
          <category term="Technology"/>
          <category label="Research"/>
        </entry>
      </feed>
      """

      {:ok, feed} = FeedParser.parse(atom)

      assert [%{} = item] = feed.items
      assert item.description == "Brief & clear summary."
      assert item.content_text == "First Atom paragraph. Second Atom paragraph."
      assert item.author == "Bruno Writer"
      assert item.categories == ["Technology", "Research"]
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
