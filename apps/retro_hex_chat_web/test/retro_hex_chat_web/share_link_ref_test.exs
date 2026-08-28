defmodule RetroHexChatWeb.ShareLinkRefTest do
  @moduledoc """
  The one place that knows what a share URL looks like, in both directions.

  Building it and recognising it were written twice before this existed, which
  is how a link the app itself produced could stop being a link the app itself
  recognised.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ShareLinkRef

  test "builds an absolute URL for a slug" do
    url = ShareLinkRef.url("abcdefghjk")

    assert url =~ "/join/abcdefghjk"
    assert url =~ ~r{\Ahttps?://}
  end

  test "recognises what it builds" do
    slug = "abcdefghjk"

    assert ShareLinkRef.slugs_in(ShareLinkRef.url(slug)) == [slug]
  end

  test "finds one inside a sentence, and several in a paste" do
    text = "olha isso https://retrohexchat.app/join/abcdefghjk e tambem /join/mnpqrstuvw"

    assert ShareLinkRef.slugs_in(text) == ["abcdefghjk", "mnpqrstuvw"]
  end

  # Every public page here also lives under a locale segment, so a link someone
  # copied from a pt-BR browser is the same link.
  test "recognises a localized link" do
    assert ShareLinkRef.slugs_in("https://retrohexchat.app/pt-BR/join/abcdefghjk") ==
             ["abcdefghjk"]

    assert ShareLinkRef.slugs_in("/zh-Hans/join/abcdefghjk") == ["abcdefghjk"]
  end

  test "does not invent slugs" do
    for text <- [
          "",
          "no links here",
          "/join/",
          "/join/TOOSHOUTY",
          "/join/short",
          "/join/toolongtobeaslug",
          "/joined/abcdefghjk",
          "https://evil.example/join/abcdefghjk",
          # Host confusion: one contains our name, the other is contained by it.
          "https://retrohexchat.app.evil.example/join/abcdefghjk",
          "https://retrohex/join/abcdefghjk",
          "http://retrohexchat.app/join/abcdefghjk"
        ] do
      assert ShareLinkRef.slugs_in(text) == [], "expected no slug in #{inspect(text)}"
    end
  end

  test "the same link twice is one slug" do
    text = "/join/abcdefghjk /join/abcdefghjk"

    assert ShareLinkRef.slugs_in(text) == ["abcdefghjk"]
  end

  test "survives what is not a string" do
    assert ShareLinkRef.slugs_in(nil) == []
    assert ShareLinkRef.slugs_in(:atom) == []
  end
end
