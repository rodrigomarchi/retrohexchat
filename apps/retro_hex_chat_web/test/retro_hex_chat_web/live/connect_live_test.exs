defmodule RetroHexChatWeb.ConnectLiveTest do
  use RetroHexChatWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RetroHexChat.Services.NickServ

  @moduletag :liveview

  describe "mount" do
    test "renders connection dialog with nickname input", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Connect to RetroHexChat"
      assert html =~ ~s(name="nickname")
    end

    test "renders title and branding", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "RetroHexChat"
      assert html =~ "Connect"
    end

    test "starts on nickname step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "User Information"
      refute html =~ "Authentication"
    end

    test "renders hidden session form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(id="connect-session-form")
      assert html =~ ~s(action="/chat/session")
      assert html =~ ~s(method="post")
      assert html =~ ~s(name="_csrf_token")
    end
  end

  describe "validate" do
    test "shows error for empty nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => ""})
      assert html =~ "disabled" or html =~ "error"
    end

    test "shows error for invalid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => " bad"})
      assert html =~ "error-text"
    end

    test "clears error for valid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "ValidNick"})
      refute html =~ "error-text"
    end
  end

  describe "nickname boundary" do
    test "connect with single-char nickname sets submit_connect and updates form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "A"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "A"})
      # Hidden form should have the nickname
      assert html =~ ~s(name="nickname")
      assert html =~ ~s(value="A")
    end

    test "connect with 16-char nickname sets submit_connect and updates form", %{conn: conn} do
      nick = String.duplicate("A", 16)
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => nick})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => nick})
      assert html =~ ~s(value="#{nick}")
    end
  end

  describe "connect with unregistered nick" do
    test "triggers submit_connect push_event with nickname in hidden form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})
      # The hidden form should contain the nickname
      assert html =~ ~s(value="TestUser")
      assert html =~ ~s(id="connect-session-form")
      # No auth_token should be rendered for unregistered nicks
      refute html =~ ~s(name="auth_token")
    end
  end

  describe "connect with registered nick" do
    setup do
      NickServ.register("RegNick", "secret123")
      :ok
    end

    test "transitions to password step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})
      assert html =~ "Authentication"
      assert html =~ "RegNick"
      assert html =~ ~s(name="password")
    end

    test "back button returns to nickname step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})

      html = render_click(view, "back", %{})
      assert html =~ "User Information"
      refute html =~ "Authentication"
    end

    test "wrong password shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "RegNick"})

      html =
        view
        |> element("form[phx-submit]")
        |> render_submit(%{"password" => "wrongpass"})

      assert html =~ "Senha incorreta"
    end

    test "correct password triggers submit_connect with auth_token", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
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
