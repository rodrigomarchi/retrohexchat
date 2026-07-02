defmodule RetroHexChatWeb.ChatLive.Components.SoundSettingsDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChatWeb.ChatLive.Components.SoundSettingsDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert SoundSettingsDialog.id() == "sound-settings-dialog"
  end

  test "renders the bare panel seeded from the settings passthrough" do
    html =
      render_component(SoundSettingsDialog,
        id: SoundSettingsDialog.id(),
        settings: SoundSettings.new()
      )

    assert html =~ ~s(data-testid="sound-settings-panel")
    refute html =~ "phx-show-modal"
    # The per-event rows render against the draft (seeded at mount).
    assert html =~ ~s(data-testid="sound-select-message")
    # Apply/preview route to the component.
    assert html =~ "sound_settings_apply"
    assert html =~ "sound_preview"
  end
end
