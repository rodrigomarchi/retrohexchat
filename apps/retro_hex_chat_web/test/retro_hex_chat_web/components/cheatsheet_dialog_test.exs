defmodule RetroHexChatWeb.Components.CheatsheetDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChatWeb.Components.CheatsheetDialog

  @moduletag :unit

  @default_bindings KeyBindings.defaults()

  describe "cheatsheet_dialog/1" do
    test "renders when visible" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "data-testid=\"cheatsheet-dialog\""
      assert html =~ "Keyboard Shortcuts"
    end

    test "does not render when not visible" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: false,
          bindings: @default_bindings
        )

      refute html =~ "cheatsheet-dialog"
    end

    test "renders all 4 categories" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "cheatsheet-category-navigation"
      assert html =~ "cheatsheet-category-system"
      assert html =~ "Navigation"
      assert html =~ "System"
    end

    test "renders shortcut labels" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "Toggle Search"
      assert html =~ "Next Window"
      assert html =~ "Previous Window"
      assert html =~ "Shortcut Cheatsheet"
    end

    test "renders shortcut key bindings" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "Ctrl+Shift+F"
      assert html =~ "Ctrl+Shift+/"
      assert html =~ "Ctrl+Shift+]"
      assert html =~ "Ctrl+Shift+["
    end

    test "renders em dash for unbound actions" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      # open_help has nil binding
      assert html =~ "—"
    end

    test "reflects custom bindings" do
      custom = Map.put(@default_bindings, :toggle_search, %{key: "q", modifiers: [:ctrl, :shift]})

      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: custom
        )

      assert html =~ "Ctrl+Shift+Q"
      refute html =~ "Ctrl+Shift+F"
    end

    test "is read-only — no text inputs" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      refute html =~ "<input"
      refute html =~ "<textarea"
    end

    test "renders close button" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "aria-label=\"Close\""
    end

    test "renders customization hint" do
      html =
        render_component(&CheatsheetDialog.cheatsheet_dialog/1,
          visible: true,
          bindings: @default_bindings
        )

      assert html =~ "Customize shortcuts in Options"
    end
  end
end
