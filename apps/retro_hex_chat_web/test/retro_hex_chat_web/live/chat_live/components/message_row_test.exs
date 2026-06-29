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
  end

  test "renders normal message content" do
    html = row(%{id: "m1", author: "bob", content: "hello world", type: :normal, timestamp: @ts})
    assert html =~ "hello world"
  end

  test "renders an action message" do
    html = row(%{id: "a1", author: "bob", content: "waves", type: :action, timestamp: @ts})
    assert html =~ "* bob"
    assert html =~ "waves"
  end

  test "renders system, service, error and notice rows" do
    assert row(%{id: "s1", content: "joined", type: :system, timestamp: @ts}) =~ "joined"
    assert row(%{id: "v1", content: "svc msg", type: :service, timestamp: @ts}) =~ "svc msg"
    assert row(%{id: "e1", content: "boom", type: :error, timestamp: @ts}) =~ "boom"

    notice =
      row(%{id: "n1", author: "srv", content: "notice text", type: :notice, timestamp: @ts})

    assert notice =~ "notice text"
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
