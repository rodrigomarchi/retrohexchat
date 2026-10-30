defmodule RetroHexChatWeb.GoneControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChatWeb.SEO

  describe "pages removed for good" do
    for path <-
          ~w(/archive/lobby /archive/lobby/2026-10-10 /pt-BR/archive/lobby/2026-10-10
             /how-it-works /pt-BR/how-it-works /privacy /pt-BR/privacy) do
      test "#{path} tells a search engine it is gone", %{conn: conn} do
        conn = get(conn, unquote(path))

        assert html_response(conn, 410) =~ ~s(data-testid="bsod")
        assert get_resp_header(conn, "x-robots-tag") == [SEO.noindex_content()]
      end
    end
  end
end
