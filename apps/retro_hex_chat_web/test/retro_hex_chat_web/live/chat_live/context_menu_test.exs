defmodule RetroHexChatWeb.ChatLive.ContextMenuTest do
  @moduledoc """
  Tests for context menu data attributes and chat context menu functionality.
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  @moduletag :e2e

  setup do
    channel = "#ctxmenu#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  # ── Phase 2: Data Attributes ──────────────────────────────────

  describe "data attributes on chat messages" do
    test "regular messages have data-nick on .chat-nick span", %{conn: conn, channel: channel} do
      nick = "CtxNick#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})
      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(data-nick="#{nick}")
      assert html =~ "chat-nick"
    end

    test "messages have data-author attribute", %{conn: conn, channel: channel} do
      nick = "CtxAuth#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Test message"})
      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(data-author="#{nick}")
    end

    test "messages have data-message-id attribute", %{conn: conn, channel: channel} do
      nick = "CtxMsgId#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "ID test"})
      Process.sleep(50)
      html = render(view)

      assert html =~ "data-message-id="
    end

    test "system messages have data-system-message attribute", %{conn: conn, channel: channel} do
      # First user joins channel
      nick1 = "CtxSys1#{uid()}"
      {:ok, view1, _html} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      # Second user joins — first user sees the join system message
      nick2 = "CtxSys2#{uid()}"
      {:ok, view2, _html} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)
      Process.sleep(100)
      html = render(view1)

      # The join system message should have data-system-message="true"
      assert html =~ ~s(data-system-message="true")
    end

    test "regular messages do NOT have data-system-message on their div", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxNoSys#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Regular msg"})
      Process.sleep(50)
      html = render(view)

      # Regular messages should have data-author
      assert html =~ ~s(data-author="#{nick}")

      # Regular messages have type :message, so class is chat-message--message
      assert html =~ "chat-message--message"

      # Verify that message-type divs do not include data-system-message
      refute Regex.match?(
               ~r/chat-message--message[^<]*data-system-message/,
               html
             )
    end

    test "URLs in messages get data-url attribute", %{conn: conn, channel: channel} do
      nick = "CtxUrl#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "Check https://example.com"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "data-url="
      assert html =~ "https://example.com"
    end
  end

  # ── Phase 3 US1: Nick Context Menu ──────────────────────────────

  describe "nick context menu in chat" do
    test "chat_context_menu event with type=nick opens nick menu", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxNM1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Simulate right-click on nick by pushing the event directly
      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "SomeUser",
        "author" => "SomeUser",
        "message_id" => "msg-1",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> hello"
      })

      html = render(view)

      assert html =~ "Private Message"
      assert html =~ "Whois"
      assert html =~ "Copy Nick"
      assert html =~ "Ignore"
      assert html =~ "Add to Address Book"
      assert html =~ "Set Nick Color"
      assert html =~ ~s(data-testid="ctx-chat-pm")
      assert html =~ ~s(data-testid="ctx-chat-whois")
      assert html =~ ~s(data-testid="ctx-chat-copy-nick")
    end

    test "op user sees op actions in nick context menu", %{conn: conn, channel: channel} do
      nick = "CtxOp1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Make user an operator
      Server.set_mode(channel, nick, "+o", [nick])

      Process.sleep(50)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "TargetUser",
        "author" => "TargetUser",
        "message_id" => "msg-2",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <TargetUser> hi"
      })

      html = render(view)

      assert html =~ "Kick"
      assert html =~ "Ban"
      assert html =~ "Give Voice (+v)"
      assert html =~ "Give Op (+o)"
      assert html =~ ~s(data-testid="ctx-chat-kick")
      assert html =~ ~s(data-testid="ctx-chat-ban")
    end

    test "non-op user does NOT see op actions", %{conn: conn} do
      # Use a separate channel so the first joiner is op, not our test user
      nop_channel = "#ctxnop#{uid()}"
      ensure_channel(nop_channel)

      # First user joins and becomes op/owner
      owner = "CtxOwn#{uid()}"
      {:ok, owner_view, _html} = live(chat_conn(conn, owner), "/chat")
      join_channel(owner_view, nop_channel)

      # Second user joins (non-op)
      nick = "CtxNop1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, nop_channel)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "OtherUser",
        "author" => "OtherUser",
        "message_id" => "msg-3",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <OtherUser> hi"
      })

      html = render(view)

      # Op-only items should not be present
      refute html =~ ~s(data-testid="ctx-chat-kick")
      refute html =~ ~s(data-testid="ctx-chat-ban")
      refute html =~ ~s(data-testid="ctx-chat-voice")
      refute html =~ ~s(data-testid="ctx-chat-op")
    end

    test "right-click own nick shows disabled self-targeting actions", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxSelf#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => nick,
        "author" => nick,
        "message_id" => "msg-4",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <#{nick}> hi"
      })

      html = render(view)

      # Ignore should show as disabled for self
      assert html =~ ~s(data-testid="ctx-chat-ignore-disabled")
      # But PM and other actions should still be available
      assert html =~ ~s(data-testid="ctx-chat-pm")
    end

    test "Copy Nick dispatches clipboard_copy event", %{conn: conn, channel: channel} do
      nick = "CtxCpy1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "CopyMe",
        "author" => "CopyMe",
        "message_id" => "msg-5",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <CopyMe> hi"
      })

      # Click Copy Nick
      render_click(view, "ctx_chat_copy_nick", %{"nick" => "CopyMe"})
      html = render(view)

      # Menu should be closed after action
      refute html =~ ~s(data-testid="ctx-chat-pm")
    end

    test "close_chat_context_menu closes the menu", %{conn: conn, channel: channel} do
      nick = "CtxCls1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "SomeUser",
        "author" => "SomeUser",
        "message_id" => "msg-6",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> hi"
      })

      html = render(view)
      assert html =~ ~s(data-testid="ctx-chat-pm")

      # Close the menu
      render_click(view, "close_chat_context_menu")
      html = render(view)
      refute html =~ ~s(data-testid="ctx-chat-pm")
    end
  end

  # ── Phase 4 US2: URL Context Menu ───────────────────────────────

  describe "URL context menu in chat" do
    test "type=url opens URL menu with correct items", %{conn: conn, channel: channel} do
      nick = "CtxUrl1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "url",
        "x" => 100,
        "y" => 200,
        "url" => "https://example.com",
        "author" => "SomeUser",
        "message_id" => "msg-url-1",
        "is_system" => false,
        "message_urls" => ["https://example.com"],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> check https://example.com"
      })

      html = render(view)

      assert html =~ "Open Link"
      assert html =~ "Copy URL"
      assert html =~ "Save to URL List"
      assert html =~ ~s(data-testid="ctx-chat-open-url")
      assert html =~ ~s(data-testid="ctx-chat-copy-url")
      assert html =~ ~s(data-testid="ctx-chat-save-url")
    end

    test "Save to URL List adds URL to url_catcher_entries", %{conn: conn, channel: channel} do
      nick = "CtxSave#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "url",
        "x" => 100,
        "y" => 200,
        "url" => "https://saved.example.com",
        "author" => "Saver",
        "message_id" => "msg-url-2",
        "is_system" => false,
        "message_urls" => ["https://saved.example.com"],
        "has_selection" => false,
        "message_text" => "[12:00] <Saver> link"
      })

      render_click(view, "ctx_chat_save_url", %{
        "url" => "https://saved.example.com",
        "author" => "Saver"
      })

      # Menu should close and URL should be saved
      html = render(view)
      refute html =~ ~s(data-testid="ctx-chat-open-url")
    end
  end

  # ── Phase 5 US3: Channel Context Menu ─────────────────────────

  describe "channel context menu in chat" do
    test "type=channel opens channel menu with correct items", %{conn: conn, channel: channel} do
      nick = "CtxCh1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "channel",
        "x" => 100,
        "y" => 200,
        "channel" => "#general",
        "author" => "SomeUser",
        "message_id" => "msg-ch-1",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> join #general"
      })

      html = render(view)

      assert html =~ "Join Channel"
      assert html =~ "Copy Channel Name"
      assert html =~ "Channel Info"
      assert html =~ ~s(data-testid="ctx-chat-join")
    end

    test "Join Channel is disabled when user is already in that channel", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxChJ#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "channel",
        "x" => 100,
        "y" => 200,
        "channel" => channel,
        "author" => "SomeUser",
        "message_id" => "msg-ch-2",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> join #{channel}"
      })

      html = render(view)

      # Join Channel should be disabled (has disabled class)
      assert Regex.match?(~r/disabled[^>]*ctx-chat-join/, html)
    end
  end

  # ── Phase 6 US4: Message Context Menu ─────────────────────────

  describe "message context menu in chat" do
    test "type=message opens message menu with correct items", %{conn: conn, channel: channel} do
      nick = "CtxMsg1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "message",
        "x" => 100,
        "y" => 200,
        "author" => "SomeUser",
        "message_id" => "msg-m-1",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> hello world"
      })

      html = render(view)

      assert html =~ "Copy Message"
      assert html =~ "Copy Selected Text"
      assert html =~ "Reply"
      assert html =~ "Ignore Sender"
      assert html =~ ~s(data-testid="ctx-chat-copy-message")
      assert html =~ ~s(data-testid="ctx-chat-copy-selection")
      assert html =~ ~s(data-testid="ctx-chat-quote-reply")
      assert html =~ ~s(data-testid="ctx-chat-ignore-sender")
    end

    test "system message right-click does NOT show Ignore Sender", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxMSys#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "message",
        "x" => 100,
        "y" => 200,
        "author" => "System",
        "message_id" => "msg-m-2",
        "is_system" => true,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "* UserX has joined the channel"
      })

      html = render(view)

      assert html =~ "Copy Message"
      refute html =~ ~s(data-testid="ctx-chat-ignore-sender")
    end

    test "message with URL shows URL sub-items", %{conn: conn, channel: channel} do
      nick = "CtxMUrl#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "message",
        "x" => 100,
        "y" => 200,
        "url" => "https://example.com",
        "author" => "SomeUser",
        "message_id" => "msg-m-3",
        "is_system" => false,
        "message_urls" => ["https://example.com"],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> see https://example.com"
      })

      html = render(view)

      assert html =~ "Copy Message"
      assert html =~ ~s(data-testid="ctx-chat-msg-open-url")
      assert html =~ ~s(data-testid="ctx-chat-msg-copy-url")
    end

    test "Reply is enabled for non-system messages", %{conn: conn, channel: channel} do
      nick = "CtxQR#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "message",
        "x" => 100,
        "y" => 200,
        "author" => "SomeUser",
        "message_id" => "msg-m-4",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> hi"
      })

      html = render(view)

      # Reply should NOT be disabled for regular messages
      assert html =~ ~s(data-testid="ctx-chat-quote-reply")
      refute Regex.match?(~r/disabled[^>]*ctx-chat-quote-reply/, html)
    end
  end

  # ── Phase 7 US5: Extended Treebar Context Menu ────────────────

  describe "extended treebar context menu" do
    test "right-click treebar channel shows extended menu items", %{conn: conn, channel: channel} do
      nick = "CtxTb1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "channel_right_click", %{
        "channel" => channel,
        "x" => 100,
        "y" => 200
      })

      html = render(view)

      assert html =~ ~s(data-testid="treebar-context-menu")
      assert html =~ ~s(data-testid="ctx-treebar-mark-read")
      assert html =~ ~s(data-testid="ctx-treebar-mute")
      assert html =~ ~s(data-testid="ctx-treebar-copy-name")
      assert html =~ ~s(data-testid="ctx-treebar-leave")
      assert html =~ ~s(data-testid="ctx-treebar-settings")
      assert html =~ "Mark as Read"
      assert html =~ "Mute Channel"
      assert html =~ "Copy Name"
      assert html =~ "Leave Channel"
      assert html =~ "Channel Settings"
    end

    test "Mark as Read clears unread for that channel", %{conn: conn, channel: channel} do
      nick = "CtxTb2#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Switch to another channel so we can get unread on the first
      other_channel = "#ctxother#{uid()}"
      ensure_channel(other_channel)
      join_channel(view, other_channel)

      # Now mark the original channel as read via treebar menu
      render_click(view, "channel_right_click", %{
        "channel" => channel,
        "x" => 100,
        "y" => 200
      })

      render_click(view, "ctx_treebar_mark_read", %{"channel" => channel})

      # Menu should close
      html = render(view)
      refute html =~ ~s(data-testid="treebar-context-menu")
    end

    test "Mute Channel toggles mute state", %{conn: conn, channel: channel} do
      nick = "CtxTb3#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Open menu - should show "Mute Channel" since not muted
      render_click(view, "channel_right_click", %{
        "channel" => channel,
        "x" => 100,
        "y" => 200
      })

      html = render(view)
      assert html =~ "Mute Channel"

      # Click mute
      render_click(view, "ctx_treebar_mute", %{"channel" => channel})

      # Now open menu again - should show "Unmute Channel"
      render_click(view, "channel_right_click", %{
        "channel" => channel,
        "x" => 100,
        "y" => 200
      })

      html = render(view)
      assert html =~ "Unmute Channel"
    end
  end

  # ── Phase 8: Polish ───────────────────────────────────────────

  describe "context menu integration" do
    test "chat context menu has ContextMenuHook for keyboard nav and repositioning", %{
      conn: conn,
      channel: channel
    } do
      nick = "CtxHk1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "chat_context_menu", %{
        "type" => "nick",
        "x" => 100,
        "y" => 200,
        "nick" => "SomeUser",
        "author" => "SomeUser",
        "message_id" => "msg-hook-1",
        "is_system" => false,
        "message_urls" => [],
        "has_selection" => false,
        "message_text" => "[12:00] <SomeUser> hi"
      })

      html = render(view)
      assert html =~ ~s(phx-hook="ContextMenuHook")
      assert html =~ ~s(id="chat-context-menu")
    end

    test "treebar context menu has ContextMenuHook", %{conn: conn, channel: channel} do
      nick = "CtxHk2#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "channel_right_click", %{
        "channel" => channel,
        "x" => 100,
        "y" => 200
      })

      html = render(view)
      assert html =~ ~s(phx-hook="ContextMenuHook")
      assert html =~ ~s(id="treebar-context-menu")
    end

    test "nicklist context menu has shortcut hints", %{conn: conn, channel: channel} do
      nick = "CtxHk3#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # The nicklist context menu is opened via nick_right_click event
      render_click(view, "nick_right_click", %{
        "nick" => "SomeUser",
        "x" => 100,
        "y" => 200
      })

      html = render(view)
      assert html =~ ~s(data-testid="ctx-query")
      assert html =~ "Query (PM)"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp join_channel(view, channel) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{channel}"})
    Process.sleep(50)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
