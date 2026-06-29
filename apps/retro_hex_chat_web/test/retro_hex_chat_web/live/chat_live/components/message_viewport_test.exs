defmodule RetroHexChatWeb.ChatLive.Components.MessageViewportTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.MessageViewport

  @moduletag :unit

  @messages [
    %{
      id: "m1",
      author: "alice",
      content: "hello world",
      type: :message,
      timestamp: ~U[2024-01-01 12:00:00Z]
    },
    %{
      id: "s1",
      content: "* you joined",
      type: :system,
      timestamp: ~U[2024-01-01 12:01:00Z]
    }
  ]

  test "id/0 is stable" do
    assert MessageViewport.id() == "message-viewport"
  end

  test "renders the stream container even when empty" do
    html = render_component(MessageViewport, id: MessageViewport.id())

    assert html =~ ~s(id="chat-messages")
    assert html =~ ~s(phx-update="stream")
    assert html =~ ~s(phx-hook="ScrollHook")
    assert html =~ ~s(data-interactions-hook="MessageInteractionsHook")
  end

  test "a reset action streams one row per message, keyed by id" do
    html =
      render_component(MessageViewport,
        id: MessageViewport.id(),
        action: {:reset, @messages}
      )

    assert html =~ ~s(id="m1")
    assert html =~ ~s(id="s1")
    assert html =~ ~s(data-author="alice")
    assert html =~ "hello world"
    assert html =~ "you joined"
  end

  test "rows carry the message-type CSS class" do
    html =
      render_component(MessageViewport,
        id: MessageViewport.id(),
        action: {:reset, @messages}
      )

    assert html =~ "chat-message--message"
    assert html =~ "chat-message--system"
  end

  test "hides the message list when the status tab is active" do
    hidden = render_component(MessageViewport, id: MessageViewport.id(), show_status_tab: true)
    assert hidden =~ "hidden"
  end

  test "shows the channel-load spinner only when loading_channel is set" do
    idle = render_component(MessageViewport, id: MessageViewport.id())
    refute idle =~ "Loading #general"

    loading =
      render_component(MessageViewport, id: MessageViewport.id(), loading_channel: "#general")

    assert loading =~ "Loading #general"
  end

  test "shows the load-older indicator only when loading_more is true" do
    idle = render_component(MessageViewport, id: MessageViewport.id())
    refute idle =~ ~s(data-testid="scroll-loader")

    loading = render_component(MessageViewport, id: MessageViewport.id(), loading_more: true)
    assert loading =~ ~s(data-testid="scroll-loader")
  end
end
