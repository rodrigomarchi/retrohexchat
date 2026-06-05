defmodule RetroHexChatWeb.MessagingUIFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Components.UI.{ChatContextMenu, ChatInput, NicklistContextMenu}

  describe "action message input mode" do
    test "chat input renders active /me toggle state" do
      html =
        render_component(&ChatInput.chat_input/1,
          value: "",
          name: "input",
          placeholder: "Message #lobby",
          action_enabled: true,
          action_active: true,
          on_action_toggle: "toggle_action_mode"
        )

      assert html =~ ~s(data-testid="chat-action-toggle")
      assert html =~ ~s(aria-pressed="true")
      assert html =~ ~s|title="Send action message (/me)"|
      assert html =~ "What are you doing? (/me mode)"
    end

    test "toggle sends next message as /me and resets", %{conn: conn} do
      channel = "#msg-action-#{uid()}"
      nick = "MsgAct#{uid()}"
      view = connect_user(conn, nick)
      join_channel(view, channel)

      html = render(view)
      assert html =~ ~s(data-testid="chat-action-toggle")

      html = render_click(view, "toggle_action_mode")
      assert html =~ "What are you doing? (/me mode)"
      assert html =~ ~s(aria-pressed="true")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "waves hello"})

      :timer.sleep(20)
      html = render(view)
      assert html =~ "waves hello"
      assert html =~ "text-action"
      refute html =~ "What are you doing? (/me mode)"
    end

    test "empty action message shows inline error and keeps action mode", %{conn: conn} do
      channel = "#msg-empty-action-#{uid()}"
      view = connect_user(conn, "MsgEmpty#{uid()}")
      join_channel(view, channel)
      render_click(view, "toggle_action_mode")

      html =
        view
        |> element(~s([data-testid="chat-input-form"]))
        |> render_submit(%{"input" => ""})

      assert html =~ "Action message cannot be empty"
      assert html =~ "What are you doing? (/me mode)"
    end
  end

  describe "notice context menu composer" do
    test "nicklist and chat nick menus expose Send Notice after PM action" do
      nicklist_actions =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "Alice",
          on_action: "nicklist_context_action"
        )
        |> Floki.parse_document!()
        |> menu_actions()

      chat_actions =
        render_component(&ChatContextMenu.chat_context_menu/1,
          visible: true,
          type: :nick,
          target_nick: "Alice",
          on_action: "chat_context_action"
        )
        |> Floki.parse_document!()
        |> menu_actions()

      assert "context_notice" in nicklist_actions
      assert "ctx_chat_notice" in chat_actions

      assert index_of(nicklist_actions, "context_query") <
               index_of(nicklist_actions, "context_notice")

      assert index_of(nicklist_actions, "context_notice") <
               index_of(nicklist_actions, "context_whois")

      assert index_of(chat_actions, "ctx_chat_pm") < index_of(chat_actions, "ctx_chat_notice")
      assert index_of(chat_actions, "ctx_chat_notice") < index_of(chat_actions, "ctx_chat_whois")
    end

    test "nicklist Send Notice uses main input composer and sends notice", %{conn: conn} do
      channel = "#msg-notice-#{uid()}"
      sender = "NoticeFrom#{uid()}"
      target = "NoticeTo#{uid()}"

      sender_view = connect_user(conn, sender)
      target_view = connect_user(conn, target)
      join_channel(sender_view, channel)
      join_channel(target_view, channel)

      sender_view
      |> render_click("nick_right_click", %{"nick" => target, "x" => 100, "y" => 200})

      html = render_click(sender_view, "context_notice", %{"nick" => target})
      assert html =~ "Notice to #{target}:"
      assert html =~ "Send Notice"

      html =
        sender_view
        |> element(~s([data-testid="chat-input-form"]))
        |> render_submit(%{"input" => "Check out #project"})

      refute html =~ "Notice to #{target}:"
      refute html =~ "Send Notice"

      :timer.sleep(20)
      assert render(target_view) =~ "Check out #project"
    end

    test "empty notice message shows inline error and can be cancelled", %{conn: conn} do
      target = "NoticeEmpty#{uid()}"
      sender_view = connect_user(conn, "NoticeErr#{uid()}")
      _target_view = connect_user(conn, target)

      html = render_click(sender_view, "context_notice", %{"nick" => target})
      assert html =~ "Notice to #{target}:"

      html =
        sender_view
        |> element(~s([data-testid="chat-input-form"]))
        |> render_submit(%{"input" => ""})

      assert html =~ "Notice message cannot be empty"

      html = render_click(sender_view, "cancel_notice_mode")
      refute html =~ "Notice to #{target}:"
      refute html =~ "Notice message cannot be empty"
    end
  end

  describe "Feature 07 help documentation" do
    test "help topics mention action toggle and notice context menu" do
      me = HelpTopics.get_topic("cmd-me")
      notice = HelpTopics.get_topic("cmd-notice")
      private_messages = HelpTopics.get_topic("private-messages")
      shortcuts = HelpTopics.get_topic("keyboard-shortcuts")

      assert "action toggle" in me.keywords
      assert "send notice" in notice.keywords
      assert "context menu" in notice.keywords
      assert "notice" in private_messages.keywords
      assert "me" in shortcuts.keywords
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp join_channel(view, channel) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => "/join #{channel}"})
  end

  defp menu_actions(document) do
    document
    |> Floki.find("[data-testid^=\"context-menu-item-\"]")
    |> Enum.map(fn {_tag, attrs, _children} ->
      attrs
      |> Enum.find_value(fn
        {"data-testid", value} -> value
        _ -> nil
      end)
      |> String.replace_prefix("context-menu-item-", "")
    end)
  end

  defp index_of(actions, action), do: Enum.find_index(actions, &(&1 == action))
end
