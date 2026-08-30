defmodule RetroHexChatWeb.SpaceRefTest do
  @moduledoc """
  The two directions a space id travels: into a path segment, and back out.

  The element id is asserted separately from the slug because it is a contract
  with `SpaceCanvasHook` and with the Playwright specs that drive it — the kind
  of thing that breaks silently and everywhere at once.
  """
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.SpaceRef

  @moduletag :unit

  describe "slug/1 and space_id/1" do
    test "round-trip both kinds of space id" do
      for space_id <- ["#retro", "#board-room", "dm:ana:bob"] do
        assert {:ok, ^space_id} = space_id |> SpaceRef.slug() |> SpaceRef.space_id()
      end
    end

    test "the slug carries nothing a path segment has to escape" do
      slug = SpaceRef.slug("#retro")

      refute String.contains?(slug, "#")
      refute String.contains?(slug, "/")
      refute String.contains?(slug, "+")
      refute String.contains?(slug, "=")
    end

    test "a slug that decodes to nothing this app serves is refused" do
      # Not base64 at all, base64 of a shape that is not a space id, and
      # base64 of a private space missing half its pair.
      assert SpaceRef.space_id("not-a-slug!") == :error
      assert SpaceRef.space_id(Base.url_encode64("retro", padding: false)) == :error
      assert SpaceRef.space_id(Base.url_encode64("#", padding: false)) == :error
      assert SpaceRef.space_id(Base.url_encode64("dm:ana", padding: false)) == :error
      assert SpaceRef.space_id(nil) == :error
    end
  end

  describe "dom_id/1" do
    test "is the id the canvas hook and the specs look for" do
      assert SpaceRef.dom_id("#retro") == "conversation-space-" <> SpaceRef.slug("#retro")
      assert String.starts_with?(SpaceRef.dom_id("dm:ana:bob"), "conversation-space-")
    end
  end

  describe "participants/1" do
    test "recovers the pair a private space is keyed by" do
      assert SpaceRef.participants("dm:ana:bob") == {:ok, ["ana", "bob"]}
    end

    test "a channel space has no pair to recover" do
      assert SpaceRef.participants("#retro") == :error
      assert SpaceRef.participants("dm:ana") == :error
    end
  end
end
