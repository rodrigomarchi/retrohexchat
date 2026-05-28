defmodule RetroHexChatWeb.AboutE2ETest do
  @moduledoc """
  E2E tests for About dialog (US10).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "About Dialog E2E" do
    test "show_about renders AboutDialog with version and credits", %{conn: conn} do
      nick = "AB1#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "show_about", %{})
      assert html =~ "About RetroHexChat"
      assert html =~ "RetroHexChat"
      assert html =~ "Version"
      assert html =~ "logo-compact.svg"
      assert html =~ "Elixir"
    end

    test "close_dialog dismisses about", %{conn: conn} do
      nick = "AB2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "show_about", %{})
      assert has_element?(view, "#about-dialog-show-trigger")

      render_click(view, "close_dialog", %{"dialog" => "about"})
      refute has_element?(view, "#about-dialog-show-trigger")
    end
  end
end
