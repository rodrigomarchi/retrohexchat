defmodule RetroHexChatWeb.Components.UI.SoundSettingsPushTest do
  @moduledoc """
  The one row in the Sounds window that reaches a closed browser.

  It is the only control here whose existence depends on the server's own
  configuration rather than the person's preference: a self-hosted server with
  no VAPID key pair cannot send a push, and must not draw a switch that does
  nothing.
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

  test "a server that can send push offers the switch" do
    html = render_panel(push_available: true)

    assert html =~ ~s(data-testid="push-toggle")
  end

  # A control that cannot work is worse than a feature that is not there.
  test "a server with no keys draws nothing at all" do
    html = render_panel(push_available: false)

    refute html =~ ~s(data-testid="push-toggle")
    refute html =~ ~s(data-testid="push-row")
  end

  # A push has to raise a notification. A browser that refuses to show one will
  # refuse the subscription too, so offering the switch there is offering a
  # click that ends in an error.
  test "a browser that blocked notifications is not offered the switch" do
    html = render_panel(push_available: true, notify_permission: "denied")

    refute html =~ ~s(data-testid="push-toggle")
  end

  test "a browser that cannot show notifications at all is not offered it either" do
    html = render_panel(push_available: true, notify_permission: "unsupported")

    refute html =~ ~s(data-testid="push-toggle")
  end

  test "a browser that has not been asked yet is offered it" do
    html = render_panel(push_available: true, notify_permission: "default")

    assert html =~ ~s(data-testid="push-toggle")
  end

  test "the switch shows whether this browser is already subscribed" do
    assert checked?(render_panel(push_available: true, push_subscribed: true))
    refute checked?(render_panel(push_available: true, push_subscribed: false))
  end

  defp checked?(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(~s([data-testid="push-toggle"]))
    |> Floki.attribute("checked")
    |> Kernel.!=([])
  end
end
