defmodule RetroHexChatWeb.ChatLive.Components.AliasDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.AliasList
  alias RetroHexChatWeb.ChatLive.Components.AliasDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert AliasDialog.id() == "alias-dialog"
  end

  test "renders hidden with an empty-state when there are no aliases" do
    html = render_component(AliasDialog, id: AliasDialog.id())

    assert html =~ "Alias Editor"
    assert html =~ "No aliases configured"
    assert html =~ "hidden"
  end

  test "renders alias rows from the passthrough list" do
    {:ok, aliases} = AliasList.add_entry(AliasList.new(), "hi", "/msg $1 hello")

    html = render_component(AliasDialog, id: AliasDialog.id(), visible: true, aliases: aliases)

    assert html =~ "/hi"
    assert html =~ "hello"
    # Delete (always-present action button) carries the selected entry to the parent.
    assert html =~ "alias_dialog_delete"
  end
end
