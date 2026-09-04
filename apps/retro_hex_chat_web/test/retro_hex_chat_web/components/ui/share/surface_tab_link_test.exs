defmodule RetroHexChatWeb.Components.UI.SurfaceTabLinkTest do
  @moduledoc """
  The way back from a surface to the chat.

  The matching way *forward* is gone: an anchor from the chat into a surface was
  a second door into a room whose first door is the card in the conversation,
  and it was the one that skipped the conversation entirely.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SurfaceTabLink

  @moduletag :unit

  describe "back_to_chat/1" do
    # The link every surface has had since wave 0. Until now it always
    # navigated, so somebody who came from the chat got a *second* chat — and
    # the first one, holding their channels and their scroll position, was
    # taken over by it.
    test "navigates when there is no chat tab to go back to" do
      html = render_component(&back_to_chat/1, open?: false, testid: "play-back-to-chat")

      assert html =~ ~s(data-phx-link="redirect")
      refute html =~ "phx-hook"
    end

    test "tries the chat tab that exists before opening another" do
      html = render_component(&back_to_chat/1, open?: true, testid: "play-back-to-chat")

      assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
      assert html =~ ~s(data-surface-path="/chat")
      # Still a real href, so the second click does what the link says.
      assert html =~ ~s(href="/chat")
      refute html =~ ~s(data-phx-link="redirect")
    end

    # The hook reaches the note through the link's own parent, so a link with no
    # parent of its own is a link whose refusal has nowhere to be said: the first
    # click does nothing and says nothing, and the second opens the second chat
    # this whole component exists to avoid.
    test "carries the note the hook shows when no tab answers" do
      html = render_component(&back_to_chat/1, open?: true, testid: "play-back-to-chat")

      assert html =~ ~s(data-surface-tab-note)
      assert html =~ ~s(data-testid="play-back-to-chat-note")
      assert html =~ ~s(data-visible="false")
    end

    test "has no note to show when there is no tab to fail to reach" do
      html = render_component(&back_to_chat/1, open?: false, testid: "play-back-to-chat")

      refute html =~ ~s(data-surface-tab-note)
    end

    test "says the same thing in both shapes" do
      for open? <- [true, false] do
        assert render_component(&back_to_chat/1, open?: open?, testid: "t") =~ "Chat"
      end
    end
  end
end
