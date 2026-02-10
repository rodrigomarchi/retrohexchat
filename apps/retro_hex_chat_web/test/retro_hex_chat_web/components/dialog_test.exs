defmodule RetroHexChatWeb.Components.DialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Dialog

  describe "dialog/1" do
    test "does not render when visible is false" do
      html =
        render_component(&Dialog.dialog/1,
          visible: false,
          title: "Test",
          mode: "info",
          on_close: "close_dialog",
          on_confirm: "confirm_dialog",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
        )

      refute html =~ "dialog-overlay"
    end

    test "info mode shows only OK button" do
      html =
        render_component(&Dialog.dialog/1,
          visible: true,
          title: "Info",
          mode: "info",
          on_close: "close_dialog",
          on_confirm: "confirm_dialog",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
        )

      assert html =~ "OK"
      refute html =~ "Cancel"
    end

    test "confirm mode shows OK and Cancel buttons" do
      html =
        render_component(&Dialog.dialog/1,
          visible: true,
          title: "Confirm",
          mode: "confirm",
          on_close: "close_dialog",
          on_confirm: "confirm_dialog",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
        )

      assert html =~ "OK"
      assert html =~ "Cancel"
    end

    test "renders title and content" do
      html =
        render_component(&Dialog.dialog/1,
          visible: true,
          title: "My Dialog",
          mode: "info",
          on_close: "close_dialog",
          on_confirm: "confirm_dialog",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Dialog body text" end}]
        )

      assert html =~ "My Dialog"
      assert html =~ "Dialog body text"
    end
  end
end
