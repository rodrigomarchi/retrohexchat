defmodule RetroHexChatWeb.SessionPersistenceTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Services.NickServ

  defp uid, do: System.unique_integer([:positive])

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

      insert_pm(nick, "First", "oldest")
      insert_pm(nick, "Second", "middle")
      insert_pm(nick, "Third", "newest")

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # All partners should be present
      assert html =~ "Third"
      assert html =~ "Second"
      assert html =~ "First"

      # Verify order: Third should appear before First in the HTML
      third_pos = :binary.match(html, "Third") |> elem(0)
      first_pos = :binary.match(html, "First") |> elem(0)
      assert third_pos < first_pos
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

      # Simulate incoming PM from new contact
      pm_payload = %{
        event: "new_pm",
        payload: %{
          id: System.unique_integer([:positive]),
          sender: "NewPerson",
          recipient: nick,
          content: "Hey there!",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, pm_payload)
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
          id: System.unique_integer([:positive]),
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
          id: System.unique_integer([:positive]),
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
          id: System.unique_integer([:positive]),
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
end
