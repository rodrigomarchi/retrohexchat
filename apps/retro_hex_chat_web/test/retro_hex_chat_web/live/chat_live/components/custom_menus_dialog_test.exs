defmodule RetroHexChatWeb.ChatLive.Components.CustomMenusDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.CustomMenus
  alias RetroHexChatWeb.ChatLive.Components.CustomMenusDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert CustomMenusDialog.id() == "custom-menus-dialog"
  end

  test "renders hidden by default" do
    html = render_component(CustomMenusDialog, id: CustomMenusDialog.id())

    assert html =~ "Custom Menus"
    assert html =~ "hidden"
  end

  test "renders entries for the default (nicklist) tab from the passthrough struct" do
    {:ok, menus} = CustomMenus.add_entry(CustomMenus.new(), :nicklist, "Greet", "/msg $1 hi")

    html =
      render_component(CustomMenusDialog,
        id: CustomMenusDialog.id(),
        visible: true,
        custom_menus: menus
      )

    assert html =~ "Greet"
    # Delete (always-present action button) carries the selected entry + tab to the parent.
    assert html =~ "custom_menu_dialog_delete"
  end
end
