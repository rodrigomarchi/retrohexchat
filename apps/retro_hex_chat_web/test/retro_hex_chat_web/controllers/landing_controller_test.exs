defmodule RetroHexChatWeb.LandingControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  describe "GET /landing" do
    test "returns 200", %{conn: conn} do
      conn = get(conn, "/landing")
      assert html_response(conn, 200)
    end

    test "contains SEO meta tags", %{conn: conn} do
      conn = get(conn, "/landing")
      body = html_response(conn, 200)

      assert body =~ "Retro Hex Chat"
      assert body =~ ~s(name="description")
      assert body =~ ~s(property="og:title")
      assert body =~ ~s(property="og:description")
      assert body =~ ~s(name="twitter:card")
      assert body =~ ~s(application/ld+json)
    end

    test "contains all major section IDs", %{conn: conn} do
      conn = get(conn, "/landing")
      body = html_response(conn, 200)

      assert body =~ ~s(id="hero")
      assert body =~ ~s(id="problema")
      assert body =~ ~s(id="solucao")
      assert body =~ ~s(id="como-funciona")
      assert body =~ ~s(id="features")
      assert body =~ ~s(id="rede")
      assert body =~ ~s(id="instalar")
      assert body =~ ~s(id="open-source")
      assert body =~ ~s(id="apoie")
      assert body =~ ~s(id="faq")
    end

    test "loads landing-specific assets, not app.js", %{conn: conn} do
      conn = get(conn, "/landing")
      body = html_response(conn, 200)

      assert body =~ "/assets/css/landing.css"
      assert body =~ "/assets/js/landing.js"
      refute body =~ "/assets/js/app.js"
      refute body =~ "/assets/css/app.css"
    end

    test "does not contain LiveView references", %{conn: conn} do
      conn = get(conn, "/landing")
      body = html_response(conn, 200)

      refute body =~ "phx-track-static"
      refute body =~ "data-phx-session"
      refute body =~ "LiveSocket"
    end

    test "uses pt-BR lang attribute", %{conn: conn} do
      conn = get(conn, "/landing")
      body = html_response(conn, 200)

      assert body =~ ~s(lang="pt-BR")
    end
  end
end
