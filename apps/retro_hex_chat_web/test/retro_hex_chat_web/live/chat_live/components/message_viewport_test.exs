defmodule RetroHexChatWeb.ChatLive.Components.MessageViewportTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Scraper.Store
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

  # Three elements, three jobs. The scroller carries no `phx-hook` and no
  # binding on purpose: an element that pushes to the server is locked for the
  # round trip and patched through a detached clone, which costs a scroll
  # container the reader's position.
  test "renders the stream container even when empty" do
    html = render_component(MessageViewport, id: MessageViewport.id())

    assert html =~ ~s(id="chat-messages")
    assert html =~ ~s(id="chat-message-stream")
    assert html =~ ~s(phx-update="stream")
    assert html =~ ~s(id="chat-bottom-anchor")
    assert html =~ ~s(phx-hook="ChatPaginationHook")
    assert html =~ ~s(phx-hook="ChatViewportHook")

    [_, after_id] = String.split(html, ~s(id="chat-messages"), parts: 2)
    [scroller_tag, _] = String.split(after_id, ">", parts: 2)
    refute scroller_tag =~ "phx-hook"
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

  # A card that only appeared on arrival was the whole defect: the client used to
  # write a title beside the link, and nothing recreated it when the history was
  # read back. These assertions are the reload path — rows built from the archive,
  # with no push and no client involved.
  describe "link cards" do
    @describetag :integration

    @page_url "https://example.com/story"

    defp with_stored_page(attrs \\ %{}) do
      {:ok, _page} =
        Store.record_success(
          @page_url,
          Map.merge(
            %{
              title: "A perfectly ordinary headline",
              site_name: "Example News",
              description: "A summary the publisher wrote."
            },
            attrs
          )
        )

      :ok
    end

    defp row(attrs) do
      Map.merge(
        %{
          id: "m1",
          author: "alice",
          content: "olha isso #{@page_url}",
          type: :message,
          content_format: "irc",
          timestamp: ~U[2024-01-01 12:00:00Z]
        },
        attrs
      )
    end

    test "a link somebody pasted renders the page's card under the message" do
      with_stored_page()

      html =
        render_component(MessageViewport, id: MessageViewport.id(), action: {:reset, [row(%{})]})

      assert html =~ "chat-link-card"
      assert html =~ "Example News"
      assert html =~ "A perfectly ordinary headline"
      assert html =~ "Read full story"
    end

    test "a link nobody has read yet leaves the message exactly as it was" do
      html =
        render_component(MessageViewport, id: MessageViewport.id(), action: {:reset, [row(%{})]})

      refute html =~ "chat-link-card"
      assert html =~ "olha isso"
    end

    # An RSS item is already a card carrying a link. Decorating it would print
    # the same page twice, once inside the bot's card and once beneath it.
    test "a card the bots published is not given a card of its own" do
      with_stored_page()

      html =
        render_component(MessageViewport,
          id: MessageViewport.id(),
          action: {:reset, [row(%{content_format: "markdown"})]}
        )

      refute html =~ "chat-link-card"
    end

    # Campaign parameters name a referrer, not a page, so the row the archive
    # holds answers for the address as posted.
    test "a link posted with campaign parameters still finds its page" do
      with_stored_page()

      html =
        render_component(MessageViewport,
          id: MessageViewport.id(),
          action: {:reset, [row(%{content: "#{@page_url}?utm_source=newsletter"})]}
        )

      assert html =~ "chat-link-card"
    end
  end
end
