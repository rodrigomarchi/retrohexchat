defmodule RetroHexChatWeb.Live.I18nLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  describe "localized LiveView rendering" do
    test "connect screen uses the session locale", %{conn: conn} do
      conn = init_test_session(conn, %{locale: "pt_BR"})

      {:ok, _view, html} = live(conn, "/connect")

      assert html =~ ~s(<html lang="pt-BR">)
      assert html =~ "Conectar ao RetroHexChat"
      assert html =~ "Informações do usuário"
      assert html =~ "Digite seu apelido..."
      assert html =~ "Idioma"
      assert html =~ "Português"
      refute html =~ "Connect to RetroHexChat"
    end

    test "connect screen infers pt-BR from Accept-Language", %{conn: conn} do
      conn = put_req_header(conn, "accept-language", "pt-BR,pt;q=0.9,en;q=0.8")

      {:ok, _view, html} = live(conn, "/connect")

      assert html =~ ~s(<html lang="pt-BR">)
      assert html =~ "Conectar ao RetroHexChat"
      assert html =~ "Apelido"
    end
  end
end
