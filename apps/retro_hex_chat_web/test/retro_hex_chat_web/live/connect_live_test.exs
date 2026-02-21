defmodule RetroHexChatWeb.ConnectLiveTest do
  use RetroHexChatWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RetroHexChat.Services.NickServ

  @moduletag :liveview

  describe "mount" do
    test "renders connection dialog with nickname input", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ "Connect to RetroHexChat"
      assert html =~ ~s(name="nickname")
    end

    test "renders title and branding", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ "RetroHexChat"
      assert html =~ "Connect"
    end

    test "starts on nickname step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ "User Information"
      refute html =~ "Authentication"
      refute html =~ "Registration"
    end

    test "renders hidden session form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ ~s(id="connect-session-form")
      assert html =~ ~s(action="/chat/session")
      assert html =~ ~s(method="post")
      assert html =~ ~s(name="_csrf_token")
    end

    test "renders nick-help text with rules", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ "nick-help"
      assert html =~ "Case sensitive"
    end
  end

  describe "session expiry flash" do
    test "shows expired session flash when reason=expired", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect?reason=expired")
      html = render(view)
      assert html =~ "Sessão expirada"
    end

    test "does not show flash without reason param", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      refute html =~ "Sessão expirada"
    end
  end

  describe "session info" do
    test "renders session rules text", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ "session-info"
      assert html =~ "Apenas uma sessão por nickname"
    end
  end

  describe "validate" do
    test "shows error for empty nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => ""})
      assert html =~ "disabled" or html =~ "error"
    end

    test "shows error for invalid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => " bad"})
      assert html =~ "error-text"
    end

    test "clears error for valid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "ValidNick"})
      refute html =~ "error-text"
    end
  end

  describe "nickname boundary" do
    test "connect with single-char nickname transitions to register step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "A"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "A"})
      assert html =~ "Registration"
      assert html =~ "is available"
    end

    test "connect with 16-char nickname transitions to register step", %{conn: conn} do
      nick = String.duplicate("A", 16)
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => nick})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => nick})
      assert html =~ "Registration"
      assert html =~ nick
    end
  end

  describe "connect with unregistered nick" do
    test "transitions to register step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})
      assert html =~ "Registration"
      assert html =~ "TestUser"
      assert html =~ "is available"
      assert html =~ ~s(name="password")
      assert html =~ ~s(name="password_confirm")
    end

    test "back button returns to nickname step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})

      html = render_click(view, "back", %{})
      assert html =~ "User Information"
      refute html =~ "Registration"
    end

    test "short password shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "ab", "password_confirm" => "ab"})

      assert html =~ "at least 5 characters"
    end

    test "mismatched passwords show error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "secret123", "password_confirm" => "different"})

      assert html =~ "do not match"
    end

    test "successful registration triggers submit_connect with auth_token", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "NewUser"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "NewUser"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "secret123", "password_confirm" => "secret123"})

      assert html =~ ~s(name="auth_token")
      assert html =~ ~s(id="connect-session-form")
    end
  end

  describe "connect with registered nick" do
    setup do
      NickServ.register("RegNick", "secret123")
      :ok
    end

    test "transitions to password step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})
      assert html =~ "Authentication"
      assert html =~ "RegNick"
      assert html =~ ~s(name="password")
    end

    test "back button returns to nickname step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})

      html = render_click(view, "back", %{})
      assert html =~ "User Information"
      refute html =~ "Authentication"
    end

    test "wrong password shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "wrongpass"})

      assert html =~ "Senha incorreta"
    end

    test "correct password triggers submit_connect with auth_token", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "secret123"})

      # Hidden form should now include auth_token
      assert html =~ ~s(name="auth_token")
      assert html =~ ~s(id="connect-session-form")
    end
  end
end
