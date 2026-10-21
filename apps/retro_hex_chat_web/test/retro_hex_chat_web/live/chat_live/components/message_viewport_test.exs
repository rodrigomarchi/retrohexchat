defmodule RetroHexChatWeb.ChatLive.Components.MessageViewportTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChat.Factory, only: [insert: 2]

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Repo
  alias RetroHexChat.Scraper.Store
  alias RetroHexChat.Services.{NickServ, RegisteredNick}
  alias RetroHexChat.ShareLinks
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

  # Three elements, three jobs. The scroller carries no `phx-hook` and no
  # binding on purpose: an element that pushes to the server is locked for the
  # round trip and patched through a detached clone, which costs a scroll
  # container the reader's position.
  test "renders the stream container even when empty" do
    html = render_component(MessageViewport, id: MessageViewport.id())

    assert html =~ ~s(id="chat-messages")
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

  # The card is found by the line's id: a line whose author is not a bot
  # running now — one that was disabled, renamed, or a service that no longer
  # exists — keeps its match.
  test "a channel line that announced a match carries its card, whoever wrote it" do
    ana = insert(:registered_nick, nickname: "ana")

    {:ok, result} =
      Results.record(%{
        game_id: "hex_pong",
        origin: "ai",
        difficulty: "hard",
        p1: %{id: ana.id, nickname: "ana"},
        payload: %{"score" => %{"p1" => 11, "p2" => 3}, "winner" => 1},
        started_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })

    line =
      insert(:message,
        channel_name: "#hex-pong",
        author_nickname: "GameServ",
        content: "ana beat the computer 11 × 3 in Hex Pong"
      )

    Repo.update_all(GameResult, set: [channel_message_id: line.id])

    html =
      render_component(MessageViewport,
        id: MessageViewport.id(),
        action:
          {:reset,
           [
             %{
               id: line.id,
               source: :channel,
               author: "GameServ",
               content: line.content,
               type: :message,
               timestamp: ~U[2026-10-21 12:00:00Z]
             }
           ]}
      )

    assert html =~ ~s(data-testid="game-result-card-#{result.id}")
  end

  test "shows the channel-load spinner only when loading_channel is set" do
    idle = render_component(MessageViewport, id: MessageViewport.id())
    refute idle =~ "Loading #general"

    loading =
      render_component(MessageViewport, id: MessageViewport.id(), loading_channel: "#general")

    assert loading =~ "Loading #general"
  end

  # The sharer's flag on a card is looked up with the page's authors, so a card
  # posted by somebody else still names its sharer with their language.
  describe "share cards" do
    @describetag :integration

    test "a card carries the language of whoever shared it" do
      sharer = "Shr#{System.unique_integer([:positive])}"
      {:ok, _reply} = NickServ.register(sharer, "password123")
      registered = Repo.get_by!(RegisteredNick, nickname: sharer)
      :ok = NickLocales.remember(sharer, "ja", store: true)

      # Expired, so the card's detail is the sentence that names the sharer.
      {:ok, link} =
        ShareLinks.create(%{
          kind: "space",
          target: %{"channel" => "#nowhere#{System.unique_integer([:positive])}"},
          creator_id: registered.id,
          creator_nick: sharer,
          expires_at: DateTime.add(DateTime.utc_now(), -60)
        })

      row = %{
        id: "m1",
        author: "alice",
        content: "look https://retrohexchat.app/join/#{link.slug}",
        type: :message,
        content_format: "irc",
        timestamp: ~U[2024-01-01 12:00:00Z]
      }

      html =
        render_component(MessageViewport, id: MessageViewport.id(), action: {:reset, [row]})

      assert [_flag] =
               html
               |> Floki.parse_fragment!()
               |> Floki.find(
                 ~s([data-testid="share-message-detail"] [data-testid="nick-flag"][data-locale="ja"])
               )
    end
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
