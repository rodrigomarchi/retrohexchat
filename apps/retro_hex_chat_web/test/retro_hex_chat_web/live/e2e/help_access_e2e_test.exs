defmodule RetroHexChatWeb.HelpAccessE2ETest do
  @moduledoc """
  E2E tests for Help page access (formerly US11 help dialog quick access).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :e2e

  describe "Help Page Access E2E" do
    test "IRC Commands deep-link renders commands topic", %{conn: conn} do
      conn = get(conn, "/chat/help/commands-overview")
      html = html_response(conn, 200)

      assert html =~ "IRC Commands Reference"
      assert html =~ "/join"
    end

    test "Keyboard Shortcuts deep-link renders shortcuts topic", %{conn: conn} do
      conn = get(conn, "/chat/help/keyboard-shortcuts")
      html = html_response(conn, 200)

      assert html =~ "Keyboard Shortcuts"
    end
  end
end
