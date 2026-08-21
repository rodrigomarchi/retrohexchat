defmodule RetroHexChatWeb.Components.UI.MenuBarAppTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MenuBarApp

  @moduletag :unit

  # The menu bar has two faces: the desktop strip of dropdowns, and a mobile
  # drawer that repeats every one of those menus as a drill-down. Rendering both
  # puts each menu item in the document twice, and on a desktop the second copy
  # can never be reached. The client reports its viewport right after connect,
  # long before anyone can tap a menu, so the drawer's items wait for that.

  describe "on a desktop viewport" do
    setup do
      %{html: render_component(&menu_bar_app/1, connected: true, mobile_viewport: false)}
    end

    test "renders the desktop menus", %{html: html} do
      assert html =~ "app-menu-bar__desktop-menu"
    end

    test "renders the mobile trigger and its category rail", %{html: html} do
      assert html =~ ~s(data-testid="app-mobile-menu-trigger")
      assert html =~ ~s(data-testid="app-mobile-menu-category-file")
    end

    test "does not repeat the menu items in the mobile drawer", %{html: html} do
      refute html =~ ~s(data-testid="app-mobile-menu-section-file")
      refute html =~ ~s(data-testid="app-mobile-menu-section-help")
    end
  end

  describe "on a mobile viewport" do
    setup do
      %{html: render_component(&menu_bar_app/1, connected: true, mobile_viewport: true)}
    end

    test "fills the drawer's sections", %{html: html} do
      assert html =~ ~s(data-testid="app-mobile-menu-section-file")
      assert html =~ ~s(data-testid="app-mobile-menu-section-help")
    end

    test "still renders the category rail", %{html: html} do
      assert html =~ ~s(data-testid="app-mobile-menu-category-file")
    end
  end

  describe "before the client has reported its viewport" do
    test "fills the drawer, because a surface that never asks still needs it" do
      # The connect screen mounts no viewport hook, so `nil` is its permanent
      # answer. Skipping the items there would leave its menu empty on a phone.
      html = render_component(&menu_bar_app/1, connected: true)

      assert html =~ ~s(data-testid="app-mobile-menu-section-file")
    end
  end

  describe "disconnected" do
    test "offers only the menus that need no connection" do
      html = render_component(&menu_bar_app/1, connected: false, mobile_viewport: true)

      assert html =~ ~s(data-testid="app-mobile-menu-section-language")
      assert html =~ ~s(data-testid="app-mobile-menu-section-help")
      refute html =~ ~s(data-testid="app-mobile-menu-section-file")
    end
  end
end
