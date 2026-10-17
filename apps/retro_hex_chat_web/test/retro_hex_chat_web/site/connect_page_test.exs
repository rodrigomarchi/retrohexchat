defmodule RetroHexChatWeb.Site.ConnectPageTest do
  @moduledoc """
  The sign-in window: `/connect`, a document window of the one desktop over
  the chat. It carries the whole flow — nickname, register or password, the
  remembered terminals — and its own menus; closing it goes back to the chat.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @window ~s([data-testid="document-window-connect"])

  describe "the window" do
    test "opens over the chat, with its menus, its form and a taskbar button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(view, "#chat-desktop #{@window}")
      assert has_element?(view, ~s(#{@window} [data-window-menu] #connect-menubar))
      assert has_element?(view, ~s(#{@window} form[phx-submit="connect"]))
      assert has_element?(view, ~s([data-window-taskbar="connect"]))

      assert has_element?(
               view,
               ~s(#connect-menubar [data-testid="language-menu-item-pt_BR"] a[href^="/locale/pt_BR"])
             )
    end

    test "starts the chat at once: a sign-in form does nothing without it", %{conn: conn} do
      html = conn |> get("/connect") |> html_response(200)

      assert html =~ ~s(data-boot="now")
      assert html =~ ~s(<meta name="robots" content="noindex)
    end

    test "Help Topics opens the help viewer beside it, on the same desktop", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      render_click(view, "toolbar_action", %{"action" => "help_topics"})

      assert_patch(view, "/chat/help")
      assert has_element?(view, ~s([data-testid="document-window-help"]))
    end

    test "a reason that is not a word is no reason at all", %{conn: conn} do
      assert {:ok, view, _html} = live(conn, "/connect?reason[a]=b")
      refute has_element?(view, ~s([data-testid="session-alert"]))
    end

    test "closing it goes back to the chat, at the conversation in front", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      render_hook(view, "document_closed", %{"slot" => "connect"})

      assert_patch(view, "/c/lobby")
      refute has_element?(view, @window)
    end
  end

  describe "the form" do
    test "routes a fresh nickname to the register step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      view
      |> element(~s(form[phx-submit="connect"]))
      |> render_submit(%{"nickname" => "Conn#{uid()}"})

      assert has_element?(view, ~s(#{@window} form[phx-submit="register"]))
    end

    test "routes a registered nickname to the password step", %{conn: conn} do
      nick = "ConnReg#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, view, _html} = live(conn, "/connect")

      view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => nick})

      assert has_element?(view, ~s(#{@window} form[phx-submit="authenticate"]))
    end

    test "reports an invalid nickname in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => "9bad"})

      assert render(view) =~ "Nickname must start with a letter"
      assert has_element?(view, ~s(#{@window} form[phx-submit="connect"]))
    end
  end

  describe "a remembered terminal" do
    test "is listed as a card that signs in with one click", %{conn: conn} do
      nick = "ConnClick#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

      {:ok, view, _html} =
        conn |> put_req_cookie(TrustedDeviceCookie.name(), cookie) |> live("/connect")

      view |> element(~s([data-testid="remembered-nick-login-#{nick}"])) |> render_click()

      assert_push_event(view, "submit_connect", %{})
    end

    test "with auto-login submits without the reader touching anything", %{conn: conn} do
      nick = "ConnAuto#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)
      :ok = TrustedDevices.set_auto_login(trusted_device_id(cookie), nick, true, nick)

      {:ok, view, _html} =
        conn |> put_req_cookie(TrustedDeviceCookie.name(), cookie) |> live("/connect")

      assert_push_event(view, "submit_connect", %{})
    end
  end

  defp trusted_device_id(cookie) do
    {:ok, device} = TrustedDevices.verify_cookie(cookie)
    device.id
  end
end
