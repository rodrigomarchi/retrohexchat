defmodule RetroHexChatWeb.HelpAccessE2ETest do
  @moduledoc """
  E2E tests for Help menu quick access (US11).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "Help Menu Quick Access E2E" do
    test "IRC Commands menu item opens help at commands overview", %{conn: conn} do
      nick = "HE1#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "open_help_at_topic", %{"topic" => "commands-overview"})

      assert html =~ "help-dialog"
      assert html =~ "IRC Commands Reference"
      assert html =~ "/join"
    end

    test "Keyboard Shortcuts menu item opens help at shortcuts topic", %{conn: conn} do
      nick = "HE2#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "open_help_at_topic", %{"topic" => "keyboard-shortcuts"})

      assert html =~ "help-dialog"
      assert html =~ "Keyboard Shortcuts"
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
