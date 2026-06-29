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

  test "is hidden by default (no show-trigger)" do
    html = render_component(FloodProtectionDialog, id: FloodProtectionDialog.id())

    assert html =~ "Flood Protection"
    refute html =~ "flood-protection-dialog-show-trigger"
  end

  test "shows the passed-through settings when visible" do
    html =
      render_component(FloodProtectionDialog,
        id: FloodProtectionDialog.id(),
        visible: true,
        settings: @settings
      )

    assert html =~ "flood-protection-dialog-show-trigger"
    # Uncontrolled form seeded from the session settings; save bubbles to the parent.
    assert html =~ ~s(value="7")
    assert html =~ "flood_save_settings"
  end
end
