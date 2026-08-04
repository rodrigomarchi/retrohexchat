defmodule RetroHexChat.Chat.ContentTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Content, Formatter}

  @bold <<0x02>>
  @color <<0x03>>

  describe "render_html/3" do
    test "delegates IRC rendering without changing formatter output" do
      content = "#{@bold}bold#{@bold} #{@color}4red#{@color} <tag>"

      assert html(Content.render_html(content, :irc)) == html(Formatter.to_safe_html(content))
    end

    test "renders plain content as escaped safe HTML" do
      rendered = html(Content.render_html("hello <script>alert(1)</script>", :plain))

      assert rendered =~ "hello"
      assert rendered =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
      refute rendered =~ "<script>"
    end

    test "renders Markdown blocks and inline formatting" do
      rendered =
        """
        **bold** _em_ `code`

        > quote

        - one
        - two

        ```elixir
        IO.puts(:ok)
        ```
        """
        |> Content.render_html(:markdown)
        |> html()

      assert rendered =~ "<strong>bold</strong>"
      assert rendered =~ "<em>em</em>"
      assert rendered =~ "<code>code</code>"
      assert rendered =~ "<blockquote>"
      assert rendered =~ "<ul>"
      assert rendered =~ "<li>one</li>"
      assert rendered =~ "<pre"
      assert rendered =~ "IO.puts"
    end

    test "hardens Markdown links for chat navigation" do
      rendered = html(Content.render_html("[docs](https://example.com?a=1&b=2)", :markdown))

      assert rendered =~ ~s(href="https://example.com?a=1&amp;b=2")
      assert rendered =~ ~s(data-url="https://example.com?a=1&amp;b=2")
      assert rendered =~ ~s(target="_blank")
      assert rendered =~ ~s(rel="noopener noreferrer")
    end

    test "does not render Markdown images inline" do
      rendered =
        html(Content.render_html("![diagram](https://example.com/diagram.png)", :markdown))

      refute rendered =~ "<img"
      assert rendered =~ "diagram"
      assert rendered =~ "https://example.com/diagram.png"
    end

    test "sanitizes dangerous Markdown and raw HTML payloads" do
      rendered =
        """
        <script>alert(1)</script>

        <img src=x onerror=alert(1)>

        [bad](javascript:alert(1))

        <a href="https://example.com" onclick="alert(1)">raw link</a>
        """
        |> Content.render_html(:markdown)
        |> html()

      refute rendered =~ "<script"
      refute rendered =~ "<img"
      refute rendered =~ "onerror"
      refute rendered =~ "onclick"
      refute rendered =~ "javascript:"
      assert rendered =~ "bad"
    end
  end

  describe "plain_text/2" do
    test "returns visible IRC text" do
      assert Content.plain_text("#{@bold}bold#{@bold} #{@color}4red#{@color}", :irc) == "bold red"
    end

    test "returns plain text unchanged" do
      assert Content.plain_text("plain <tag>", :plain) == "plain <tag>"
    end

    test "returns visible Markdown text without source markers" do
      assert Content.plain_text("**release** _notes_ and `code`", :markdown) ==
               "release notes and code"
    end
  end

  describe "preview/3" do
    test "builds previews from visible text" do
      assert Content.preview("**abcdef**", :markdown, max_length: 4) == "abcd..."
      assert Content.preview("#{@bold}abcdef#{@bold}", :irc, max_length: 4) == "abcd..."
    end
  end

  describe "validate/3" do
    test "accepts supported visible content" do
      assert Content.validate("hello", :irc) == :ok
      assert Content.validate("**hello**", :markdown) == :ok
      assert Content.validate("hello", :plain) == :ok
    end

    test "rejects unsupported formats" do
      assert Content.validate("hello", :html) == {:error, :unsupported_format}
      assert Content.validate("hello", "html") == {:error, :unsupported_format}
    end

    test "rejects blank visible content" do
      assert Content.validate("#{@bold}#{@color}4", :irc) == {:error, :blank}
      assert Content.validate("   ", :markdown) == {:error, :blank}
    end

    test "rejects content over the configured max length" do
      assert Content.validate("abcd", :plain, max_length: 3) == {:error, :too_long}
    end
  end

  describe "strip_formatting/2" do
    test "removes presentation for every format" do
      assert Content.strip_formatting("#{@bold}bold#{@bold}", :irc) == "bold"

      assert Content.strip_formatting("**bold** [site](https://example.com)", :markdown) ==
               "bold site"

      assert Content.strip_formatting("plain", :plain) == "plain"
    end
  end

  describe "extract_urls/2" do
    test "extracts URLs from IRC text" do
      assert Content.extract_urls("#{@bold}https://example.com#{@bold}", :irc) == [
               "https://example.com"
             ]
    end

    test "extracts URLs from Markdown links and bare URLs" do
      assert Content.extract_urls(
               "[site](https://example.com/path?q=1) and https://hex.pm",
               :markdown
             ) == [
               "https://example.com/path?q=1",
               "https://hex.pm"
             ]
    end

    test "does not extract Markdown URLs rendered inside code" do
      markdown = """
      `https://inline.example`

      ```text
      https://block.example
      ```

      [real](https://real.example)
      """

      assert Content.extract_urls(markdown, :markdown) == ["https://real.example"]
    end
  end

  defp html({:safe, safe}), do: safe
end
