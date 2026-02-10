defmodule RetroHexChatWeb.Components.MenuBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.MenuBar

  describe "menu_bar/1" do
    test "renders all four menu items" do
      html = render_component(&MenuBar.menu_bar/1, %{})
      assert html =~ "File"
      assert html =~ "Edit"
      assert html =~ "View"
      assert html =~ "Help"
    end

    test "renders dropdown items with phx-click handlers" do
      html = render_component(&MenuBar.menu_bar/1, %{})
      assert html =~ ~s(phx-click="quit_chat")
      assert html =~ ~s(phx-click="open_search")
      assert html =~ ~s(phx-click="toggle_treebar")
      assert html =~ ~s(phx-click="show_about")
    end
  end
end
