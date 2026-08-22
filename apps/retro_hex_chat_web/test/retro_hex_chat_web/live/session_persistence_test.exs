defmodule RetroHexChatWeb.SessionPersistenceTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.{Queries, ReconnectState}
  alias RetroHexChat.Services.NickServ

  defp register_and_identify(nick) do
    NickServ.register(nick, "pass123")
    {:ok, _} = NickServ.identify(nick, "pass123")
  end

  defp insert_pm(sender, recipient, content) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: sender,
        recipient_nickname: recipient,
        content: content
      })

    pm
  end

  defp pm_sidebar_selector(nick), do: ~s([data-testid="pm-#{nick}"])

  defp pm_tab_selector(nick) do
    ~s([role="tab"][phx-value-type="pm"][phx-value-label="#{nick}"])
  end

  defp pm_activity(peer, direction \\ :incoming, type \\ :message) do
    %{
      event: "new_pm",
      payload: %{
        id: uid(),
        sender: peer,
        recipient: "irrelevant",
        content: "hello",
        type: type,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: direction
      }
    }
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  # ── US1: PM Conversation Restore on Connect ────────────────

  describe "US1: PM conversation restore on connect" do
    test "registered user sees PM partners in the sidebar, not as tabs, on connect", %{
      conn: conn
    } do
      nick = "PR#{uid()}"
      register_and_identify(nick)

      insert_pm(nick, "Alice", "Hi Alice")
      insert_pm("Bob", nick, "Hey there")
      insert_pm(nick, "Charlie", "Hello Charlie")

      {:ok, view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert html =~ ~s(data-testid="pm-Alice")
      assert html =~ ~s(data-testid="pm-Bob")
      assert html =~ ~s(data-testid="pm-Charlie")

      refute has_element?(view, pm_tab_selector("Alice"))
      refute has_element?(view, pm_tab_selector("Bob"))
      refute has_element?(view, pm_tab_selector("Charlie"))
    end

    test "PM partners are ordered by most recent message first", %{conn: conn} do
      nick = "PO#{uid()}"
      register_and_identify(nick)

      insert_pm(nick, "Zara", "oldest")
      insert_pm(nick, "Yuki", "middle")
      insert_pm(nick, "Xena", "newest")

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # All partners should be present
      assert html =~ "Xena"
      assert html =~ "Yuki"
      assert html =~ "Zara"

      # Verify order: Xena (newest) should appear before Zara (oldest) in the HTML
      xena_pos = :binary.match(html, "Xena") |> elem(0)
      zara_pos = :binary.match(html, "Zara") |> elem(0)
      assert xena_pos < zara_pos
    end

    test "guest user sees no PM conversations restored", %{conn: conn} do
      nick = "Guest_#{uid()}"

      # Create PM history for a nick that won't be identified
      insert_pm(nick, "Someone", "Hi")

      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      # Guest should not see PM partners restored (no load_persisted_data)
      refute html =~ ~s(data-testid="pm-Someone")
    end

    test "self-PMs are excluded from restored conversations", %{conn: conn} do
      nick = "SP#{uid()}"
      register_and_identify(nick)

      insert_pm(nick, nick, "Note to self")
      insert_pm(nick, "Other", "Hi")

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert html =~ "Other"
      refute html =~ ~s(data-testid="pm-#{nick}")
    end

    test "empty PM history does not cause errors", %{conn: conn} do
      nick = "EP#{uid()}"
      register_and_identify(nick)

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Should mount without errors
      assert html =~ nick
    end
  end

  # ── US2: Incoming PM records sidebar activity and opens a background tab ───

  describe "US2: incoming PM records sidebar activity without taking the screen" do
    test "new contact appears in conversations with unread and no tab on PM activity", %{
      conn: conn
    } do
      nick = "AO#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, pm_activity("NewPerson"))

      assert has_element?(view, pm_sidebar_selector("NewPerson"))
      assert has_element?(view, ~s([data-testid="pm-unread-badge-NewPerson"]))
      # It never took the screen, so it never took the bar.
      refute has_element?(view, pm_tab_selector("NewPerson"))
    end

    test "incoming P2P invite lands in the sidebar without taking the screen", %{conn: conn} do
      nick = "PI#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, pm_activity("Caller", :incoming, :p2p_invite))

      assert has_element?(view, pm_sidebar_selector("Caller"))
      assert has_element?(view, ~s([data-testid="pm-unread-badge-Caller"]))
      refute has_element?(view, pm_tab_selector("Caller"))
    end

    test "clicking a sidebar PM opens a tab and clears unread", %{conn: conn} do
      nick = "OC#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, pm_activity("NewPerson"))

      view
      |> element(pm_sidebar_selector("NewPerson"))
      |> render_click()

      assert has_element?(view, pm_sidebar_selector("NewPerson"))
      assert has_element?(view, pm_tab_selector("NewPerson"))
      refute has_element?(view, ~s([data-testid="pm-unread-badge-NewPerson"]))
    end

    test "existing contact moves to top on incoming PM activity", %{conn: conn} do
      nick = "MT#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open two PM conversations via /query
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Alice"})

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Bob"})

      # Alice should be before Bob (Alice added first, then Bob prepended)
      # Actually with prepend: Bob is at head, Alice is second
      # Now simulate activity from Alice — she should move to top in the sidebar.
      send(view.pid, pm_activity("Alice"))
      html = render(view)

      alice_pos = :binary.match(html, ~s(data-testid="pm-Alice")) |> elem(0)
      bob_pos = :binary.match(html, ~s(data-testid="pm-Bob")) |> elem(0)
      assert alice_pos < bob_pos
    end

    test "ignored user does NOT appear in conversations", %{conn: conn} do
      nick = "IG#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore the user
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/ignore IgnoredUser"})

      send(view.pid, pm_activity("IgnoredUser"))

      refute has_element?(view, pm_sidebar_selector("IgnoredUser"))
      refute has_element?(view, pm_tab_selector("IgnoredUser"))
    end
  end

  # ── US3: pm_activity is the lightweight user-topic PM signal ───

  describe "US3: pm_activity updates PM conversations" do
    test "{:pm_activity, ...} from new contact creates a sidebar entry, not a tab", %{conn: conn} do
      nick = "IN#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, pm_activity("Dave"))

      assert has_element?(view, pm_sidebar_selector("Dave"))
      refute has_element?(view, pm_tab_selector("Dave"))
    end

    test "{:pm_activity, ...} from ignored user does NOT create sidebar entry", %{conn: conn} do
      nick = "IX#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore the user first
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/ignore BadGuy"})

      send(view.pid, pm_activity("BadGuy"))

      refute has_element?(view, pm_sidebar_selector("BadGuy"))
      refute has_element?(view, pm_tab_selector("BadGuy"))
    end

    test "{:pm_activity, ...} from existing contact does NOT duplicate", %{conn: conn} do
      nick = "ND#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open conversation first
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Dave"})

      send(view.pid, pm_activity("Dave"))
      html = render(view)

      # Count occurrences of pm-Dave — should be exactly 1
      matches = Regex.scan(~r/data-testid="pm-Dave"/, html)
      assert length(matches) == 1
    end
  end

  # ── US4: PM Conversation Ordering by Recency ───────────────

  describe "US4: PM recency ordering" do
    test "incoming PM activity reorders conversations by recency", %{conn: conn} do
      nick = "RO#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open three PM conversations
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Charlie"})

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Bob"})

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Alice"})

      # Current order: Alice, Bob, Charlie (most recently added first).
      # Now Charlie has PM activity — should move to top.
      send(view.pid, pm_activity("Charlie"))
      html = render(view)

      charlie_pos = :binary.match(html, ~s(data-testid="pm-Charlie")) |> elem(0)
      alice_pos = :binary.match(html, ~s(data-testid="pm-Alice")) |> elem(0)
      assert charlie_pos < alice_pos
    end
  end

  # ── Bug fixes: PM close unsubscribe + PM edit context ───

  describe "close_pm_tab closes the buffer but keeps the sidebar conversation" do
    test "closing PM tab keeps sidebar entry and removes only the tab", %{conn: conn} do
      nick = "CU#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open PM with Eve
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Eve"})

      assert has_element?(view, pm_sidebar_selector("Eve"))
      assert has_element?(view, pm_tab_selector("Eve"))

      # Close PM tab
      view |> render_click("close_pm_tab", %{"nickname" => "Eve"})
      assert has_element?(view, pm_sidebar_selector("Eve"))
      refute has_element?(view, pm_tab_selector("Eve"))

      send(view.pid, pm_activity("Eve"))

      assert has_element?(view, pm_sidebar_selector("Eve"))
      assert has_element?(view, ~s([data-testid="pm-unread-badge-Eve"]))
      # Reopened in the sidebar only — it does not steal the bar back.
      refute has_element?(view, pm_tab_selector("Eve"))
    end
  end

  describe "PM reconnect state" do
    test "identified users persist reconnect state in the backend", %{conn: conn} do
      nick = "RP#{uid()}"
      register_and_identify(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Bob"})

      assert_push_event(view, "save_reconnect_state", %{
        nickname: ^nick,
        active_pm: "Bob",
        open_pm_tabs: ["Bob"]
      })

      assert {:ok, snapshot} = ReconnectState.load(nick)
      assert snapshot.open_pm_tabs == ["Bob"]
      assert snapshot.active_pm == "Bob"
      assert "#lobby" in snapshot.channels
    end

    test "mount restores persisted reconnect state without a client storage hook", %{conn: conn} do
      nick = "RM#{uid()}"
      register_and_identify(nick)

      assert :ok =
               ReconnectState.save(nick, %{
                 channels: ["#lobby", "#restore"],
                 active_channel: "#restore",
                 welcomed_channels: ["#restore"]
               })

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert assigns(view).reconnect_active_channel == "#restore"

      send(view.pid, {:execute_rejoin, 1, ["#lobby", "#restore"]})
      render(view)

      assert "#restore" in assigns(view).session.channels

      send(view.pid, {:execute_rejoin, 2, ["#lobby", "#restore"]})
      render(view)

      assert assigns(view).session.active_channel == "#restore"
    end

    test "intentional quit deletes the persisted reconnect state", %{conn: conn} do
      nick = "RQ#{uid()}"
      register_and_identify(nick)
      assert :ok = ReconnectState.save(nick, %{channels: ["#lobby"], active_channel: "#lobby"})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/quit"})

      assert_push_event(view, "intentional_disconnect", %{})
      assert {:error, :not_found} = ReconnectState.load(nick)
    end

    test "opening a PM tab saves open_pm_tabs in reconnect state", %{conn: conn} do
      nick = "RS#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Bob"})

      assert_push_event(view, "save_reconnect_state", %{
        nickname: ^nick,
        active_pm: "Bob",
        open_pm_tabs: ["Bob"]
      })
    end

    test "restore_session restores only PMs listed in open_pm_tabs", %{conn: conn} do
      nick = "RT#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "restore_session", %{
        "nickname" => nick,
        "channels" => ["#lobby"],
        "active_channel" => nil,
        "active_pm" => "Bob",
        "open_pm_tabs" => ["Bob"]
      })

      send(view.pid, {:execute_rejoin, 1, ["#lobby"]})
      render(view)

      assert assigns(view).session.active_pm == "Bob"
      assert has_element?(view, pm_tab_selector("Bob"))
      assert has_element?(view, pm_sidebar_selector("Bob"))
    end

    test "restore_session with legacy active_pm but no open_pm_tabs does not open a PM tab", %{
      conn: conn
    } do
      nick = "RL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "restore_session", %{
        "nickname" => nick,
        "channels" => ["#lobby"],
        "active_channel" => nil,
        "active_pm" => "Bob"
      })

      send(view.pid, {:execute_rejoin, 1, ["#lobby"]})
      render(view)

      refute assigns(view).session.active_pm == "Bob"
      refute has_element?(view, pm_tab_selector("Bob"))
      refute has_element?(view, pm_sidebar_selector("Bob"))
    end
  end

  describe "PM nickname rename state" do
    test "nick_changed renames sidebar PMs, open tabs and active PM", %{conn: conn} do
      nick = "RN#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Bob"})

      assert has_element?(view, pm_sidebar_selector("Bob"))
      assert has_element?(view, pm_tab_selector("Bob"))

      send(view.pid, {:nick_changed, %{old_nick: "Bob", new_nick: "Robert"}})
      render(view)

      assert assigns(view).session.active_pm == "Robert"
      assert has_element?(view, pm_sidebar_selector("Robert"))
      assert has_element?(view, pm_tab_selector("Robert"))
      refute has_element?(view, pm_sidebar_selector("Bob"))
      refute has_element?(view, pm_tab_selector("Bob"))
    end
  end

  describe "PM edit/delete context detection" do
    test "PM edit while viewing channel does NOT corrupt channel stream", %{conn: conn} do
      nick = "PE#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open PM with Frank, then switch back to channel
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/query Frank"})

      view |> render_click("switch_channel", %{"channel" => "#lobby"})

      # Simulate PM edit event arriving (from pm:frank:nick topic)
      edit_payload = %{
        event: "message_edited",
        payload: %{id: 1, content: "edited PM content", edited_at: DateTime.utc_now()}
      }

      send(view.pid, edit_payload)
      html = render(view)

      # The edited PM content should NOT appear in the channel stream
      refute html =~ "edited PM content"
    end
  end
end
