defmodule RetroHexChatWeb.Components.UI.SurfaceTabLinkTest do
  @moduledoc """
  The two shapes of the way into a surface's own tab.

  A tab you do not have is opened; one you do is gone back to. The difference
  matters because opening a second tab of a P2P session moves the session into
  it — the takeover contract firing for somebody who only wanted to look at
  what they already had.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SurfaceTabLink

  @moduletag :unit

  describe "surface_tab_link/1" do
    test "offers to open a tab that is not open, and asks nothing of the browser" do
      html =
        render_component(&surface_tab_link/1,
          path: "/call/abc",
          open?: false,
          testid: "call-tab"
        )

      assert html =~ "Open in a tab"
      refute html =~ "Go to the tab"
      refute html =~ "phx-hook"
      refute html =~ "surface-tab-note"
    end

    test "offers to go back to a tab that is open, and carries the hook that tries" do
      html =
        render_component(&surface_tab_link/1,
          path: "/call/abc",
          open?: true,
          testid: "call-tab"
        )

      assert html =~ "Go to the tab"
      refute html =~ "Open in a tab"
      assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
      assert html =~ ~s(data-surface-path="/call/abc")
    end

    # It stays an anchor in both shapes: that is what keeps middle-click and
    # "open in new tab" working, and it is what makes the fallback free.
    test "is an anchor with the real address either way, and never an opener" do
      for open? <- [true, false] do
        html = render_component(&surface_tab_link/1, path: "/space/x", open?: open?)

        assert html =~ ~s(href="/space/x")
        assert html =~ ~s(target="_blank")
        assert html =~ ~s(rel="noopener")
      end
    end

    # Only the hook ever reveals it, and only after a tab failed to answer.
    test "carries the already-open sentence, hidden, only in the go-back shape" do
      open = render_component(&surface_tab_link/1, path: "/p2p/t", open?: true)
      closed = render_component(&surface_tab_link/1, path: "/p2p/t", open?: false)

      assert open =~ "It is already open in another window of yours."
      assert open =~ ~s(data-visible="false")
      refute closed =~ "It is already open in another window of yours."
    end

    test "two addresses get two element ids, because both can be on screen" do
      one = render_component(&surface_tab_link/1, path: "/call/one", open?: true)
      two = render_component(&surface_tab_link/1, path: "/call/two", open?: true)

      assert [id_one] = Regex.run(~r/id="(surface-tab-link-[^"]+)"/, one, capture: :all_but_first)
      assert [id_two] = Regex.run(~r/id="(surface-tab-link-[^"]+)"/, two, capture: :all_but_first)
      refute id_one == id_two
    end
  end

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
