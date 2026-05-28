defmodule RetroHexChatWeb.HelpAccessFeatureTest do
  @moduledoc """
  E2E tests for Help page access (formerly US11 help dialog quick access).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview_feature

  describe "Help Page Access E2E" do
    test "IRC Commands deep-link renders commands topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/commands-overview")

      assert html =~ "IRC Commands Reference"
      assert html =~ "/join"
    end

    test "Keyboard Shortcuts deep-link renders shortcuts topic", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat/help/keyboard-shortcuts")

      assert html =~ "Keyboard Shortcuts"
    end
  end
end
