defmodule RetroHexChatWeb.ChatLive.Components.SoundSettingsDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChatWeb.ChatLive.Components.SoundSettingsDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert SoundSettingsDialog.id() == "sound-settings-dialog"
  end

  test "renders hidden by default" do
    html = render_component(SoundSettingsDialog, id: SoundSettingsDialog.id())

    assert html =~ "Sound Settings"
    assert html =~ "hidden"
  end

  test "opens with the session's sound settings as the draft" do
    html =
      render_component(SoundSettingsDialog,
        id: SoundSettingsDialog.id(),
        visible: true,
        action: {:open, SoundSettings.new()}
      )

    # The per-event rows render against the draft.
    assert html =~ ~s(data-testid="sound-select-message")
    # Apply/preview route to the component.
    assert html =~ "sound_settings_apply"
    assert html =~ "sound_preview"
  end
end
