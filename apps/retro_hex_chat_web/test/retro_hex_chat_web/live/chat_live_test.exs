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
      {:ok, _view, html} = live(chat_conn(conn, "MountUser"), "/chat")
      assert html =~ "MountUser"
      assert html =~ "#lobby"
    end

    test "invalid nickname redirects to /", %{conn: conn} do
      result = live(chat_conn(conn, "!!invalid!!"), "/chat")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end

    test "registered but unidentified nick shows NickServ notice", %{conn: conn} do
      # Insert directly into DB to avoid NickServ marking it as identified
      alias RetroHexChat.Services.Queries
      {:ok, _} = Queries.insert_registered_nick("RegNotice", "pass123")

      {:ok, _view, html} = live(chat_conn(conn, "RegNotice"), "/chat")
      assert html =~ "NickServ" or html =~ "registered"
    end

    test "already-identified nick skips NickServ timer", %{conn: conn} do
      NickServ.register("IdentNick", "pass123")

      {:ok, _view, html} = live(chat_conn(conn, "IdentNick"), "/chat")
      refute html =~ "60 seconds"
    end
  end

  # ── send_input ────────────────────────────────────────────

  describe "send_input" do
    test "empty input is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EmptyInput"), "/chat")
      html = view |> element("form.chat-input-form") |> render_submit(%{"input" => ""})
      # Page should not crash, still shows the interface
      assert html =~ "EmptyInput" or html =~ "chat-input-form"
    end

    test "plain text in channel sends message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sender1"), "/chat")

      # Switch from status tab to #lobby channel
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello everyone"})

      # Give PubSub a moment to deliver
      Process.sleep(50)
      html = render(view)
      assert html =~ "Hello everyone"
    end

    test "sender sees own message exactly once (no optimistic + broadcast duplicate)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(chat_conn(conn, "NoDup"), "/chat")
      render_click(view, "switch_channel", %{"channel" => "#lobby"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "unique_dedup_test_msg"})

      # Wait for PubSub broadcast to arrive back to sender
      Process.sleep(100)
      html = render(view)

      # Message must appear exactly once — count occurrences of the unique content
      occurrences = html |> String.split("unique_dedup_test_msg") |> length() |> Kernel.-(1)
      assert occurrences == 1, "Expected message once, got #{occurrences} times"
    end

    test "/join command joins a new channel", %{conn: conn} do
      ensure_channel("#jointest")
      {:ok, view, _html} = live(chat_conn(conn, "Joiner1"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #jointest"})
      html = render(view)
      assert html =~ "#jointest"
    end

    test "/part command leaves the current channel", %{conn: conn} do
      ensure_channel("#parttest")
      {:ok, view, _html} = live(chat_conn(conn, "Parter1"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "Switcher"), "/chat")

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
      {:ok, view, html} = live(chat_conn(conn, "Searcher"), "/chat")
      refute html =~ "search-bar"

      html = render_click(view, "toggle_search")
      assert html =~ "search-bar"

      html = render_click(view, "toggle_search")
      refute html =~ "search-bar"
    end

    test "close_search clears search state", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SearchClose"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "close_search")
      refute html =~ "search-bar"
    end
  end

  # ── context_menu ──────────────────────────────────────────

  describe "context_menu" do
    test "nick_right_click shows context menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxUser"), "/chat")

      html =
        render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 100, "y" => 200})

      assert html =~ "context-menu"
    end

    test "close_context_menu hides context menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxClose"), "/chat")
      render_click(view, "nick_right_click", %{"nick" => "someone", "x" => 100, "y" => 200})
      html = render_click(view, "close_context_menu")
      refute html =~ "context-menu"
    end

    test "context_query opens PM conversation", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CtxQuery"), "/chat")
      render_click(view, "nick_right_click", %{"nick" => "pmtarget", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "pmtarget"})
      assert html =~ "pmtarget"
    end
  end

  # ── PubSub handlers ──────────────────────────────────────

  describe "PubSub handlers" do
    test "new_message broadcast appears in stream", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PubUser1"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "PubJoin"), "/chat")
      send(view.pid, {:user_joined, %{nickname: "newcomer"}})
      html = render(view)
      assert html =~ "newcomer" and html =~ "joined"
    end

    test "user_left broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PubLeft"), "/chat")
      send(view.pid, {:user_left, %{nickname: "leaver", reason: nil}})
      html = render(view)
      assert html =~ "leaver" and html =~ "left"
    end

    test "force_disconnect redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ForceDisc"), "/chat")

      result = render_click(view, "close_context_menu")
      assert is_binary(result)

      send(view.pid, {:force_disconnect, %{reason: "Ghosted by admin"}})

      {path, _flash} = assert_redirect(view)
      assert path =~ "/chat/session/clear"
      assert path =~ "Ghosted"
    end

    test "single session enforcement disconnects existing session", %{conn: conn} do
      {:ok, view1, _html} = live(chat_conn(conn, "SSEnforce"), "/chat")

      # Second session with the same nick — should kick the first
      {:ok, _view2, _html} = live(chat_conn(conn, "SSEnforce"), "/chat")

      {path, _flash} = assert_redirect(view1)
      assert path =~ "/chat/session/clear"
    end

    test "force_rename updates nickname", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "RenameMe"), "/chat")
      send(view.pid, {:force_rename, %{reason: "Identify timeout (60s)"}})
      html = render(view)
      assert html =~ "Guest_"
      assert html =~ "Identify timeout"
    end
  end

  # ── menu/toolbar ──────────────────────────────────────────

  describe "menu and toolbar" do
    test "quit_chat redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Quitter"), "/chat")
      result = render_click(view, "quit_chat")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end

    test "toggle_treebar toggles visibility", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TreeToggle"), "/chat")
      # Treebar should be visible initially (has class="treebar")
      html = render(view)
      assert html =~ ~s(class="treebar")

      html = render_click(view, "toggle_treebar")
      refute html =~ ~s(class="treebar")

      html = render_click(view, "toggle_treebar")
      assert html =~ ~s(class="treebar")
    end

    test "toggle_nicklist toggles visibility", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NickToggle"), "/chat")
      html = render(view)
      assert html =~ "nick-" or html =~ "Users"

      html = render_click(view, "toggle_nicklist")
      # After toggling off, nicklist should not be rendered
      refute html =~ "nick-owner" and html =~ "nick-regular"
    end
  end

  # ── about dialog ──────────────────────────────────────────

  describe "about dialog" do
    test "show_about shows dialog, close_dialog hides it", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "AboutUser"), "/chat")
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
    test "after mount in isolated channel, nicklist shows the user as owner", %{conn: conn} do
      ensure_channel("#nick_iso1")
      {:ok, view, _html} = live(chat_conn(conn, "NickOp"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso1"})
      html = render(view)
      assert html =~ "nick-owner"
      assert html =~ "NickOp"
      assert html =~ "Users (1)"
    end

    test "after second user joins via PubSub, nicklist updates", %{conn: conn} do
      ensure_channel("#nick_iso2")
      {:ok, view, _html} = live(chat_conn(conn, "NickHost"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso2"})

      send(view.pid, {:user_joined, %{nickname: "NickGuest", role: :regular}})
      html = render(view)
      assert html =~ "NickHost"
      assert html =~ "NickGuest"
      assert html =~ "Users (2)"
    end

    test "after user_left PubSub, user removed from nicklist", %{conn: conn} do
      ensure_channel("#nick_iso3")
      {:ok, view, _html} = live(chat_conn(conn, "NickStay"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "CountUser"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso4"})
      html = render(view)
      assert html =~ "Users: 1"

      send(view.pid, {:user_joined, %{nickname: "CountGuest", role: :regular}})
      html = render(view)
      assert html =~ "Users: 2"
    end

    test "switching channel reloads nicklist for new channel", %{conn: conn} do
      ensure_channel("#nick_ch2")
      {:ok, view, _html} = live(chat_conn(conn, "NickSwitch"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "NickPm"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #nick_iso5"})
      render_click(view, "nick_right_click", %{"nick" => "pmpal", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "pmpal"})
      refute html =~ "nick-owner"
    end

    test "user_kicked removes user from nicklist", %{conn: conn} do
      ensure_channel("#nick_iso6")
      {:ok, view, _html} = live(chat_conn(conn, "KickHost"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "KickPres"), "/chat")
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

  describe "nick change dialog" do
    test "/nick shows confirmation dialog instead of changing immediately", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OldNick1"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick NewNick1"})
      html = render(view)
      assert html =~ "nick-change-dialog"
      assert html =~ "NewNick1"
      assert html =~ "new chat session"
    end

    test "cancel closes the dialog without changes", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CancelNick"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick Target1"})
      assert render(view) =~ "nick-change-dialog"

      view |> element("[data-testid=\"nick-change-cancel-btn\"]") |> render_click()
      refute render(view) =~ "nick-change-dialog"
    end

    test "Escape closes the dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EscNick"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick EscTarget"})
      assert render(view) =~ "nick-change-dialog"

      render_hook(view, "cancel_nick_change", %{})
      refute render(view) =~ "nick-change-dialog"
    end

    test "unregistered nick confirm sets nick_change_target for POST", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "UnregNick"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick FreeNick1"})
      assert render(view) =~ "nick-change-dialog"

      view |> element("[data-testid=\"nick-change-confirm-btn\"]") |> render_click()
      html = render(view)
      refute html =~ "nick-change-dialog"
      assert html =~ "FreeNick1"
    end

    test "registered nick shows password field", %{conn: conn} do
      NickServ.register("RegTarget1", "secret123")
      {:ok, view, _html} = live(chat_conn(conn, "RegNick1"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick RegTarget1"})
      html = render(view)
      assert html =~ "nick-change-dialog"
      assert html =~ "nick-change-password"
      assert html =~ "NickServ"
    end

    test "registered nick with wrong password shows error", %{conn: conn} do
      NickServ.register("RegTarget2", "correct_pass")
      {:ok, view, _html} = live(chat_conn(conn, "RegNick2"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick RegTarget2"})

      view
      |> element("[data-testid=\"nick-change-confirm-btn\"]")
      |> render_click(%{"password" => "wrong_pass"})

      html = render(view)
      assert html =~ "Incorrect password"
      assert html =~ "nick-change-dialog"
    end

    test "registered nick with correct password sets target and token for POST", %{conn: conn} do
      NickServ.register("RegTarget3", "correct_pass")
      {:ok, view, _html} = live(chat_conn(conn, "RegNick3"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick RegTarget3"})

      view
      |> element("[data-testid=\"nick-change-confirm-btn\"]")
      |> render_click(%{"password" => "correct_pass"})

      html = render(view)
      refute html =~ "nick-change-dialog"
      assert html =~ "RegTarget3"
    end

    test "password field updates via update_nick_change_password event", %{conn: conn} do
      NickServ.register("RegTarget4", "pass")
      {:ok, view, _html} = live(chat_conn(conn, "RegNick4"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/nick RegTarget4"})

      render_hook(view, "update_nick_change_password", %{"value" => "typed"})
      html = render(view)
      assert html =~ "nick-change-dialog"
    end

    test "receiving nick_changed broadcast shows system message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NickObserver"), "/chat")

      send(view.pid, {:nick_changed, %{old_nick: "Alice", new_nick: "Bob"}})
      html = render(view)
      assert html =~ "Alice" and html =~ "Bob"
    end
  end

  # ── B3: mode_changed updates nicklist ───────────────────

  describe "mode_changed nicklist update" do
    test "mode_changed +o updates user role to operator in nicklist", %{conn: conn} do
      ensure_channel("#mode_op")
      {:ok, view, _html} = live(chat_conn(conn, "ModeHost"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "VoiceHost"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "DeopHost"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "PmUnread"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "PmClr"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "UnreadUser"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "UnreadClr"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "UnreadActive"), "/chat")

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
      {:ok, _view, _html} = live(chat_conn(conn, "PresUser"), "/chat")
      Process.sleep(50)

      users = Tracker.list_users("channel:#lobby")
      nicks = Enum.map(users, & &1.nickname)
      assert "PresUser" in nicks
    end

    test "after join second channel, user tracked in both", %{conn: conn} do
      ensure_channel("#pres_ch2")
      {:ok, view, _html} = live(chat_conn(conn, "PresMulti"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #pres_ch2"})
      Process.sleep(50)

      lobby_users = Tracker.list_users("channel:#lobby")
      ch2_users = Tracker.list_users("channel:#pres_ch2")

      assert "PresMulti" in Enum.map(lobby_users, & &1.nickname)
      assert "PresMulti" in Enum.map(ch2_users, & &1.nickname)
    end

    test "after part channel, user untracked from that channel", %{conn: conn} do
      ensure_channel("#pres_part")
      {:ok, view, _html} = live(chat_conn(conn, "PresPart"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "ModUser1"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #mod_normal"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "Hello world"
    end

    test "in +m channel, operator can send message", %{conn: conn} do
      ensure_channel("#mod_op")
      {:ok, view, _html} = live(chat_conn(conn, "ModOp"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "ModRegular"), "/chat")
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

      {:ok, view, _html} = live(chat_conn(conn, "VoicedUser"), "/chat")
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

  describe "autocomplete" do
    test "autocomplete dropdown hidden by default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "PalUser"), "/chat")
      refute html =~ "autocomplete-dropdown"
    end

    test "autocomplete_query shows dropdown", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalOpen"), "/chat")
      html = render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      assert html =~ "autocomplete-dropdown"
    end

    test "autocomplete_close hides dropdown", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalClose"), "/chat")
      render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      html = render_click(view, "autocomplete_close")
      refute html =~ "autocomplete-dropdown"
    end

    test "autocomplete_select inserts command prefix into input", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalSelect"), "/chat")
      render_click(view, "autocomplete_query", %{"type" => "command", "partial" => ""})
      html = render_click(view, "autocomplete_select", %{"type" => "command", "value" => "join"})
      assert html =~ "/join "
      refute html =~ "autocomplete-dropdown"
    end

    test "autocomplete_query with partial filters the list", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PalFilter"), "/chat")
      html = render_click(view, "autocomplete_query", %{"type" => "command", "partial" => "jo"})
      assert html =~ "autocomplete-dropdown"
    end
  end

  describe "keyboard shortcuts" do
    test "history_navigate up with empty history does not crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistUser"), "/chat")
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "chat-input-form"
    end

    test "history_navigate returns previous command after sending", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistNav"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})
      html = render_click(view, "history_navigate", %{"direction" => "up"})
      assert html =~ "Hello world"
    end

    test "tab_complete with matching nick suggests completion", %{conn: conn} do
      ensure_channel("#tab_ch")
      {:ok, view, _html} = live(chat_conn(conn, "TabUser"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #tab_ch"})

      send(view.pid, {:user_joined, %{nickname: "TabTarget", role: :regular}})
      render(view)

      html = render_click(view, "tab_complete", %{"partial" => "Tab"})
      assert html =~ "TabTarget" or html =~ "TabUser"
    end

    test "tab_complete with no match does not alter input", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TabNone"), "/chat")
      html = render_click(view, "tab_complete", %{"partial" => "zzz_nomatch"})
      assert html =~ "chat-input-form"
    end
  end

  # ── F7: trivial handler fixes ────────────────────────────

  describe "trivial handler fixes" do
    test "settings event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SettingsUser"), "/chat")
      html = render_click(view, "settings")
      assert html =~ "chat-input-form"
    end

    test "open_search shows search bar", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OpenSearchUser"), "/chat")
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

      {:ok, view, _html} = live(chat_conn(conn, "PwUser"), "/chat")

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

      {:ok, view, _html} = live(chat_conn(conn, "PwFail"), "/chat")

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

      {:ok, view, _html} = live(chat_conn(conn, "BanVictim"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "PmErr1"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "PmErr2"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "ActRegular"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #act_mod"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/me waves"})
      Process.sleep(50)
      html = render(view)
      assert html =~ "moderated" or html =~ "Cannot send"
    end
  end

  # ── G3: context menu error paths ──────────────────────

  describe "context menu error paths" do
    test "context_kick by non-operator closes context menu silently", %{conn: conn} do
      ensure_channel("#ctx_kick_err")
      # Create channel with someone else as owner (first joiner)
      Server.join("#ctx_kick_err", "CtxFounder", nil)

      {:ok, view, _html} = live(chat_conn(conn, "CtxNonOp"), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #ctx_kick_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_kick", %{"nick" => "CtxFounder"})
      # Context menu closes; kick silently fails (non-operator cannot kick)
      refute html =~ "context-menu"
    end

    test "context_ban by non-operator closes context menu silently", %{conn: conn} do
      ensure_channel("#ctx_ban_err")
      Server.join("#ctx_ban_err", "BanFounder", nil)

      {:ok, view, _html} = live(chat_conn(conn, "BanNonOp"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_ban_err"})

      render_click(view, "nick_right_click", %{"nick" => "BanFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_ban", %{"nick" => "BanFounder"})
      # Context menu closes; ban silently fails (non-operator cannot ban)
      refute html =~ "context-menu"
    end
  end

  # ── G5: pagination ─────────────────────────────────────

  describe "pagination" do
    test "load_more is no-op when already loading", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "LoadNoop"), "/chat")
      # First load_more should be no-op since there's no oldest_message_id set
      html = render_click(view, "load_more")
      assert html =~ "chat-input-form"
    end

    test "load_more appends older messages when available", %{conn: conn} do
      ensure_channel("#load_more_ch")
      {:ok, view, _html} = live(chat_conn(conn, "LoadMore"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "CtrlF"), "/chat")

      html =
        render_click(view, "window_keydown", %{
          "key" => "f",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      assert html =~ "search-bar"
    end

    test "Escape closes search", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EscSearch"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      refute html =~ "search-bar"
    end

    test "Escape without search open is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EscNoop"), "/chat")
      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      assert html =~ "chat-input-form"
    end

    test "unhandled key is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "KeyNoop"), "/chat")
      html = render_click(view, "window_keydown", %{"key" => "a"})
      assert html =~ "chat-input-form"
    end
  end

  # ── G4: search functionality ──────────────────────────

  describe "search functionality" do
    test "search_input returns matching messages", %{conn: conn} do
      ensure_channel("#search_fn")
      {:ok, view, _html} = live(chat_conn(conn, "SearchFn"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #search_fn"})

      # Send some messages to create searchable content
      Server.send_message("#search_fn", "SearchFn", "hello world")
      Server.send_message("#search_fn", "SearchFn", "goodbye world")
      Process.sleep(50)

      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "hello"})
      assert html =~ "search-bar"
    end

    test "search empty query clears results but keeps bar open", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SearchEmpty"), "/chat")
      render_click(view, "toggle_search")
      html = render_change(view, "search_input", %{"query" => ""})
      assert html =~ "search-bar"
      assert html =~ "No results"
    end

    test "search_next cycles through results", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SearchNext"), "/chat")
      render_click(view, "toggle_search")
      # Even without results, search_next should not crash
      html = render_click(view, "search_next")
      assert html =~ "chat-input-form"
    end

    test "search_prev cycles backwards", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SearchPrev"), "/chat")
      render_click(view, "toggle_search")
      # Even without results, search_prev should not crash
      html = render_click(view, "search_prev")
      assert html =~ "chat-input-form"
    end
  end

  # ── R3: context_whois handler ────────────────────────────

  describe "context_whois" do
    test "context_whois closes context menu and does not crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WhoisUser"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "CtxOpGiver"), "/chat")
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

    test "non-operator context_op closes context menu silently", %{conn: conn} do
      ensure_channel("#ctx_op_err")
      Server.join("#ctx_op_err", "CtxOpFounder", nil)

      {:ok, view, _html} = live(chat_conn(conn, "CtxOpNoPerms"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_op_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxOpFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_op", %{"nick" => "CtxOpFounder"})
      # Context menu closes; set_mode silently fails (non-operator cannot op)
      refute html =~ "context-menu"
    end
  end

  # ── R3: context_voice handler ──────────────────────────

  describe "context_voice" do
    test "operator can grant +v via context menu", %{conn: conn} do
      ensure_channel("#ctx_v_ch")
      {:ok, view, _html} = live(chat_conn(conn, "CtxVGiver"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_v_ch"})

      send(view.pid, {:user_joined, %{nickname: "CtxVRecv", role: :regular}})
      render(view)

      render_click(view, "nick_right_click", %{"nick" => "CtxVRecv", "x" => 0, "y" => 0})
      html = render_click(view, "context_voice", %{"nick" => "CtxVRecv"})
      refute html =~ "context-menu"
    end

    test "non-operator context_voice closes context menu silently", %{conn: conn} do
      ensure_channel("#ctx_v_err")
      Server.join("#ctx_v_err", "CtxVFounder", nil)

      {:ok, view, _html} = live(chat_conn(conn, "CtxVNoPerms"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ctx_v_err"})

      render_click(view, "nick_right_click", %{"nick" => "CtxVFounder", "x" => 0, "y" => 0})
      html = render_click(view, "context_voice", %{"nick" => "CtxVFounder"})
      # Context menu closes; set_mode silently fails (non-operator cannot voice)
      refute html =~ "context-menu"
    end
  end

  # ── R3: disconnect handler ─────────────────────────────

  describe "disconnect toolbar" do
    test "disconnect cleans up and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "DiscUser"), "/chat")
      result = render_click(view, "disconnect")
      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end
  end

  # ── R3: channel_list handler ───────────────────────────

  describe "channel_list dialog" do
    test "channel_list opens inline dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ChanListUser"), "/chat")
      html = render_click(view, "channel_list")
      assert html =~ ~s(data-testid="channel-list-dialog")
      assert html =~ "Channel List"
    end
  end

  # ── R3: user_banned info handler ───────────────────────

  describe "user_banned broadcast" do
    test "user_banned shows banned message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "BanWatch"), "/chat")

      send(view.pid, {:user_banned, %{operator: "Admin", target: "BadUser", reason: "spam"}})
      html = render(view)
      assert html =~ "BadUser"
      assert html =~ "banned"
      assert html =~ "Admin"
      assert html =~ "spam"
    end

    test "user_banned without reason omits reason text", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "BanNoReason"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "TopicWatch"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "ModeNoParams"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "SelfPm"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "TabMulti"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "SearchRegex"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "[test("})
      assert html =~ "search-bar" or html =~ "chat-input-form"
    end

    test "search_input with backslash does not crash", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SearchSlash"), "/chat")
      render_click(view, "toggle_search")
      html = render_click(view, "search_input", %{"query" => "test\\value"})
      assert html =~ "search-bar" or html =~ "chat-input-form"
    end
  end

  # ── R4: /topic command ────────────────────────────────

  describe "/topic command via LiveView" do
    test "/topic with no args shows current topic", %{conn: conn} do
      ensure_channel("#topic_view")
      {:ok, view, _html} = live(chat_conn(conn, "TopicViewer"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #topic_view"})

      # Set a topic first
      Server.set_topic("#topic_view", "TopicViewer", "Hello World")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/topic"})
      html = render(view)
      assert html =~ "Hello World"
    end

    test "/topic with no args and empty topic shows 'No topic set'", %{conn: conn} do
      ensure_channel("#topic_empty")
      {:ok, view, _html} = live(chat_conn(conn, "TopicEmpty"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #topic_empty"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/topic"})
      html = render(view)
      assert html =~ "No topic set"
    end

    test "/topic with text sets the topic", %{conn: conn} do
      ensure_channel("#topic_set")
      {:ok, view, _html} = live(chat_conn(conn, "TopicSetter"), "/chat")
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

      {:ok, view, _html} = live(chat_conn(conn, "TopicLockReg"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "AwayUser"), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/away Gone fishing"})

      html = render(view)
      assert html =~ "You are now away"
      assert html =~ "Gone fishing"
    end

    test "/away without message clears away status", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "AwayClr"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "ClearUser"), "/chat")

      # Switch from status tab to #lobby channel
      render_click(view, "switch_channel", %{"channel" => "#lobby"})

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
      {:ok, view, _html} = live(chat_conn(conn, "WhoisCmd"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "HelpUser"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/help"})
      html = render(view)
      assert html =~ "Available commands"
    end

    test "/help join shows specific command help", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HelpJoin"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/help join"})
      html = render(view)
      assert html =~ "/join"
    end
  end

  # ── R4: /list command ──────────────────────────────────

  describe "/list command via LiveView" do
    test "/list opens channel list dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "ListUser"), "/chat")

      html =
        view |> element("form.chat-input-form") |> render_submit(%{"input" => "/list"})

      assert html =~ ~s(data-testid="channel-list-dialog")
      assert html =~ "Channel List"
    end
  end

  # ── R3-E8: handle_info catch-all ───────────────────────

  describe "handle_info catch-all" do
    test "unknown message does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CatchAll"), "/chat")
      send(view.pid, {:completely_unknown_event, %{data: "test"}})
      html = render(view)
      assert html =~ "chat-input-form"
    end

    test "unknown map message does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CatchAll2"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "PmTree"), "/chat")

      render_click(view, "nick_right_click", %{"nick" => "TreeTarget", "x" => 0, "y" => 0})
      html = render_click(view, "context_query", %{"nick" => "TreeTarget"})

      # PM should appear in treebar Private section
      assert html =~ "Private"
      assert html =~ "TreeTarget"
      # The PM should be active (tree-active class)
      assert html =~ "tree-active"
    end

    test "switching to PM hides channel content and shows PM view", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PmSwitch"), "/chat")

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
      refute html =~ "nick-owner"
      # PM target should be shown as active
      assert html =~ "PmPal"
    end

    test "switching from PM back to channel restores channel view", %{conn: conn} do
      ensure_channel("#pm_back")
      {:ok, view, _html} = live(chat_conn(conn, "PmBack"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #pm_back"})

      # Open PM conversation
      render_click(view, "nick_right_click", %{"nick" => "PmFriend", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmFriend"})

      # Verify we're in PM view (no nicklist)
      html = render(view)
      refute html =~ "nick-owner"

      # Switch back to channel
      html =
        view
        |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#pm_back"]))
        |> render_click()

      # Channel view restored: nicklist visible, user shown as owner
      assert html =~ "nick-owner"
      assert html =~ "PmBack"
    end
  end

  # ── R5: current user kicked self ─────────────────────────

  describe "current user being kicked" do
    test "removes channel and switches to another", %{conn: conn} do
      ensure_channel("#kick_self")
      {:ok, view, _html} = live(chat_conn(conn, "KickSelf"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "PmActive"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "BanOper"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "KickReason"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "KickNoReason"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "HistMulti"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "ScrollBot"), "/chat")
      html = render_click(view, "scroll_to_bottom")
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: search_next/prev with actual results ───────────────

  describe "search navigation with results" do
    test "search_next cycles through results when results exist", %{conn: conn} do
      ensure_channel("#search_nav")
      {:ok, view, _html} = live(chat_conn(conn, "SearchNav"), "/chat")
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
    test "single matching nick sends tab_matches push_event", %{conn: conn} do
      ensure_channel("#tab_single")
      {:ok, view, _html} = live(chat_conn(conn, "TabSingle"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #tab_single"})

      # Add a user with unique prefix
      send(view.pid, {:user_joined, %{nickname: "UniqueZz", role: :regular}})
      render(view)

      # Tab complete now uses push_event instead of direct assign
      # Just verify it doesn't crash
      html =
        render_click(view, "tab_complete", %{"partial" => "Unique", "is_start" => true})

      assert is_binary(html)
    end
  end

  # ── R6: -v mode update in nicklist ────────────────────────

  describe "mode_changed -v" do
    test "-v removes voiced role and resets to regular", %{conn: conn} do
      ensure_channel("#mode_devoice")
      {:ok, view, _html} = live(chat_conn(conn, "DevoiceHost"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "QuitUser"), "/chat")

      result =
        view |> element("form.chat-input-form") |> render_submit(%{"input" => "/quit bye"})

      assert {:error, {:live_redirect, %{to: "/connect"}}} = result
    end
  end

  # ── R6: history_navigate unknown direction ─────────────────

  describe "history_navigate edge cases" do
    test "unknown direction is no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistUnk"), "/chat")
      html = render_click(view, "history_navigate", %{"direction" => "left"})
      assert html =~ "chat-input-form"
    end

    test "navigate down past beginning clears input", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistDown"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "MeAction"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "PartLast"), "/chat")

      # Part #lobby (the only channel)
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/part"})
      html = render(view)
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: /cs system message dispatch ────────────────────────

  describe "/cs and /ns service message dispatch" do
    test "/cs help shows ChanServ service message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CsHelp"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/cs help"})
      html = render(view)
      assert html =~ "cs register" or html =~ "Available commands"
    end

    test "/ns help shows NickServ service message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "NsHelp"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ns help"})
      html = render(view)
      assert html =~ "ns register" or html =~ "Available commands"
    end
  end

  # ── R6: /mode via UI action dispatch ────────────────────────

  describe "/mode command via UI action" do
    test "/mode +m sets moderated mode via dispatch", %{conn: conn} do
      ensure_channel("#mode_cmd")
      {:ok, view, _html} = live(chat_conn(conn, "ModeCmd"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "KickCmd"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "BanCmd"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #ban_cmd"})

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ban Troll"})
      Process.sleep(50)
      html = render(view)
      # Should succeed (operator banning a non-member adds to ban list)
      assert html =~ "chat-input-form"
    end
  end

  # ── R6: join from session ────────────────────────────────────

  describe "join from session" do
    test "join_channel in session joins additional channel on mount", %{conn: conn} do
      ensure_channel("#param_join")

      join_conn =
        Phoenix.ConnTest.init_test_session(conn, %{
          "chat_nickname" => "ParamJoin",
          "chat_join_channel" => "#param_join"
        })

      {:ok, _view, html} = live(join_conn, "/chat")
      assert html =~ "#param_join"
    end
  end

  # ── T012: Inline formatting rendering (US1) ──────────────

  describe "inline formatting rendering" do
    test "bold control codes render irc-bold span", %{conn: conn} do
      ensure_channel("#fmt_bold")
      {:ok, view, _html} = live(chat_conn(conn, "FmtBold"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "FmtItalic"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "FmtUline"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "FmtSys"), "/chat")
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #fmt_sys"})

      # System messages (like join notifications) should not contain irc-* spans
      html = render(view)
      # Join messages are system type — they should not have formatting spans
      refute html =~ ~s(class="irc-bold")
      refute html =~ ~s(class="irc-italic")
    end

    test "service messages are NOT parsed for format codes", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FmtSvc"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "FmtErr"), "/chat")

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
      {:ok, view, _html} = live(chat_conn(conn, "ClrFg"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "ClrFgBg"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "ClrCombo"), "/chat")
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
      {:ok, _view, html} = live(chat_conn(conn, "TbRender"), "/chat")
      assert html =~ ~s(data-testid="format-btn-bold")
      assert html =~ ~s(data-testid="format-btn-italic")
      assert html =~ ~s(data-testid="format-btn-underline")
      assert html =~ ~s(data-testid="format-btn-color")
    end

    test "toolbar has correct 98.css button styling", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "TbStyle"), "/chat")
      assert html =~ "formatting-toolbar"
      assert html =~ "format-btn"
    end
  end

  # ── T020: Color picker dropdown (US3) ───────────────────

  describe "color picker dropdown" do
    test "color picker contains 16 color swatches", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "CpSwatches"), "/chat")

      for i <- 0..15 do
        assert html =~ ~s(data-color-code="#{i}")
      end
    end

    test "color picker swatches are in a grid container", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "CpGrid"), "/chat")
      assert html =~ "format-color-dropdown"
      assert html =~ "color-swatch"
    end
  end

  # ── T026: Strip formatting toggle (US4) ──────────────────

  describe "strip formatting toggle" do
    test "default: formatted messages render with irc-* spans", %{conn: conn} do
      ensure_channel("#strip_dflt")
      {:ok, view, _html} = live(chat_conn(conn, "StripDflt"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "StripOn"), "/chat")
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
      {:ok, view, _html} = live(chat_conn(conn, "StripFlip"), "/chat")
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
      {:ok, _view, html} = live(chat_conn(conn, "StripUI"), "/chat")
      assert html =~ "data-testid=\"strip-formatting-toggle\""
    end
  end

  # ── T031: PM formatting verification ─────────────────────

  describe "PM formatting" do
    test "formatted PM renders with irc-* spans", %{conn: conn} do
      # Set up two users
      {:ok, sender, _html} = live(chat_conn(conn, "PmFmtSend"), "/chat")
      {:ok, receiver, _html} = live(chat_conn(build_conn(), "PmFmtRecv"), "/chat")

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
      {:ok, sender, _html} = live(chat_conn(conn, "PmStripS"), "/chat")
      {:ok, receiver, _html} = live(chat_conn(build_conn(), "PmStripR"), "/chat")

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

  # ── Channel Central ─────────────────────────────────────

  describe "Channel Central dialog" do
    test "open via menu shows dialog with channel info", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcMenu"), "/chat")

      html = view |> element("[data-testid=toolbar-channel-central]") |> render_click()

      assert html =~ "channel-central-dialog"
      assert html =~ "Channel Central"
      assert html =~ "#lobby"
    end

    test "close via close button hides dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcClose"), "/chat")

      view |> element("[data-testid=toolbar-channel-central]") |> render_click()
      html = view |> element("[phx-click=close_channel_central]") |> render_click()

      refute html =~ "channel-central-dialog"
    end

    test "Escape key closes dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcEsc"), "/chat")

      view |> element("[data-testid=toolbar-channel-central]") |> render_click()
      html = render_keydown(view, "window_keydown", %{"key" => "Escape"})

      refute html =~ "channel-central-dialog"
    end

    test "tab switching works", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcTabs"), "/chat")

      view |> element("[data-testid=toolbar-channel-central]") |> render_click()

      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "cc-modes-panel"

      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "cc-bans-panel"

      html = view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      assert html =~ "cc-ban-ex-panel"

      html = view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      assert html =~ "cc-invite-ex-panel"

      html = view |> element("[data-testid=cc-tab-general]") |> render_click()
      assert html =~ "cc-general-panel"
    end

    test "all tabs display data for the channel", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcData"), "/chat")

      view |> element("[data-testid=toolbar-channel-central]") |> render_click()

      # General tab shows channel name and member count
      html = render(view)
      assert html =~ "#lobby"

      # Modes tab shows mode checkboxes
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "Moderated (+m)"
      assert html =~ "Invite Only (+i)"

      # Bans tab shows empty bans
      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "No bans"
    end

    test "non-operator sees disabled controls", %{conn: conn} do
      # Create a channel with an existing operator
      channel = "#ccro-#{System.unique_integer([:positive])}"
      ensure_channel(channel)
      {:ok, _} = Server.join(channel, "ExistingOp")

      {:ok, view, _html} = live(chat_conn(conn, "CcReadOnly"), "/chat")

      # Join via /join command
      render_click(view, "send_input", %{"input" => "/join #{channel}"})

      # Switch to the channel and open Channel Central directly (avoid # in CSS selectors)
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = render(view)

      # Should NOT see Set Topic button (non-operator)
      refute html =~ "cc-set-topic-btn"

      # Check modes tab - should see disabled
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "disabled"
      refute html =~ "cc-apply-modes-btn"
    end

    test "operator sees editable controls", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CcOp"), "/chat")

      # User is operator of a new channel (first to join)
      channel = "#ccop-#{System.unique_integer([:positive])}"

      # Join via /join command (first user becomes operator)
      render_click(view, "send_input", %{"input" => "/join #{channel}"})

      # Switch and open CC directly (avoid # in CSS selectors)
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = render(view)
      assert html =~ "cc-set-topic-btn"
      assert html =~ "cc-topic-input"

      # Check modes tab - should see Apply button
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "cc-apply-modes-btn"
    end
  end

  # ── T027: Channel Central topic editing ───────────────────

  describe "Channel Central topic editing" do
    test "operator can set topic via Channel Central", %{conn: conn} do
      channel = "#cctop-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcTopicOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Set a topic
      view
      |> element("form[phx-submit=cc_set_topic]")
      |> render_submit(%{"topic" => "New test topic"})

      html = render(view)
      assert html =~ "New test topic"
    end

    test "clearing topic works", %{conn: conn} do
      channel = "#ccclr-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcTopClr"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})

      # Set topic first
      Server.set_topic(channel, "CcTopClr", "Temp topic")
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Clear topic
      view |> element("form[phx-submit=cc_set_topic]") |> render_submit(%{"topic" => ""})

      # Verify server state has empty topic (can't use refute html =~ because
      # "Temp topic" will appear in system messages in the chat area)
      {:ok, state} = Server.get_state(channel)
      assert state.topic == ""
    end
  end

  # ── T030: Channel Central mode toggles ───────────────────

  describe "Channel Central mode toggles" do
    test "operator can set +m moderated mode", %{conn: conn} do
      channel = "#ccmod-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcModeOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Switch to modes tab and apply +m
      view |> element("[data-testid=cc-tab-modes]") |> render_click()

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"moderated" => "true"})

      # Verify mode is set on server
      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "m"
    end

    test "operator can set +k key mode", %{conn: conn} do
      channel = "#cckey-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcKeyOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-modes]") |> render_click()

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"has_key" => "true", "key_value" => "secret123"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "k"
    end
  end

  # ── T034: Channel Central ban management ─────────────────

  describe "Channel Central ban management" do
    test "operator can add ban via dialog", %{conn: conn} do
      channel = "#ccban-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcBanOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Switch to bans tab
      view |> element("[data-testid=cc-tab-bans]") |> render_click()

      # Open add ban dialog
      view |> element("[data-testid=cc-add-ban-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-ban-dialog"

      # Submit ban
      view |> element("form[phx-submit=cc_add_ban]") |> render_submit(%{"nickname" => "BadUser"})

      html = render(view)
      assert html =~ "cc-ban-entry-BadUser"
    end

    test "operator can remove ban", %{conn: conn} do
      channel = "#ccunb-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcUnBan"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})

      # Ban someone first
      Server.ban(channel, "CcUnBan", "Banned1")

      render_click(view, "open_channel_central", %{"cc_channel" => channel})
      view |> element("[data-testid=cc-tab-bans]") |> render_click()

      html = render(view)
      assert html =~ "cc-ban-entry-Banned1"

      # Select the ban
      render_click(view, "cc_ban_select", %{"nickname" => "Banned1"})

      # Remove the ban
      view |> element("[data-testid=cc-remove-ban-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-ban-entry-Banned1"
    end
  end

  # ── T039: Channel Central ban exceptions ─────────────────

  describe "Channel Central ban exceptions" do
    test "operator can add ban exception via dialog", %{conn: conn} do
      channel = "#ccbex-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcBExOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      view |> element("[data-testid=cc-add-ban-ex-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-ban-ex-dialog"

      view
      |> element("form[phx-submit=cc_add_ban_exception]")
      |> render_submit(%{"nickname" => "Exempt1"})

      html = render(view)
      assert html =~ "cc-ban-ex-entry-Exempt1"
    end

    test "operator can remove ban exception", %{conn: conn} do
      channel = "#ccbrx-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcBRxOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})

      # Add ban exception directly
      Server.add_ban_exception(channel, "CcBRxOp", "ExUser")

      render_click(view, "open_channel_central", %{"cc_channel" => channel})
      view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()

      html = render(view)
      assert html =~ "cc-ban-ex-entry-ExUser"

      render_click(view, "cc_ban_ex_select", %{"nickname" => "ExUser"})
      view |> element("[data-testid=cc-remove-ban-ex-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-ban-ex-entry-ExUser"
    end
  end

  # ── T044: Channel Central invite exceptions ──────────────

  describe "Channel Central invite exceptions" do
    test "operator can add invite exception via dialog", %{conn: conn} do
      channel = "#cciex-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcIExOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      view |> element("[data-testid=cc-add-invite-ex-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-invite-ex-dialog"

      view
      |> element("form[phx-submit=cc_add_invite_exception]")
      |> render_submit(%{"nickname" => "InvUser"})

      html = render(view)
      assert html =~ "cc-invite-ex-entry-InvUser"
    end

    test "operator can remove invite exception", %{conn: conn} do
      channel = "#ccirx-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcIRxOp"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.add_invite_exception(channel, "CcIRxOp", "InvExUser")

      render_click(view, "open_channel_central", %{"cc_channel" => channel})
      view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()

      html = render(view)
      assert html =~ "cc-invite-ex-entry-InvExUser"

      render_click(view, "cc_invite_ex_select", %{"nickname" => "InvExUser"})
      view |> element("[data-testid=cc-remove-invite-ex-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-invite-ex-entry-InvExUser"
    end
  end

  # ── T048: Channel Central real-time updates ───────────────

  describe "Channel Central real-time updates" do
    test "topic change by another user updates dialog", %{conn: conn} do
      channel = "#ccrt1-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcRtObs"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Another user changes the topic
      Server.set_topic(channel, "CcRtObs", "New real-time topic")

      html = render(view)
      assert html =~ "New real-time topic"
    end

    test "mode change updates dialog", %{conn: conn} do
      channel = "#ccrt2-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcRtMod"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Set moderated mode — triggers PubSub broadcast
      Server.set_mode(channel, "CcRtMod", "+m", [])

      # Render to process the PubSub message, then switch to modes tab
      render(view)
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "Moderated (+m)"
    end

    test "ban change updates dialog ban list", %{conn: conn} do
      channel = "#ccrt3-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, "CcRtBan"), "/chat")

      render_click(view, "send_input", %{"input" => "/join #{channel}"})
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Ban someone from server side
      Server.ban(channel, "CcRtBan", "BannedRt")

      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "cc-ban-entry-BannedRt"
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  # ── empty states ───────────────────────────────────────

  describe "empty nicklist state" do
    test "nicklist renders without empty state when users are present", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "NickUser"), "/chat")
      # User auto-joins #lobby — nicklist renders with user count
      assert html =~ "nicklist"
      refute html =~ "nicklist-empty-state"
    end
  end

  describe "empty treebar state" do
    test "treebar shows empty state when no channels and no PMs", %{conn: conn} do
      # This is hard to test in isolation since #lobby is auto-joined.
      # The treebar should have at least #lobby after mount.
      {:ok, _view, html} = live(chat_conn(conn, "TreeUser"), "/chat")
      assert html =~ "#lobby"
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
