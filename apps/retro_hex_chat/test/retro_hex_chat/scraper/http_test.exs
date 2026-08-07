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
