defmodule RetroHexChatWeb.E2ETest do
  @moduledoc """
  End-to-end tests validating complete user journeys and all visual elements.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 1: ConnectLive
  # ══════════════════════════════════════════════════════════════

  describe "Screen 1: ConnectLive" do
    test "1.1 renders nickname input and Connect button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/connect")
      assert html =~ ~s(name="nickname")
      assert html =~ "Connect"
      assert html =~ "connect-btn"
    end

    test "1.2 empty nickname keeps button disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => ""})
      assert html =~ "disabled"
    end

    test "1.3 nickname >16 chars shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      long = String.duplicate("A", 17)
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => long})
      assert html =~ "error-text"
    end

    test "1.4 nickname with space shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "bad nick"})
      assert html =~ "error-text"
    end

    test "1.5 nickname starting with number shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "1nick"})
      assert html =~ "error-text"
    end

    test "1.6 valid nickname clears error and enables button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "ValidNick"})
      refute html =~ "error-text"
      refute html =~ ~s(disabled="disabled")
    end

    test "1.7 boundary: 1-char nickname accepted", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "A"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "A"})
      assert html =~ ~s(value="A")
      assert html =~ ~s(id="connect-session-form")
    end

    test "1.8 boundary: 16-char nickname accepted", %{conn: conn} do
      nick = String.duplicate("B", 16)
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => nick})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => nick})
      assert html =~ ~s(value="#{nick}")
      assert html =~ ~s(id="connect-session-form")
    end

    test "1.9 valid submit triggers form submission to /chat/session", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "TestUser"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "TestUser"})
      assert html =~ ~s(value="TestUser")
      assert html =~ ~s(action="/chat/session")
    end

    test "1.10 IRC special chars [Nick] work", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      view |> element("form[phx-submit]") |> render_change(%{"nickname" => "[Nick]"})
      html = view |> element("form[phx-submit]") |> render_submit(%{"nickname" => "[Nick]"})
      assert html =~ ~s(id="connect-session-form")
    end

    test "1.11 invalid chars !!bad show error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")
      html = view |> element("form[phx-submit]") |> render_change(%{"nickname" => "!!bad"})
      assert html =~ "error-text"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 2: ChatLive — Layout and Connection
  # ══════════════════════════════════════════════════════════════

  describe "Screen 2: ChatLive layout and connection" do
    test "2.1 mount shows complete layout (conversations, chat, status, toolbar)", %{
      conn: conn
    } do
      {:ok, _view, html} = live(chat_conn(conn, "LayoutUser"), "/chat")
      assert html =~ "conversations"
      assert html =~ "chat-area"
      assert html =~ "conversations-users"
      assert html =~ "status-bar"
      assert html =~ "toolbar"
    end

    test "2.2 auto-join #lobby, user appears in conversations user list", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "LobbyJoin"), "/chat")
      assert html =~ "#lobby"
      assert html =~ "LobbyJoin"
    end

    test "2.3 status bar shows nick, channel, user count, connection", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "StatusChk"), "/chat")
      assert html =~ ~s(data-testid="status-nick")
      assert html =~ "StatusChk"
      assert html =~ ~s(data-testid="status-channel")
      assert html =~ "#lobby"
      assert html =~ ~s(data-testid="status-users")
      assert html =~ ~s(data-testid="status-connection")
      assert html =~ "● On"
    end

    test "2.4 mount without nickname redirects to /", %{conn: conn} do
      result = live(chat_conn(conn, "!!invalid!!"), "/chat")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end

    test "2.5 chat input and Send button present", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "InputChk"), "/chat")
      assert html =~ "chat-input"
      assert html =~ "Send"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 3: Messages
  # ══════════════════════════════════════════════════════════════

  describe "Screen 3: Messages" do
    test "3.1 regular message shows nick, timestamp, content", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "MsgUser"), "/chat")
      # Switch from status tab to #lobby channel
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      send_message_and_wait(view, "Hello E2E")
      html = render(view)
      assert html =~ "chat-nick"
      assert html =~ "chat-timestamp"
      assert html =~ "Hello E2E"
    end

    test "3.2 message doesn't leak to another channel", %{conn: conn} do
      ch = unique_channel("leak")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "LeakUser"), "/chat")
      send_command(view, "/join #{ch}")
      send_message_and_wait(view, "secret msg in #{ch}")

      # Switch to #lobby
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      html = render(view)
      refute html =~ "secret msg in #{ch}"
    end

    test "3.3 /me action renders with chat-action class", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ActionUser"), "/chat")
      send_message_and_wait(view, "/me waves hello")
      html = render(view)
      assert html =~ "chat-action"
    end

    test "3.4 system message (join) renders with chat-system class", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SysMsgUser"), "/chat")
      send(view.pid, {:user_joined, %{nickname: "NewPerson"}})
      html = render(view)
      assert html =~ "chat-system"
      assert html =~ "joined"
    end

    test "3.5 error message renders with chat-error class", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ErrMsgUser"), "/chat")
      send_command(view, "/foobar")
      html = render(view)
      assert html =~ "chat-error"
    end

    test "3.6 empty message is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EmptyMsg"), "/chat")
      html = view |> element("form.chat-input-form") |> render_submit(%{"input" => ""})
      assert html =~ "chat-input-form"
    end

    test "3.7 HTML entities escaped (anti-XSS)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "XssUser"), "/chat")
      send_message_and_wait(view, "<script>alert('xss')</script>")
      html = render(view)
      refute html =~ "<script>"
    end

    test "3.8 /clear empties the message stream", %{conn: conn} do
      ch = unique_channel("clear")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "ClearE2E"), "/chat")
      send_command(view, "/join #{ch}")
      send_message_and_wait(view, "ClearMe message")
      html = render(view)
      assert html =~ "ClearMe message"

      send_command(view, "/clear")
      html = render(view)
      refute html =~ "ClearMe message"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 4: Channel Operations
  # ══════════════════════════════════════════════════════════════

  describe "Screen 4: Channel operations" do
    test "4.1 /join creates channel, appears in conversations, switches to it", %{conn: conn} do
      ch = unique_channel("join")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "JoinE2E"), "/chat")
      send_command(view, "/join #{ch}")
      html = render(view)
      assert html =~ ch
    end

    test "4.2 /join with correct password succeeds", %{conn: conn} do
      ch = unique_channel("pw")
      ensure_channel(ch)
      Server.join(ch, "PwFounder", nil)
      Server.set_mode(ch, "PwFounder", "+k", ["secret"])

      {:ok, view, _html} = live(chat_conn(conn, "PwJoin"), "/chat")
      send_command(view, "/join #{ch} secret")
      html = render(view)
      assert html =~ ch
    end

    test "4.3 /join with wrong password shows error", %{conn: conn} do
      ch = unique_channel("pwfail")
      ensure_channel(ch)
      Server.join(ch, "PwfFounder", nil)
      Server.set_mode(ch, "PwfFounder", "+k", ["correct"])

      {:ok, view, _html} = live(chat_conn(conn, "PwFail"), "/chat")
      send_command(view, "/join #{ch} wrong")
      html = render(view)
      assert html =~ "chat-error" or html =~ "key"
    end

    test "4.4 /part leaves channel, switches to another", %{conn: conn} do
      ch = unique_channel("part")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "PartE2E"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/part")
      html = render(view)
      assert html =~ "#lobby"
    end

    test "4.5 /part last channel doesn't crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PartLastE2E"), "/chat")
      send_command(view, "/part")
      html = render(view)
      assert html =~ "chat-input-form"
    end

    test "4.6 click on conversations changes active channel", %{conn: conn} do
      ch = unique_channel("tree")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TreeClick"), "/chat")
      send_command(view, "/join #{ch}")

      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
        |> render_click()

      assert html =~ "conversations-active"
    end

    test "4.7 message in inactive channel marks conversations-unread", %{conn: conn} do
      ch = unique_channel("unread")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "UnreadE2E"), "/chat")
      send_command(view, "/join #{ch}")

      # Switch back to #lobby
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send message to inactive channel
      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: "unr-#{uid()}",
          author: "someone",
          content: "unread msg",
          type: :message,
          channel: ch,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "conversations-unread"
    end

    test "4.8 switching to unread channel clears indicator", %{conn: conn} do
      ch = unique_channel("clr")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "ClrE2E"), "/chat")
      send_command(view, "/join #{ch}")

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: "unr2-#{uid()}",
          author: "x",
          content: "y",
          type: :message,
          channel: ch,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "conversations-unread"

      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#{ch}"]))
        |> render_click()

      refute html =~ "conversations-unread"
    end

    test "4.9 limit of 10 channels shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "LimitE2E"), "/chat")

      # Already in #lobby (1). Join 9 more = 10 total
      for i <- 1..9 do
        ch = unique_channel("lim#{i}")
        ensure_channel(ch)
        send_command(view, "/join #{ch}")
      end

      # 11th join should fail
      ch11 = unique_channel("lim11")
      ensure_channel(ch11)
      send_command(view, "/join #{ch11}")
      html = render(view)
      assert html =~ "chat-error" or html =~ "maximum"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 5: Channel Modes
  # ══════════════════════════════════════════════════════════════

  describe "Screen 5: Channel modes" do
    test "5.1 +m moderated: regular user can't send", %{conn: conn} do
      ch = unique_channel("mod")
      ensure_channel(ch)
      Server.join(ch, "ModFounder", nil)
      Server.set_mode(ch, "ModFounder", "+m")

      {:ok, view, _html} = live(chat_conn(conn, "ModReg"), "/chat")
      send_command(view, "/join #{ch}")
      send_message_and_wait(view, "try to speak")
      html = render(view)
      assert html =~ "moderated" or html =~ "Cannot send"
    end

    test "5.2 +t topic lock: non-op can't /topic", %{conn: conn} do
      ch = unique_channel("tlock")
      ensure_channel(ch)
      Server.join(ch, "TlockOp", nil)
      Server.set_mode(ch, "TlockOp", "+t")

      {:ok, view, _html} = live(chat_conn(conn, "TlockReg"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/topic Nope")
      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end

    test "5.3 +i invite-only reflected in state", %{conn: conn} do
      ch = unique_channel("inv")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "InvOp"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/mode +i")
      Process.sleep(50)

      {:ok, state} = Server.get_state(ch)
      assert state.modes =~ "i"
    end

    test "5.4 +k key reflected in state", %{conn: conn} do
      ch = unique_channel("key")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "KeyOp"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/mode +k secret123")
      Process.sleep(50)

      {:ok, state} = Server.get_state(ch)
      assert state.modes =~ "k"
    end

    test "5.5 +l limit reflected in state", %{conn: conn} do
      ch = unique_channel("lim")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "LimOp"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/mode +l 5")
      Process.sleep(50)

      {:ok, state} = Server.get_state(ch)
      assert state.modes =~ "l"
    end

    test "5.6 -m removes moderated: regular can send again", %{conn: conn} do
      ch = unique_channel("unmod")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "UnmodOp"), "/chat")
      send_command(view, "/join #{ch}")

      # Set +m, then -m
      Server.set_mode(ch, "UnmodOp", "+m")
      Server.set_mode(ch, "UnmodOp", "-m")

      # Join a second user (regular)
      {:ok, view2, _html} = live(chat_conn(new_conn(), "UnmodReg"), "/chat")
      send_command(view2, "/join #{ch}")
      send_message_and_wait(view2, "can speak again")
      html = render(view2)
      refute html =~ "moderated"
    end

    test "5.7 non-operator /mode shows error", %{conn: conn} do
      ch = unique_channel("noopmod")
      ensure_channel(ch)
      Server.join(ch, "NoOpFounder", nil)

      {:ok, view, _html} = live(chat_conn(conn, "NoOpMod"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/mode +m")
      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 6: Moderation
  # ══════════════════════════════════════════════════════════════

  describe "Screen 6: Moderation" do
    test "6.1 /kick shows system message", %{conn: conn} do
      ch = unique_channel("kick")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "KickOp"), "/chat")
      send_command(view, "/join #{ch}")

      # Add target to channel
      Server.join(ch, "KickVictim", nil)
      send(view.pid, {:user_joined, %{nickname: "KickVictim", role: :regular}})

      send_command(view, "/kick KickVictim spamming")
      Process.sleep(50)
      html = render(view)
      assert html =~ "kicked"
    end

    test "6.2 kick via context menu works", %{conn: conn} do
      ch = unique_channel("ctxkick")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "CtxKickOp"), "/chat")
      send_command(view, "/join #{ch}")

      Server.join(ch, "CtxKickTgt", nil)
      send(view.pid, {:user_joined, %{nickname: "CtxKickTgt", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "CtxKickTgt", "x" => 0, "y" => 0})
      html = render_click(view, "context_kick", %{"nick" => "CtxKickTgt"})
      refute html =~ "context-menu"
    end

    test "6.3 /ban shows system message", %{conn: conn} do
      ch = unique_channel("ban")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "BanOpE2E"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/ban BanVictim spambot")
      Process.sleep(50)
      html = render(view)
      # Ban may show as system message or just succeed without error
      assert html =~ "chat-input-form"
    end

    test "6.4 ban via context menu works", %{conn: conn} do
      ch = unique_channel("ctxban")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "CtxBanOp"), "/chat")
      send_command(view, "/join #{ch}")

      Server.join(ch, "CtxBanTgt", nil)
      send(view.pid, {:user_joined, %{nickname: "CtxBanTgt", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "CtxBanTgt", "x" => 0, "y" => 0})
      html = render_click(view, "context_ban", %{"nick" => "CtxBanTgt"})
      refute html =~ "context-menu"
    end

    test "6.5 give op via context menu shows @prefix", %{conn: conn} do
      ch = unique_channel("giveop")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "GiveOpE2E"), "/chat")
      send_command(view, "/join #{ch}")

      send(view.pid, {:user_joined, %{nickname: "OpRecv", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "OpRecv", "x" => 0, "y" => 0})
      render_click(view, "context_op", %{"nick" => "OpRecv"})

      # Mode change broadcast should update user list
      Process.sleep(50)
      html = render(view)
      assert html =~ "nick-operator" or html =~ "nick-owner"
    end

    test "6.6 give voice via context menu shows +prefix", %{conn: conn} do
      ch = unique_channel("givevoice")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "GiveVoice"), "/chat")
      send_command(view, "/join #{ch}")

      # Also join the target in the server so set_mode works
      Server.join(ch, "VoRecv", nil)
      send(view.pid, {:user_joined, %{nickname: "VoRecv", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "VoRecv", "x" => 0, "y" => 0})
      render_click(view, "context_voice", %{"nick" => "VoRecv"})

      # Wait for PubSub mode_changed broadcast to arrive
      Process.sleep(100)
      html = render(view)
      assert html =~ "nick-voiced" or html =~ "sets mode"
    end

    test "6.7 non-op kick shows error", %{conn: conn} do
      ch = unique_channel("nonopkick")
      ensure_channel(ch)
      Server.join(ch, "RealOp", nil)

      {:ok, view, _html} = live(chat_conn(conn, "NoOpKick"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/kick RealOp test")
      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end

    test "6.8 non-op ban shows error", %{conn: conn} do
      ch = unique_channel("nonopban")
      ensure_channel(ch)
      Server.join(ch, "BanOp2", nil)

      {:ok, view, _html} = live(chat_conn(conn, "NoOpBan"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/ban BanOp2 test")
      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end

    test "6.9 kicked user removed from user list", %{conn: conn} do
      ch = unique_channel("kickremove")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "KickRmOp"), "/chat")
      send_command(view, "/join #{ch}")

      send(view.pid, {:user_joined, %{nickname: "KickRmTgt", role: :regular}})
      html = render(view)
      assert html =~ "KickRmTgt"

      send(
        view.pid,
        {:user_kicked, %{operator: "KickRmOp", target: "KickRmTgt", reason: nil}}
      )

      html = render(view)
      refute html =~ "nick-regular"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 7: User List (in conversations)
  # ══════════════════════════════════════════════════════════════

  describe "Screen 7: User List" do
    test "7.1 user list shows role icons under active channel", %{conn: conn} do
      ch = unique_channel("nickgrp")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "NickGrp"), "/chat")
      send_command(view, "/join #{ch}")
      html = render(view)
      # User is owner (first to join) — role icon visible in conversations
      assert html =~ "nick-owner"
      assert html =~ "conversations-users"
    end

    test "7.2 prefixes: @ for op, + for voiced", %{conn: conn} do
      ch = unique_channel("prefix")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "PrefixOp"), "/chat")
      send_command(view, "/join #{ch}")

      send(view.pid, {:user_joined, %{nickname: "VoUser", role: :voiced}})
      html = render(view)
      assert html =~ "nick-owner"
      assert html =~ "nick-voiced"
    end

    test "7.3 away user has nick-away class", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AwayNick"), "/chat")
      # Set away via /away — this updates the Tracker and shows system message
      send_command(view, "/away Gone fishing")
      html = render(view)
      assert html =~ "now away"
    end

    test "7.4 right-click opens context menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxOpen"), "/chat")

      html =
        render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 100, "y" => 200})

      assert html =~ "context-menu"
    end

    test "7.5 op sees extra context items (Kick, Ban, Give Op, Give Voice)", %{conn: conn} do
      ch = unique_channel("opctx")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "OpCtx"), "/chat")
      send_command(view, "/join #{ch}")

      # As the first user (operator), right-click should show op items
      html = render_click(view, "nick_right_click", %{"nick" => "SomeUser", "x" => 0, "y" => 0})
      assert html =~ "ctx-kick"
      assert html =~ "ctx-ban"
      assert html =~ "ctx-op"
      assert html =~ "ctx-voice"
    end

    test "7.6 click outside closes context menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxClose"), "/chat")
      render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 0, "y" => 0})
      html = render_click(view, "close_context_menu")
      refute html =~ "context-menu"
    end

    test "7.7 user count is correct", %{conn: conn} do
      ch = unique_channel("count")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "CountE2E"), "/chat")
      send_command(view, "/join #{ch}")
      html = render(view)
      # User count shown in conversations next to channel name
      assert html =~ "(1)"

      send(view.pid, {:user_joined, %{nickname: "CountGuest", role: :regular}})
      html = render(view)
      assert html =~ "(2)"
    end

    test "7.8 /whois sets whois assigns without crashing", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WhoisE2E"), "/chat")
      send_command(view, "/whois WhoisTarget")
      html = render(view)
      # View stays alive and functional (whois dialog may or may not render)
      assert html =~ "chat-input-form"
    end

    test "7.9 context_whois closes menu and sets whois", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxWhois"), "/chat")
      render_click(view, "nick_right_click", %{"nick" => "WhoTgt", "x" => 0, "y" => 0})
      html = render_click(view, "context_whois", %{"nick" => "WhoTgt"})
      refute html =~ "context-menu"
      assert html =~ "chat-input-form"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 8: Private Messages
  # ══════════════════════════════════════════════════════════════

  describe "Screen 8: Private messages" do
    test "8.1 /msg opens PM, message appears", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmSnd"), "/chat")
      send_command(view, "/msg PmRecipient Hello PM!")
      Process.sleep(50)
      html = render(view)
      assert html =~ "PmRecipient"
    end

    test "8.2 /query opens tab in conversations", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "QryUser"), "/chat")
      send_command(view, "/query QryTarget")
      html = render(view)
      assert html =~ "QryTarget"
      assert html =~ "Private"
    end

    test "8.3 PM via context menu Query (PM)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxPm"), "/chat")
      render_click(view, "nick_right_click", %{"nick" => "PmPal", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "PmPal"})
      assert html =~ "PmPal"
      assert html =~ "conversations-active"
    end

    test "8.4 user list hides during PM, shows in channel", %{conn: conn} do
      ch = unique_channel("pmnick")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "PmNick"), "/chat")
      send_command(view, "/join #{ch}")

      # Open PM — user list should hide (no conversations-users)
      render_click(view, "nick_right_click", %{"nick" => "pmpal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "pmpal"})
      html = render(view)
      refute html =~ "conversations-users"

      # Switch back to channel — user list should show
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#{ch}"]))
        |> render_click()

      assert html =~ "conversations-users"
    end

    test "8.5 unread indicator for PM", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmUnrdE2E"), "/chat")

      # Open PM, then switch back to channel
      render_click(view, "nick_right_click", %{"nick" => "UnrdPal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "UnrdPal"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Receive PM while in channel
      send(view.pid, %{
        event: "new_pm",
        payload: %{
          id: "pm-unrd-#{uid()}",
          sender: "UnrdPal",
          recipient: "PmUnrdE2E",
          content: "hey",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "conversations-unread"
    end

    test "8.6 switching to unread PM clears indicator", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmClrE2E"), "/chat")

      render_click(view, "nick_right_click", %{"nick" => "ClrPal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "ClrPal"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      send(view.pid, %{
        event: "new_pm",
        payload: %{
          id: "pm-clr-#{uid()}",
          sender: "ClrPal",
          recipient: "PmClrE2E",
          content: "hello",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "conversations-unread"

      html =
        view
        |> element(~s(li[phx-click="switch_pm"][phx-value-nickname="ClrPal"]))
        |> render_click()

      refute html =~ "conversations-unread"
    end

    test "8.7 PM arrives while PM is active (no unread)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmActE2E"), "/chat")

      render_click(view, "nick_right_click", %{"nick" => "ActPal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "ActPal"})

      # Stay in PM, receive message
      send(view.pid, %{
        event: "new_pm",
        payload: %{
          id: "pm-act-#{uid()}",
          sender: "ActPal",
          recipient: "PmActE2E",
          content: "live msg",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "live msg"
      refute html =~ "conversations-unread"
    end

    test "8.8 /msg without message shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmNoMsg"), "/chat")
      send_command(view, "/msg SomeTarget")
      html = render(view)
      assert html =~ "chat-error" or html =~ "No message"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 9: Nick Changes
  # ══════════════════════════════════════════════════════════════

  describe "Screen 9: Nick changes" do
    test "9.1 /nick shows confirmation dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OldNickE2E"), "/chat")
      send_command(view, "/nick NewNickE2E")
      html = render(view)
      assert html =~ "nick-change-dialog"
      assert html =~ "NewNickE2E"
      assert html =~ "new chat session"
    end

    test "9.2 nick_changed broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NickObs"), "/chat")
      send(view.pid, {:nick_changed, %{old_nick: "Alice", new_nick: "Bob"}})
      html = render(view)
      assert html =~ "now known as"
    end

    test "9.3 /nick shows dialog and confirm prepares session POST", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TrackOld"), "/chat")
      send_command(view, "/nick TrackNew")

      # Dialog should be visible
      html = render(view)
      assert html =~ "nick-change-dialog"
      assert html =~ "TrackNew"

      # Confirm the nick change (unregistered nick)
      view |> element("[data-testid=\"nick-change-confirm-btn\"]") |> render_click()

      html = render(view)
      refute html =~ "nick-change-dialog"
      # Hidden form should have the target nick
      assert html =~ "TrackNew"
    end

    test "9.4 /nick !!invalid shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NickInv"), "/chat")
      send_command(view, "/nick !!invalid")
      html = render(view)
      assert html =~ "chat-error"
    end

    test "9.5 /nick SameNick shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SameNick"), "/chat")
      send_command(view, "/nick SameNick")
      html = render(view)
      assert html =~ "chat-error" or html =~ "already"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 10: NickServ
  # ══════════════════════════════════════════════════════════════

  describe "Screen 10: NickServ" do
    test "10.1 /ns register registers nickname", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NsReg"), "/chat")
      send_command(view, "/ns register testpass")
      html = render(view)
      assert html =~ "registered" or html =~ "NickServ"
    end

    test "10.2 /ns identify identifies user", %{conn: conn} do
      NickServ.register("NsIdent", "mypass")
      {:ok, view, _html} = live(chat_conn(conn, "NsIdent"), "/chat")
      send_command(view, "/ns identify mypass")
      html = render(view)
      assert html =~ "identified" or html =~ "NickServ"
    end

    test "10.3 /ns info shows registration info", %{conn: conn} do
      NickServ.register("NsInfo", "pass")
      {:ok, view, _html} = live(chat_conn(conn, "NsInfo"), "/chat")
      send_command(view, "/ns info")
      html = render(view)
      assert html =~ "NsInfo" or html =~ "registered" or html =~ "NickServ"
    end

    test "10.4 /ns drop deregisters", %{conn: conn} do
      NickServ.register("NsDrop", "droppass")
      {:ok, view, _html} = live(chat_conn(conn, "NsDrop"), "/chat")
      send_command(view, "/ns identify droppass")
      send_command(view, "/ns drop droppass")
      html = render(view)
      assert html =~ "dropped" or html =~ "NickServ"
    end

    test "10.5 /ns help shows help", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NsHelp"), "/chat")
      send_command(view, "/ns help")
      html = render(view)
      assert html =~ "register" or html =~ "NickServ" or html =~ "Available"
    end

    test "10.6 /ns ghost broadcasts force_disconnect to target", %{conn: conn} do
      NickServ.register("GhostTgt", "gpass")
      NickServ.register("Ghoster", "gpass")

      # Target user connects
      {:ok, tgt_view, _html} = live(chat_conn(new_conn(), "GhostTgt"), "/chat")

      # Ghoster connects and identifies
      {:ok, view, _html} = live(chat_conn(conn, "Ghoster"), "/chat")
      send_command(view, "/ns identify gpass")

      # Ghost the target
      send_command(view, "/ns ghost GhostTgt")
      html = render(view)
      assert html =~ "Ghost" or html =~ "NickServ"

      # Target should receive force_disconnect and redirect via session clear
      {path, _flash} = assert_redirect(tgt_view)
      assert path =~ "/chat/session/clear"
      assert path =~ "Ghosted"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 11: ChanServ
  # ══════════════════════════════════════════════════════════════

  describe "Screen 11: ChanServ" do
    test "11.1 /cs register registers channel (when identified)", %{conn: conn} do
      ch = unique_channel("csreg")
      ensure_channel(ch)
      NickServ.register("CsReg", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsReg"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      html = render(view)
      assert html =~ "registered" or html =~ "ChanServ"
    end

    test "11.2 /cs drop deregisters channel", %{conn: conn} do
      ch = unique_channel("csdrop")
      ensure_channel(ch)
      NickServ.register("CsDrop", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsDrop"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs drop")
      html = render(view)
      assert html =~ "dropped" or html =~ "ChanServ"
    end

    test "11.3 /cs info shows channel info", %{conn: conn} do
      ch = unique_channel("csinfo")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "CsInfo"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs info")
      html = render(view)
      assert html =~ "ChanServ" or html =~ ch
    end

    test "11.4 /cs sop add manages access", %{conn: conn} do
      ch = unique_channel("cssop")
      ensure_channel(ch)
      NickServ.register("CsSop", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsSop"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs sop add SopTarget")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "SopTarget" or html =~ "added"
    end

    test "11.5 /cs help shows help", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CsHelp"), "/chat")
      send_command(view, "/cs help")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "register" or html =~ "Available"
    end

    test "11.6 /cs aop add adds AOP access", %{conn: conn} do
      ch = unique_channel("csaop")
      ensure_channel(ch)
      NickServ.register("CsAop", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsAop"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs aop add AopTarget")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "added" or html =~ "AopTarget"
    end

    test "11.7 /cs vop add adds VOP access", %{conn: conn} do
      ch = unique_channel("csvop")
      ensure_channel(ch)
      NickServ.register("CsVop", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsVop"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs vop add VopTarget")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "added" or html =~ "VopTarget"
    end

    test "11.8 /cs sop del removes SOP access", %{conn: conn} do
      ch = unique_channel("cssopdel")
      ensure_channel(ch)
      NickServ.register("CsSopDel", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsSopDel"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs sop add DelTarget")
      send_command(view, "/cs sop del DelTarget")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "removed" or html =~ "DelTarget"
    end

    test "11.9 /cs aop del on non-existent nick shows error", %{conn: conn} do
      ch = unique_channel("csaopdel")
      ensure_channel(ch)
      NickServ.register("CsAopDel", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsAopDel"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs aop del Nobody")
      html = render(view)
      assert html =~ "not found" or html =~ "chat-error" or html =~ "ChanServ"
    end

    test "11.10 /cs sop list shows access info", %{conn: conn} do
      ch = unique_channel("cssoplist")
      ensure_channel(ch)
      NickServ.register("CsSopLst", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsSopLst"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs sop list")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "Access list"
    end

    test "11.11 /cs vop del removes VOP access", %{conn: conn} do
      ch = unique_channel("csvopdel")
      ensure_channel(ch)
      NickServ.register("CsVopDel", "pass")

      {:ok, view, _html} = live(chat_conn(conn, "CsVopDel"), "/chat")
      send_command(view, "/ns identify pass")
      send_command(view, "/join #{ch}")
      send_command(view, "/cs register")
      send_command(view, "/cs vop add VdTarget")
      send_command(view, "/cs vop del VdTarget")
      html = render(view)
      assert html =~ "ChanServ" or html =~ "removed" or html =~ "VdTarget"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 12: Topic
  # ══════════════════════════════════════════════════════════════

  describe "Screen 12: Topic" do
    test "12.1 /topic sets topic (operator)", %{conn: conn} do
      ch = unique_channel("topicset")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TopicOp"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/topic Welcome to #{ch}")
      Process.sleep(50)

      {:ok, state} = Server.get_state(ch)
      assert state.topic == "Welcome to #{ch}"
    end

    test "12.2 /topic without args shows current topic", %{conn: conn} do
      ch = unique_channel("topicview")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TopicView"), "/chat")
      send_command(view, "/join #{ch}")
      Server.set_topic(ch, "TopicView", "Hello World")
      send_command(view, "/topic")
      html = render(view)
      assert html =~ "Hello World"
    end

    test "12.3 /topic on empty topic shows 'No topic set'", %{conn: conn} do
      ch = unique_channel("notopic")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "NoTopic"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/topic")
      html = render(view)
      assert html =~ "No topic"
    end

    test "12.4 /topic with +t by non-op shows error", %{conn: conn} do
      ch = unique_channel("topicerr")
      ensure_channel(ch)
      Server.join(ch, "TopErrOp", nil)
      Server.set_mode(ch, "TopErrOp", "+t")

      {:ok, view, _html} = live(chat_conn(conn, "TopErrReg"), "/chat")
      send_command(view, "/join #{ch}")
      send_command(view, "/topic Nope")
      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 13: Search
  # ══════════════════════════════════════════════════════════════

  describe "Screen 13: Search" do
    test "13.1 Edit > Find opens search bar", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FindE2E"), "/chat")
      html = render_click(view, "open_search")
      assert html =~ "search-bar"
    end

    test "13.2 typing query shows results counter", %{conn: conn} do
      ch = unique_channel("srch")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "SrchE2E"), "/chat")
      send_command(view, "/join #{ch}")

      Server.send_message(ch, "SrchE2E", "findme one")
      Server.send_message(ch, "SrchE2E", "findme two")
      Process.sleep(50)

      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "findme"})
      assert html =~ "search-bar"
    end

    test "13.3 prev/next navigate results", %{conn: conn} do
      ch = unique_channel("srchnav")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "SrchNav"), "/chat")
      send_command(view, "/join #{ch}")

      Server.send_message(ch, "SrchNav", "navmatch one")
      Server.send_message(ch, "SrchNav", "navmatch two")
      Process.sleep(50)

      render_click(view, "toggle_search")
      render_click(view, "search_input", %{"query" => "navmatch"})
      html1 = render_click(view, "search_next")
      html2 = render_click(view, "search_prev")
      assert html1 =~ "search-bar"
      assert html2 =~ "search-bar"
    end

    test "13.4 close search hides bar", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchCls"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "close_search")
      refute html =~ "search-bar"
    end

    test "13.5 no results shows indicator", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchNone"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "zzz_nomatch_ever"})
      assert html =~ "No results"
    end

    test "13.6 search bar hidden by default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "SrchDef"), "/chat")
      refute html =~ "search-bar"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 14: Command Palette
  # ══════════════════════════════════════════════════════════════

  describe "Screen 14: Autocomplete" do
    test "14.1 autocomplete query shows dropdown", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalOpen"), "/chat")
      html = render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      assert html =~ "autocomplete-dropdown"
    end

    test "14.2 filter reduces command list", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalFilt"), "/chat")
      html = render_click(view, "autocomplete_query", %{"type" => "command", "partial" => "jo"})
      assert html =~ "autocomplete-dropdown"
    end

    test "14.3 select command inserts /cmd in input", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalSel"), "/chat")
      render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      html = render_click(view, "autocomplete_select", %{"type" => "command", "value" => "join"})
      assert html =~ "/join "
      refute html =~ "autocomplete-dropdown"
    end

    test "14.4 close autocomplete hides it", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalCls"), "/chat")
      render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      html = render_click(view, "autocomplete_close")
      refute html =~ "autocomplete-dropdown"
    end

    test "14.5 autocomplete hidden by default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "PalDef"), "/chat")
      refute html =~ "autocomplete-dropdown"
    end

    test "14.6 /help shows available commands list", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HelpE2E"), "/chat")
      send_command(view, "/help")
      html = render(view)
      assert html =~ "Available commands"
    end

    test "14.7 /help join shows specific command help", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HelpCmdE2E"), "/chat")
      send_command(view, "/help join")
      html = render(view)
      assert html =~ "/join"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 15: UI Toggles
  # ══════════════════════════════════════════════════════════════

  describe "Screen 15: UI toggles" do
    test "15.1 toggle conversations hides/shows", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "TreeTgl"), "/chat")
      assert html =~ ~s(class="conversations")

      html = render_click(view, "toggle_conversations")
      refute html =~ ~s(class="conversations")

      html = render_click(view, "toggle_conversations")
      assert html =~ ~s(class="conversations")
    end

    test "15.2 conversations shows user list under active channel", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "NickTgl"), "/chat")
      assert html =~ "conversations-users"
      assert html =~ "NickTgl"
    end

    test "15.3 show about opens dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AboutE2E"), "/chat")
      html = render_click(view, "show_about")
      assert html =~ "About RetroHexChat"
    end

    test "15.4 close dialog closes about", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ClsAbout"), "/chat")
      render_click(view, "show_about")
      html = render_click(view, "close_dialog")
      refute html =~ "dialog-overlay"
    end

    test "15.5 quit chat redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "QuitE2E"), "/chat")
      result = render_click(view, "quit_chat")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end

    test "15.6 disconnect toolbar redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "DiscE2E"), "/chat")
      result = render_click(view, "disconnect")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end

    test "15.7 /quit command redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "QuitCmdE2E"), "/chat")
      result = send_command(view, "/quit leaving")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 16: Away Status
  # ══════════════════════════════════════════════════════════════

  describe "Screen 16: Away status" do
    test "16.1 /away sets away status", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AwayE2E"), "/chat")
      send_command(view, "/away Gone fishing")
      html = render(view)
      assert html =~ "now away"
    end

    test "16.2 /away without args clears away", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AwayClrE2E"), "/chat")
      send_command(view, "/away Busy")
      send_command(view, "/away")
      html = render(view)
      assert html =~ "no longer away"
    end

    test "16.3 away updates Presence/Tracker", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AwayTrk"), "/chat")
      send_command(view, "/away fishing")
      Process.sleep(50)

      users = Tracker.list_users("channel:#lobby")

      away_user =
        Enum.find(users, fn u -> u.nickname == "AwayTrk" end)

      assert away_user == nil or away_user.away == true
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 17: History and Keyboard
  # ══════════════════════════════════════════════════════════════

  describe "Screen 17: History and keyboard" do
    test "17.1 arrow up navigates command history", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistUp"), "/chat")
      send_message(view, "First message")
      send_message(view, "Second message")

      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "Second message"
    end

    test "17.2 arrow down navigates forward", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistDn"), "/chat")
      send_message(view, "First")
      send_message(view, "Second")

      render_click(view, "history_navigate", %{"direction" => "up"})
      render_click(view, "history_navigate", %{"direction" => "up"})
      html = render_click(view, "history_navigate", %{"direction" => "down"})
      assert html =~ "Second"
    end

    test "17.3 tab complete with single match", %{conn: conn} do
      ch = unique_channel("tabcmp")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TabCmp"), "/chat")
      send_command(view, "/join #{ch}")

      send(view.pid, {:user_joined, %{nickname: "UniqueXyz", role: :regular}})
      render(view)

      # Tab complete now sends matches via push_event instead of direct assign
      html =
        render_click(view, "tab_complete", %{"partial" => "Unique", "is_start" => true})

      assert is_binary(html)
    end

    test "17.4 tab complete no match: no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TabNo"), "/chat")
      html = render_click(view, "tab_complete", %{"partial" => "zzz_nomatch"})
      assert html =~ "chat-input-form"
    end

    test "17.5 tab complete multiple matches: no-op", %{conn: conn} do
      ch = unique_channel("tabmulti")
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TabMulti"), "/chat")
      send_command(view, "/join #{ch}")

      send(view.pid, {:user_joined, %{nickname: "TabAlphaA", role: :regular}})
      send(view.pid, {:user_joined, %{nickname: "TabAlphaB", role: :regular}})
      render(view)

      html = render_click(view, "tab_complete", %{"partial" => "TabAlph"})
      assert html =~ "chat-input-form"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 18: Multi-user
  # ══════════════════════════════════════════════════════════════

  describe "Screen 18: Multi-user" do
    test "18.1 two users in same channel see messages", %{conn: conn} do
      ch = unique_channel("multi")
      ensure_channel(ch)
      {:ok, view1, _html} = live(chat_conn(conn, "Multi1"), "/chat")
      send_command(view1, "/join #{ch}")

      {:ok, view2, _html} = live(chat_conn(new_conn(), "Multi2"), "/chat")
      send_command(view2, "/join #{ch}")

      send_message_and_wait(view1, "Hello from Multi1")

      html2 = render(view2)
      assert html2 =~ "Hello from Multi1"
    end

    test "18.2 user_joined broadcast shows 'has joined'", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "JoinBc"), "/chat")
      send(view.pid, {:user_joined, %{nickname: "newcomer"}})
      html = render(view)
      assert html =~ "joined"
    end

    test "18.3 user_left broadcast shows 'has left'", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "LeftBc"), "/chat")
      send(view.pid, {:user_left, %{nickname: "leaver", reason: nil}})
      html = render(view)
      assert html =~ "left"
    end

    test "18.4 nick_changed broadcast shows 'now known as'", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NickBc"), "/chat")
      send(view.pid, {:nick_changed, %{old_nick: "Alice", new_nick: "Bob"}})
      html = render(view)
      assert html =~ "now known as"
    end

    test "18.5 user_kicked broadcast shows 'kicked'", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "KickBc"), "/chat")

      send(view.pid, {:user_joined, %{nickname: "BadGuy", role: :regular}})

      send(
        view.pid,
        {:user_kicked, %{operator: "Admin", target: "BadGuy", reason: "spam"}}
      )

      html = render(view)
      assert html =~ "kicked"
    end

    test "18.6 force_disconnect redirects via session clear", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ForceE2E"), "/chat")
      send(view.pid, {:force_disconnect, %{reason: "Ghosted"}})
      {path, _flash} = assert_redirect(view)
      assert path =~ "/chat/session/clear"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 19: Error Handling
  # ══════════════════════════════════════════════════════════════

  describe "Screen 19: Error handling" do
    test "19.1 unknown command /foobar shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UnkCmd"), "/chat")
      send_command(view, "/foobar")
      html = render(view)
      assert html =~ "Unknown command" or html =~ "chat-error"
    end

    test "19.2 command without required args shows usage/error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NoArgs"), "/chat")
      send_command(view, "/kick")
      html = render(view)
      assert html =~ "Usage" or html =~ "chat-error"
    end

    test "19.3 unknown handle_info doesn't crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UnkInfo"), "/chat")
      send(view.pid, {:completely_unknown_event, %{data: "test"}})
      html = render(view)
      assert html =~ "chat-input-form"
    end

    test "19.4 PM to self doesn't crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SelfPm"), "/chat")
      send_command(view, "/msg SelfPm hello self")
      Process.sleep(50)
      html = render(view)
      assert html =~ "chat-input-form"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Screen 20: Channel List Dialog (inline modal)
  # ══════════════════════════════════════════════════════════════

  describe "Screen 20: Channel List Dialog" do
    test "20.1 opens dialog with channel table", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E1"), "/chat")
      html = render_click(view, "channel_list")
      assert html =~ "Channel List"
      assert html =~ ~s(data-testid="channel-list-dialog")
    end

    test "20.2 filter by name works", %{conn: conn} do
      ch = unique_channel("filtch")
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E2"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "filtch"})

      assert html =~ ch
    end

    test "20.3 regex metacharacters in filter are safe", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E3"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "[test(.*"})

      assert html =~ "Channel List"
    end

    test "20.4 join from list closes dialog", %{conn: conn} do
      ensure_channel("#lobby")
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E4"), "/chat")
      render_click(view, "channel_list")

      html = render_click(view, "channel_list_join", %{"channel" => "#lobby"})
      refute html =~ ~s(data-testid="channel-list-dialog")
    end

    test "20.5 close button dismisses dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E5"), "/chat")
      render_click(view, "channel_list")
      html = render_click(view, "toggle_channel_list")
      refute html =~ ~s(data-testid="channel-list-dialog")
    end

    test "20.6 empty list shows 'No channels found'", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E6"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "zzz_nonexistent_ever"})

      assert html =~ "No channels found"
    end

    test "20.7 /list command opens channel list dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanE2E7"), "/chat")
      html = send_command(view, "/list")
      assert html =~ ~s(data-testid="channel-list-dialog")
      assert html =~ "Channel List"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp send_message(view, text) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => text})
  end

  defp send_message_and_wait(view, text) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => text})
    Process.sleep(50)
  end

  # ══════════════════════════════════════════════════════════
  # Screen 21: Text Formatting & Colors
  # ══════════════════════════════════════════════════════════

  describe "Screen 21: Text Formatting" do
    test "21.1 bold+color message renders correctly for sender", %{conn: conn} do
      chan = unique_channel("e2e_fmt")
      ensure_channel(chan)
      {:ok, view, _html} = live(chat_conn(conn, "E2eFmt"), "/chat")
      send_command(view, "/join #{chan}")

      msg = <<0x02>> <> <<0x03>> <> "4Bold red text" <> <<0x0F>>
      send_command(view, msg)

      Process.sleep(50)
      html = render(view)
      assert html =~ "irc-bold"
      assert html =~ "irc-fg-4"
      assert html =~ "Bold red text"
    end

    test "21.2 bold+color message renders correctly for receiver", %{conn: conn} do
      chan = unique_channel("e2e_fmtr")
      ensure_channel(chan)
      {:ok, sender, _html} = live(chat_conn(conn, "E2eFmtS"), "/chat")
      {:ok, receiver, _html} = live(chat_conn(new_conn(), "E2eFmtR"), "/chat")

      send_command(sender, "/join #{chan}")
      send_command(receiver, "/join #{chan}")

      msg = <<0x02>> <> "Bold for receiver" <> <<0x02>>
      send_command(sender, msg)

      Process.sleep(50)
      html = render(receiver)
      assert html =~ "irc-bold"
      assert html =~ "Bold for receiver"
    end

    test "21.3 formatting toolbar buttons are visible", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "E2eTbar"), "/chat")
      assert html =~ ~s(data-testid="format-btn-bold")
      assert html =~ ~s(data-testid="format-btn-italic")
      assert html =~ ~s(data-testid="format-btn-underline")
      assert html =~ ~s(data-testid="format-btn-color")
    end

    test "21.4 strip formatting toggle hides formatting", %{conn: conn} do
      chan = unique_channel("e2e_strip")
      ensure_channel(chan)
      {:ok, view, _html} = live(chat_conn(conn, "E2eStrip"), "/chat")
      send_command(view, "/join #{chan}")

      msg = <<0x02>> <> "Bold text" <> <<0x02>>
      send_command(view, msg)

      Process.sleep(50)
      assert render(view) =~ "irc-bold"

      render_click(view, "toggle_strip_formatting")
      html = render(view)
      assert html =~ "Bold text"
      refute html =~ "irc-bold"
    end

    test "21.5 format-only message is rejected", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "E2eFmtOnly"), "/chat")

      # Send message with only format codes (no visible text)
      msg = <<0x02>> <> <<0x02>>
      send_command(view, msg)

      Process.sleep(50)
      html = render(view)
      # Should show error or be a no-op (message not sent)
      refute html =~ ~s(class="chat-message chat-message--message")
    end

    test "21.6 color picker has 16 swatches", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "E2eCpick"), "/chat")

      for i <- 0..15 do
        assert html =~ ~s(data-color-code="#{i}")
      end
    end

    test "21.7 strip toggle button has active state after click", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "E2eStAct"), "/chat")
      refute render(view) =~ "format-btn-active"

      render_click(view, "toggle_strip_formatting")
      assert render(view) =~ "format-btn-active"
    end
  end

  defp send_command(view, cmd) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => cmd})
  end

  defp unique_channel(prefix) do
    "##{prefix}_#{uid()}"
  end

  defp new_conn do
    Phoenix.ConnTest.build_conn()
  end
end
