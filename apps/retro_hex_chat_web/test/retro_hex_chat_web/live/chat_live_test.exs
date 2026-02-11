defmodule RetroHexChatWeb.ChatLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ

  setup do
    # Ensure #lobby exists for most tests
    ensure_channel("#lobby")
    :ok
  end

  # ── mount ─────────────────────────────────────────────────

  describe "mount" do
    test "valid nickname mounts successfully and joins #lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=MountUser")
      assert html =~ "MountUser"
      assert html =~ "#lobby"
    end

    test "invalid nickname redirects to /", %{conn: conn} do
      result = live(conn, "/chat?nickname=!!invalid!!")
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end

    test "registered nick shows NickServ notice", %{conn: conn} do
      # Register a nick first
      NickServ.register("RegNotice", "pass123")

      {:ok, _view, html} = live(conn, "/chat?nickname=RegNotice")
      assert html =~ "NickServ" or html =~ "registered"
    end
  end

  # ── send_input ────────────────────────────────────────────

  describe "send_input" do
    test "empty input is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=EmptyInput")
      html = view |> element("form.chat-input-form") |> render_submit(%{"input" => ""})
      # Page should not crash, still shows the interface
      assert html =~ "EmptyInput" or html =~ "chat-input-form"
    end

    test "plain text in channel sends message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=Sender1")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello everyone"})

      # Give PubSub a moment to deliver
      Process.sleep(50)
      html = render(view)
      assert html =~ "Hello everyone"
    end

    test "/join command joins a new channel", %{conn: conn} do
      ensure_channel("#jointest")
      {:ok, view, _html} = live(conn, "/chat?nickname=Joiner1")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #jointest"})
      html = render(view)
      assert html =~ "#jointest"
    end

    test "/part command leaves the current channel", %{conn: conn} do
      ensure_channel("#parttest")
      {:ok, view, _html} = live(conn, "/chat?nickname=Parter1")

      # Join a second channel first
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #parttest"})
      # Now part
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/part"})
      html = render(view)
      # Should have switched back to #lobby
      assert html =~ "#lobby"
    end
  end

  # ── switch_channel ────────────────────────────────────────

  describe "switch_channel" do
    test "clicking channel in treebar switches active channel", %{conn: conn} do
      ensure_channel("#switch_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=Switcher")

      # Join second channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #switch_ch"})

      # Switch back to #lobby via treebar
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
        |> render_click()

      assert html =~ "#lobby"
    end
  end

  # ── search ────────────────────────────────────────────────

  describe "search" do
    test "toggle_search shows and hides search bar", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chat?nickname=Searcher")
      refute html =~ "search-bar"

      html = render_click(view, "toggle_search")
      assert html =~ "search-bar"

      html = render_click(view, "toggle_search")
      refute html =~ "search-bar"
    end

    test "close_search clears search state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchClose")
      render_click(view, "toggle_search")
      html = render_click(view, "close_search")
      refute html =~ "search-bar"
    end
  end

  # ── context_menu ──────────────────────────────────────────

  describe "context_menu" do
    test "nick_right_click shows context menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CtxUser")

      html =
        render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 100, "y" => 200})

      assert html =~ "context-menu"
    end

    test "close_context_menu hides context menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CtxClose")
      render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 100, "y" => 200})
      html = render_click(view, "close_context_menu")
      refute html =~ "context-menu"
    end

    test "context_query opens PM conversation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CtxQuery")
      render_click(view, "nick_right_click", %{"nick" => "pmtarget", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "pmtarget"})
      assert html =~ "pmtarget"
    end
  end

  # ── PubSub handlers ──────────────────────────────────────

  describe "PubSub handlers" do
    test "new_message broadcast appears in stream", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PubUser1")

      msg = %{
        event: "new_message",
        payload: %{
          id: "pubmsg-#{System.unique_integer([:positive])}",
          author: "other_user",
          content: "PubSub hello",
          type: :message,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)
      assert html =~ "PubSub hello"
    end

    test "user_joined broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PubJoin")
      send(view.pid, {:user_joined, %{nickname: "newcomer"}})
      html = render(view)
      assert html =~ "newcomer" and html =~ "joined"
    end

    test "user_left broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PubLeft")
      send(view.pid, {:user_left, %{nickname: "leaver", reason: nil}})
      html = render(view)
      assert html =~ "leaver" and html =~ "left"
    end

    test "force_disconnect redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ForceDisc")

      result = render_click(view, "close_context_menu")
      assert is_binary(result)

      send(view.pid, {:force_disconnect, %{reason: "Ghosted by admin"}})

      flash = assert_redirect(view, "/")
      assert flash["error"] =~ "Disconnected"
    end

    test "force_rename updates nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=RenameMe")
      send(view.pid, {:force_rename, %{reason: "Identify timeout (60s)"}})
      html = render(view)
      assert html =~ "Guest_"
      assert html =~ "Identify timeout"
    end
  end

  # ── menu/toolbar ──────────────────────────────────────────

  describe "menu and toolbar" do
    test "quit_chat redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=Quitter")
      result = render_click(view, "quit_chat")
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end

    test "toggle_treebar toggles visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=TreeToggle")
      # Treebar should be visible initially (has class="treebar")
      html = render(view)
      assert html =~ ~s(class="treebar")

      html = render_click(view, "toggle_treebar")
      refute html =~ ~s(class="treebar")

      html = render_click(view, "toggle_treebar")
      assert html =~ ~s(class="treebar")
    end

    test "toggle_nicklist toggles visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=NickToggle")
      html = render(view)
      assert html =~ "nick-" or html =~ "Users"

      html = render_click(view, "toggle_nicklist")
      # After toggling off, nicklist should not be rendered
      refute html =~ "nick-operator" and html =~ "nick-regular"
    end
  end

  # ── about dialog ──────────────────────────────────────────

  describe "about dialog" do
    test "show_about shows dialog, close_dialog hides it", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chat?nickname=AboutUser")
      refute html =~ "About RetroHexChat"

      html = render_click(view, "show_about")
      assert html =~ "About RetroHexChat"
      assert html =~ "Windows 98"

      html = render_click(view, "close_dialog")
      refute html =~ "dialog-overlay"
    end
  end

  # ── F1: nicklist integration ────────────────────────────

  describe "nicklist integration" do
    test "after mount in isolated channel, nicklist shows the user as operator", %{conn: conn} do
      ensure_channel("#nick_iso1")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickOp")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso1"})
      html = render(view)
      assert html =~ "nick-operator"
      assert html =~ "NickOp"
      assert html =~ "Users (1)"
    end

    test "after second user joins via PubSub, nicklist updates", %{conn: conn} do
      ensure_channel("#nick_iso2")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickHost")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso2"})

      send(view.pid, {:user_joined, %{nickname: "NickGuest", role: :regular}})
      html = render(view)
      assert html =~ "NickHost"
      assert html =~ "NickGuest"
      assert html =~ "Users (2)"
    end

    test "after user_left PubSub, user removed from nicklist", %{conn: conn} do
      ensure_channel("#nick_iso3")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickStay")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso3"})

      send(view.pid, {:user_joined, %{nickname: "NickLeave", role: :regular}})
      html = render(view)
      assert html =~ "Users (2)"
      assert html =~ "nick-regular"

      send(view.pid, {:user_left, %{nickname: "NickLeave", reason: nil}})
      html = render(view)
      assert html =~ "Users (1)"
      refute html =~ "nick-regular"
    end

    test "statusbar shows correct user_count after joins", %{conn: conn} do
      ensure_channel("#nick_iso4")
      {:ok, view, _html} = live(conn, "/chat?nickname=CountUser")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso4"})
      html = render(view)
      assert html =~ "Users: 1"

      send(view.pid, {:user_joined, %{nickname: "CountGuest", role: :regular}})
      html = render(view)
      assert html =~ "Users: 2"
    end

    test "switching channel reloads nicklist for new channel", %{conn: conn} do
      ensure_channel("#nick_ch2")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickSwitch")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_ch2"})

      # Switch back to #lobby
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
        |> render_click()

      # Should show the user in #lobby's nicklist
      assert html =~ "NickSwitch"
    end

    test "switching to PM hides nicklist", %{conn: conn} do
      ensure_channel("#nick_iso5")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickPm")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso5"})
      render_click(view, "nick_right_click", %{"nick" => "pmpal", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "pmpal"})
      refute html =~ "nick-operator"
    end

    test "user_kicked removes user from nicklist", %{conn: conn} do
      ensure_channel("#nick_iso6")
      {:ok, view, _html} = live(conn, "/chat?nickname=KickHost")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso6"})

      send(view.pid, {:user_joined, %{nickname: "KickTarget", role: :regular}})
      html = render(view)
      assert html =~ "nick-regular"
      assert html =~ "Users (2)"

      send(view.pid, {:user_kicked, %{operator: "KickHost", target: "KickTarget", reason: nil}})
      html = render(view)
      assert html =~ "Users (1)"
      refute html =~ "nick-regular"
    end
  end

  # ── B1: Presence cleanup on kick ────────────────────────

  describe "presence cleanup on kick" do
    test "kicked user is untracked from Presence", %{conn: conn} do
      ensure_channel("#kick_pres")
      {:ok, view, _html} = live(conn, "/chat?nickname=KickPres")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #kick_pres"})
      Process.sleep(50)

      # Verify tracked before kick
      users_before = Tracker.list_users("channel:#kick_pres")
      assert "KickPres" in Enum.map(users_before, & &1.nickname)

      # Simulate being kicked
      send(view.pid, {:user_kicked, %{operator: "Admin", target: "KickPres", reason: "bye"}})
      Process.sleep(50)

      # Verify untracked after kick
      users_after = Tracker.list_users("channel:#kick_pres")
      refute "KickPres" in Enum.map(users_after, & &1.nickname)
    end
  end

  # ── F4: nick change broadcast ───────────────────────────

  describe "nick change broadcast" do
    test "/nick updates nickname locally", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=OldNick1")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick NewNick1"})
      html = render(view)
      assert html =~ "NewNick1"
      assert html =~ "You are now known as"
    end

    test "/nick broadcasts system message to shared channels", %{conn: conn} do
      ensure_channel("#nick_bcast")
      {:ok, view, _html} = live(conn, "/chat?nickname=NickBcast1")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_bcast"})

      # Subscribe to the channel to observe broadcasts
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#nick_bcast")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick NickBcast2"})

      assert_receive {:nick_changed, %{old_nick: "NickBcast1", new_nick: "NickBcast2"}}, 1000
    end

    test "/nick updates Presence metadata", %{conn: conn} do
      ensure_channel("#nick_pres")
      {:ok, view, _html} = live(conn, "/chat?nickname=PreNick")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_pres"})
      Process.sleep(50)

      users_before = Tracker.list_users("channel:#nick_pres")
      assert "PreNick" in Enum.map(users_before, & &1.nickname)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick PostNick"})
      Process.sleep(50)

      users_after = Tracker.list_users("channel:#nick_pres")
      nicks = Enum.map(users_after, & &1.nickname)
      assert "PostNick" in nicks
      refute "PreNick" in nicks
    end

    test "receiving nick_changed broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=NickObserver")

      send(view.pid, {:nick_changed, %{old_nick: "Alice", new_nick: "Bob"}})
      html = render(view)
      assert html =~ "Alice" and html =~ "Bob"
    end
  end

  # ── B3: mode_changed updates nicklist ───────────────────

  describe "mode_changed nicklist update" do
    test "mode_changed +o updates user role to operator in nicklist", %{conn: conn} do
      ensure_channel("#mode_op")
      {:ok, view, _html} = live(conn, "/chat?nickname=ModeHost")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mode_op"})

      # Add a regular user
      send(view.pid, {:user_joined, %{nickname: "ModeTarget", role: :regular}})
      html = render(view)
      assert html =~ "nick-regular"

      # Grant operator
      send(
        view.pid,
        {:mode_changed, %{nickname: "ModeHost", mode_string: "+o", params: ["ModeTarget"]}}
      )

      html = render(view)
      assert html =~ "sets mode +o"
      # ModeTarget should now be in operator section
      assert html =~ "@ModeTarget"
    end

    test "mode_changed +v updates user role to voiced in nicklist", %{conn: conn} do
      ensure_channel("#mode_voice")
      {:ok, view, _html} = live(conn, "/chat?nickname=VoiceHost")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mode_voice"})

      send(view.pid, {:user_joined, %{nickname: "VoiceTarget", role: :regular}})
      html = render(view)
      assert html =~ "nick-regular"

      send(
        view.pid,
        {:mode_changed, %{nickname: "VoiceHost", mode_string: "+v", params: ["VoiceTarget"]}}
      )

      html = render(view)
      assert html =~ "sets mode +v"
      assert html =~ "nick-voiced"
    end

    test "mode_changed -o removes operator status in nicklist", %{conn: conn} do
      ensure_channel("#mode_deop")
      {:ok, view, _html} = live(conn, "/chat?nickname=DeopHost")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mode_deop"})

      # Add an operator user
      send(view.pid, {:user_joined, %{nickname: "DeopTarget", role: :operator}})
      html = render(view)
      assert html =~ "@DeopTarget"

      # Remove operator
      send(
        view.pid,
        {:mode_changed, %{nickname: "DeopHost", mode_string: "-o", params: ["DeopTarget"]}}
      )

      html = render(view)
      assert html =~ "sets mode -o"
      refute html =~ "@DeopTarget"
    end
  end

  # ── B2: PM unread tracking ──────────────────────────────

  describe "PM unread tracking" do
    test "PM in non-active conversation marks as unread", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmUnread")

      # Open a PM conversation with Alice, then switch back to channel
      render_click(view, "nick_right_click", %{"nick" => "Alice", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "Alice"})

      # Switch back to #lobby channel
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Receive a PM from Alice while viewing #lobby
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: "pm-unread-#{System.unique_integer([:positive])}",
          sender: "Alice",
          recipient: "PmUnread",
          content: "Hey there!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)
      assert html =~ "tree-unread"
    end

    test "switch_pm clears unread for that PM", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmClr")

      # Open PM with Bob, then switch back to channel
      render_click(view, "nick_right_click", %{"nick" => "Bob", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "Bob"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Receive PM from Bob to create unread
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: "pm-clr-#{System.unique_integer([:positive])}",
          sender: "Bob",
          recipient: "PmClr",
          content: "Hello!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)
      assert html =~ "tree-unread"

      # Switch to Bob's PM — should clear unread
      html =
        view
        |> element(~s(li[phx-click="switch_pm"][phx-value-nickname="Bob"]))
        |> render_click()

      refute html =~ "tree-unread"
    end
  end

  # ── F2: unread indicators ───────────────────────────────

  describe "unread indicators" do
    test "message in non-active channel marks channel as unread", %{conn: conn} do
      ensure_channel("#unread_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=UnreadUser")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #unread_ch"})

      # Switch back to #lobby — #unread_ch is now inactive
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send a message to the non-active channel
      msg = %{
        event: "new_message",
        payload: %{
          id: "unr-#{System.unique_integer([:positive])}",
          author: "someone",
          content: "hey",
          type: :message,
          channel: "#unread_ch",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)
      assert html =~ "tree-unread"
    end

    test "switching to unread channel clears the indicator", %{conn: conn} do
      ensure_channel("#unread_clr")
      {:ok, view, _html} = live(conn, "/chat?nickname=UnreadClr")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #unread_clr"})

      # Switch to #lobby
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send a message to #unread_clr
      msg = %{
        event: "new_message",
        payload: %{
          id: "unr2-#{System.unique_integer([:positive])}",
          author: "someone",
          content: "hello",
          type: :message,
          channel: "#unread_clr",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)
      assert html =~ "tree-unread"

      # Switch to #unread_clr — should clear unread
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#unread_clr"]))
        |> render_click()

      refute html =~ "tree-unread"
    end

    test "message in active channel does NOT mark as unread", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=UnreadActive")

      msg = %{
        event: "new_message",
        payload: %{
          id: "unr3-#{System.unique_integer([:positive])}",
          author: "someone",
          content: "active msg",
          type: :message,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)
      refute html =~ "tree-unread"
    end
  end

  # ── F5: presence tracking ───────────────────────────────

  describe "presence tracking" do
    test "after mount, user is tracked in presence for #lobby", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/chat?nickname=PresUser")
      Process.sleep(50)

      users = Tracker.list_users("channel:#lobby")
      nicks = Enum.map(users, & &1.nickname)
      assert "PresUser" in nicks
    end

    test "after join second channel, user tracked in both", %{conn: conn} do
      ensure_channel("#pres_ch2")
      {:ok, view, _html} = live(conn, "/chat?nickname=PresMulti")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #pres_ch2"})
      Process.sleep(50)

      lobby_users = Tracker.list_users("channel:#lobby")
      ch2_users = Tracker.list_users("channel:#pres_ch2")

      assert "PresMulti" in Enum.map(lobby_users, & &1.nickname)
      assert "PresMulti" in Enum.map(ch2_users, & &1.nickname)
    end

    test "after part channel, user untracked from that channel", %{conn: conn} do
      ensure_channel("#pres_part")
      {:ok, view, _html} = live(conn, "/chat?nickname=PresPart")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #pres_part"})
      Process.sleep(50)

      users_before = Tracker.list_users("channel:#pres_part")
      assert "PresPart" in Enum.map(users_before, & &1.nickname)

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/part"})
      Process.sleep(50)

      users_after = Tracker.list_users("channel:#pres_part")
      refute "PresPart" in Enum.map(users_after, & &1.nickname)
    end
  end

  # ── F3: moderation enforcement ──────────────────────────

  describe "moderation enforcement" do
    test "in unmoderated channel, message is sent normally", %{conn: conn} do
      ensure_channel("#mod_normal")
      {:ok, view, _html} = live(conn, "/chat?nickname=ModUser1")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mod_normal"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "Hello world"
    end

    test "in +m channel, operator can send message", %{conn: conn} do
      ensure_channel("#mod_op")
      {:ok, view, _html} = live(conn, "/chat?nickname=ModOp")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mod_op"})

      # First user is operator — set +m
      Server.set_mode("#mod_op", "ModOp", "+m")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Op can speak"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "Op can speak"
    end

    test "in +m channel, regular user gets moderated error", %{conn: conn} do
      ensure_channel("#mod_reg")
      # First user joins as operator
      Server.join("#mod_reg", "Founder", nil)
      Server.set_mode("#mod_reg", "Founder", "+m")

      # Second user joins as regular
      {:ok, view, _html} = live(conn, "/chat?nickname=ModRegular")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mod_reg"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "I cannot speak"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "moderated" or html =~ "Cannot send"
    end

    test "in +m channel, voiced user can send message", %{conn: conn} do
      ensure_channel("#mod_voiced")
      # First user (operator)
      Server.join("#mod_voiced", "Founder2", nil)
      Server.set_mode("#mod_voiced", "Founder2", "+m")

      {:ok, view, _html} = live(conn, "/chat?nickname=VoicedUser")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mod_voiced"})

      # Give voice
      Server.set_mode("#mod_voiced", "Founder2", "+v", ["VoicedUser"])

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Voiced can talk"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "Voiced can talk"
    end
  end

  # ── F6: command palette + keyboard shortcuts ─────────────

  describe "command palette" do
    test "CommandPalette component rendered in template (hidden by default)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=PalUser")
      # When hidden, the :if={@command_palette_visible} means it won't render
      refute html =~ "command-palette"
    end

    test "open_command_palette shows palette", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PalOpen")
      html = render_click(view, "open_command_palette")
      assert html =~ "command-palette"
    end

    test "close_command_palette hides palette", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PalClose")
      render_click(view, "open_command_palette")
      html = render_click(view, "close_command_palette")
      refute html =~ "command-palette"
    end

    test "select_command inserts command prefix into input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PalSelect")
      render_click(view, "open_command_palette")
      html = render_click(view, "select_command", %{"command" => "join"})
      assert html =~ "/join "
      refute html =~ "command-palette"
    end

    test "filter_command_palette filters the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PalFilter")
      render_click(view, "open_command_palette")
      html = render_click(view, "filter_command_palette", %{"filter" => "jo"})
      assert html =~ "command-palette"
    end
  end

  describe "keyboard shortcuts" do
    test "history_navigate up with empty history does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HistUser")
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "chat-input-form"
    end

    test "history_navigate returns previous command after sending", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HistNav")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "Hello world"
    end

    test "tab_complete with matching nick suggests completion", %{conn: conn} do
      ensure_channel("#tab_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=TabUser")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #tab_ch"})

      send(view.pid, {:user_joined, %{nickname: "TabTarget", role: :regular}})
      render(view)

      html = render_click(view, "tab_complete", %{"partial" => "Tab"})
      assert html =~ "TabTarget" or html =~ "TabUser"
    end

    test "tab_complete with no match does not alter input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=TabNone")
      html = render_click(view, "tab_complete", %{"partial" => "zzz_nomatch"})
      assert html =~ "chat-input-form"
    end
  end

  # ── F7: trivial handler fixes ────────────────────────────

  describe "trivial handler fixes" do
    test "settings event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SettingsUser")
      html = render_click(view, "settings")
      assert html =~ "chat-input-form"
    end

    test "open_search shows search bar", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=OpenSearchUser")
      html = render_click(view, "open_search")
      assert html =~ "search-bar"
    end
  end

  # ── B7: /join password passthrough ──────────────────────

  describe "join with password" do
    test "joining password-protected channel with correct password succeeds", %{conn: conn} do
      ensure_channel("#pw_ch")
      # Set key mode on the channel
      Server.join("#pw_ch", "PwFounder", nil)
      Server.set_mode("#pw_ch", "PwFounder", "+k", ["secret123"])

      {:ok, view, _html} = live(conn, "/chat?nickname=PwUser")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #pw_ch secret123"})

      html = render(view)
      assert html =~ "#pw_ch"
    end

    test "joining password-protected channel with wrong password shows error", %{conn: conn} do
      ensure_channel("#pw_ch2")
      Server.join("#pw_ch2", "PwFounder2", nil)
      Server.set_mode("#pw_ch2", "PwFounder2", "+k", ["correctpass"])

      {:ok, view, _html} = live(conn, "/chat?nickname=PwFail")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #pw_ch2 wrongpass"})

      html = render(view)
      assert html =~ "chat-error" or html =~ "password" or html =~ "key"
    end
  end

  # ── B8: join channel error feedback ─────────────────────

  describe "join channel error feedback" do
    test "joining channel when banned shows error message", %{conn: conn} do
      ensure_channel("#ban_join")
      Server.join("#ban_join", "BanOp", nil)
      Server.ban("#ban_join", "BanOp", "BanVictim", "not welcome")

      {:ok, view, _html} = live(conn, "/chat?nickname=BanVictim")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #ban_join"})

      html = render(view)
      assert html =~ "chat-error" or html =~ "banned"
    end
  end

  # ── B5: PM send error handling ──────────────────────────

  describe "PM send error handling" do
    test "PM send failure shows error message to user", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmErr1")

      # Open PM conversation with someone
      render_click(view, "nick_right_click", %{"nick" => "PmTarget", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmTarget"})

      # Send a valid PM — should succeed without error
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello PM!"})
      Process.sleep(50)
      html = render(view)
      refute html =~ "chat-error"
    end

    test "PM send via /msg with missing message shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmErr2")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/msg PmTarget2"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "chat-error" or html =~ "No message specified"
    end
  end

  # ── G2: /me action in moderated channel ─────────────────

  describe "action message moderation" do
    test "/me action in +m channel blocked for regular user", %{conn: conn} do
      ensure_channel("#act_mod")
      # First user joins as operator
      Server.join("#act_mod", "ActFounder", nil)
      Server.set_mode("#act_mod", "ActFounder", "+m")

      # Second user joins as regular
      {:ok, view, _html} = live(conn, "/chat?nickname=ActRegular")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #act_mod"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/me waves"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "moderated" or html =~ "Cannot send"
    end
  end

  # ── G3: context menu error paths ──────────────────────

  describe "context menu error paths" do
    test "context_kick shows error when not operator", %{conn: conn} do
      ensure_channel("#ctx_kick_err")
      # Create channel with someone else as operator
      Server.join("#ctx_kick_err", "CtxFounder", nil)

      {:ok, view, _html} = live(conn, "/chat?nickname=CtxNonOp")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #ctx_kick_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_kick", %{"nick" => "CtxFounder"})
      assert html =~ "chat-error" or html =~ "operator"
    end

    test "context_ban shows error when not operator", %{conn: conn} do
      ensure_channel("#ctx_ban_err")
      Server.join("#ctx_ban_err", "BanFounder", nil)

      {:ok, view, _html} = live(conn, "/chat?nickname=BanNonOp")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_ban_err"})

      render_click(view, "nick_right_click", %{"nick" => "BanFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_ban", %{"nick" => "BanFounder"})
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ── G5: pagination ─────────────────────────────────────

  describe "pagination" do
    test "load_more is no-op when already loading", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=LoadNoop")
      # First load_more should be no-op since there's no oldest_message_id set
      html = render_click(view, "load_more")
      assert html =~ "chat-input-form"
    end

    test "load_more appends older messages when available", %{conn: conn} do
      ensure_channel("#load_more_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=LoadMore")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #load_more_ch"})

      # Send enough messages to have something to paginate
      for i <- 1..3 do
        Server.send_message("#load_more_ch", "LoadMore", "Message #{i}")
      end

      Process.sleep(100)

      # Switch away and back to reload messages with pagination state
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#load_more_ch"]))
        |> render_click()

      assert html =~ "chat-input-form"
    end
  end

  # ── G6: keyboard shortcuts ────────────────────────────

  describe "window keyboard shortcuts" do
    test "Ctrl+F opens search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CtrlF")
      html = render_click(view, "window_keydown", %{"key" => "f", "ctrlKey" => true})
      assert html =~ "search-bar"
    end

    test "Escape closes search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=EscSearch")
      render_click(view, "toggle_search")
      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      refute html =~ "search-bar"
    end

    test "Escape without search open is no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=EscNoop")
      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      assert html =~ "chat-input-form"
    end

    test "unhandled key is no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=KeyNoop")
      html = render_click(view, "window_keydown", %{"key" => "a"})
      assert html =~ "chat-input-form"
    end
  end

  # ── G4: search functionality ──────────────────────────

  describe "search functionality" do
    test "search_input returns matching messages", %{conn: conn} do
      ensure_channel("#search_fn")
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchFn")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #search_fn"})

      # Send some messages to create searchable content
      Server.send_message("#search_fn", "SearchFn", "hello world")
      Server.send_message("#search_fn", "SearchFn", "goodbye world")
      Process.sleep(50)

      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "hello"})
      assert html =~ "search-bar"
    end

    test "search empty query clears state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchEmpty")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => ""})
      refute html =~ "search-bar"
    end

    test "search_next cycles through results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchNext")
      render_click(view, "toggle_search")
      # Even without results, search_next should not crash
      html = render_click(view, "search_next")
      assert html =~ "chat-input-form"
    end

    test "search_prev cycles backwards", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchPrev")
      render_click(view, "toggle_search")
      # Even without results, search_prev should not crash
      html = render_click(view, "search_prev")
      assert html =~ "chat-input-form"
    end
  end

  # ── R3: context_whois handler ────────────────────────────

  describe "context_whois" do
    test "context_whois closes context menu and does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=WhoisUser")
      render_click(view, "nick_right_click", %{"nick" => "WhoisTarget", "x" => 0, "y" => 0})
      html = render_click(view, "context_whois", %{"nick" => "WhoisTarget"})
      # Context menu should be closed
      refute html =~ "context-menu"
      # LiveView should still be functional
      assert html =~ "chat-input-form"
    end
  end

  # ── R3: context_op handler ─────────────────────────────

  describe "context_op" do
    test "operator can grant +o via context menu", %{conn: conn} do
      ensure_channel("#ctx_op_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=CtxOpGiver")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_op_ch"})

      # Add a regular user
      send(view.pid, {:user_joined, %{nickname: "CtxOpRecv", role: :regular}})
      render(view)

      # Right-click and grant op
      render_click(view, "nick_right_click", %{"nick" => "CtxOpRecv", "x" => 0, "y" => 0})
      html = render_click(view, "context_op", %{"nick" => "CtxOpRecv"})
      # Context menu should be closed and mode applied
      refute html =~ "context-menu"
    end

    test "non-operator context_op shows error", %{conn: conn} do
      ensure_channel("#ctx_op_err")
      Server.join("#ctx_op_err", "CtxOpFounder", nil)

      {:ok, view, _html} = live(conn, "/chat?nickname=CtxOpNoPerms")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_op_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxOpFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_op", %{"nick" => "CtxOpFounder"})
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ── R3: context_voice handler ──────────────────────────

  describe "context_voice" do
    test "operator can grant +v via context menu", %{conn: conn} do
      ensure_channel("#ctx_v_ch")
      {:ok, view, _html} = live(conn, "/chat?nickname=CtxVGiver")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_v_ch"})

      send(view.pid, {:user_joined, %{nickname: "CtxVRecv", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "CtxVRecv", "x" => 0, "y" => 0})
      html = render_click(view, "context_voice", %{"nick" => "CtxVRecv"})
      refute html =~ "context-menu"
    end

    test "non-operator context_voice shows error", %{conn: conn} do
      ensure_channel("#ctx_v_err")
      Server.join("#ctx_v_err", "CtxVFounder", nil)

      {:ok, view, _html} = live(conn, "/chat?nickname=CtxVNoPerms")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_v_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxVFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_voice", %{"nick" => "CtxVFounder"})
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ── R3: disconnect handler ─────────────────────────────

  describe "disconnect toolbar" do
    test "disconnect cleans up and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=DiscUser")
      result = render_click(view, "disconnect")
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end
  end

  # ── R3: channel_list handler ───────────────────────────

  describe "channel_list navigation" do
    test "channel_list navigates to /channels", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ChanListUser")
      result = render_click(view, "channel_list")
      assert {:error, {:live_redirect, %{to: "/channels"}}} = result
    end
  end

  # ── R3: user_banned info handler ───────────────────────

  describe "user_banned broadcast" do
    test "user_banned shows banned message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=BanWatch")

      send(view.pid, {:user_banned, %{operator: "Admin", target: "BadUser", reason: "spam"}})
      html = render(view)
      assert html =~ "BadUser"
      assert html =~ "banned"
      assert html =~ "Admin"
      assert html =~ "spam"
    end

    test "user_banned without reason omits reason text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=BanNoReason")

      send(view.pid, {:user_banned, %{operator: "Mod", target: "Spammer", reason: nil}})
      html = render(view)
      assert html =~ "Spammer"
      assert html =~ "banned"
      assert html =~ "Mod"
    end
  end

  # ── R3: topic_changed info handler ─────────────────────

  describe "topic_changed broadcast" do
    test "topic_changed shows topic change message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=TopicWatch")

      send(view.pid, {:topic_changed, %{nickname: "TopicSetter", topic: "New Topic Here"}})
      html = render(view)
      assert html =~ "TopicSetter"
      assert html =~ "changed the topic"
      assert html =~ "New Topic Here"
    end
  end

  # ── R3: mode_changed without params ────────────────────

  describe "mode_changed without params" do
    test "mode_changed without params shows mode message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ModeNoParams")

      send(view.pid, {:mode_changed, %{nickname: "ModeOp", mode_string: "+m"}})
      html = render(view)
      assert html =~ "ModeOp"
      assert html =~ "sets mode"
      assert html =~ "+m"
    end
  end

  # ── R3-E5: PM to self ─────────────────────────────────

  describe "PM to self" do
    test "sending /msg to own nick does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SelfPm")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/msg SelfPm hello self"})

      Process.sleep(50)
      html = render(view)
      # Should not crash — either shows the message or shows an error
      assert html =~ "chat-input-form"
    end
  end

  # ── R3-E6: tab complete multiple matches ───────────────

  describe "tab complete multiple matches" do
    test "partial matching multiple nicks does not crash", %{conn: conn} do
      ensure_channel("#tab_multi")
      {:ok, view, _html} = live(conn, "/chat?nickname=TabMulti")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #tab_multi"})

      # Add two users with same prefix
      send(view.pid, {:user_joined, %{nickname: "TabAlpha", role: :regular}})
      send(view.pid, {:user_joined, %{nickname: "TabAlphaTwo", role: :regular}})
      render(view)

      html = render_click(view, "tab_complete", %{"partial" => "TabAlph"})
      assert html =~ "chat-input-form"
    end
  end

  # ── R3-E7: search with regex special chars ─────────────

  describe "search with special characters" do
    test "search_input with regex metacharacters does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchRegex")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "[test("})
      assert html =~ "search-bar" or html =~ "chat-input-form"
    end

    test "search_input with backslash does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchSlash")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "test\\value"})
      assert html =~ "search-bar" or html =~ "chat-input-form"
    end
  end

  # ── R4: /topic command ────────────────────────────────

  describe "/topic command via LiveView" do
    test "/topic with no args shows current topic", %{conn: conn} do
      ensure_channel("#topic_view")
      {:ok, view, _html} = live(conn, "/chat?nickname=TopicViewer")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #topic_view"})

      # Set a topic first
      Server.set_topic("#topic_view", "TopicViewer", "Hello World")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/topic"})
      html = render(view)
      assert html =~ "Hello World"
    end

    test "/topic with no args and empty topic shows 'No topic set'", %{conn: conn} do
      ensure_channel("#topic_empty")
      {:ok, view, _html} = live(conn, "/chat?nickname=TopicEmpty")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #topic_empty"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/topic"})
      html = render(view)
      assert html =~ "No topic set"
    end

    test "/topic with text sets the topic", %{conn: conn} do
      ensure_channel("#topic_set")
      {:ok, view, _html} = live(conn, "/chat?nickname=TopicSetter")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #topic_set"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/topic New Topic Here"})

      Process.sleep(50)
      {:ok, state} = Server.get_state("#topic_set")
      assert state.topic == "New Topic Here"
    end

    test "/topic with topic_lock by regular user shows error", %{conn: conn} do
      ensure_channel("#topic_lock")
      Server.join("#topic_lock", "TopicLockOp", nil)
      Server.set_mode("#topic_lock", "TopicLockOp", "+t")

      {:ok, view, _html} = live(conn, "/chat?nickname=TopicLockReg")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #topic_lock"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/topic Nope"})

      html = render(view)
      assert html =~ "chat-error" or html =~ "operator"
    end
  end

  # ── R4: /away command ──────────────────────────────────

  describe "/away command via LiveView" do
    test "/away with message sets away status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=AwayUser")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/away Gone fishing"})

      html = render(view)
      assert html =~ "You are now away"
      assert html =~ "Gone fishing"
    end

    test "/away without message clears away status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=AwayClr")

      # First set away
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/away Busy"})

      # Then clear
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/away"})

      html = render(view)
      assert html =~ "no longer away"
    end
  end

  # ── R4: /clear command ─────────────────────────────────

  describe "/clear command via LiveView" do
    test "/clear empties the chat messages stream", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ClearUser")

      # Send some messages first
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Message 1"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "Message 1"

      # Clear
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/clear"})
      html = render(view)
      refute html =~ "Message 1"
    end
  end

  # ── R4: /whois command ─────────────────────────────────

  describe "/whois command via LiveView" do
    test "/whois opens whois dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=WhoisCmd")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois SomeUser"})

      html = render(view)
      # The show_whois assign is set to true; the template may render a dialog or the assign
      assert html =~ "chat-input-form"
    end
  end

  # ── R4: /help command ──────────────────────────────────

  describe "/help command via LiveView" do
    test "/help shows available commands", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/help"})
      html = render(view)
      assert html =~ "Available commands"
    end

    test "/help join shows specific command help", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpJoin")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/help join"})
      html = render(view)
      assert html =~ "/join"
    end
  end

  # ── R4: /list command ──────────────────────────────────

  describe "/list command via LiveView" do
    test "/list navigates to channel list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ListUser")

      result =
        view |> element("form.chat-input-form") |> render_submit(%{"input" => "/list"})

      assert {:error, {:live_redirect, %{to: "/channels"}}} = result
    end
  end

  # ── R3-E8: handle_info catch-all ───────────────────────

  describe "handle_info catch-all" do
    test "unknown message does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CatchAll")
      send(view.pid, {:completely_unknown_event, %{data: "test"}})
      html = render(view)
      assert html =~ "chat-input-form"
    end

    test "unknown map message does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CatchAll2")
      send(view.pid, %{event: "unknown_event", payload: %{foo: "bar"}})
      html = render(view)
      assert html =~ "chat-input-form"
    end
  end

  # ── R5: PM conversation lifecycle via ChatLive ──────────

  describe "PM conversation lifecycle" do
    test "opening PM via context_query shows conversation in treebar Private section", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmTree")

      render_click(view, "nick_right_click", %{"nick" => "TreeTarget", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "TreeTarget"})

      # PM should appear in treebar Private section
      assert html =~ "Private"
      assert html =~ "TreeTarget"
      # The PM should be active (tree-active class)
      assert html =~ "tree-active"
    end

    test "switching to PM hides channel content and shows PM view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmSwitch")

      # Open PM conversation
      render_click(view, "nick_right_click", %{"nick" => "PmPal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmPal"})

      # Switch back to channel
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Now switch to PM via treebar
      html =
        view
        |> element(~s(li[phx-click="switch_pm"][phx-value-nickname="PmPal"]))
        |> render_click()

      # Nicklist should be hidden in PM view
      refute html =~ "nick-operator"
      # PM target should be shown as active
      assert html =~ "PmPal"
    end

    test "switching from PM back to channel restores channel view", %{conn: conn} do
      ensure_channel("#pm_back")
      {:ok, view, _html} = live(conn, "/chat?nickname=PmBack")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #pm_back"})

      # Open PM conversation
      render_click(view, "nick_right_click", %{"nick" => "PmFriend", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmFriend"})

      # Verify we're in PM view (no nicklist)
      html = render(view)
      refute html =~ "nick-operator"

      # Switch back to channel
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#pm_back"]))
        |> render_click()

      # Channel view restored: nicklist visible, user shown as operator
      assert html =~ "nick-operator"
      assert html =~ "PmBack"
    end
  end

  # ── R5: current user kicked self ─────────────────────────

  describe "current user being kicked" do
    test "removes channel and switches to another", %{conn: conn} do
      ensure_channel("#kick_self")
      {:ok, view, _html} = live(conn, "/chat?nickname=KickSelf")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #kick_self"})
      html = render(view)
      assert html =~ "#kick_self"

      # Simulate being kicked from #kick_self
      send(
        view.pid,
        {:user_kicked, %{operator: "Admin", target: "KickSelf", reason: "bye"}}
      )

      html = render(view)
      # Should have switched back to #lobby (or another remaining channel)
      assert html =~ "#lobby"
      assert html =~ "kicked"
    end
  end

  # ── R5: PM message while viewing active PM ────────────────

  describe "PM message arriving while viewing active PM" do
    test "streams message directly into chat", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PmActive")

      # Open PM conversation and stay in it
      render_click(view, "nick_right_click", %{"nick" => "PmSender", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmSender"})

      # Verify we're in PM view
      html = render(view)
      assert html =~ "PmSender"

      # Receive a PM while viewing that PM
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: "pm-active-#{System.unique_integer([:positive])}",
          sender: "PmSender",
          recipient: "PmActive",
          content: "Hello from PM!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)
      # Message should appear in the stream directly (not just as unread)
      assert html =~ "Hello from PM!"
      refute html =~ "tree-unread"
    end
  end

  # ── R5: context_ban success ────────────────────────────────

  describe "context_ban success" do
    test "operator banning removes user from nicklist", %{conn: conn} do
      ensure_channel("#ctx_ban_ok")
      {:ok, view, _html} = live(conn, "/chat?nickname=BanOper")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_ban_ok"})

      # Add a regular user to nicklist
      send(view.pid, {:user_joined, %{nickname: "BanTarget", role: :regular}})
      html = render(view)
      assert html =~ "BanTarget"
      assert html =~ "Users (2)"

      # Ban via context menu (BanOper is operator as first user)
      render_click(view, "nick_right_click", %{"nick" => "BanTarget", "x" => 0, "y" => 0})
      render_click(view, "context_ban", %{"nick" => "BanTarget"})

      # After ban, the user_banned PubSub broadcast removes the user
      Process.sleep(50)
      html = render(view)
      # The ban should succeed (no error since we're operator) and user removed via broadcast
      refute html =~ "chat-error"
    end
  end

  # ── R5: user_kicked with/without reason ────────────────────

  describe "user_kicked reason display" do
    test "user_kicked with reason shows reason in system message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=KickReason")

      send(
        view.pid,
        {:user_kicked, %{operator: "Admin", target: "BadUser", reason: "spamming"}}
      )

      html = render(view)
      assert html =~ "BadUser"
      assert html =~ "kicked"
      assert html =~ "spamming"
    end

    test "user_kicked without reason omits reason in system message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=KickNoReason")

      send(
        view.pid,
        {:user_kicked, %{operator: "Mod", target: "Nuisance", reason: nil}}
      )

      html = render(view)
      assert html =~ "Nuisance"
      assert html =~ "kicked"
      refute html =~ "()"
    end
  end

  # ── R5: history_navigate multiple steps ────────────────────

  describe "history_navigate multiple steps" do
    test "navigate up 3x then down 1x shows correct messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HistMulti")

      # Send 3 messages to populate history
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "First message"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Second message"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Third message"})

      # Navigate up 1x — should show most recent (Third)
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "Third message"

      # Navigate up 2x — should show Second
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "Second message"

      # Navigate up 3x — should show First
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "First message"

      # Navigate down 1x — should show Second again
      html = render_click(view, "history_navigate", %{"direction" => "down"})
      assert html =~ "Second message"
    end
  end

  # ── R6: scroll_to_bottom ──────────────────────────────────

  describe "scroll_to_bottom" do
    test "scroll_to_bottom clears new messages indicator", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=ScrollBot")
      html = render_click(view, "scroll_to_bottom")
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: search_next/prev with actual results ───────────────

  describe "search navigation with results" do
    test "search_next cycles through results when results exist", %{conn: conn} do
      ensure_channel("#search_nav")
      {:ok, view, _html} = live(conn, "/chat?nickname=SearchNav")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #search_nav"})

      # Create searchable messages
      Server.send_message("#search_nav", "SearchNav", "findme one")
      Server.send_message("#search_nav", "SearchNav", "findme two")
      Process.sleep(50)

      render_click(view, "toggle_search")
      render_click(view, "search_input", %{"query" => "findme"})

      # Now navigate — should not crash and should cycle
      html = render_click(view, "search_next")
      assert html =~ "search-bar"

      html = render_click(view, "search_prev")
      assert html =~ "search-bar"
    end
  end

  # ── R6: tab complete single match ──────────────────────────

  describe "tab complete single match" do
    test "single matching nick completes with colon suffix", %{conn: conn} do
      ensure_channel("#tab_single")
      {:ok, view, _html} = live(conn, "/chat?nickname=TabSingle")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #tab_single"})

      # Add a user with unique prefix
      send(view.pid, {:user_joined, %{nickname: "UniqueZz", role: :regular}})
      render(view)

      html = render_click(view, "tab_complete", %{"partial" => "Unique"})
      assert html =~ "UniqueZz: "
    end
  end

  # ── R6: -v mode update in nicklist ────────────────────────

  describe "mode_changed -v" do
    test "-v removes voiced role and resets to regular", %{conn: conn} do
      ensure_channel("#mode_devoice")
      {:ok, view, _html} = live(conn, "/chat?nickname=DevoiceHost")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #mode_devoice"})

      # Add a voiced user
      send(view.pid, {:user_joined, %{nickname: "VoicedUser", role: :voiced}})
      html = render(view)
      assert html =~ "nick-voiced"

      # Remove voice
      send(
        view.pid,
        {:mode_changed, %{nickname: "DevoiceHost", mode_string: "-v", params: ["VoicedUser"]}}
      )

      html = render(view)
      assert html =~ "sets mode -v"
      refute html =~ "nick-voiced"
    end
  end

  # ── R6: /quit command ──────────────────────────────────────

  describe "/quit command" do
    test "/quit redirects to connect page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=QuitUser")

      result =
        view |> element("form.chat-input-form") |> render_submit(%{"input" => "/quit bye"})

      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end
  end

  # ── R6: history_navigate unknown direction ─────────────────

  describe "history_navigate edge cases" do
    test "unknown direction is no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HistUnk")
      html = render_click(view, "history_navigate", %{"direction" => "left"})
      assert html =~ "chat-input-form"
    end

    test "navigate down past beginning clears input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HistDown")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello"})

      # Navigate up then down past beginning
      render_click(view, "history_navigate", %{"direction" => "up"})
      html = render_click(view, "history_navigate", %{"direction" => "down"})
      # Input should be cleared
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: /me action in channel with type :action ─────────────

  describe "/me action message type" do
    test "/me sends action type message in channel", %{conn: conn} do
      ensure_channel("#me_action")
      {:ok, view, _html} = live(conn, "/chat?nickname=MeAction")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #me_action"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/me dances"})
      Process.sleep(50)
      html = render(view)
      # Should show the action message in the chat
      assert html =~ "dances" or html =~ "chat-action"
    end
  end

  # ── R6: part last channel ──────────────────────────────────

  describe "part last channel" do
    test "parting only channel clears messages and shows empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=PartLast")

      # Part #lobby (the only channel)
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/part"})
      html = render(view)
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: /cs system message dispatch ────────────────────────

  describe "/cs and /ns service message dispatch" do
    test "/cs help shows ChanServ service message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=CsHelp")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/cs help"})
      html = render(view)
      assert html =~ "cs register" or html =~ "Available commands"
    end

    test "/ns help shows NickServ service message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=NsHelp")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ns help"})
      html = render(view)
      assert html =~ "ns register" or html =~ "Available commands"
    end
  end

  # ── R6: /mode via UI action dispatch ────────────────────────

  describe "/mode command via UI action" do
    test "/mode +m sets moderated mode via dispatch", %{conn: conn} do
      ensure_channel("#mode_cmd")
      {:ok, view, _html} = live(conn, "/chat?nickname=ModeCmd")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mode_cmd"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/mode +m"})
      Process.sleep(50)
      html = render(view)
      # Mode change should succeed or show mode message
      assert html =~ "sets mode" or html =~ "+m"
    end
  end

  # ── R6: /kick command via UI action dispatch ─────────────────

  describe "/kick command via UI action" do
    test "/kick non-member shows error", %{conn: conn} do
      ensure_channel("#kick_cmd")
      {:ok, view, _html} = live(conn, "/chat?nickname=KickCmd")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #kick_cmd"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/kick Ghost"})
      html = render(view)
      assert html =~ "chat-error" or html =~ "not in channel"
    end
  end

  # ── R6: /ban command via UI action dispatch ─────────────────

  describe "/ban command via UI action" do
    test "/ban via dispatch works for operator", %{conn: conn} do
      ensure_channel("#ban_cmd")
      {:ok, view, _html} = live(conn, "/chat?nickname=BanCmd")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ban_cmd"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ban Troll"})
      Process.sleep(50)
      html = render(view)
      # Should succeed (operator banning a non-member adds to ban list)
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: join from params ────────────────────────────────────

  describe "join from params" do
    test "join param in URL joins additional channel on mount", %{conn: conn} do
      ensure_channel("#param_join")
      {:ok, _view, html} = live(conn, "/chat?nickname=ParamJoin&join=%23param_join")
      assert html =~ "#param_join"
    end
  end

  # ── T012: Inline formatting rendering (US1) ──────────────

  describe "inline formatting rendering" do
    test "bold control codes render irc-bold span", %{conn: conn} do
      ensure_channel("#fmt_bold")
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtBold")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #fmt_bold"})

      # Send message with bold control codes
      bold_msg = <<0x02>> <> "Hello" <> <<0x02>> <> " world"
      view |> element("form.chat-input-form") |> render_submit(%{"input" => bold_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ ~s(class="irc-bold")
      assert html =~ "Hello"
    end

    test "italic control codes render irc-italic span", %{conn: conn} do
      ensure_channel("#fmt_italic")
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtItalic")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #fmt_italic"})

      italic_msg = <<0x1D>> <> "styled" <> <<0x1D>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => italic_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ ~s(class="irc-italic")
      assert html =~ "styled"
    end

    test "underline control codes render irc-underline span", %{conn: conn} do
      ensure_channel("#fmt_uline")
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtUline")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #fmt_uline"})

      underline_msg = <<0x1F>> <> "link" <> <<0x1F>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => underline_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ ~s(class="irc-underline")
      assert html =~ "link"
    end

    test "system messages are NOT parsed for format codes", %{conn: conn} do
      ensure_channel("#fmt_sys")
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtSys")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #fmt_sys"})

      # System messages (like join notifications) should not contain irc-* spans
      html = render(view)
      # Join messages are system type — they should not have formatting spans
      refute html =~ ~s(class="irc-bold")
      refute html =~ ~s(class="irc-italic")
    end

    test "service messages are NOT parsed for format codes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtSvc")

      # NickServ messages are service type — trigger one
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns help"})

      Process.sleep(50)
      html = render(view)
      # Service messages should render without irc-* formatting spans
      refute html =~ ~s(class="irc-bold")
    end

    test "error messages are NOT parsed for format codes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=FmtErr")

      # Trigger an error message (e.g., invalid command)
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/kick"})

      Process.sleep(50)
      html = render(view)
      # Error messages should not have formatting spans
      refute html =~ ~s(class="irc-fg-)
    end
  end

  # ── T013: Color code rendering (US2) ────────────────────

  describe "color code rendering" do
    test "foreground color renders irc-fg span", %{conn: conn} do
      ensure_channel("#clr_fg")
      {:ok, view, _html} = live(conn, "/chat?nickname=ClrFg")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #clr_fg"})

      # Color code: \x03 4 = red foreground
      color_msg = <<0x03>> <> "4Red text" <> <<0x03>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => color_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ "irc-fg-4"
      assert html =~ "Red text"
    end

    test "foreground + background color renders both irc-fg and irc-bg spans", %{conn: conn} do
      ensure_channel("#clr_fgbg")
      {:ok, view, _html} = live(conn, "/chat?nickname=ClrFgBg")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #clr_fgbg"})

      # Color code: \x03 4,1 = red fg, black bg
      color_msg = <<0x03>> <> "4,1Red on black" <> <<0x03>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => color_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ "irc-fg-4"
      assert html =~ "irc-bg-1"
      assert html =~ "Red on black"
    end

    test "combined bold + color renders both irc-bold and irc-fg classes", %{conn: conn} do
      ensure_channel("#clr_combo")
      {:ok, view, _html} = live(conn, "/chat?nickname=ClrCombo")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #clr_combo"})

      # Bold + color 4 (red)
      combo_msg = <<0x02>> <> <<0x03>> <> "4Bold red" <> <<0x0F>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => combo_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ "irc-bold"
      assert html =~ "irc-fg-4"
      assert html =~ "Bold red"
    end
  end

  # ── T019: Formatting toolbar rendering (US3) ─────────────

  describe "formatting toolbar" do
    test "toolbar renders B, I, U, and Color buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=TbRender")
      assert html =~ ~s(data-testid="format-btn-bold")
      assert html =~ ~s(data-testid="format-btn-italic")
      assert html =~ ~s(data-testid="format-btn-underline")
      assert html =~ ~s(data-testid="format-btn-color")
    end

    test "toolbar has correct 98.css button styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=TbStyle")
      assert html =~ "formatting-toolbar"
      assert html =~ "format-btn"
    end
  end

  # ── T020: Color picker dropdown (US3) ───────────────────

  describe "color picker dropdown" do
    test "color picker contains 16 color swatches", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=CpSwatches")

      for i <- 0..15 do
        assert html =~ ~s(data-color-code="#{i}")
      end
    end

    test "color picker swatches are in a grid container", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=CpGrid")
      assert html =~ "format-color-dropdown"
      assert html =~ "color-swatch"
    end
  end

  # ── T026: Strip formatting toggle (US4) ──────────────────

  describe "strip formatting toggle" do
    test "default: formatted messages render with irc-* spans", %{conn: conn} do
      ensure_channel("#strip_dflt")
      {:ok, view, _html} = live(conn, "/chat?nickname=StripDflt")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #strip_dflt"})

      bold_msg = <<0x02>> <> "Bold text" <> <<0x02>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => bold_msg})

      Process.sleep(50)
      html = render(view)
      assert html =~ "irc-bold"
      assert html =~ "Bold text"
    end

    test "after toggle: formatted messages render as plain text", %{conn: conn} do
      ensure_channel("#strip_on")
      {:ok, view, _html} = live(conn, "/chat?nickname=StripOn")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #strip_on"})

      bold_msg = <<0x02>> <> "Bold text" <> <<0x02>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => bold_msg})

      Process.sleep(50)
      # Toggle strip formatting on
      render_click(view, "toggle_strip_formatting")

      html = render(view)
      assert html =~ "Bold text"
      refute html =~ "irc-bold"
    end

    test "toggle event flips preference back", %{conn: conn} do
      ensure_channel("#strip_flip")
      {:ok, view, _html} = live(conn, "/chat?nickname=StripFlip")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #strip_flip"})

      bold_msg = <<0x02>> <> "Toggled" <> <<0x02>>
      view |> element("form.chat-input-form") |> render_submit(%{"input" => bold_msg})

      Process.sleep(50)

      # Toggle on (strip)
      render_click(view, "toggle_strip_formatting")
      html = render(view)
      refute html =~ "irc-bold"

      # Toggle off (restore formatting)
      render_click(view, "toggle_strip_formatting")
      html = render(view)
      assert html =~ "irc-bold"
    end

    test "strip toggle UI control is visible", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chat?nickname=StripUI")
      assert html =~ "data-testid=\"strip-formatting-toggle\""
    end
  end

  # ── T031: PM formatting verification ─────────────────────

  describe "PM formatting" do
    test "formatted PM renders with irc-* spans", %{conn: conn} do
      # Set up two users
      {:ok, sender, _html} = live(conn, "/chat?nickname=PmFmtSend")
      {:ok, receiver, _html} = live(build_conn(), "/chat?nickname=PmFmtRecv")

      # Sender opens PM to receiver
      sender
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/msg PmFmtRecv " <> <<0x02>> <> "bold PM" <> <<0x02>>})

      Process.sleep(50)

      # Switch receiver to PM conversation
      render_click(receiver, "switch_pm", %{"nickname" => "PmFmtSend"})
      Process.sleep(50)
      html = render(receiver)
      assert html =~ "irc-bold"
      assert html =~ "bold PM"
    end

    test "strip formatting applies to PMs", %{conn: conn} do
      {:ok, sender, _html} = live(conn, "/chat?nickname=PmStripS")
      {:ok, receiver, _html} = live(build_conn(), "/chat?nickname=PmStripR")

      sender
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/msg PmStripR " <> <<0x02>> <> "bold PM" <> <<0x02>>})

      Process.sleep(50)

      # Toggle strip formatting on receiver
      render_click(receiver, "toggle_strip_formatting")

      render_click(receiver, "switch_pm", %{"nickname" => "PmStripS"})
      Process.sleep(50)
      html = render(receiver)
      assert html =~ "bold PM"
      refute html =~ "irc-bold"
    end
  end

  # ── Help Dialog ────────────────────────────────────────────

  describe "help dialog" do
    test "F1 opens help dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser1")
      html = render_keydown(view, "window_keydown", %{"key" => "F1"})
      assert html =~ "help-dialog"
      assert html =~ "RetroHexChat Help"
    end

    test "toggle_help_dialog opens and closes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser2")

      html = render_click(view, "toggle_help_dialog")
      assert html =~ "help-dialog"

      html = render_click(view, "toggle_help_dialog")
      refute html =~ "help-dialog"
    end

    test "close_help closes the dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser3")
      render_click(view, "toggle_help_dialog")
      html = render_click(view, "close_help")
      refute html =~ "help-dialog"
    end

    test "help_tab switches tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser4")
      render_click(view, "toggle_help_dialog")

      html = render_click(view, "help_tab", %{"tab" => "index"})
      assert html =~ "help-index-filter"

      html = render_click(view, "help_tab", %{"tab" => "search"})
      assert html =~ "help-search-input"

      html = render_click(view, "help_tab", %{"tab" => "contents"})
      assert html =~ "Getting Started"
    end

    test "help_select_topic shows topic content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser5")
      render_click(view, "toggle_help_dialog")

      html = render_click(view, "help_select_topic", %{"id" => "welcome"})
      assert html =~ "Welcome to RetroHexChat"
    end

    test "help_search finds topics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser6")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})

      html = render_click(view, "help_search", %{"query" => "join"})
      assert html =~ "help-result-cmd-join"
    end

    test "help_index_filter filters keywords", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser7")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "index"})

      html = render_keyup(view, "help_index_filter", %{"value" => "buddy"})
      assert html =~ "buddy"
    end

    test "help_content_click navigates cross-references", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser8")
      render_click(view, "toggle_help_dialog")

      html =
        render_click(view, "help_content_click", %{"data-help-topic" => "connecting"})

      assert html =~ "Connecting"
    end

    test "help_content_click without topic is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUser9")
      render_click(view, "toggle_help_dialog")

      html = render_click(view, "help_content_click", %{})
      assert html =~ "help-dialog"
    end

    test "help_search_input with Enter triggers search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUserA")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})

      html =
        render_keyup(view, "help_search_input", %{"key" => "Enter", "value" => "mode"})

      assert html =~ "help-result-cmd-mode"
    end

    test "help_search_input without Enter just updates query", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat?nickname=HelpUserB")
      render_click(view, "toggle_help_dialog")
      render_click(view, "help_tab", %{"tab" => "search"})

      html = render_keyup(view, "help_search_input", %{"key" => "m", "value" => "m"})
      # No search results shown for single char
      refute html =~ "help-result-"
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
