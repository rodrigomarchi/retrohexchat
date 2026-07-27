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
      TrustedDevices.remember_nick(nil, nick, label: "Home terminal", actor_nickname: nick)

    {:ok, view, html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> live(~p"/connect")

    assert html =~ ~s(data-testid="remembered-nicks")
    assert html =~ ~s(data-testid="remembered-nick-#{nick}")
    assert html =~ "Home terminal"

    view
    |> element(~s([data-testid="remembered-nick-#{nick}"]))
    |> render_click()

    assert_push_event(view, "submit_connect", %{})
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
end
