defmodule RetroHexChatWeb.ChatLive.Components.MuteDurationDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.MuteDurationDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert MuteDurationDialog.id() == "mute-duration-dialog"
  end

  test "renders the dialog root hidden by default" do
    html = render_component(MuteDurationDialog, id: MuteDurationDialog.id())

    assert html =~ ~s(id="#{MuteDurationDialog.id()}")
    # Closed dialogs keep their root in the DOM but stay hidden via CSS.
    assert html =~ "hidden"
  end

  test "opens for a target nick via the :open action" do
    html =
      render_component(MuteDurationDialog,
        id: MuteDurationDialog.id(),
        action: {:open, "Bob"}
      )

    assert html =~ "Mute User"
    assert html =~ "Bob"
    assert html =~ "mute-duration-input"
    assert html =~ "mute_duration_cancel"
  end
end
