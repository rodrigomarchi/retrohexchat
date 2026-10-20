defmodule RetroHexChatWeb.StatusBarFeatureTest do
  @moduledoc """
  E2E tests for status bar with lag, clock, and connection state.
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "Status Bar E2E" do
    test "ping event returns pong with client_time", %{conn: conn} do
      nick = "SB6#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      # Sending a ping event should not crash
      html = render_click(view, "ping", %{"client_time" => 1_000_000})
      assert html =~ ~s(id="lag-display")
    end

    test "lag_update event updates lag display", %{conn: conn} do
      nick = "SB7#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      html = render_click(view, "lag_update", %{"lag_ms" => 45})
      assert html =~ "45ms"
    end
  end
end
