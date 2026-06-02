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

    test "stores Bengali locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/bn-BD?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "bn"
    end

    test "stores Urdu locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/ur-PK?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "ur"
    end

    test "stores Traditional Chinese locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/zh-TW?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "zh_hant"
    end

    test "stores Portugal Portuguese locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/pt-PT?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "pt_PT"
    end

    test "stores Italian locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/it-IT?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "it"
    end

    test "stores Polish locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/pl-PL?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "pl"
    end

    test "stores Dutch locale aliases", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/nl-BE?return_to=/connect")

      assert redirected_to(conn) == "/connect"
      assert get_session(conn, :locale) == "nl"
    end

    test "falls back to English for unsupported locales", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get("/locale/xx?return_to=/connect")

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
