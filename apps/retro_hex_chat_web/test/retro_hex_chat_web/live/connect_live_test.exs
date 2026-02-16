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
  end

  describe "validate" do
    test "shows error for empty nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => ""})
      assert html =~ "disabled" or html =~ "error"
    end

    test "shows error for invalid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => " bad"})
      assert html =~ "error-text"
    end

    test "clears error for valid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => "ValidNick"})
      refute html =~ "error-text"
    end
  end

  describe "nickname boundary" do
    test "connect with single-char nickname succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "A"})
      result = view |> element("form") |> render_submit(%{"nickname" => "A"})
      assert {:error, {:live_redirect, %{to: "/chat?nickname=A"}}} = result
    end

    test "connect with 16-char nickname succeeds", %{conn: conn} do
      nick = String.duplicate("A", 16)
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => nick})
      result = view |> element("form") |> render_submit(%{"nickname" => nick})
      expected_path = "/chat?nickname=#{nick}"
      assert {:error, {:live_redirect, %{to: ^expected_path}}} = result
    end
  end

  describe "connect with unregistered nick" do
    test "navigates to /chat directly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "TestUser"})
      result = view |> element("form") |> render_submit(%{"nickname" => "TestUser"})
      assert {:error, {:live_redirect, %{to: "/chat?nickname=TestUser"}}} = result
    end
  end

  describe "connect with registered nick" do
    setup do
      NickServ.register("RegNick", "secret123")
      :ok
    end

    test "transitions to password step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "RegNick"})
      html = view |> element("form") |> render_submit(%{"nickname" => "RegNick"})
      assert html =~ "Authentication"
      assert html =~ "RegNick"
      assert html =~ ~s(name="password")
    end

    test "back button returns to nickname step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form") |> render_submit(%{"nickname" => "RegNick"})

      html = render_click(view, "back", %{})
      assert html =~ "User Information"
      refute html =~ "Authentication"
    end

    test "wrong password shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form") |> render_submit(%{"nickname" => "RegNick"})

      html =
        view
        |> element("form")
        |> render_submit(%{"password" => "wrongpass"})

      assert html =~ "Senha incorreta"
    end

    test "correct password navigates with auth_token", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "RegNick"})
      view |> element("form") |> render_submit(%{"nickname" => "RegNick"})

      result =
        view
        |> element("form")
        |> render_submit(%{"password" => "secret123"})

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "/chat?nickname=RegNick"
      assert path =~ "auth_token="
    end
  end
end
