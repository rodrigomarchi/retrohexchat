defmodule RetroHexChatWeb.Components.HighlightDialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.HighlightWord
  alias RetroHexChatWeb.Components.HighlightDialog

  @moduletag :unit

  describe "highlight_dialog/1" do
    test "renders when visible" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: false,
          show_highlight_edit_dialog: false
        )

      assert html =~ "Highlight Words"
      assert html =~ "Rodrigo"
      assert html =~ "highlight-own-nick"
    end

    test "does not render when not visible" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: false,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: false,
          show_highlight_edit_dialog: false
        )

      refute html =~ "Highlight Words"
    end

    test "renders custom highlight words" do
      entries = [
        HighlightWord.new(word: "phoenix", bg_color: nil, position: 0),
        HighlightWord.new(word: "deploy", bg_color: 4, position: 1)
      ]

      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: entries,
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: false,
          show_highlight_edit_dialog: false
        )

      assert html =~ "phoenix"
      assert html =~ "deploy"
      assert html =~ "highlight-word-phoenix"
      assert html =~ "highlight-word-deploy"
    end

    test "shows own nick as non-removable" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: false,
          show_highlight_edit_dialog: false
        )

      assert html =~ "highlight-own-nick"
      assert html =~ "(default)"
    end

    test "shows empty state when no custom words" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: false,
          show_highlight_edit_dialog: false
        )

      assert html =~ "No custom highlight words configured"
    end

    test "renders add dialog when show_highlight_add_dialog is true" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: true,
          show_highlight_edit_dialog: false
        )

      assert html =~ "Add Highlight Word"
      assert html =~ "highlight-word-input"
    end

    test "renders color picker grid" do
      html =
        render_component(&HighlightDialog.highlight_dialog/1,
          visible: true,
          highlight_entries: [],
          highlight_selected: nil,
          own_nick: "Rodrigo",
          show_highlight_add_dialog: true,
          show_highlight_edit_dialog: false
        )

      assert html =~ "highlight-color-grid"
      assert html =~ "highlight-color-0"
      assert html =~ "highlight-color-15"
      assert html =~ "highlight-color-none"
    end
  end
end
