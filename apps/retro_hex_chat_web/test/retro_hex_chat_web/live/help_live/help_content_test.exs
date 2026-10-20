defmodule RetroHexChatWeb.HelpLive.HelpContentTest do
  use RetroHexChatWeb.ConnCase, async: true

  describe "the shared content helpers" do
    test "help_link renders a cross-reference to another topic", %{conn: conn} do
      hrefs =
        conn
        |> get("/chat/help/ui-desktop")
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.find("a")
        |> Floki.attribute("href")

      assert "/chat/help/ui-start-menu" in hrefs
    end
  end
end
