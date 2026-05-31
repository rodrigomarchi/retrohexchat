defmodule RetroHexChatWeb.LocaleControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  describe "update/2" do
    test "stores the selected locale and redirects to a local return path", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/pt-BR?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "pt_BR"
    end

    test "falls back to English for unsupported locales", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/es?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "en"
    end

    test "rejects external return paths", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/pt_BR?return_to=https://example.com/phishing")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "pt_BR"
    end
  end
end
