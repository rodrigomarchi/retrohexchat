defmodule RetroHexChatWeb.Components.UI.SoundSettingsNotifyTest do
  @moduledoc """
  The desktop-notification column of the Sounds window.

  It is a third answer beside sound and flash, per event, and it is the only
  one whose availability the browser decides — so the window has to say what
  the browser last answered, and stop offering to ask when asking cannot work.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SoundSettingsDialog

  @moduletag :unit

  alias RetroHexChat.Chat.SoundSettings

  defp render_panel(opts) do
    render_component(
      &sound_settings_panel/1,
      Keyword.merge(
        [id: "sound-settings", settings: SoundSettings.new(), notify_permission: "granted"],
        opts
      )
    )
  end

  test "every event offers a notify toggle beside its sound and flash" do
    html = render_panel([])

    for event <- SoundSettings.event_types() do
      assert html =~ ~s(data-testid="notify-toggle-#{event}")
    end
  end

  test "the toggle shows the stored preference per event" do
    settings =
      SoundSettings.new()
      |> SoundSettings.set_notify(:message, true)
      |> SoundSettings.set_notify(:pm, false)

    html = render_panel(settings: settings)

    assert html =~ ~s(data-testid="notify-toggle-message")
    assert html =~ ~s(data-testid="notify-toggle-pm")
  end

  # Blocked is final until the person changes it in their browser, so offering
  # to ask again is a button that cannot work.
  test "a browser that refused is explained rather than asked again" do
    html = render_panel(notify_permission: "denied")

    assert html =~ ~s(data-testid="notify-permission-denied")
    refute html =~ ~s(data-testid="notify-permission-ask")
  end

  test "a browser that has not been asked is offered the question" do
    html = render_panel(notify_permission: "default")

    assert html =~ ~s(data-testid="notify-permission-ask")
    refute html =~ ~s(data-testid="notify-permission-denied")
  end

  test "a browser with no notification support says so and offers nothing" do
    html = render_panel(notify_permission: "unsupported")

    assert html =~ ~s(data-testid="notify-permission-unsupported")
    refute html =~ ~s(data-testid="notify-permission-ask")
  end

  test "a browser that already agreed is asked nothing" do
    html = render_panel(notify_permission: "granted")

    refute html =~ ~s(data-testid="notify-permission-ask")
    refute html =~ ~s(data-testid="notify-permission-denied")
  end
end
