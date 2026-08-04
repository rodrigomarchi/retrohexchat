defmodule RetroHexChatWeb.Components.UI.ChatMessageTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatMessage

  @moduletag :unit

  defp render_message(type) do
    render_component(&chat_message/1,
      type: type,
      nick: "alice",
      inner_block: %{
        inner_block: fn _, _ -> "hello" end
      }
    )
  end

  describe "chat_message/1 type styling" do
    test "renders a notify_rename system message without crashing" do
      # Regression: a nick change broadcasts a :notify_rename message. A missing
      # type_class/1 clause used to raise FunctionClauseError, crashing the chat
      # LiveView and reloading every connected client.
      html = render_message("notify_rename")
      assert html =~ "text-notice"
      assert html =~ "hello"
    end

    test "renders an unknown message type plainly instead of crashing" do
      # The catch-all guarantees one unexpected type can never take down the
      # whole channel's LiveView.
      html = render_message("some_future_type")
      assert html =~ "hello"
    end

    test "still styles known types" do
      assert render_message("error") =~ "text-error"
      assert render_message("notify_online") =~ "text-success"
    end
  end

  describe "chat_message/1 meta column" do
    test "renders an interactive .chat-nick handle without angle brackets" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "alice",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(class="chat-nick)
      assert html =~ ~s(data-nick="alice")
      assert html =~ "alice"
      refute html =~ "&lt;alice&gt;"
    end

    test "renders a non-interactive source origin with no data-nick" do
      html =
        render_component(&chat_message/1,
          type: "system",
          source: "System",
          inner_block: %{inner_block: fn _, _ -> "joined" end}
        )

      assert html =~ "System"
      assert html =~ ~s(title="System")
      refute html =~ "data-nick"
    end

    test "keeps the timestamp testid and carries the full datetime in the title" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "bob",
          timestamp: "01/01 12:00",
          meta_title: "01/01/2024 12:00",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(data-testid="chat-message-timestamp")
      assert html =~ "01/01 12:00"
      assert html =~ ~s(title="01/01/2024 12:00")
    end
  end

  describe "chat_message/1 shape" do
    test "speech stacks its text under the head, behind a spine in the nick colour" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "alice",
          nick_color: "nick-color-3",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(data-message-layout="stacked")
      assert html =~ "chat-message__body"
      assert html =~ ~s(class="chat-message__spine nick-color-3")
    end

    test "narration rides the head line and has no body" do
      action =
        render_component(&chat_message/1,
          type: "action",
          nick: "alice",
          inner_block: %{inner_block: fn _, _ -> "* waves" end}
        )

      system =
        render_component(&chat_message/1,
          type: "system",
          source: "System",
          inner_block: %{inner_block: fn _, _ -> "joined" end}
        )

      assert action =~ ~s(data-message-layout="inline")
      assert system =~ ~s(data-message-layout="inline")
      refute action =~ "chat-message__body"
      refute system =~ "chat-message__body"
    end

    # An inline help card is a block: riding the head line would put a card
    # where a sentence belongs.
    test "an explicit layout overrides the type-derived shape" do
      html =
        render_component(&chat_message/1,
          type: "system",
          source: "Help",
          kind: "help",
          layout: "stacked",
          inner_block: %{inner_block: fn _, _ -> "card" end}
        )

      assert html =~ ~s(data-message-layout="stacked")
      assert html =~ "chat-message__body"
    end
  end

  describe "chat_message/1 kind icon" do
    test "a nick-authored line shows the user glyph" do
      html =
        render_component(&chat_message/1,
          type: "normal",
          nick: "alice",
          inner_block: %{inner_block: fn _, _ -> "hi" end}
        )

      assert html =~ ~s(data-message-kind="user")
      assert html =~ "<svg"
    end

    test "a system origin line shows the system glyph, not the user glyph" do
      html =
        render_component(&chat_message/1,
          type: "system",
          source: "System",
          inner_block: %{inner_block: fn _, _ -> "joined" end}
        )

      assert html =~ ~s(data-message-kind="system")
      refute html =~ ~s(data-message-kind="user")
    end

    test "an explicit kind overrides the type-derived icon" do
      html =
        render_component(&chat_message/1,
          type: "system",
          source: "Help",
          kind: "help",
          inner_block: %{inner_block: fn _, _ -> "help" end}
        )

      assert html =~ ~s(data-message-kind="help")
      refute html =~ ~s(data-message-kind="system")
    end
  end

  describe "message_kind_icon/1" do
    test "renders a distinct svg for each known kind" do
      user = render_component(&message_kind_icon/1, kind: "user")
      system = render_component(&message_kind_icon/1, kind: "system")

      assert user =~ "<svg"
      assert system =~ "<svg"
      refute user == system
    end

    test "renders nothing for an unknown kind" do
      html = render_component(&message_kind_icon/1, kind: "some_future_kind")

      refute html =~ "<svg"
      refute html =~ "data-message-kind"
    end
  end
end
