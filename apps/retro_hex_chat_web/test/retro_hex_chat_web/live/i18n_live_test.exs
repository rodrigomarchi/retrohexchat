defmodule RetroHexChatWeb.Live.I18nLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  describe "localized LiveView rendering" do
    test "the sign-in window uses the session locale, at its localized address", %{conn: conn} do
      conn = init_test_session(conn, %{locale: "pt_BR"})

      assert {:error, {:redirect, %{to: "/pt-BR/connect"}}} = live(conn, "/connect")
      {:ok, _view, html} = live(conn, "/pt-BR/connect")

      assert html =~ ~s(lang="pt-BR")
      assert html =~ "Conectar ao RetroHexChat"
      assert html =~ "Informações do usuário"
      assert html =~ "Digite seu apelido..."
      assert html =~ "Idioma"
      assert html =~ "Português"
      refute html =~ "Connect to RetroHexChat"
    end

    test "the sign-in window infers pt-BR from Accept-Language, at its localized address", %{
      conn: conn
    } do
      conn = put_req_header(conn, "accept-language", "pt-BR,pt;q=0.9,en;q=0.8")

      assert {:error, {:redirect, %{to: "/pt-BR/connect"}}} = live(conn, "/connect")
      {:ok, _view, html} = live(conn, "/pt-BR/connect")

      assert html =~ ~s(lang="pt-BR")
      assert html =~ "Conectar ao RetroHexChat"
      assert html =~ "Apelido"
    end
  end
end
