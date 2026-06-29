defmodule RetroHexChatWeb.AboutFeatureTest do
  @moduledoc """
  E2E tests for About dialog (US10).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "About Dialog" do
    # About is a stateless dialog: its content is always rendered, and it is
    # opened/closed purely client-side via `show_modal`/`hide_modal` (logo +
    # Help menu, OK/X/Escape). No server `show_about` state is involved.

    test "renders the About dialog content (version + credits)", %{conn: conn} do
      nick = "AB1#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render(view)
      assert html =~ "About RetroHexChat"
      assert html =~ "Version"
      assert html =~ "logo-compact.svg"
      assert html =~ "Elixir"
    end

    test "starts hidden with no server-driven show state", %{conn: conn} do
      nick = "AB2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      # Always present in the DOM...
      assert has_element?(view, "#about-dialog")
      # ...but closed by default: the server-driven show trigger only exists when
      # `show` is true, and About is never opened from the server (client JS only).
      refute has_element?(view, "#about-dialog-show-trigger")
    end
  end
end
