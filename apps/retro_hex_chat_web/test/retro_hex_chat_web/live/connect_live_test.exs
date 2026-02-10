defmodule RetroHexChatWeb.ConnectLiveTest do
  use RetroHexChatWeb.ConnCase

  import Phoenix.LiveViewTest

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
  end

  describe "validate" do
    test "shows error for empty nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => ""})
      # Empty nickname should either show error or keep button disabled
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

  describe "connect" do
    test "valid submit navigates to /chat", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "TestUser"})
      result = view |> element("form") |> render_submit(%{"nickname" => "TestUser"})
      assert {:error, {:live_redirect, %{to: "/chat?nickname=TestUser"}}} = result
    end
  end
end
