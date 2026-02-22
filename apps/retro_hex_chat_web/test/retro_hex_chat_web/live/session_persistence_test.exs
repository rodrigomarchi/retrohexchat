defmodule RetroHexChatWeb.SessionPersistenceTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.Queries
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

  # ── US1: PM Conversation Restore on Connect ────────────────

  describe "US1: PM conversation restore on connect" do
    test "registered user sees PM partners in treebar on connect", %{conn: conn} do
      nick = "PR#{uid()}"
      register_and_identify(nick)

      insert_pm(nick, "Alice", "Hi Alice")
      insert_pm("Bob", nick, "Hey there")
      insert_pm(nick, "Charlie", "Hello Charlie")

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Charlie"
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

  # ── US2: Incoming PM Auto-Opens Conversation ───────────────

  describe "US2: incoming PM auto-opens conversation" do
    test "new contact appears in treebar on incoming PM", %{conn: conn} do
      nick = "AO#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Receiver gets {:incoming_pm_notify} on user:nick (the actual path for new contacts)
      send(view.pid, {:incoming_pm_notify, %{sender: "NewPerson"}})
      html = render(view)

      assert html =~ "NewPerson"
      assert html =~ ~s(data-testid="pm-NewPerson")
    end

    test "existing contact moves to top on incoming PM", %{conn: conn} do
      nick = "MT#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open two PM conversations via /query
      view |> render_submit("send_input", %{"input" => "/query Alice"})
      view |> render_submit("send_input", %{"input" => "/query Bob"})

      # Alice should be before Bob (Alice added first, then Bob prepended)
      # Actually with prepend: Bob is at head, Alice is second
      # Now simulate PM from Alice — she should move to top
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: uid(),
          sender: "Alice",
          recipient: nick,
          content: "Hello!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)

      alice_pos = :binary.match(html, ~s(data-testid="pm-Alice")) |> elem(0)
      bob_pos = :binary.match(html, ~s(data-testid="pm-Bob")) |> elem(0)
      assert alice_pos < bob_pos
    end

    test "ignored user does NOT auto-open conversation", %{conn: conn} do
      nick = "IG#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore the user
      view |> render_submit("send_input", %{"input" => "/ignore IgnoredUser"})

      # Simulate PM from ignored user
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: uid(),
          sender: "IgnoredUser",
          recipient: nick,
          content: "You can't see me",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)

      refute html =~ ~s(data-testid="pm-IgnoredUser")
    end
  end

  # ── US3: {:incoming_pm_notify} auto-opens PM in treebar ───

  describe "US3: incoming_pm_notify auto-opens PM" do
    test "{:incoming_pm_notify} from new contact auto-opens PM in treebar", %{conn: conn} do
      nick = "IN#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Receiver gets {:incoming_pm_notify} on user:nick (NOT new_pm on pm:sorted)
      send(view.pid, {:incoming_pm_notify, %{sender: "Dave"}})
      html = render(view)

      assert html =~ ~s(data-testid="pm-Dave")
    end

    test "{:incoming_pm_notify} from ignored user does NOT auto-open", %{conn: conn} do
      nick = "IX#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore the user first
      view |> render_submit("send_input", %{"input" => "/ignore BadGuy"})

      send(view.pid, {:incoming_pm_notify, %{sender: "BadGuy"}})
      html = render(view)

      refute html =~ ~s(data-testid="pm-BadGuy")
    end

    test "{:incoming_pm_notify} from existing contact does NOT duplicate", %{conn: conn} do
      nick = "ND#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open conversation first
      view |> render_submit("send_input", %{"input" => "/query Dave"})

      # Now get a notify — should NOT create a second entry
      send(view.pid, {:incoming_pm_notify, %{sender: "Dave"}})
      html = render(view)

      # Count occurrences of pm-Dave — should be exactly 1
      matches = Regex.scan(~r/data-testid="pm-Dave"/, html)
      assert length(matches) == 1
    end
  end

  # ── US4: PM Conversation Ordering by Recency ───────────────

  describe "US4: PM recency ordering" do
    test "incoming PM reorders conversations by recency", %{conn: conn} do
      nick = "RO#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open three PM conversations
      view |> render_submit("send_input", %{"input" => "/query Charlie"})
      view |> render_submit("send_input", %{"input" => "/query Bob"})
      view |> render_submit("send_input", %{"input" => "/query Alice"})

      # Current order: Alice, Bob, Charlie (most recently added first)
      # Now Charlie sends a PM — should move to top
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: uid(),
          sender: "Charlie",
          recipient: nick,
          content: "I'm back!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)

      charlie_pos = :binary.match(html, ~s(data-testid="pm-Charlie")) |> elem(0)
      alice_pos = :binary.match(html, ~s(data-testid="pm-Alice")) |> elem(0)
      assert charlie_pos < alice_pos
    end
  end

  # ── Bug fixes: PM close unsubscribe + PM edit context ───

  describe "close_pm_tab unsubscribes from PM topic" do
    test "closing PM tab stops receiving new_pm events for that conversation", %{conn: conn} do
      nick = "CU#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open PM with Eve
      view |> render_submit("send_input", %{"input" => "/query Eve"})
      assert render(view) =~ ~s(data-testid="pm-Eve")

      # Close PM tab
      view |> render_click("close_pm_tab", %{"nickname" => "Eve"})
      refute render(view) =~ ~s(data-testid="pm-Eve")

      # Send a new_pm directly — if unsubscribed, apply_new_pm won't fire for stale sub
      # But incoming_pm_notify on user:nick should still auto-open
      # The key behavior: no phantom unread for a non-visible tab
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: uid(),
          sender: "Eve",
          recipient: nick,
          content: "Are you there?",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
      html = render(view)

      # After unsubscribe, stale new_pm should NOT create phantom unread for closed tab
      # Eve should NOT appear in treebar (no auto-open from new_pm path)
      refute html =~ ~s(data-testid="pm-Eve")
    end
  end

  describe "PM edit/delete context detection" do
    test "PM edit while viewing channel does NOT corrupt channel stream", %{conn: conn} do
      nick = "PE#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open PM with Frank, then switch back to channel
      view |> render_submit("send_input", %{"input" => "/query Frank"})
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
