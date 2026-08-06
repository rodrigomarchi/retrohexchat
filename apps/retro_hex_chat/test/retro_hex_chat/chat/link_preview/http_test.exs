defmodule RetroHexChat.Chat.LinkPreview.HTTPTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Chat.LinkPreview.HTTP

  @moduletag :unit

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.delete_env(:retro_hex_chat, :link_preview_req_options)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :link_preview_req_options)
    end)

    :ok
  end

  describe "parse_title/1" do
    test "extracts title from simple HTML" do
      html = "<html><head><title>Hello World</title></head></html>"
      assert HTTP.parse_title(html) == {:ok, "Hello World"}
    end

    test "extracts title with attributes" do
      html = ~s(<title lang="en">My Page</title>)
      assert HTTP.parse_title(html) == {:ok, "My Page"}
    end

    test "strips whitespace from title" do
      html = "<title>  spaced  title  </title>"
      assert HTTP.parse_title(html) == {:ok, "spaced title"}
    end

    test "handles multiline title" do
      html = "<title>\n  Multi\n  Line\n  Title\n</title>"
      assert HTTP.parse_title(html) == {:ok, "Multi Line Title"}
    end

    test "HTML-escapes title text for the legacy title API" do
      html = "<title>Tom & Jerry < Preview</title>"

      assert HTTP.parse_title(html) ==
               {:ok, "Tom &amp; Jerry &lt; Preview"}
    end

    test "truncates title over 200 chars" do
      long_title = String.duplicate("a", 250)
      {:ok, result} = HTTP.parse_title("<title>#{long_title}</title>")
      assert String.length(result) == 203
      assert String.ends_with?(result, "...")
    end

    test "returns error for no title tag" do
      html = "<html><head></head></html>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "returns error for empty title" do
      html = "<title></title>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "returns error for whitespace-only title" do
      html = "<title>   </title>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "case insensitive title tag" do
      html = "<TITLE>My Title</TITLE>"
      assert HTTP.parse_title(html) == {:ok, "My Title"}
    end
  end

  describe "parse_metadata/2" do
    test "prefers Open Graph metadata" do
      html = """
      <html>
        <head>
          <title>Fallback title</title>
          <meta property="og:title" content="OG &amp; Title">
          <meta property="og:description" content="OG description">
          <meta property="og:image" content="/images/story.png">
          <meta property="og:url" content="/story">
          <meta property="og:site_name" content="Example News">
        </head>
      </html>
      """

      assert {:ok, metadata} = HTTP.parse_metadata(html, "https://example.com/posts/1")
      assert metadata.title == "OG & Title"
      assert metadata.description == "OG description"
      assert metadata.image == "https://example.com/images/story.png"
      assert metadata.url == "https://example.com/story"
      assert metadata.site_name == "Example News"
    end

    test "uses Twitter/X cards before plain HTML fallbacks" do
      html = """
      <head>
        <title>Fallback</title>
        <meta name="description" content="Plain description">
        <meta name="twitter:title" content="Card title">
        <meta name="twitter:description" content="Card description">
        <meta name="twitter:image" content="https://example.com/card.jpg">
      </head>
      """

      assert {:ok, metadata} = HTTP.parse_metadata(html, "https://example.com/story")
      assert metadata.title == "Card title"
      assert metadata.description == "Card description"
      assert metadata.image == "https://example.com/card.jpg"
    end

    test "uses Schema.org JSON-LD when social tags are missing" do
      html = """
      <head>
        <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "NewsArticle",
            "headline": "Structured headline",
            "description": "Structured description",
            "image": {"url": "https://example.com/structured.webp"},
            "publisher": {"name": "Structured Daily"}
          }
        </script>
      </head>
      """

      assert {:ok, metadata} = HTTP.parse_metadata(html, "https://example.com/story")
      assert metadata.title == "Structured headline"
      assert metadata.description == "Structured description"
      assert metadata.image == "https://example.com/structured.webp"
      assert metadata.site_name == "Structured Daily"
    end

    test "uses title, meta description and canonical as final HTML fallback" do
      html = """
      <head>
        <title>Plain title</title>
        <meta name="description" content="Plain description">
        <link rel="canonical" href="https://example.com/canonical">
      </head>
      """

      assert {:ok, metadata} = HTTP.parse_metadata(html, "https://example.com/story")
      assert metadata.title == "Plain title"
      assert metadata.description == "Plain description"
      assert metadata.url == "https://example.com/canonical"
    end

    test "drops private preview images" do
      html = """
      <head>
        <meta property="og:title" content="Private image">
        <meta property="og:image" content="http://127.0.0.1/private.png">
      </head>
      """

      assert {:ok, metadata} = HTTP.parse_metadata(html, "https://example.com/story")
      assert metadata.title == "Private image"
      refute Map.has_key?(metadata, :image)
    end
  end

  describe "fetch_metadata/1" do
    setup do
      Application.put_env(:retro_hex_chat, :link_preview_req_options,
        plug: {Req.Test, __MODULE__}
      )

      :ok
    end

    test "fetches metadata through the configured request adapter" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, """
        <head>
          <meta property="og:title" content="Fetched title">
          <meta property="og:description" content="Fetched description">
        </head>
        """)
      end)

      assert {:ok, metadata} = HTTP.fetch_metadata("https://example.com/story")
      assert metadata.title == "Fetched title"
      assert metadata.description == "Fetched description"
    end

    test "follows oEmbed discovery when the page is incomplete" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case conn.request_path do
          "/story" ->
            Req.Test.html(conn, """
            <head>
              <link
                rel="alternate"
                type="application/json+oembed"
                href="https://example.com/oembed?url=https%3A%2F%2Fexample.com%2Fstory">
            </head>
            """)

          "/oembed" ->
            Req.Test.json(conn, %{
              title: "oEmbed title",
              provider_name: "Video Provider",
              thumbnail_url: "https://example.com/thumb.jpg"
            })
        end
      end)

      assert {:ok, metadata} = HTTP.fetch_metadata("https://example.com/story")
      assert metadata.title == "oEmbed title"
      assert metadata.site_name == "Video Provider"
      assert metadata.image == "https://example.com/thumb.jpg"
    end

    test "follows oEmbed discovery from an HTTP Link header" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case conn.request_path do
          "/story" ->
            conn
            |> Plug.Conn.put_resp_header(
              "link",
              ~s(<https://example.com/oembed?url=https%3A%2F%2Fexample.com%2Fstory>; rel="alternate"; type="application/json+oembed")
            )
            |> Req.Test.html("<head></head>")

          "/oembed" ->
            Req.Test.json(conn, %{
              title: "Header oEmbed title",
              provider_name: "Header Provider",
              thumbnail_url: "https://example.com/header-thumb.jpg"
            })
        end
      end)

      assert {:ok, metadata} = HTTP.fetch_metadata("https://example.com/story")
      assert metadata.title == "Header oEmbed title"
      assert metadata.site_name == "Header Provider"
      assert metadata.image == "https://example.com/header-thumb.jpg"
    end

    test "does not read unbounded HTML bodies looking for late metadata" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.html(conn, String.duplicate("x", 260_000) <> "<title>Too late</title>")
      end)

      assert {:error, :no_metadata} = HTTP.fetch_metadata("https://example.com/late")
    end

    test "validates redirect targets before following them" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.redirect(conn, external: "http://127.0.0.1/private")
      end)

      assert {:error, :blocked} = HTTP.fetch_metadata("https://example.com/redirect")
    end

    test "refuses private initial URLs" do
      assert {:error, :blocked} = HTTP.fetch_metadata("http://127.0.0.1/story")
    end

    test "fetch_title_result preserves retryable HTTP status codes for workers" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        Plug.Conn.resp(conn, 503, "service unavailable")
      end)

      assert {:error, {:http_status, 503}} =
               HTTP.fetch_title_result("https://example.com/unavailable")

      assert {:error, :server_error} = HTTP.fetch_title("https://example.com/unavailable")
    end

    test "fetch_title_result preserves non-retryable HTTP status codes for workers" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        Plug.Conn.resp(conn, 404, "not found")
      end)

      assert {:error, {:http_status, 404}} =
               HTTP.fetch_title_result("https://example.com/missing")

      assert {:error, :not_found} = HTTP.fetch_title("https://example.com/missing")
    end
  end
end
