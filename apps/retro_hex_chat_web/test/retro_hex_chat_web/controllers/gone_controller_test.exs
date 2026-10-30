defmodule RetroHexChatWeb.GoneControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChatWeb.SEO

  describe "the retired public archive" do
    for path <- ~w(/archive/lobby /archive/lobby/2026-10-10 /pt-BR/archive/lobby/2026-10-10) do
      test "#{path} tells a search engine it is gone", %{conn: conn} do
        conn = get(conn, unquote(path))

        assert response(conn, 410) == "Gone"
        assert get_resp_header(conn, "x-robots-tag") == [SEO.noindex_content()]
      end
    end
  end
end
