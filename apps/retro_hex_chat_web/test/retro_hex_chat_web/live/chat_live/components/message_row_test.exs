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
    assert html =~ "chat-message--normal"
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
    assert html =~ ~s(class="chat-link")
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

  # Layout tokens the message shape depends on. Pinned on the component so the
  # coverage is deterministic (a full LiveView render was flaky).
  test "speech stacks its text under the head, with a data-nick handle and no angle brackets" do
    html = row(%{id: "g1", author: "alice", content: "hi", type: :normal, timestamp: @ts})
    assert html =~ ~s(data-message-layout="stacked")
    assert html =~ "chat-message__body"
    assert html =~ ~s(data-nick="alice")
    refute html =~ "&lt;alice&gt;"
  end

  # Narration has no author to bind the eye to and is short: a second line for
  # it would be ceremony, so it rides the head line and wraps to the margin.
  test "narration rides the head line instead of stacking" do
    action = row(%{id: "g2", author: "alice", content: "waves", type: :action, timestamp: @ts})
    system = row(%{id: "g3", content: "joined", type: :system, timestamp: @ts})

    assert action =~ ~s(data-message-layout="inline")
    assert system =~ ~s(data-message-layout="inline")
    refute system =~ "chat-message__body"
  end

  test "action messages carry the text-action class" do
    html = row(%{id: "a2", author: "bob", content: "waves", type: :action, timestamp: @ts})
    assert html =~ "text-action"
  end

  test "system messages are italicized (no grid nick column)" do
    html = row(%{id: "sy1", content: "joined", type: :system, timestamp: @ts})
    assert html =~ "italic"
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

  test "renders P2P invite messages as a plain request line without card actions" do
    html =
      row(
        %{
          id: "p2p1",
          author: "alice",
          content: "P2P session invite - accept it on this card. /lobby/tok123",
          type: :p2p_invite,
          timestamp: @ts,
          session_card: %{
            kind: :lobby,
            token: "tok123",
            status: "pending",
            terminal?: false,
            created_by: "alice",
            peer: "bob",
            created_at: @ts,
            connected_at: nil,
            closed_at: nil,
            closed_reason: nil,
            duration_seconds: nil
          }
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

    assert html =~ "chat-message--failed"
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
    assert html =~ "chat-message--highlighted"
    assert html =~ ~s(data-testid="highlighted-message")
  end

  test "tags each row with the kind icon matching its type" do
    assert row(%{id: "k1", author: "bob", content: "hi", type: :normal, timestamp: @ts}) =~
             ~s(data-message-kind="user")

    assert row(%{id: "k2", content: "joined", type: :system, timestamp: @ts}) =~
             ~s(data-message-kind="system")

    assert row(%{id: "k3", content: "boom", type: :error, timestamp: @ts}) =~
             ~s(data-message-kind="error")

    assert row(%{id: "k4", content: "svc", type: :service, timestamp: @ts}) =~
             ~s(data-message-kind="service")
  end

  test "deleted rows use the deleted kind icon" do
    html =
      row(%{
        id: "k5",
        author: "bob",
        content: "x",
        type: :normal,
        timestamp: @ts,
        deleted_at: @ts
      })

    assert html =~ ~s(data-message-kind="deleted")
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
end
