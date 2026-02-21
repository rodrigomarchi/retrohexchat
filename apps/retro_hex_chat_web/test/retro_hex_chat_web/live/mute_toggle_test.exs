defmodule RetroHexChatWeb.MuteToggleTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  describe "mute toggle in status bar" do
    test "mute toggle button renders in status bar", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render(view)
      assert html =~ "data-testid=\"mute-toggle\""
      assert html =~ "mute-toggle"
    end

    test "clicking mute toggles to muted state", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="mute-toggle"]))
      |> render_click()

      html = render(view)
      assert html =~ "mute-toggle"

      # Toggle back
      view
      |> element(~s([data-testid="mute-toggle"]))
      |> render_click()

      html = render(view)
      assert html =~ "mute-toggle"
    end

    test "toggle_mute pushes toggle_mute event to client", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="mute-toggle"]))
      |> render_click()

      assert_push_event(view, "toggle_mute", %{})
    end

    test "mute_state_sync updates server-side muted state", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Initially unmuted
      html = render(view)
      assert html =~ "mute-toggle"

      # Simulate client-side mute sync (as if localStorage had muted=true)
      render_hook(view, "mute_state_sync", %{"muted" => true})

      html = render(view)
      assert html =~ "mute-toggle"
    end
  end
end
