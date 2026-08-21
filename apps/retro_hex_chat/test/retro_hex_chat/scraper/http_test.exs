defmodule RetroHexChat.Scraper.HTTPTest do
  @moduledoc """
  What one visit to a page yields beyond its preview text.

  The extraction itself is covered by `RetroHexChat.Chat.LinkPreview.HTTPTest`,
  which drives the same code through the older adapter. What is asserted here is
  the part that only exists because pages are now stored for sixty days: the
  fields that make the *next* visit cheap, and the conditional request that makes
  it free.
  """
  use ExUnit.Case, async: false

  alias RetroHexChat.Scraper.HTTP

  @moduletag :unit

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:retro_hex_chat, :scraper_req_options, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :scraper_req_options) end)
    :ok
  end

  describe "scrape/2" do
    test "reports what the transfer revealed alongside what the publisher wrote" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("etag", ~s("v1"))
        |> Plug.Conn.put_resp_header("last-modified", "Wed, 21 Oct 2026 07:28:00 GMT")
        |> Req.Test.html("""
        <head>
          <meta property="og:title" content="Stored once">
          <meta property="og:site_name" content="Example News">
        </head>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/story")

      assert scrape.metadata.title == "Stored once"
      assert scrape.metadata.site_name == "Example News"
      assert scrape.final_url == "https://example.com/story"
      assert scrape.http_status == 200
      assert scrape.etag == ~s("v1")
      assert scrape.last_modified == "Wed, 21 Oct 2026 07:28:00 GMT"
      assert scrape.content_type =~ "text/html"
    end

    test "returns the publisher's text unescaped" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, ~s(<head><meta property="og:title" content="Tom &amp; Jerry"></head>))
      end)

      assert {:ok, %{metadata: %{title: "Tom & Jerry"}}} =
               HTTP.scrape("https://example.com/story")
    end

    test "offers the publisher a chance to say nothing changed" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, "if-none-match") == [~s("v1")]

        assert Plug.Conn.get_req_header(conn, "if-modified-since") == [
                 "Wed, 21 Oct 2026 07:28:00 GMT"
               ]

        Plug.Conn.resp(conn, 304, "")
      end)

      assert {:not_modified} =
               HTTP.scrape("https://example.com/story",
                 if_none_match: ~s("v1"),
                 if_modified_since: "Wed, 21 Oct 2026 07:28:00 GMT"
               )
    end

    test "sends no conditional headers for a page it has never seen" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, "if-none-match") == []
        assert Plug.Conn.get_req_header(conn, "if-modified-since") == []

        Req.Test.html(conn, ~s(<head><title>First visit</title></head>))
      end)

      assert {:ok, %{metadata: %{title: "First visit"}}} = HTTP.scrape("https://example.com/new")
    end

    test "refuses an address the server should not reach" do
      assert {:error, :blocked} = HTTP.scrape("http://127.0.0.1/story")
    end

    test "refuses to pass off a URL as a byline" do
      # What the BBC actually publishes in `article:author`.
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="A story">
          <meta property="article:author" content="https://www.facebook.com/bbcnews">
        </head>
        """)
      end)

      assert {:ok, %{author: nil}} = HTTP.scrape("https://example.com/bbc")
    end

    test "does not mistake a JSON-LD node id for a person" do
      # WordPress emits `author: {"@id": "https://site/#/schema/person/…"}` when
      # the name lives in a separate node.
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="A story">
          <script type="application/ld+json">
            {"@type": "NewsArticle",
             "author": {"@id": "https://tecnoblog.net/#/schema/person/188268929b"}}
          </script>
        </head>
        """)
      end)

      assert {:ok, %{author: nil}} = HTTP.scrape("https://example.com/wp")
    end

    test "does not attribute an article to the publication's own social account" do
      # `twitter:creator` is as often the outlet as the writer, so it is not a
      # byline source at all.
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="A story">
          <meta name="twitter:creator" content="@engadget">
        </head>
        """)
      end)

      assert {:ok, %{author: nil}} = HTTP.scrape("https://example.com/tw")
    end

    test "tells a bot wall apart from a page with nothing on it" do
      # What arstechnica.com actually serves: HTTP 202, an empty <title>, and the
      # AWS WAF challenge script. Ten of one hundred and fifty-two real feed links
      # came back like this.
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.resp(202, """
        <!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title></title>
        <script type="text/javascript">window.awsWafCookieDomainList = [];</script>
        </head><body></body></html>
        """)
      end)

      assert {:error, :bot_challenge} = HTTP.scrape("https://example.com/walled")
    end

    test "recognises the header Cloudflare states it outright in" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("cf-mitigated", "challenge")
        |> Req.Test.html("<head><title></title></head>")
      end)

      assert {:error, :bot_challenge} = HTTP.scrape("https://example.com/cf")
    end

    test "an article that merely writes about challenge scripts still extracts" do
      # The markers are only consulted for a page that yielded nothing at all, so
      # a page quoting them keeps working.
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><meta property="og:title" content="How cf_chl_opt and awsWafCookie work"></head>
        <body><article><p>Both challenge scripts set a cookie.</p></article></body>
        """)
      end)

      assert {:ok, %{metadata: %{title: "How cf_chl_opt and awsWafCookie work"}}} =
               HTTP.scrape("https://example.com/about-walls")
    end

    test "a genuinely empty page is still just empty" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, "<head><title></title></head><body></body>")
      end)

      assert {:error, :no_metadata} = HTTP.scrape("https://example.com/blank")
    end

    test "keeps a byline that is a person" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="A story">
          <meta name="author" content="Marlowe Starling">
        </head>
        """)
      end)

      assert {:ok, %{author: "Marlowe Starling"}} = HTTP.scrape("https://example.com/ok")
    end

    test "reads the whole document, not only its head" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><meta property="og:title" content="With a body"></head>
        <body>
          <nav>Home About Contact</nav>
          <article>
            <p>The first paragraph.</p>
            <aside>Related links</aside>
            <p>The second   paragraph.</p>
            <script>tracking()</script>
          </article>
          <footer>Copyright</footer>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/story")

      assert scrape.content_text == "The first paragraph. The second paragraph."
      refute scrape.content_text_truncated
      assert scrape.raw_metadata["sources"]["content_text"] == "article"
    end

    test "falls back to the body when the document names no main content" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><meta property="og:title" content="Soup"></head>
        <body><nav>Menu</nav><div>Some words</div><footer>Copyright</footer></body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/soup")

      assert scrape.content_text == "Some words"
      assert scrape.raw_metadata["sources"]["content_text"] == "body"
    end

    test "stores an excerpt and word count from the article body" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><title>Article title</title></head>
        <body>
          <article>
            <p>The newsroom did not ship a meta description, but the article has a
            useful opening paragraph for the chat card.</p>
            <p>More reporting follows after the lead.</p>
          </article>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/body-summary")

      assert scrape.metadata.title == "Article title"
      assert scrape.excerpt =~ "The newsroom did not ship a meta description"
      assert scrape.content_word_count >= 20
      assert scrape.raw_metadata["sources"]["content_text"] == "article"
    end

    test "uses article heading and image when preview tags are thin" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <body>
          <article>
            <h1>Headline from the story body</h1>
            <img
              srcset="/small.jpg 320w, /images/hero-large.jpg 1200w"
              alt="Flooded avenue after the storm"
              width="1200"
              height="675">
            <p>The page forgot its social tags, but the article itself is usable.</p>
          </article>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/no-head")

      assert scrape.metadata.title == "Headline from the story body"
      assert scrape.metadata.image == "https://example.com/images/hero-large.jpg"
      assert scrape.metadata.image_alt == "Flooded avenue after the storm"
      assert scrape.raw_metadata["sources"]["title"] == "heading"
      assert scrape.raw_metadata["sources"]["image"] == "article_image"
    end

    test "rejects decorative content images instead of publishing a bad thumbnail" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><title>Tokyo feels offshore quake</title></head>
        <body>
          <div id="content">
            <h1>Tokyo feels offshore quake</h1>
            <p>The article text is useful enough to publish even when the page has
            no trustworthy representative image.</p>
            <div id="appDownload">
              <img src="/fileftp/2026/08/qr.png" width="1200" height="675">
            </div>
            <div class="recommend-list">
              <img src="/images/related-story.jpg" width="1200" height="675">
            </div>
          </div>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/no-good-image")

      refute Map.has_key?(scrape.metadata, :image)
      assert scrape.raw_metadata["image_selection"]["selected"] == nil

      rejected =
        scrape.raw_metadata["image_selection"]["candidates"]
        |> Enum.map(& &1["rejected"])

      assert "decorative_container:download" in rejected
      assert "decorative_marker:related" in rejected
    end

    test "uses an RSS feed image hint ahead of weak document fallbacks" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><title>Feed supplied the photo</title></head>
        <body>
          <div id="content">
            <h1>Feed supplied the photo</h1>
            <p>The article has no social image but the feed carried the story photo.</p>
            <img src="/body/fallback.jpg" width="1200" height="675">
          </div>
        </body>
        """)
      end)

      assert {:ok, scrape} =
               HTTP.scrape("https://example.com/feed-hint",
                 metadata_hints: %{
                   image: "https://example.com/feed-photo.jpg",
                   image_alt: "Rescue workers on a flooded avenue",
                   image_source: "media_content"
                 }
               )

      assert scrape.metadata.image == "https://example.com/feed-photo.jpg"
      assert scrape.metadata.image_alt == "Rescue workers on a flooded avenue"
      assert scrape.raw_metadata["sources"]["image"] == "feed_media"
      assert scrape.raw_metadata["image_selection"]["selected"]["source"] == "feed_media"
      assert scrape.raw_metadata["image_selection"]["selected"]["selector"] == "media_content"
    end

    test "uses rich RSS feed hints when the page itself is thin" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <body><main><p>Login required.</p></main></body>
        """)
      end)

      published_at = ~U[2026-08-20 12:00:00Z]

      assert {:ok, scrape} =
               HTTP.scrape("https://example.com/feed-rich",
                 metadata_hints: %{
                   title: "Feed supplied title",
                   description: "Feed supplied a useful summary for the chat card.",
                   content_text:
                     "Feed paragraph one with real article context. Feed paragraph two has more detail.",
                   author: "Lia Reporter",
                   published_at: published_at,
                   tags: ["World", "Asia"],
                   feed_item: %{
                     "title" => "Feed supplied title",
                     "link" => "https://example.com/feed-rich",
                     "description" => "Feed supplied a useful summary for the chat card.",
                     "content_text" =>
                       "Feed paragraph one with real article context. Feed paragraph two has more detail.",
                     "author" => "Lia Reporter",
                     "categories" => ["World", "Asia"]
                   }
                 }
               )

      assert scrape.metadata.title == "Feed supplied title"
      assert scrape.metadata.description == "Feed supplied a useful summary for the chat card."
      assert scrape.author == "Lia Reporter"
      assert scrape.published_at == published_at
      assert scrape.tags == ["World", "Asia"]
      assert scrape.content_text =~ "Feed paragraph one"
      assert scrape.raw_metadata["sources"]["title"] == "feed_item"
      assert scrape.raw_metadata["sources"]["description"] == "feed_item"
      assert scrape.raw_metadata["sources"]["content_text"] == "feed_item"
      assert scrape.raw_metadata["feed_item"]["title"] == "Feed supplied title"
      assert scrape.raw_metadata["feed_item"]["categories"] == ["World", "Asia"]
    end

    test "caps a very long article and says so" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><meta property="og:title" content="Long"></head>
        <body><main><p>#{String.duplicate("word ", 50_000)}</p></main></body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/long")

      assert String.length(scrape.content_text) == 200_000
      assert scrape.content_text_truncated
      assert scrape.content_word_count == 50_000
    end

    test "stores news fields from article metadata" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="Structured field story">
          <meta property="article:modified_time" content="2026-08-20T12:30:00Z">
          <meta property="article:section" content="Climate">
          <meta property="article:tag" content="storms">
          <meta property="article:tag" content="infrastructure">
          <meta name="keywords" content="flooding, city planning">
          <script type="application/ld+json">
            {
              "@type": "NewsArticle",
              "keywords": ["resilience", "weather"],
              "image": {
                "url": "https://example.com/field.jpg",
                "caption": "Residents clearing a street"
              }
            }
          </script>
        </head>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/fields")

      assert scrape.modified_at == ~U[2026-08-20 12:30:00Z]
      assert scrape.section == "Climate"
      assert "storms" in scrape.tags
      assert "city planning" in scrape.tags
      assert "resilience" in scrape.tags
      assert scrape.metadata.image_alt == "Residents clearing a street"
    end

    test "reads generic publisher metadata beyond Open Graph" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta name="parsely-title" content="Parsely title">
          <meta name="sailthru.description" content="Sailthru summary">
          <meta name="parsely-author" content="Nina Reporter">
          <meta name="parsely-pub-date" content="2026-08-20T10:30:00Z">
          <meta name="parsely-section" content="World">
          <meta name="parsely-tags" content="diplomacy, elections">
          <meta name="sailthru.image.full" content="https://example.com/parsely.jpg">
        </head>
        <body><p>Short body.</p></body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/publisher-metadata")

      assert scrape.metadata.title == "Parsely title"
      assert scrape.metadata.description == "Sailthru summary"
      assert scrape.metadata.image == "https://example.com/parsely.jpg"
      assert scrape.author == "Nina Reporter"
      assert scrape.published_at == ~U[2026-08-20 10:30:00Z]
      assert scrape.section == "World"
      assert "diplomacy" in scrape.tags
      assert "elections" in scrape.tags
      assert scrape.raw_metadata["sources"]["title"] == "parsely"
      assert scrape.raw_metadata["sources"]["description"] == "sailthru"
      assert scrape.raw_metadata["quality"]["image_selected_source"] == "sailthru"
    end

    test "uses JSON-LD articleBody as same-hit content when it is richer" do
      body = Enum.map_join(1..160, " ", fn index -> "jsonld#{index}" end)

      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <script type="application/ld+json">
            {
              "@type": "NewsArticle",
              "headline": "Story body from JSON-LD",
              "articleBody": "#{body}"
            }
          </script>
        </head>
        <body><main><p>Thin page body.</p></main></body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/jsonld-body")

      assert scrape.metadata.title == "Story body from JSON-LD"
      assert scrape.content_text =~ "jsonld1"
      assert scrape.content_word_count == 160
      assert scrape.raw_metadata["sources"]["content_text"] == "json_ld_article_body"
      assert scrape.raw_metadata["quality"]["content_strategy"] == "json_ld_article_body"
    end

    test "reads microdata article fields from the document body" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <body>
          <article itemscope itemtype="https://schema.org/NewsArticle">
            <h1 itemprop="headline">Microdata headline</h1>
            <meta itemprop="description" content="Microdata summary">
            <meta itemprop="datePublished" content="2026-08-20T09:00:00Z">
            <span itemprop="author" itemscope itemtype="https://schema.org/Person">
              <span itemprop="name">Mira Writer</span>
            </span>
            <meta itemprop="keywords" content="science, climate">
            <img itemprop="image" src="/microdata.jpg" width="1200" height="675">
            <div itemprop="articleBody">
              <p>Microdata paragraph one has useful context.</p>
              <p>Microdata paragraph two keeps the article readable.</p>
            </div>
          </article>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/microdata")

      assert scrape.metadata.title == "Microdata headline"
      assert scrape.metadata.description == "Microdata summary"
      assert scrape.metadata.image == "https://example.com/microdata.jpg"
      assert scrape.author == "Mira Writer"
      assert scrape.published_at == ~U[2026-08-20 09:00:00Z]
      assert "science" in scrape.tags
      assert "climate" in scrape.tags
      assert scrape.content_text =~ "Microdata paragraph one"
      assert scrape.raw_metadata["sources"]["title"] == "microdata"
      assert scrape.raw_metadata["sources"]["content_text"] == "microdata_article_body"
    end

    test "chooses a dense readability candidate over noisy body text" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head><title>Readable page</title></head>
        <body>
          <div class="menu">
            <a href="/a">Home</a><a href="/b">Topics</a><a href="/c">Subscribe</a>
          </div>
          <div class="story-content">
            <p>The first reported paragraph carries the actual story, with names,
            places, and enough punctuation to look like prose.</p>
            <p>The second paragraph continues the report with details readers can
            use in the chat card.</p>
          </div>
        </body>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/readability")

      assert scrape.content_text =~ "The first reported paragraph"
      refute scrape.content_text =~ "Home Topics Subscribe"
      assert scrape.raw_metadata["sources"]["content_text"] == "readability"
    end

    test "records who each preview field came from" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <title>HTML title</title>
          <meta name="twitter:title" content="Card title">
          <meta property="og:description" content="OG description">
          <link rel="canonical" href="https://example.com/canonical">
        </head>
        """)
      end)

      assert {:ok, %{raw_metadata: raw}} = HTTP.scrape("https://example.com/story")

      assert raw["sources"]["title"] == "twitter"
      assert raw["sources"]["description"] == "og"
      assert raw["sources"]["url"] == "canonical"
      assert raw["og"]["og:description"] == "OG description"
      assert raw["twitter"]["twitter:title"] == "Card title"
    end

    test "survives a publisher that nests an object where the schema says string" do
      # Real pages do this constantly — `"author": {"@id": "..."}` and
      # `"author": [{...}]` are both valid JSON-LD. Converting one to a string
      # raised, and the caller reported the page as unreachable.
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="Nested author">
          <script type="application/ld+json">
            {"@type": "NewsArticle",
             "author": [{"@type": "Person", "name": "Ada Lovelace", "@id": "#ada"}],
             "inLanguage": ["en-GB", "en"]}
          </script>
        </head>
        """)
      end)

      assert {:ok, scrape} = HTTP.scrape("https://example.com/nested")

      assert scrape.metadata.title == "Nested author"
      assert scrape.author == "Ada Lovelace"
      assert scrape.lang == "en-GB"
    end

    test "preserves the status code that decides whether a retry is worth it" do
      Req.Test.expect(__MODULE__, fn conn -> Plug.Conn.resp(conn, 503, "unavailable") end)

      assert {:error, {:http_status, 503}} = HTTP.scrape("https://example.com/unavailable")
    end
  end
end
