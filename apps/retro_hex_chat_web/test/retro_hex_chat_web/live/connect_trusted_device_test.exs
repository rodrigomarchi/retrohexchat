defmodule RetroHexChatWeb.ConnectTrustedDeviceTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @moduletag :liveview_feature

  test "remembered nicks render on connect and can submit trusted login", %{conn: conn} do
    nick = "ConnTrust#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick,
        label: "Home terminal",
        actor_nickname: nick,
        client_info: %{
          browser: "Firefox 152",
          os: "macOS 10.15",
          screen: "1512x982",
          timezone: "America/Sao_Paulo",
          language: "pt-BR",
          color_depth: 24,
          cores: 10,
          touch: false
        }
      )

    {:ok, view, html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    assert html =~ ~s(data-testid="remembered-nicks")
    assert html =~ ~s(data-testid="remembered-nick-#{nick}")
    assert has_element?(view, ~s([data-testid="remembered-nick-login-#{nick}"]), "Log in")

    # The row is the way back in, not a description of this browser: what the
    # terminal is lives in Trusted Terminals.
    refute html =~ "Firefox 152"
    refute html =~ "1512x982"
    refute html =~ "America/Sao_Paulo"
    assert has_element?(view, ~s([data-testid="manual-login-btn"]))

    assert has_element?(
             view,
             ~s([data-testid="trusted-auto-login-#{nick}"][data-state="unchecked"])
           )

    refute has_element?(view, ~s([data-testid="manual-nickname-details"]))
    refute has_element?(view, ~s(input#nickname))
    refute has_element?(view, ~s([data-testid="connect-btn"]))

    # Log in is the row's own POST, which needs no LiveView to work.
    assert has_element?(
             view,
             ~s|form[action="/chat/session"][method="post"]:not([phx-submit]) input[name="nickname"][value="#{nick}"]|
           )

    assert has_element?(
             view,
             ~s(form[action="/chat/session"] input[name="trusted_device_login"][value="true"])
           )

    assert has_element?(
             view,
             ~s(form[action="/chat/session"] button[type="submit"][data-testid="remembered-nick-login-#{nick}"])
           )
  end

  test "the auto-login switch waits disabled until the window has joined", %{conn: conn} do
    nick = "Wait#{uid()}"
    NickServ.register(nick, "pass123")
    {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)
    conn = put_req_cookie(conn, TrustedDeviceCookie.name(), cookie)

    dead = conn |> get(~p"/connect") |> html_response(200)
    assert dead =~ ~r/id="trusted-auto-login-#{nick}"[^>]*disabled/

    {:ok, view, _html} = live(conn, ~p"/connect")
    refute has_element?(view, ~s([data-testid="trusted-auto-login-#{nick}"][disabled]))
  end

  test "remembered terminal can enable auto-login preference", %{conn: conn} do
    first = "AutoFirst#{uid()}"
    second = "AutoSecond#{uid()}"
    NickServ.register(first, "pass123")
    NickServ.register(second, "pass123")

    {:ok, %{cookie_value: cookie, device: device}} =
      TrustedDevices.remember_nick(nil, first, label: "Home terminal", actor_nickname: first)

    {:ok, _} = TrustedDevices.remember_nick(cookie, second, actor_nickname: second)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    view
    |> element(~s([data-testid="trusted-auto-login-#{first}"]))
    |> render_click()

    assert %{nickname: ^first, auto_login: true} =
             Enum.find(TrustedDevices.remembered_nicks(device.id), & &1.auto_login)

    html = render(view)
    assert html =~ ~s(data-testid="trusted-auto-login-#{first}")

    assert has_element?(
             view,
             ~s([data-testid="trusted-auto-login-#{first}"][data-state="checked"])
           )

    view
    |> element(~s([data-testid="trusted-auto-login-#{second}"]))
    |> render_click()

    assert %{nickname: ^second, auto_login: true} =
             Enum.find(TrustedDevices.remembered_nicks(device.id), & &1.auto_login)

    remembered = TrustedDevices.remembered_nicks(device.id)
    assert %{auto_login: false} = Enum.find(remembered, &(&1.nickname == first))
  end

  test "remembered terminal screen can switch to manual nickname login", %{conn: conn} do
    nick = "ManTrust#{uid()}"
    NickServ.register(nick, "pass123")
    {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    refute has_element?(view, ~s(input#nickname))

    view
    |> element(~s([data-testid="manual-login-btn"]))
    |> render_click()

    assert has_element?(view, ~s(input#nickname))
    assert has_element?(view, ~s([data-testid="connect-btn"]))
    assert has_element?(view, ~s([data-testid="trusted-choices-btn"]))

    view
    |> element(~s([data-testid="trusted-choices-btn"]))
    |> render_click()

    refute has_element?(view, ~s(input#nickname))
    assert has_element?(view, ~s([data-testid="remembered-nicks"]))
  end

  test "typing a remembered nick also uses trusted login", %{conn: conn} do
    nick = "TypedTrust#{uid()}"
    NickServ.register(nick, "pass123")
    {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    view |> element(~s([data-testid="manual-login-btn"])) |> render_click()

    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})

    assert_push_event(view, "submit_connect", %{})
  end

  test "remember terminal shows only the label, once ticked", %{conn: conn} do
    nick = "Suggest#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, view, _html} = live(conn, ~p"/connect")

    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})

    assert has_element?(view, ~s([data-testid="remember-device-panel"][hidden]))
    assert has_element?(view, ~s([data-testid="device-label"][data-device-label-input]))
    refute has_element?(view, ~s([data-device-meta-item]))
  end

  test "failed authentication preserves remember terminal label fields", %{conn: conn} do
    nick = "KeepTrust#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, view, _html} = live(conn, ~p"/connect")

    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})

    view
    |> element(~s(form[phx-submit="authenticate"]))
    |> render_submit(%{
      "password" => "wrong",
      "remember_device" => "true",
      "device_label" => "Mac Firefox"
    })

    assert has_element?(view, ~s([data-testid="remember-device"][checked]))
    refute has_element?(view, ~s([data-testid="remember-device-panel"][hidden]))
    assert has_element?(view, ~s([data-testid="device-label"][value="Mac Firefox"]))
  end
end
