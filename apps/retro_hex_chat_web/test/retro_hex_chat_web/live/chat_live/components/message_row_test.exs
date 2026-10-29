defmodule RetroHexChatWeb.ChatLive.Components.MessageRowTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.MessageRow

  @moduletag :unit

  @ts ~U[2024-01-01 12:00:00Z]

  defp row(msg, overrides \\ %{}) do
    assigns =
      Map.merge(
        %{
          dom_id: "chat_messages-#{msg.id}",
          msg: msg,
          nick_color_fn: fn _nick -> nil end,
          timestamp_format: :dd_mm_hh_mm,
          timezone: "Etc/UTC",
          strip_formatting: false,
          edit_mode_message_id: nil
        },
        overrides
      )

    render_component(&MessageRow.message_row/1, assigns)
  end

  test "wraps the row in a div keyed by dom_id with type class and data attributes" do
    html = row(%{id: "m1", author: "alice", content: "hi", type: :normal, timestamp: @ts})

    assert html =~ ~s(id="chat_messages-m1")
    assert html =~ ~s(data-author="alice")
    assert html =~ ~s(data-real-id="m1")
    assert html =~ ~s(data-message-format="irc")
    assert html =~ ~s(data-message-text="hi")
    assert html =~ ~s(data-message-source-b64="aGk=")
  end

  test "stores Markdown visible text and original source for context menu copy" do
    html =
      row(%{
        id: "m-copy",
        author: "bob",
        content: "**hello** [doc](https://example.com)",
        content_format: "markdown",
        plain_content: "hello doc",
        type: :normal,
        timestamp: @ts
      })

    assert html =~ ~s(data-message-format="markdown")
    assert html =~ ~s(data-message-text="hello doc")

    assert html =~
             ~s(data-message-source-b64="#{Base.encode64("**hello** [doc](https://example.com)")}")
  end

  test "renders normal message content" do
    html = row(%{id: "m1", author: "bob", content: "hello world", type: :normal, timestamp: @ts})
    assert html =~ "hello world"
  end

  test "renders markdown message content when content_format is markdown" do
    html =
      row(%{
        id: "m-md",
        author: "bob",
        content: "**hello** [doc](https://example.com)",
        content_format: "markdown",
        type: :normal,
        timestamp: @ts
      })

    assert html =~ "<strong>hello</strong>"
    assert html =~ ~s(href="https://example.com")
  end

  test "strips markdown message content when strip_formatting is true" do
    html =
      row(
        %{
          id: "m-md-strip",
          author: "bob",
          content: "**hello** [doc](https://example.com)",
          content_format: "markdown",
          type: :normal,
          timestamp: @ts
        },
        %{strip_formatting: true}
      )

    assert html =~ "hello doc"
    refute html =~ "<strong>"
    refute html =~ "<a "
  end

  # The card is Markdown the archive produced, so it renders through the same
  # sanitising helper as any other message body — publisher image included.
  test "renders the link card a decorated row carries" do
    html =
      row(%{
        id: "m-card",
        author: "bob",
        content: "olha isso https://example.com/story",
        type: :normal,
        timestamp: @ts,
        link_preview:
          "**Example News** | A headline\n\n![Example News preview image](<https://example.com/card.png>)"
      })

    assert html =~ "chat-link-card"
    assert html =~ "<strong>Example News</strong>"
    assert html =~ "chat-markdown-image-shell"
    assert html =~ "chat-markdown-image"
  end

  # Suppressed rather than flattened: a card without its layout is a paragraph
  # of link text the reader already has in the message above it.
  test "shows no link card to a reader who asked for plain text" do
    html =
      row(
        %{
          id: "m-card-strip",
          author: "bob",
          content: "olha isso https://example.com/story",
          type: :normal,
          timestamp: @ts,
          link_preview: "**Example News** | A headline"
        },
        %{strip_formatting: true}
      )

    refute html =~ "chat-link-card"
    refute html =~ "Example News"
  end

  test "renders the bracket-free DD/MM HH:MM timestamp for the row" do
    html = row(%{id: "m1", author: "bob", content: "hi", type: :normal, timestamp: @ts})
    assert html =~ "01/01 12:00"
    refute html =~ "[01/01 12:00]"
  end

  test "renders an action message with the author in the meta column and * body" do
    html = row(%{id: "a1", author: "bob", content: "waves", type: :action, timestamp: @ts})
    # The author moves to the interactive nick column; the body keeps only "* content".
    assert html =~ ~s(data-nick="bob")
    assert html =~ "* waves"
    refute html =~ "* bob"
  end

  test "renders system, service, error and notice rows" do
    assert row(%{id: "s1", content: "joined", type: :system, timestamp: @ts}) =~ "joined"
    assert row(%{id: "v1", content: "svc msg", type: :service, timestamp: @ts}) =~ "svc msg"
    assert row(%{id: "e1", content: "boom", type: :error, timestamp: @ts}) =~ "boom"

    notice =
      row(%{id: "n1", author: "srv", content: "notice text", type: :notice, timestamp: @ts})

    assert notice =~ "notice text"
  end

  # A bot greeting delivered as a notice carried mIRC colour codes, and the
  # notice branch interpolated its content directly instead of formatting it.
  # The browser swallows the 0x03 byte and shows what follows it, so the colour
  # printed as text: "06 [Wanda] 13guest!". Every type formats its content now.
  @coloured "\x0306\x02[Wanda]\x0F guest!"

  test "every message type renders mIRC codes as markup, never as stray digits" do
    types = [
      %{id: "c1", author: "wanda", content: @coloured, type: :notice, timestamp: @ts},
      %{id: "c2", content: @coloured, type: :system, timestamp: @ts},
      %{id: "c3", content: @coloured, type: :p2p_system, timestamp: @ts},
      %{id: "c4", content: @coloured, type: :service, timestamp: @ts},
      %{id: "c5", content: @coloured, type: :error, timestamp: @ts},
      %{id: "c6", author: "wanda", content: @coloured, type: :action, timestamp: @ts},
      %{id: "c7", author: "wanda", content: @coloured, type: :normal, timestamp: @ts}
    ]

    for msg <- types do
      html = row(msg)

      assert html =~ ~s(class="irc-fg-6"), "#{msg.type} lost its colour span"
      assert html =~ "irc-bold"
      assert html =~ "[Wanda]"
      refute html =~ "06", "#{msg.type} leaked the colour code's digits"
      refute html =~ "\x03", "#{msg.type} passed the control byte through"
    end
  end

  test "stripping formatting drops the codes without leaving their digits" do
    html =
      row(%{id: "c8", author: "wanda", content: @coloured, type: :notice, timestamp: @ts}, %{
        strip_formatting: true
      })

    assert html =~ "[Wanda]"
    refute html =~ "irc-fg-6"
    refute html =~ "06"
  end

  # A P2P invite renders as a request line, carrying none of the accept/decline
  # apparatus a session card would bring with it. The invite is a variant of the
  # share card, so there is no sentence pointing at where the control is: the
  # card *is* the control.
  test "renders a P2P invite as a request line with no session-card apparatus" do
    html =
      row(
        %{
          id: "p2p1",
          author: "alice",
          content: "P2P session invite - accept it on this card. /lobby/tok123",
          type: :p2p_invite,
          timestamp: @ts
        },
        %{viewer: "bob"}
      )

    assert html =~ "P2P request"
    assert html =~ "Use the P2P control in this private message."
    refute html =~ ~s(data-testid="session-card")
    refute html =~ ~s(data-testid="p2p-invite-card")
    refute html =~ "session-card-accept"
    refute html =~ "session-card-decline"
    refute html =~ "/lobby/tok123"
  end

  test "an invite carrying its session draws the card, and drops the sentence for it" do
    html =
      row(
        %{
          id: "p2p2",
          author: "alice",
          content: "P2P session request. Use the P2P control in this PM. /p2p/tok12345",
          type: :p2p_invite,
          timestamp: @ts,
          share_card: %{
            slug: nil,
            kind: "p2p",
            target: %{"session_token" => "tok12345"},
            creator_nick: nil,
            state: :live,
            reason: nil,
            count: 1,
            participants: [],
            channel_name: nil,
            game_id: nil
          }
        },
        %{viewer: "bob"}
      )

    assert html =~ "P2P request"
    assert html =~ ~s(data-testid="share-message-card")
    assert html =~ ~s(data-share-kind="p2p")
    assert html =~ "/p2p/tok12345"
    # The card is the control, so the sentence pointing at one is gone.
    refute html =~ "Use the P2P control in this private message."
    # And no address that belongs to nobody but the two of them is offered for
    # copying.
    refute html =~ ~s(data-testid="share-message-copy")
  end

  test "a taken seat offers its match to watch, and nothing to join" do
    seat = fn watch? ->
      row(%{
        id: "seat#{watch?}",
        author: "System",
        content: "ana is looking for a partner in Hex Pong — https://x/join/abc",
        type: :system,
        timestamp: @ts,
        share_card: %{
          slug: "abc",
          kind: "play",
          target: %{"game_id" => "hex_pong", "session_token" => "tokw"},
          creator_nick: "ana",
          state: :ended,
          reason: :full,
          watch?: watch?,
          participants: [],
          channel_name: nil,
          game_id: "hex_pong"
        }
      })
    end

    html = seat.(true)
    assert html =~ ~s(data-testid="share-message-watch")
    assert html =~ ~s(href="/watch/tokw")
    refute html =~ ~s(data-testid="share-message-enter")

    refute seat.(false) =~ "share-message-watch"
  end

  describe "a match's card" do
    defp match_card(place) do
      %{
        result_id: 41,
        game_id: "hex_tennis_quick",
        base_id: "hex_tennis",
        origin: "p2p",
        difficulty: nil,
        p1_nickname: "ana",
        p2_nickname: "beto",
        p1_score: 3,
        p2_score: 1,
        outcome: :p1,
        ranked: true,
        personal_best: false,
        duration_ms: 125_000,
        finished_at: @ts,
        place: place
      }
    end

    test "stands in for the announcing bot's sentence in a game's channel" do
      html =
        row(%{
          id: 7,
          author: "Scoreboard",
          content: "ana beat beto 3 × 1 in Hex Tennis: Quick Match",
          type: :message,
          timestamp: @ts,
          result_card: match_card(:channel)
        })

      assert html =~ ~s(data-testid="game-result-card-41")
      assert html =~ "Hex Tennis: Quick Match"
      assert html =~ "ana 3 × 1 beto"
      assert html =~ "Winner: ana"

      # The game's name leads to its home — a mode's, to its game's.
      assert [home] =
               html |> Floki.parse_fragment!() |> Floki.find(~s([data-testid="game-result-home"]))

      assert Floki.attribute(home, "href") == ["/games/hex-tennis"]
      assert Floki.attribute(home, "data-phx-link") == ["patch"]

      # The sentence stays on the row for copying, and is not drawn.
      refute html |> Floki.parse_fragment!() |> Floki.find(".chat-message__text") |> Floki.text() =~
               "ana beat beto"

      # Already in the game's channel: no way into it.
      refute html =~ ~s(data-testid="game-result-channel")
    end

    test "carries the way into the game's channel from the players' conversation" do
      html =
        row(%{
          id: 8,
          author: "ana",
          content: "ana beat beto 3 × 1 in Hex Tennis: Quick Match",
          type: :p2p_system,
          timestamp: @ts,
          result_card: match_card(:private)
        })

      assert html =~ ~s(data-testid="game-result-card-41")
      assert html =~ ~s(data-testid="game-result-channel")
      assert html =~ ~s(phx-value-channel="#hex-tennis")
    end

    test "a reader who asked for plain text gets the sentence instead" do
      html =
        row(
          %{
            id: 9,
            author: "Scoreboard",
            content: "ana beat beto 3 × 1 in Hex Tennis: Quick Match",
            type: :message,
            timestamp: @ts,
            result_card: match_card(:channel)
          },
          %{strip_formatting: true}
        )

      assert html =~ "ana beat beto"
      refute html =~ "game-result-card"
    end
  end

  describe "an arcade play's card" do
    defp play_card(place) do
      %{
        play_id: 52,
        game_id: "doom_shareware",
        nickname: "ana",
        started_at: @ts,
        place: place,
        locale: "pt_BR"
      }
    end

    defp play_row(place, opts \\ %{}) do
      row(
        %{
          id: 12,
          author: "Pixel",
          content: "ana started the game DOOM: Knee-Deep in the Dead",
          type: :message,
          timestamp: @ts,
          play_card: play_card(place)
        },
        opts
      )
    end

    test "stands in for the sentence: who, which game, and the way to play it" do
      html = play_row(:channel)
      doc = Floki.parse_fragment!(html)

      assert html =~ ~s(data-testid="arcade-play-card-52")
      assert html =~ "DOOM Engine"

      assert doc
             |> Floki.find(~s([data-testid="arcade-play-who"]))
             |> Floki.text()
             |> String.split()
             |> Enum.join(" ") == "ana started the game"

      assert doc
             |> Floki.find(~s([data-testid="arcade-play-who"] [data-testid="nick-flag"]))
             |> Floki.attribute("data-locale") == ["pt_BR"]

      assert [home] = Floki.find(doc, ~s([data-testid="arcade-play-home"]))
      assert Floki.attribute(home, "href") == ["/games/doom-shareware"]

      assert [play] = Floki.find(doc, ~s([data-testid="arcade-play-play"]))
      assert Floki.attribute(play, "phx-click") == ["open_arcade"]
      assert Floki.attribute(play, "phx-value-game-id") == ["doom_shareware"]

      refute doc |> Floki.find(".chat-message__text") |> Floki.text() =~ "started the game DOOM"
      # Already in the game's channel: no way into it.
      refute html =~ ~s(data-testid="arcade-play-channel")
    end

    test "in #arcade it also leads to the game's own channel" do
      html = play_row(:feed)
      assert html =~ ~s(data-testid="arcade-play-channel")
      assert html =~ ~s(phx-value-channel="#doom-shareware")
    end

    test "a reader who asked for plain text gets the sentence instead" do
      html = play_row(:channel, %{strip_formatting: true})
      assert html =~ "ana started the game DOOM"
      refute html =~ "arcade-play-card"
    end
  end

  test "renders a deleted placeholder instead of content" do
    html =
      row(%{
        id: "d1",
        author: "bob",
        content: "secret",
        type: :normal,
        timestamp: @ts,
        deleted_at: @ts
      })

    assert html =~ "chat-message--deleted"
    refute html =~ "secret"
  end

  test "renders an edited tag for edited messages" do
    html =
      row(%{
        id: "ed1",
        author: "bob",
        content: "fixed",
        type: :normal,
        timestamp: @ts,
        edited_at: @ts
      })

    assert html =~ "fixed"
    assert html =~ "edited"
  end

  test "renders a retry affordance for failed messages" do
    html =
      row(%{
        id: "f1",
        author: "bob",
        content: "lost",
        type: :normal,
        timestamp: @ts,
        status: :failed,
        target: "#room"
      })

    assert html =~ ~s(data-msg-status="failed")
    assert html =~ ~s(data-temp-id="f1")
  end

  test "marks the editing row when its id matches edit_mode_message_id" do
    msg = %{id: "m9", author: "bob", content: "edit me", type: :normal, timestamp: @ts}
    html = row(msg, %{edit_mode_message_id: "m9"})
    assert html =~ "chat-message--editing"
  end

  test "tags highlighted rows" do
    msg = %{
      id: "h1",
      author: "bob",
      content: "ping",
      type: :normal,
      timestamp: @ts,
      highlighted: true
    }

    html = row(msg)
    assert html =~ ~s(data-testid="highlighted-message")
  end

  test "renders a reply block when reply_to_id is present" do
    msg = %{
      id: "r1",
      author: "bob",
      content: "answer",
      type: :normal,
      timestamp: @ts,
      reply_to_id: "p1",
      reply_to_author: "alice",
      reply_to_preview: "question?"
    }

    html = row(msg)
    assert html =~ "answer"
    assert html =~ "question?"
  end

  describe "speaker runs and days" do
    test "a row continuing a run passes it on, with its band" do
      html =
        row(%{
          id: "c1",
          author: "bob",
          content: "more",
          type: :normal,
          timestamp: @ts,
          group_start?: false,
          band: :b,
          day_break: nil
        })

      assert html =~ ~s(data-continuation="true")
      assert html =~ ~s(data-band="b")
      refute html =~ ~s(data-testid="day-break")
    end

    test "the first row of a day draws the day above itself, outside the band" do
      html =
        row(%{
          id: "c2",
          author: "bob",
          content: "first",
          type: :normal,
          timestamp: @ts,
          group_start?: true,
          band: :a,
          day_break: ~D[2024-01-01]
        })

      doc = LazyHTML.from_fragment(html)

      assert [label] =
               doc |> LazyHTML.query("[data-testid=day-break]") |> LazyHTML.text() |> List.wrap()

      assert label =~ "01/01/2024"
      assert doc |> LazyHTML.query("[data-band] [data-testid=day-break]") |> Enum.count() == 0
    end

    test "a row with no run information draws its header as before" do
      html = row(%{id: "c3", author: "bob", content: "x", type: :normal, timestamp: @ts})

      refute html =~ "data-continuation"
    end
  end

  describe "the reader's own lines" do
    test "are marked so their band can be told apart, whatever the nickname's case" do
      msg = %{id: "o1", author: "Bob", content: "mine", type: :normal, timestamp: @ts}

      assert row(msg, %{viewer: "bob"}) =~ ~s(data-own="true")
      refute row(msg, %{viewer: "ana"}) =~ "data-own"
      refute row(msg) =~ "data-own"
    end

    test "narration is never the reader's own" do
      msg = %{id: "o2", author: "bob", content: "waves", type: :action, timestamp: @ts}

      refute row(msg, %{viewer: "bob"}) =~ "data-own"
    end
  end

  # The server writes some system lines with their own leading star; the row's
  # narration star must not double it ("* * Auto-joining #jogos...").
  test "a system line that already starts with a star prints one" do
    html =
      row(%{
        id: "sys-star",
        author: "System",
        content: "* Auto-joining #jogos...",
        type: :system,
        timestamp: @ts
      })

    text = html |> LazyHTML.from_fragment() |> LazyHTML.text()

    assert text =~ "* Auto-joining"
    refute text =~ ~r/\*\s*\*/
  end

  test "a line that is only emoji is printed large" do
    html = row(%{id: "j1", author: "ana", content: "\u{1F643}", type: :normal, timestamp: @ts})

    assert html =~ "chat-content--jumbo"

    refute row(%{id: "j2", author: "ana", content: "ok", type: :normal, timestamp: @ts}) =~
             "chat-content--jumbo"
  end
end
