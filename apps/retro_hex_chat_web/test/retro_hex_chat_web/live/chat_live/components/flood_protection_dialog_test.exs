defmodule RetroHexChatWeb.ChatLive.Components.FloodProtectionDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.FloodProtectionDialog

  @moduletag :unit

  @settings %{
    flood_threshold: 7,
    flood_window_seconds: 12,
    spam_threshold: 4,
    spam_window_seconds: 25,
    auto_ignore_duration_seconds: 90
  }

  test "id/0 is stable" do
    assert FloodProtectionDialog.id() == "flood-protection-dialog"
  end

  test "renders the bare panel with the passed-through settings" do
    html =
      render_component(FloodProtectionDialog,
        id: FloodProtectionDialog.id(),
        settings: @settings
      )

    assert html =~ ~s(data-testid="flood-protection-panel")
    refute html =~ "phx-show-modal"
    # Uncontrolled form seeded from the session settings; save bubbles to the parent.
    assert html =~ ~s(value="7")
    assert html =~ "flood_save_settings"
  end
end
