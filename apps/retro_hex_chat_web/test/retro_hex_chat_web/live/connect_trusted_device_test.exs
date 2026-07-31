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
    assert html =~ "Home terminal"
    assert html =~ "Firefox 152"
    assert html =~ "macOS 10.15"
    assert html =~ "1512x982"
    assert html =~ "America/Sao_Paulo"
    assert html =~ "24-bit"
    assert html =~ "10 cores"
    assert html =~ "This device"
    assert html =~ "Trusted"
    assert html =~ "NickServ"
    assert html =~ "Enter as #{nick}"
    assert html =~ "No touch"
    assert has_element?(view, ~s([data-testid="manual-login-btn"]))

    assert has_element?(
             view,
             ~s([data-testid="trusted-auto-login-#{nick}"][data-state="unchecked"])
           )

    refute has_element?(view, ~s([data-testid="manual-nickname-details"]))
    refute has_element?(view, ~s(input#nickname))
    refute has_element?(view, ~s([data-testid="connect-btn"]))

    view
    |> element(~s([data-testid="remembered-nick-login-#{nick}"]))
    |> render_click()

    assert_push_event(view, "submit_connect", %{})
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

    assert %{nickname: ^first, auto_login: true} = TrustedDevices.auto_login_nick(device.id)

    html = render(view)
    assert html =~ ~s(data-testid="trusted-auto-login-#{first}")

    assert has_element?(
             view,
             ~s([data-testid="trusted-auto-login-#{first}"][data-state="checked"])
           )

    view
    |> element(~s([data-testid="trusted-auto-login-#{second}"]))
    |> render_click()

    assert %{nickname: ^second, auto_login: true} = TrustedDevices.auto_login_nick(device.id)

    remembered = TrustedDevices.remembered_nicks(device.id)
    assert %{auto_login: false} = Enum.find(remembered, &(&1.nickname == first))
  end

  test "auto-login remembered nick submits trusted login on connect", %{conn: conn} do
    nick = "AutoGo#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{cookie_value: cookie, device: device}} =
      TrustedDevices.remember_nick(nil, nick, label: "Home terminal", actor_nickname: nick)

    assert :ok = TrustedDevices.set_auto_login(device.id, nick, true, nick)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    assert_push_event(view, "submit_connect", %{})
  end

  test "auto-login is skipped when connect opens with a reason", %{conn: conn} do
    nick = "AutoHold#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{cookie_value: cookie, device: device}} =
      TrustedDevices.remember_nick(nil, nick, label: "Home terminal", actor_nickname: nick)

    assert :ok = TrustedDevices.set_auto_login(device.id, nick, true, nick)

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect?reason=disconnected")

    assert has_element?(
             view,
             ~s([data-testid="trusted-auto-login-#{nick}"][data-state="checked"])
           )

    assert has_element?(view, ~s([data-testid="remembered-nick-login-#{nick}"]))
  end

  test "connect reason renders the machine that took over the nick", %{conn: conn} do
    nick = "Takeover#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick,
        label: "Current Mac",
        actor_nickname: nick,
        client_info: %{"browser" => "Safari 18", "os" => "macOS 15"}
      )

    {:ok, takeover} =
      TrustedDevices.record_session_start(nick, nil, %{
        "browser" => "Chrome 150",
        "os" => "Windows 10+",
        "timezone" => "America/Sao_Paulo",
        "screen" => "1920x1080",
        "color_depth" => 24,
        "cores" => 8
      })

    disconnect_context = %{
      "session_ref" => takeover.session_ref,
      "nickname" => nick,
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, view, html} =
      conn
      |> init_test_session(%{last_disconnect_context: disconnect_context})
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect?reason=disconnected")

    assert has_element?(view, ~s([data-testid="takeover-session-card"]))
    assert html =~ "Machine that disconnected you"
    assert html =~ "Active"
    assert html =~ "Chrome 150"
    assert html =~ "Windows 10+"
    assert html =~ "1920x1080"
    assert html =~ "8 cores"
    assert html =~ "24-bit"
    assert html =~ "Current Mac"
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

    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})

    assert_push_event(view, "submit_connect", %{})
  end

  test "remember terminal fields expose device label suggestion targets", %{conn: conn} do
    nick = "Suggest#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, view, _html} = live(conn, ~p"/connect")

    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})

    assert has_element?(view, ~s([data-testid="remember-device-panel"][hidden]))
    assert has_element?(view, ~s([data-testid="device-label"][data-device-label-input]))
    assert has_element?(view, ~s([data-testid="device-metadata-details"][open]))

    assert has_element?(
             view,
             ~s([data-testid="device-label-suggestion"][data-device-label-suggestion])
           )

    assert has_element?(
             view,
             ~s([data-testid="device-label-metadata"][data-device-label-metadata])
           )

    assert has_element?(view, ~s([data-device-meta-item="browser"]))
    assert has_element?(view, ~s([data-device-meta-item="os"]))
    assert has_element?(view, ~s([data-device-meta-item="device_type"]))
    assert has_element?(view, ~s([data-device-meta-item="language"]))
    assert has_element?(view, ~s([data-device-meta-item="screen"]))
    assert has_element?(view, ~s([data-device-meta-item="timezone"]))
    assert has_element?(view, ~s([data-device-meta-item="color_depth"]))
    assert has_element?(view, ~s([data-device-meta-item="cores"]))
    assert has_element?(view, ~s([data-device-meta-item="touch"]))
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
