defmodule RetroHexChat.Scraper.MarkupTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Scraper.Markup

  describe "decode_entities/1" do
    test "decodes named typographic entities" do
      assert Markup.decode_entities(
               "It&rsquo;s &ldquo;here&rdquo; &mdash; at last&hellip; &copy;"
             ) ==
               "It’s “here” — at last… ©"
    end

    test "decodes decimal and hexadecimal references" do
      assert Markup.decode_entities("&#8217; &#x2014;") == "’ —"
    end

    test "leaves an unknown name as written" do
      assert Markup.decode_entities("&bogus; &amp;") == "&bogus; &"
    end
  end

  describe "srcset_url/1" do
    test "picks the widest candidate" do
      assert Markup.srcset_url("a.jpg 320w, b.jpg 1024w, c.jpg 640w") == "b.jpg"
    end

    test "takes a lone URL and returns nil for nothing" do
      assert Markup.srcset_url("only.jpg") == "only.jpg"
      assert Markup.srcset_url(nil) == nil
      assert Markup.srcset_url(" , ") == nil
    end
  end

  describe "parse_datetime/1" do
    test "reads ISO 8601 with an offset" do
      assert Markup.parse_datetime("2026-10-21T10:00:00+02:00") == ~U[2026-10-21 08:00:00Z]
    end

    test "reads a bare date as midnight UTC" do
      assert Markup.parse_datetime("2026-10-21") == ~U[2026-10-21 00:00:00Z]
    end

    test "reads the RFC 822 form feeds use" do
      assert Markup.parse_datetime("Tue, 21 Oct 2026 10:00:00 GMT") == ~U[2026-10-21 10:00:00Z]
    end

    test "nil for anything else" do
      assert Markup.parse_datetime("yesterday") == nil
      assert Markup.parse_datetime("  ") == nil
      assert Markup.parse_datetime(nil) == nil
    end
  end
end
