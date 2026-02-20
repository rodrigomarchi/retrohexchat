defmodule RetroHexChatWeb.Components.CheatsheetDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.CheatsheetDialog

  @moduletag :unit

  describe "cheatsheet_dialog/1" do
    test "renders when visible" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "data-testid=\"cheatsheet-dialog\""
      assert html =~ "Keyboard Shortcuts"
    end

    test "does not render when not visible" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: false
        )

      refute html =~ "cheatsheet-dialog"
    end

    test "renders all 4 categories" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "cheatsheet-category-navigation"
      assert html =~ "cheatsheet-category-system"
      assert html =~ "Navigation"
      assert html =~ "System"
    end

    test "renders shortcut labels" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "Toggle Search"
      assert html =~ "Next Window"
      assert html =~ "Previous Window"
      assert html =~ "Shortcut Cheatsheet"
    end

    test "renders shortcut key bindings" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "Ctrl+Shift+F"
      assert html =~ "Ctrl+Shift+/"
      assert html =~ "Ctrl+Shift+]"
      assert html =~ "Ctrl+Shift+["
    end

    test "renders em dash for unbound actions" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      # open_help has nil binding
      assert html =~ "\u2014"
    end

    test "is read-only — no text inputs" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      refute html =~ "<input"
      refute html =~ "<textarea"
    end

    test "renders close button" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "aria-label=\"Close\""
    end

    test "renders footer hint about Ctrl+Shift combinations" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true
        )

      assert html =~ "All shortcuts use Ctrl+Shift combinations"
    end
  end
end
