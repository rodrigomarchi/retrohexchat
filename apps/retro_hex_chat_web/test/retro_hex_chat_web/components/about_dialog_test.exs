defmodule RetroHexChatWeb.Components.AboutDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.AboutDialog

  @moduletag :unit

  describe "about_dialog/1" do
    test "renders when visible" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "data-testid=\"about-dialog\""
      assert html =~ "About RetroHexChat"
    end

    test "does not render when not visible" do
      html = render_component(&AboutDialog.about_dialog/1, visible: false)

      refute html =~ "about-dialog"
    end

    test "renders RetroHexChat name" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "RetroHexChat"
    end

    test "renders version number" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "v1.0"
    end

    test "renders ASCII art logo" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "data-testid=\"about-logo\""
      assert html =~ "about-logo"
    end

    test "renders credits text" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "Built with Elixir, Phoenix LiveView, and a retro design system"
    end

    test "renders OK button" do
      html = render_component(&AboutDialog.about_dialog/1, visible: true)

      assert html =~ "about-ok-btn"
      assert html =~ "OK"
    end
  end
end
