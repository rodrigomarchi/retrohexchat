defmodule RetroHexChat.Chat.URLDetectorTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.URLDetector

  @moduletag :unit

  describe "extract_urls/1" do
    test "detects simple https URL" do
      assert URLDetector.extract_urls("check https://example.com out") == ["https://example.com"]
    end

    test "detects simple http URL" do
      assert URLDetector.extract_urls("visit http://example.com") == ["http://example.com"]
    end

    test "detects URL with path" do
      assert URLDetector.extract_urls("see https://example.com/path/to/page") ==
               ["https://example.com/path/to/page"]
    end

    test "detects URL with query params and fragment" do
      assert URLDetector.extract_urls("link https://example.com/path?q=test&page=2#section") ==
               ["https://example.com/path?q=test&page=2#section"]
    end

    test "trims trailing period" do
      assert URLDetector.extract_urls("visit https://example.com.") == ["https://example.com"]
    end

    test "trims trailing comma" do
      assert URLDetector.extract_urls("see https://example.com, and more") ==
               ["https://example.com"]
    end

    test "trims trailing exclamation mark" do
      assert URLDetector.extract_urls("check https://example.com!") == ["https://example.com"]
    end

    test "trims trailing question mark (not part of query)" do
      assert URLDetector.extract_urls("is it https://example.com?") == ["https://example.com"]
    end

    test "preserves question mark in query string" do
      assert URLDetector.extract_urls("link https://example.com?q=hello") ==
               ["https://example.com?q=hello"]
    end

    test "trims trailing colon" do
      assert URLDetector.extract_urls("see https://example.com:") == ["https://example.com"]
    end

    test "trims trailing semicolon" do
      assert URLDetector.extract_urls("see https://example.com;") == ["https://example.com"]
    end

    test "handles balanced parentheses (Wikipedia style)" do
      url = "https://en.wikipedia.org/wiki/Elixir_(programming_language)"

      assert URLDetector.extract_urls("see #{url}") == [url]
    end

    test "trims unbalanced closing parenthesis" do
      assert URLDetector.extract_urls("(see https://example.com)") == ["https://example.com"]
    end

    test "handles balanced brackets" do
      assert URLDetector.extract_urls("see https://example.com/path[1]") ==
               ["https://example.com/path[1]"]
    end

    test "trims unbalanced closing bracket" do
      assert URLDetector.extract_urls("[see https://example.com]") == ["https://example.com"]
    end

    test "detects multiple URLs" do
      text = "links: https://a.com and https://b.com"
      assert URLDetector.extract_urls(text) == ["https://a.com", "https://b.com"]
    end

    test "detects URL with port number" do
      assert URLDetector.extract_urls("see http://localhost:4000/path") ==
               ["http://localhost:4000/path"]
    end

    test "returns empty list for no URLs" do
      assert URLDetector.extract_urls("no urls here") == []
    end

    test "returns empty list for empty string" do
      assert URLDetector.extract_urls("") == []
    end

    test "does not detect bare domains" do
      assert URLDetector.extract_urls("visit example.com") == []
    end

    test "URL-only message" do
      assert URLDetector.extract_urls("https://example.com") == ["https://example.com"]
    end

    test "handles IRC format codes in input" do
      # Bold control code around URL
      assert URLDetector.extract_urls("\x02https://example.com\x02") == ["https://example.com"]
    end

    test "handles color codes around URL" do
      # Color code 04 (red) around URL
      assert URLDetector.extract_urls("\x0304https://example.com\x03") == ["https://example.com"]
    end

    test "case insensitive scheme detection" do
      assert URLDetector.extract_urls("see HTTPS://EXAMPLE.COM") == ["HTTPS://EXAMPLE.COM"]
    end

    test "URL with encoded characters" do
      assert URLDetector.extract_urls("see https://example.com/path%20with%20spaces") ==
               ["https://example.com/path%20with%20spaces"]
    end

    test "URL with @ symbol" do
      assert URLDetector.extract_urls("see https://user@example.com/path") ==
               ["https://user@example.com/path"]
    end

    test "URL ending with slash" do
      assert URLDetector.extract_urls("see https://example.com/") == ["https://example.com/"]
    end

    test "multiple trailing punctuation trimmed" do
      assert URLDetector.extract_urls("see https://example.com...") == ["https://example.com"]
    end

    test "URL in parenthetical sentence" do
      assert URLDetector.extract_urls("(visit https://example.com/page for more)") ==
               ["https://example.com/page"]
    end

    test "nested parentheses in URL preserved" do
      url = "https://example.com/a(b(c))"

      assert URLDetector.extract_urls("see #{url}") == [url]
    end
  end

  describe "linkify/1" do
    test "wraps URL in anchor tag with correct attributes" do
      result = URLDetector.linkify("see https://example.com here")

      assert result =~ ~s(<a href="https://example.com")
      assert result =~ ~s(target="_blank")
      assert result =~ ~s(rel="noopener noreferrer")
      assert result =~ ~s(class="chat-link")
      assert result =~ ~s(title="https://example.com")
    end

    test "HTML-escapes non-URL text" do
      result = URLDetector.linkify("<b>see</b> https://example.com")

      assert result =~ "&lt;b&gt;see&lt;/b&gt;"
      assert result =~ ~s(<a href="https://example.com")
    end

    test "handles multiple URLs" do
      result = URLDetector.linkify("a https://a.com b https://b.com c")

      assert result =~ ~s(href="https://a.com")
      assert result =~ ~s(href="https://b.com")
    end

    test "truncates display text for URLs over 100 chars" do
      long_path = String.duplicate("a", 90)
      url = "https://example.com/#{long_path}"
      result = URLDetector.linkify("see #{url}")

      # href should have full URL
      assert result =~ ~s(href="#{url}")
      # Display text should be truncated
      assert result =~ "..."
      # Title should have full URL
      assert result =~ ~s(title="#{url}")
    end

    test "does not truncate URLs exactly 100 chars" do
      # Build a URL that is exactly 100 chars
      base = "https://example.com/"
      padding = String.duplicate("x", 100 - String.length(base))
      url = base <> padding
      assert String.length(url) == 100

      result = URLDetector.linkify(url)

      refute result =~ "..."
    end

    test "returns HTML-escaped text when no URLs" do
      assert URLDetector.linkify("hello <world>") == "hello &lt;world&gt;"
    end

    test "returns empty string for empty input" do
      assert URLDetector.linkify("") == ""
    end

    test "URL-only input becomes a single link" do
      result = URLDetector.linkify("https://example.com")

      assert result =~ ~s(<a href="https://example.com")
      refute result =~ "&amp;"
    end

    test "escapes ampersand in surrounding text but not in href" do
      result = URLDetector.linkify("a & b https://example.com?a=1&b=2 c")

      assert result =~ "a &amp; b"
      assert result =~ ~s(href="https://example.com?a=1&amp;b=2")
    end
  end

  describe "linkify_html/1" do
    test "wraps URL text in anchor tag within span" do
      html = ~s(<span class="irc-bold">see https://example.com here</span>)
      result = URLDetector.linkify_html(html)

      assert result =~ ~s(<a href="https://example.com")
      assert result =~ ~s(class="chat-link")
      assert result =~ ~s(target="_blank")
    end

    test "preserves existing span classes" do
      html = ~s(<span class="irc-bold">https://example.com</span>)
      result = URLDetector.linkify_html(html)

      assert result =~ "irc-bold"
      assert result =~ ~s(href="https://example.com")
    end

    test "handles plain text without spans" do
      result = URLDetector.linkify_html("see https://example.com here")

      assert result =~ ~s(<a href="https://example.com")
    end

    test "handles multiple URLs in formatted HTML" do
      html =
        ~s(<span class="irc-bold">https://a.com</span> and <span>https://b.com</span>)

      result = URLDetector.linkify_html(html)

      assert result =~ ~s(href="https://a.com")
      assert result =~ ~s(href="https://b.com")
    end

    test "truncates long URLs in HTML context" do
      long_path = String.duplicate("a", 90)
      url = "https://example.com/#{long_path}"
      html = ~s(<span>#{url}</span>)
      result = URLDetector.linkify_html(html)

      assert result =~ ~s(href="#{url}")
      assert result =~ "..."
    end

    test "returns unchanged HTML when no URLs" do
      html = ~s(<span class="irc-bold">hello world</span>)
      assert URLDetector.linkify_html(html) == html
    end

    test "returns empty string for empty input" do
      assert URLDetector.linkify_html("") == ""
    end
  end

  describe "extract_urls/1 property-based" do
    use ExUnit.Case
    use ExUnitProperties

    property "every returned URL starts with http:// or https://" do
      check all(text <- string(:printable, min_length: 0, max_length: 500)) do
        urls = URLDetector.extract_urls(text)

        for url <- urls do
          assert String.starts_with?(url, "http://") or String.starts_with?(url, "https://"),
                 "URL #{inspect(url)} doesn't start with http(s)://"
        end
      end
    end

    property "returned URLs do not end with common trailing punctuation" do
      check all(text <- string(:printable, min_length: 0, max_length: 500)) do
        urls = URLDetector.extract_urls(text)

        for url <- urls do
          last_char = String.last(url)

          refute last_char in [".", ",", "!", ";"],
                 "URL #{inspect(url)} ends with trailing punctuation #{inspect(last_char)}"
        end
      end
    end

    property "URLs with embedded scheme are always found" do
      check all(
              prefix <- string(:alphanumeric, min_length: 0, max_length: 10),
              domain <- string(:alphanumeric, min_length: 1, max_length: 20),
              suffix <- string(:alphanumeric, min_length: 0, max_length: 10)
            ) do
        url = "https://#{domain}.com"
        text = "#{prefix} #{url} #{suffix}"
        urls = URLDetector.extract_urls(text)

        assert url in urls,
               "Expected #{inspect(url)} in #{inspect(urls)} from text #{inspect(text)}"
      end
    end
  end
end
