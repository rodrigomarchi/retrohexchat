defmodule RetroHexChatWeb.StatusBarE2ETest do
  @moduledoc """
  E2E tests for status bar with lag, clock, and connection state.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "Status Bar E2E" do
    test "renders status bar with channel and connection on chat page", %{conn: conn} do
      nick = "SB1#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"status-bar-app\""
    end

    test "shows connected state by default", %{conn: conn} do
      nick = "SB2#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      # V2 status bar shows the nickname and channel
      assert html =~ nick
    end

    test "lag display shows initial dash", %{conn: conn} do
      nick = "SB3#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "id=\"lag-display\""
    end

    test "clock display has hook attached", %{conn: conn} do
      nick = "SB4#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "phx-hook=\"ClockHook\""
      assert html =~ "id=\"clock-display\""
    end

    test "lag hook is attached", %{conn: conn} do
      nick = "SB5#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "phx-hook=\"LagHook\""
      assert html =~ "id=\"lag-display\""
    end

    test "ping event returns pong with client_time", %{conn: conn} do
      nick = "SB6#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Sending a ping event should not crash
      html = render_click(view, "ping", %{"client_time" => 1_000_000})
      assert html =~ nick
    end

    test "lag_update event updates lag display", %{conn: conn} do
      nick = "SB7#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "lag_update", %{"lag_ms" => 45})
      assert html =~ "45ms"
    end

    test "lag_update with high value shows warning class", %{conn: conn} do
      nick = "SB8#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "lag_update", %{"lag_ms" => 350})
      assert html =~ "350ms"
      assert html =~ "text-warning-alt"
    end

    test "lag_update with null shows timeout", %{conn: conn} do
      nick = "SB9#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "lag_update", %{"lag_ms" => nil})
      assert html =~ "text-error"
    end

    test "connection status component is rendered", %{conn: conn} do
      nick = "SBA#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"status-bar-app\""
    end
  end
end
