defmodule RetroHexChatWeb.LandingConnectWindowTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @landing_paths ~w(/ /how-it-works /features /privacy /install /community /faq)

  describe "the connect window on the public pages" do
    for path <- @landing_paths do
      test "GET #{path} carries a working connect window", %{conn: conn} do
        {:ok, view, html} = live(conn, unquote(path))

        assert html =~ ~s(data-testid="landing-connect-window")
        assert html =~ ~s(data-window-id="connect")
        assert has_element?(view, ~s(form[phx-submit="connect"]))
        assert has_element?(view, ~s(#connect-session-form))
        assert has_element?(view, ~s([data-window-taskbar="connect"]))
      end
    end

    test "the form routes a fresh nickname to the register step", %{conn: conn} do
      nick = "Landing#{uid()}"
      {:ok, view, _html} = live(conn, "/")

      view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => nick})

      assert has_element?(view, ~s(form[phx-submit="register"]))
    end

    test "the form routes a registered nickname to the password step", %{conn: conn} do
      nick = "LandingReg#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, view, _html} = live(conn, "/")

      view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => nick})

      assert has_element?(view, ~s(form[phx-submit="authenticate"]))
    end

    test "an invalid nickname reports its error in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => "9bad"})

      assert render(view) =~ "Nickname must start with a letter"
      assert has_element?(view, ~s(form[phx-submit="connect"]))
    end
  end

  # The window is dead-rendered on every page, but the socket that drives it is
  # not: it costs more than the whole public bundle. Which readers pay for it up
  # front is the trade-off these two tests pin down.
  describe "when the LiveSocket loads" do
    test "an anonymous reader stays on the lazy path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(data-connect-eager="false")
      refute html =~ ~s(data-connect-eager="true")
    end

    test "a reader with a remembered terminal boots during render", %{conn: conn} do
      nick = "LandEager#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

      {:ok, _view, html} =
        conn |> put_req_cookie(TrustedDeviceCookie.name(), cookie) |> live("/")

      assert html =~ ~s(data-connect-eager="true")
      assert html =~ ~s(data-testid="remembered-nick-login-#{nick}")
    end
  end

  describe "one-click trusted terminal" do
    test "signs in straight from a landing page", %{conn: conn} do
      nick = "LandClick#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

      {:ok, view, _html} =
        conn |> put_req_cookie(TrustedDeviceCookie.name(), cookie) |> live("/")

      view |> element(~s([data-testid="remembered-nick-login-#{nick}"])) |> render_click()

      assert_push_event(view, "submit_connect", %{})
    end

    test "auto-login submits without the reader touching anything", %{conn: conn} do
      nick = "LandAuto#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)
      :ok = TrustedDevices.set_auto_login(trusted_device_id(cookie), nick, true, nick)

      {:ok, view, _html} =
        conn |> put_req_cookie(TrustedDeviceCookie.name(), cookie) |> live("/")

      assert_push_event(view, "submit_connect", %{})
    end
  end

  defp trusted_device_id(cookie) do
    {:ok, device} = TrustedDevices.verify_cookie(cookie)
    device.id
  end
end
