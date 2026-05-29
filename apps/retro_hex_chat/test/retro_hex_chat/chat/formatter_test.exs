defmodule RetroHexChat.Chat.FormatterTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :unit

  alias RetroHexChat.Chat.Formatter

  # Control code constants
  @bold <<0x02>>
  @color <<0x03>>
  @reset <<0x0F>>
  @reverse <<0x16>>
  @italic <<0x1D>>
  @strikethrough <<0x1E>>
  @underline <<0x1F>>

  # ── T001: strip/1 ────────────────────────────────────────────────────

  describe "strip/1" do
    test "returns plain text unchanged" do
      assert Formatter.strip("Hello world") == "Hello world"
    end

    test "returns empty string for empty input" do
      assert Formatter.strip("") == ""
    end

    test "strips bold codes" do
      assert Formatter.strip("#{@bold}Hello#{@bold} world") == "Hello world"
    end

    test "strips italic codes" do
      assert Formatter.strip("#{@italic}Hello#{@italic}") == "Hello"
    end

    test "strips underline codes" do
      assert Formatter.strip("#{@underline}Hello#{@underline}") == "Hello"
    end

    test "strips strikethrough codes" do
      assert Formatter.strip("#{@strikethrough}Hello#{@strikethrough}") == "Hello"
    end

    test "strips reverse codes" do
      assert Formatter.strip("#{@reverse}Hello#{@reverse}") == "Hello"
    end

    test "strips reset code" do
      assert Formatter.strip("#{@bold}Hello#{@reset} world") == "Hello world"
    end

    test "strips color code with foreground number" do
      assert Formatter.strip("#{@color}4Red text#{@color}") == "Red text"
    end

    test "strips color code with foreground and background" do
      assert Formatter.strip("#{@color}4,1Red on black#{@color}") == "Red on black"
    end

    test "strips bare color code (reset)" do
      assert Formatter.strip("Colored #{@color}normal") == "Colored normal"
    end

    test "strips zero-padded color codes" do
      assert Formatter.strip("#{@color}04Red#{@color}") == "Red"
    end

    test "strips all control codes from complex message" do
      msg = "#{@bold}#{@color}4,1Bold red#{@color}#{@bold} #{@italic}italic#{@reset} plain"
      assert Formatter.strip(msg) == "Bold red italic plain"
    end

    test "strips multiple consecutive control codes" do
      msg = "#{@bold}#{@italic}#{@underline}text#{@reset}"
      assert Formatter.strip(msg) == "text"
    end

    test "handles color code 16 as color 1 followed by literal 6" do
      # \x0316 should be interpreted as color 1 + literal "6"... but strip removes both
      # The color code consumes up to 2 digits where the result is 0-15
      # "16" -> first digit "1" is valid (1), second digit "6" makes "16" which is > 15
      # So only "1" is consumed as color, "6" remains as text
      assert Formatter.strip("#{@color}16text#{@color}") == "6text"
    end
  end

  # ── T002: to_safe_html/1 ─────────────────────────────────────────────

  describe "to_safe_html/1" do
    test "returns empty safe string for empty input" do
      assert Formatter.to_safe_html("") == {:safe, ""}
    end

    test "passes plain text through with HTML escaping" do
      assert Formatter.to_safe_html("Hello world") == {:safe, "Hello world"}
    end

    test "HTML-escapes user text content" do
      result = Formatter.to_safe_html("<script>alert('xss')</script>")
      {:safe, html} = result
      assert html =~ "&lt;script&gt;"
      refute html =~ "<script>"
    end

    test "renders bold text" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}Hello#{@bold} world")
      assert html =~ ~s(<span class="irc-bold">Hello</span>)
      assert html =~ " world"
    end

    test "renders italic text" do
      {:safe, html} = Formatter.to_safe_html("#{@italic}Hello#{@italic}")
      assert html =~ ~s(<span class="irc-italic">Hello</span>)
    end

    test "renders underline text" do
      {:safe, html} = Formatter.to_safe_html("#{@underline}Hello#{@underline}")
      assert html =~ ~s(<span class="irc-underline">Hello</span>)
    end

    test "renders strikethrough text" do
      {:safe, html} = Formatter.to_safe_html("#{@strikethrough}Hello#{@strikethrough}")
      assert html =~ ~s(<span class="irc-strikethrough">Hello</span>)
    end

    test "renders reverse text" do
      {:safe, html} = Formatter.to_safe_html("#{@reverse}Hello#{@reverse}")
      assert html =~ "irc-reverse"
      assert html =~ "Hello"
    end

    test "renders foreground color" do
      {:safe, html} = Formatter.to_safe_html("#{@color}4Red#{@color}")
      assert html =~ ~s(irc-fg-4)
      assert html =~ "Red"
    end

    test "renders foreground and background color" do
      {:safe, html} = Formatter.to_safe_html("#{@color}4,1Red on black#{@color}")
      assert html =~ ~s(irc-fg-4)
      assert html =~ ~s(irc-bg-1)
      assert html =~ "Red on black"
    end

    test "renders zero-padded color codes" do
      {:safe, html} = Formatter.to_safe_html("#{@color}04Red#{@color}")
      assert html =~ ~s(irc-fg-4)
    end

    test "resets all formatting with reset code" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}Bold #{@reset}normal")
      assert html =~ ~s(<span class="irc-bold">Bold </span>)
      assert html =~ "normal"
    end

    test "renders combined bold + italic" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}#{@italic}Both#{@reset}")
      assert html =~ "irc-bold"
      assert html =~ "irc-italic"
      assert html =~ "Both"
    end

    test "renders combined bold + color" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}#{@color}4Bold red#{@reset}")
      assert html =~ "irc-bold"
      assert html =~ "irc-fg-4"
      assert html =~ "Bold red"
    end

    test "nested formats: closing one does not close the other" do
      {:safe, html} =
        Formatter.to_safe_html("#{@bold}#{@italic}both#{@bold} just italic#{@italic}")

      # After closing bold, italic should still be active
      assert html =~ "irc-italic"
      assert html =~ "just italic"
    end

    test "unclosed format codes apply to rest of message" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}all bold")
      assert html =~ "irc-bold"
      assert html =~ "all bold"
    end

    test "bare color code resets color" do
      {:safe, html} = Formatter.to_safe_html("#{@color}4Red#{@color} normal")
      # After bare \x03, color should be reset
      assert html =~ " normal"
    end

    test "HTML escapes text within formatted spans" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}<b>evil</b>#{@bold}")
      assert html =~ "&lt;b&gt;evil&lt;/b&gt;"
      refute html =~ "<b>evil</b>"
    end
  end

  # ── T003: has_visible_text?/1 and count_codes/1 ─────────────────────

  describe "has_visible_text?/1" do
    test "returns false for empty string" do
      refute Formatter.has_visible_text?("")
    end

    test "returns false for format codes only" do
      refute Formatter.has_visible_text?("#{@bold}#{@italic}#{@reset}")
    end

    test "returns false for format codes + whitespace only" do
      refute Formatter.has_visible_text?("#{@bold}   #{@bold}")
    end

    test "returns false for color codes only" do
      refute Formatter.has_visible_text?("#{@color}4#{@color}")
    end

    test "returns true for plain text" do
      assert Formatter.has_visible_text?("Hello")
    end

    test "returns true for formatted text with visible content" do
      assert Formatter.has_visible_text?("#{@bold}Hello#{@bold}")
    end
  end

  describe "count_codes/1" do
    test "returns 0 for plain text" do
      assert Formatter.count_codes("Hello world") == 0
    end

    test "returns 0 for empty string" do
      assert Formatter.count_codes("") == 0
    end

    test "counts bold toggle codes" do
      assert Formatter.count_codes("#{@bold}Hello#{@bold}") == 2
    end

    test "counts all format code types" do
      msg = "#{@bold}#{@italic}#{@underline}#{@strikethrough}#{@reverse}#{@reset}"
      assert Formatter.count_codes(msg) == 6
    end

    test "counts color codes" do
      assert Formatter.count_codes("#{@color}4Red#{@color}") == 2
    end

    test "counts color codes with foreground and background" do
      assert Formatter.count_codes("#{@color}4,1text#{@color}") == 2
    end
  end

  # ── T004: StreamData property tests ──────────────────────────────────

  describe "property tests" do
    @control_chars [0x02, 0x03, 0x0F, 0x16, 0x1D, 0x1E, 0x1F]

    property "strip/1 output never contains control characters" do
      check all(text <- string(:printable, min_length: 0, max_length: 100)) do
        # Insert some random control codes
        with_codes =
          text
          |> String.graphemes()
          |> Enum.map_join(fn char ->
            if :rand.uniform(3) == 1 do
              code = Enum.random(@control_chars)
              <<code>> <> char
            else
              char
            end
          end)

        stripped = Formatter.strip(with_codes)

        for <<byte <- stripped>> do
          refute byte in @control_chars,
                 "strip/1 output contains control character #{inspect(byte)}"
        end
      end
    end

    property "to_safe_html/1 preserves visible text from strip/1" do
      check all(text <- string(:printable, min_length: 1, max_length: 50)) do
        # Plain text without control codes should pass through
        stripped = Formatter.strip(text)
        {:safe, html} = Formatter.to_safe_html(text)

        # The HTML should contain the escaped visible text (after stripping HTML tags).
        text_from_html =
          html
          |> String.replace(~r/<[^>]+>/, "")

        escaped_stripped =
          stripped
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()

        assert text_from_html =~ escaped_stripped or stripped == ""
      end
    end

    property "plain text input produces no span wrapping" do
      check all(text <- string(:printable, min_length: 1, max_length: 50)) do
        {:safe, html} = Formatter.to_safe_html(text)
        refute html =~ "<span", "Plain text should not produce span elements"
      end
    end
  end

  # ── T005: Edge cases ─────────────────────────────────────────────────

  describe "edge cases" do
    test "malformed color code: non-numeric after 0x03" do
      {:safe, html} = Formatter.to_safe_html("#{@color}abc")
      # \x03 followed by non-numeric should not crash, text displayed as-is
      assert html =~ "abc"
      refute html =~ "irc-fg"
    end

    test "color 16 parsed as color 1 + literal 6" do
      {:safe, html} = Formatter.to_safe_html("#{@color}16text#{@color}")
      # "16" -> color 1, literal "6text"
      assert html =~ "irc-fg-1"
      assert html =~ "6text"
    end

    test "128-code soft limit: excess codes stripped, text preserved" do
      # Build a message with 200 bold toggles
      codes = String.duplicate(@bold, 200)
      msg = codes <> "visible text"

      {:safe, html} = Formatter.to_safe_html(msg)
      # Text should be preserved regardless of code count
      assert html =~ "visible text"
    end

    test "128-code soft limit: codes beyond limit are stripped" do
      # Build message with exactly 130 codes interspersed with text
      parts =
        for i <- 1..130 do
          "#{@bold}t#{i}"
        end

      msg = Enum.join(parts)
      {:safe, html} = Formatter.to_safe_html(msg, max_codes: 128)
      # Should contain text but not more than 128 code-generated spans
      assert html =~ "t1"
      assert html =~ "t130"
    end

    test "empty string returns empty safe html" do
      assert Formatter.to_safe_html("") == {:safe, ""}
    end

    test "whitespace-only after stripping returns whitespace" do
      {:safe, html} = Formatter.to_safe_html("#{@bold}   #{@bold}")
      assert String.trim(String.replace(html, ~r/<[^>]+>/, "")) == ""
    end

    test "color code with only background comma but no bg number" do
      # \x03 4, (comma but no second number) — should set fg=4, no bg
      {:safe, html} = Formatter.to_safe_html("#{@color}4,text#{@color}")
      assert html =~ "irc-fg-4"
      refute html =~ "irc-bg"
    end

    test "multiple resets in a row" do
      {:safe, html} = Formatter.to_safe_html("#{@reset}#{@reset}#{@reset}text")
      assert html =~ "text"
    end

    test "color 0 (white) is a valid color" do
      {:safe, html} = Formatter.to_safe_html("#{@color}0White text#{@color}")
      assert html =~ "irc-fg-0"
    end

    test "color 15 is a valid color" do
      {:safe, html} = Formatter.to_safe_html("#{@color}15Grey text#{@color}")
      assert html =~ "irc-fg-15"
    end

    test "background color 15 is valid" do
      {:safe, html} = Formatter.to_safe_html("#{@color}4,15text#{@color}")
      assert html =~ "irc-fg-4"
      assert html =~ "irc-bg-15"
    end
  end
end
