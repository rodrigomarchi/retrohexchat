defmodule RetroHexChatWeb.App.LobbyLive.Components.ChatIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.App.LobbyLive.Components.ChatIsland

  @moduletag :unit

  test "id/0 is stable" do
    assert ChatIsland.id() == "lobby-chat"
  end

  test "renders the chat panel with an empty history" do
    html = render_component(ChatIsland, id: ChatIsland.id())

    assert html =~ ~s(data-testid="lobby-chat")
    assert html =~ ~s(id="lobby-chat-form")
  end

  test "a system message (C1) appears in the history" do
    html =
      render_component(ChatIsland,
        id: ChatIsland.id(),
        system_message: "Could not access your microphone or camera."
      )

    assert html =~ "Could not access your microphone or camera."
  end

  test "a peer/own chat line is appended from the lobby_message adapter" do
    html =
      render_component(ChatIsland,
        id: ChatIsland.id(),
        append_message: %{
          id: 1,
          sender_nick: "neo",
          content: "hello there",
          type: "chat",
          timestamp: DateTime.utc_now()
        }
      )

    assert html =~ "neo"
    assert html =~ "hello there"
  end
end
