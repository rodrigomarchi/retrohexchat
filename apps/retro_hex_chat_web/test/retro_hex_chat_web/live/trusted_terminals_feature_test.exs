defmodule RetroHexChatWeb.TrustedTerminalsFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie
  alias RetroHexChatWeb.Components.UI.{MenuBarApp, StartMenuApp}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  test "navigation surfaces expose Trusted Terminals" do
    menu_html =
      render_component(&MenuBarApp.menu_bar_app/1,
        connected: true,
        on_action: "toolbar_action"
      )

    start_html =
      render_component(&StartMenuApp.start_menu_app/1,
        on_action: "toolbar_action"
      )

    assert menu_html =~ ~s(data-testid="context-menu-item-open_trusted_terminals_dialog")
    assert start_html =~ ~s(data-testid="start-menu-item-open_trusted_terminals_dialog")
    assert menu_html =~ "Trusted Terminals"
    assert start_html =~ "Trusted Terminals"
  end

  test "toolbar action opens managed window with devices and sessions", %{conn: conn} do
    nick = "Term#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{device: device, cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick, label: "Desktop terminal", actor_nickname: nick)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> chat_conn(nick, pre_identified: true)
      |> live(~p"/chat")

    refute has_element?(view, ~s([data-window-id="trusted-terminals"]))

    render_click(view, "toolbar_action", %{"action" => "open_trusted_terminals_dialog"})

    assert has_element?(
             view,
             ~s([data-window-id="trusted-terminals"][data-window-managed="true"])
           )

    assert_push_event(view, "window_command", %{action: "open", id: "trusted-terminals"})
    assert has_element?(view, ~s([data-testid="trusted-device-#{device.id}"]))
    assert render(view) =~ "Desktop terminal"

    view
    |> element(~s([data-testid="trusted-device-rename-form-#{device.id}"]))
    |> render_submit(%{"device_id" => "#{device.id}", "label" => "Travel terminal"})

    assert render(view) =~ "Travel terminal"

    render_hook(view, "window_closed", %{"id" => "trusted-terminals"})
    refute has_element?(view, ~s([data-window-id="trusted-terminals"]))
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
