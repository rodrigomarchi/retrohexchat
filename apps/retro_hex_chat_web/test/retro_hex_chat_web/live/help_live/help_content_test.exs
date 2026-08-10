defmodule RetroHexChatWeb.HelpLive.HelpContentTest do
  use RetroHexChatWeb.ConnCase, async: true

  # One topic per content module, so a module that stops resolving its shared
  # helpers fails here rather than on the reader's screen.
  @topics_by_module [
    {"feature-arcade", "Arcade"},
    {"bot-command", "Bots"},
    {"channels", "Channels"},
    {"feature-message-layout", "ChatFeatures"},
    {"feature-notices", "ChatStatusFeatures"},
    {"cmd-ban", "CommandsAtoM"},
    {"cmd-admin", "CommandsAdmin"},
    {"cmd-whois", "CommandsNtoZ"},
    {"feature-hex-pong", "Games"},
    {"feature-video-call", "P2P"},
    {"ui-desktop", "UI"}
  ]

  describe "help topic pages" do
    for {topic, module} <- @topics_by_module do
      test "renders a topic from HelpContent.#{module}", %{conn: conn} do
        article =
          conn
          |> get("/chat/help/#{unquote(topic)}")
          |> html_response(200)
          |> Floki.parse_document!()
          |> Floki.find(~s([data-testid="help-content-pane"] article))

        assert article != [], "the topic rendered no article at all"

        assert article |> Floki.text() |> String.trim() != "",
               "the topic rendered an empty article"
      end
    end
  end

  describe "the shared content helpers" do
    test "help_h4 renders a heading carrying its icon", %{conn: conn} do
      headings =
        conn
        |> get("/chat/help/ui-desktop")
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.find("h4")

      assert headings != []

      assert Enum.any?(headings, fn heading ->
               Floki.find([heading], "svg") != []
             end),
             "expected at least one help_h4 heading to render its icon"
    end

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
