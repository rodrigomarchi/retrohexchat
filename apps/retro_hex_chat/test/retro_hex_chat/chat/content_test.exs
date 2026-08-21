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

    test "renders Markdown images inline with browser hardening" do
      rendered =
        html(Content.render_html("![diagram](https://example.com/diagram.png)", :markdown))

      assert rendered =~ ~s(<span class="chat-markdown-image-shell" data-image-state="loading">)
      assert rendered =~ "<img"
      assert rendered =~ ~s(src="https://example.com/diagram.png")
      assert rendered =~ ~s(alt="diagram")
      assert rendered =~ ~s(loading="lazy")
      assert rendered =~ ~s(decoding="async")
      assert rendered =~ ~s(referrerpolicy="no-referrer")
      assert rendered =~ ~s(class="chat-markdown-image")
    end

    test "omits dangerous Markdown image URLs" do
      rendered = html(Content.render_html("![bad](javascript:alert(1))", :markdown))

      refute rendered =~ "javascript:"
      refute rendered =~ "<img"
      assert rendered =~ "bad"
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

  describe "reply_preview/1" do
    test "takes already-visible text as it stands" do
      assert Content.reply_preview(%{plain_content: "just text"}) == "just text"
    end

    test "renders formatted content down before quoting it" do
      assert Content.reply_preview(%{content: "**bold**", content_format: :markdown}) == "bold"

      assert Content.reply_preview(%{content: "#{@bold}bold#{@bold}", content_format: :irc}) ==
               "bold"
    end

    test "cuts a long quote so the ellipsis fits inside the budget" do
      preview = Content.reply_preview(%{plain_content: String.duplicate("a", 200)})

      assert String.length(preview) == 100
      assert String.ends_with?(preview, "...")
    end

    test "leaves a quote exactly at the budget uncut" do
      exact = String.duplicate("a", 100)

      assert Content.reply_preview(%{plain_content: exact}) == exact
    end

    test "cuts a formatted quote to the same width" do
      preview =
        Content.reply_preview(%{content: String.duplicate("b", 200), content_format: :plain})

      assert String.length(preview) == 100
      assert String.ends_with?(preview, "...")
    end

    test "quotes empty content as nothing" do
      assert Content.reply_preview(%{plain_content: ""}) == ""
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

  describe "validate_message/4" do
    setup do
      original = Gettext.get_locale(RetroHexChat.Gettext)
      on_exit(fn -> Gettext.put_locale(RetroHexChat.Gettext, original) end)
      :ok
    end

    test "says nothing about a message that is fine" do
      assert Content.validate_message("hello", :irc) == :ok
    end

    test "refuses an empty message" do
      assert {:error, message} = Content.validate_message("   ", :irc)
      assert message =~ "empty"
    end

    # The one exemption every sender makes, and the reason this wrapper exists
    # rather than each of them repeating it.
    test "allows an empty message that carries an attachment" do
      assert Content.validate_message("", :irc, [1]) == :ok
    end

    test "says how long is too long, with the limit in the sentence" do
      long = String.duplicate("x", 1001)

      assert {:error, message} = Content.validate_message(long, :irc)
      assert message =~ "1000"
    end

    # This was the one sentence of the four that nobody translated, in both
    # copies of this function, so a Portuguese server answered it in English.
    test "and says it in the reader's language" do
      long = String.duplicate("x", 1001)

      Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")

      assert {:error, message} = Content.validate_message(long, :irc)
      refute message =~ "exceeds maximum length"
      assert message =~ "1000"
    end

    test "refuses a format it does not know" do
      assert {:error, message} = Content.validate_message("hello", "brainfuck")
      assert message =~ "format"
    end
  end

  defp html({:safe, safe}), do: safe
end
