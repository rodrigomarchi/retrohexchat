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
    ua_hash = TrustedDevices.hash_fingerprint("feature-test-user-agent")
    ip_hash = TrustedDevices.hash_fingerprint("203.0.113.10")

    {:ok, %{device: device, cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick,
        label: "Desktop terminal",
        actor_nickname: nick,
        user_agent_hash: ua_hash,
        ip_hash: ip_hash,
        client_info: %{
          browser: "Firefox 152.0",
          os: "macOS 10.15",
          screen: "1512x982",
          timezone: "America/Sao_Paulo",
          language: "pt-BR",
          color_depth: 24,
          cores: 10,
          touch: false
        }
      )

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

    assert has_element?(
             view,
             ~s([data-testid="trusted-device-#{device.id}"][data-trusted-terminal-card])
           )

    html = render(view)

    assert html =~ "Desktop terminal"
    assert html =~ "Firefox 152.0"
    assert html =~ "macOS 10.15"
    assert html =~ "1512x982"
    assert html =~ "pt-BR"
    assert html =~ "24-bit"
    assert html =~ "10 cores"
    assert html =~ "No touch"
    assert html =~ String.slice(ua_hash, 0, 12)
    assert html =~ String.slice(ip_hash, 0, 12)
    assert has_element?(view, ~s([data-testid="trusted-terminals-tab-devices"]))
    assert has_element?(view, ~s([data-testid="trusted-terminals-tab-sessions"]))
    assert has_element?(view, ~s([data-testid="trusted-terminals-tab-events"]))
    assert html =~ ~s(data-active-tab="devices")

    assert has_element?(
             view,
             ~s([data-testid="trusted-device-auto-login-#{device.id}"][data-state="unchecked"])
           )

    view
    |> element(~s([data-testid="trusted-device-auto-login-#{device.id}"]))
    |> render_click()

    assert %{nickname: ^nick, auto_login: true} = TrustedDevices.auto_login_nick(device.id)

    assert has_element?(
             view,
             ~s([data-testid="trusted-device-auto-login-#{device.id}"][data-state="checked"])
           )

    html =
      view
      |> element(~s([data-testid="trusted-terminals-tab-sessions"]))
      |> render_click()

    assert html =~ ~s(data-active-tab="sessions")

    html =
      view
      |> element(~s([data-testid="trusted-terminals-refresh"]))
      |> render_click()

    assert html =~ ~s(data-active-tab="sessions")

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
