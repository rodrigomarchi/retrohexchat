defmodule RetroHexChatWeb.ChatLive.Components.KnockRequestDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.KnockRequestDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert KnockRequestDialog.id() == "knock-request-dialog"
  end

  test "renders hidden by default" do
    html = render_component(KnockRequestDialog, id: KnockRequestDialog.id())

    assert html =~ "Request Channel Access"
    assert html =~ "hidden"
  end

  test "opens for a channel with a cleared draft" do
    html =
      render_component(KnockRequestDialog,
        id: KnockRequestDialog.id(),
        visible: true,
        action: {:open, "#secret"}
      )

    assert html =~ "#secret"
    assert html =~ ~s(data-testid="knock-request-submit")
  end

  test "shows the typed message and an error" do
    html =
      render_component(KnockRequestDialog,
        id: KnockRequestDialog.id(),
        visible: true,
        action: {:error, "let me in", "Channel does not exist"}
      )

    assert html =~ "let me in"
    assert html =~ ~s(data-testid="knock-request-error")
    assert html =~ "Channel does not exist"
  end
end
