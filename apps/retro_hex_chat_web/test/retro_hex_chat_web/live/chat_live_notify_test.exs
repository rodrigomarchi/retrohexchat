defmodule RetroHexChatWeb.ChatLiveNotifyTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Services.Queries, as: SvcQueries

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── US1: Notify list CRUD ──────────────────────────────────────

  describe "US1: Notify list CRUD" do
    test "add buddy via event", %{conn: conn} do
      nick = "AddBuddy#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => "BuddyFriend", "note" => "my pal"})

      # Open the notify list window to see the entry
      html = render_click(view, "toggle_notify_list")
      assert html =~ "BuddyFriend"
      assert html =~ "my pal"
    end

    test "remove buddy via event", %{conn: conn} do
      nick = "RmBuddy#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add first, then remove
      render_click(view, "notify_add", %{"nickname" => "ToRemove", "note" => ""})
      render_click(view, "toggle_notify_list")
      html = render(view)
      # Verify the entry row exists in the notify list window
      assert html =~ "notify-entry-ToRemove"

      render_click(view, "notify_remove", %{"nickname" => "ToRemove"})
      html = render(view)
      # After removal, the entry row should be gone from the notify list window
      refute html =~ "notify-entry-ToRemove"
    end

    test "edit note via event", %{conn: conn} do
      nick = "EditNote#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => "NoteTarget", "note" => "old note"})
      render_click(view, "toggle_notify_list")
      html = render(view)
      assert html =~ "old note"

      render_click(view, "notify_edit", %{"nickname" => "NoteTarget", "note" => "new note"})
      html = render(view)
      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "reject self-add", %{conn: conn} do
      nick = "SelfAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => nick, "note" => ""})

      # Open window — self should not appear as a tracked entry
      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-list-window"
      refute html =~ "notify-entry-#{nick}"
    end

    test "reject duplicate add", %{conn: conn} do
      nick = "DupAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => "DupTarget", "note" => "first"})
      render_click(view, "notify_add", %{"nickname" => "DupTarget", "note" => "second"})

      # Open window — should have only one entry with the original note
      html = render_click(view, "toggle_notify_list")
      assert html =~ "DupTarget"
      assert html =~ "first"
      refute html =~ "second"
    end
  end

  # ── US1: NickServ identify loads notify list ───────────────────

  describe "US1: NickServ identify loads notify list" do
    test "loading saved notify list on identify", %{conn: conn} do
      nick = "Identify#{System.unique_integer([:positive])}"

      # Register nick with NickServ so we can save a notify list
      {:ok, _} = SvcQueries.insert_registered_nick(nick, "password123")

      on_exit(fn ->
        # Delete entries/settings before the registered nick (FK cascade)
        NotifyList.delete_entry(nick, "SavedBuddy")

        case SvcQueries.find_by_nickname(nick) do
          nil -> :ok
          reg -> SvcQueries.delete_registered_nick(reg)
        end
      end)

      # Pre-save a notify list to DB
      notify_list = NotifyList.new()
      {:ok, notify_list} = NotifyList.add_entry(notify_list, nick, "SavedBuddy", "from DB")
      :ok = NotifyList.save(nick, notify_list)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Simulate NickServ identify broadcast
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "user:#{nick}",
        {:nickserv_identified, %{nickname: nick}}
      )

      Process.sleep(100)

      # Open notify list window to verify entries loaded
      html = render_click(view, "toggle_notify_list")
      assert html =~ "SavedBuddy"
      assert html =~ "from DB"
    end
  end

  # ── US2: Presence notifications ────────────────────────────────

  describe "US2: Presence notifications" do
    test "tracked buddy connect triggers debounce timer", %{conn: conn} do
      nick = "PresConn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add a buddy to track
      render_click(view, "notify_add", %{"nickname" => "OnBuddy", "note" => ""})

      # Simulate buddy connecting
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_connected, %{nickname: "OnBuddy"}}
      )

      Process.sleep(50)

      # Manually fire the debounce timer message for testing
      send(view.pid, {:notify_debounce, "OnBuddy", :online})

      Process.sleep(50)
      html = render(view)
      assert html =~ "OnBuddy"
      assert html =~ "online"
    end

    test "tracked buddy disconnect triggers debounce timer", %{conn: conn} do
      nick = "PresDis#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add a buddy to track
      render_click(view, "notify_add", %{"nickname" => "OffBuddy", "note" => ""})

      # Simulate buddy disconnecting
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: "OffBuddy"}}
      )

      Process.sleep(50)

      # Manually fire the debounce timer message for testing
      send(view.pid, {:notify_debounce, "OffBuddy", :offline})

      Process.sleep(50)
      html = render(view)
      assert html =~ "OffBuddy"
      assert html =~ "offline"
    end

    test "non-tracked user events are ignored", %{conn: conn} do
      nick = "PresIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Do NOT add "Stranger" to the notify list

      # Simulate stranger connecting
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_connected, %{nickname: "Stranger"}}
      )

      Process.sleep(50)
      html = render(view)
      # No status notification should appear for Stranger
      refute html =~ "Stranger" and html =~ "is now online"
    end
  end

  # ── US2: Rename tracking ───────────────────────────────────────

  describe "US2: Rename tracking" do
    test "nick_changed updates notify list entry", %{conn: conn} do
      nick = "RenTrack#{System.unique_integer([:positive])}"
      ch = "#ren_track_#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Join isolated channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      # Add buddy
      render_click(view, "notify_add", %{"nickname" => "OldNick", "note" => "buddy"})

      # Simulate nick_changed broadcast on the channel
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "channel:#{ch}",
        {:nick_changed, %{old_nick: "OldNick", new_nick: "NewNick"}}
      )

      Process.sleep(50)

      # Open notify list to verify the entry was updated
      html = render_click(view, "toggle_notify_list")
      assert html =~ "NewNick"
      assert html =~ "buddy"
      # Check that old nick is gone from the notify list entries (not the chat messages)
      assert html =~ "notify-entry-NewNick"
      refute html =~ "notify-entry-OldNick"
    end
  end

  # ── US3: Notify list window ────────────────────────────────────

  describe "US3: Notify list window" do
    test "toggle_notify_list shows/hides window", %{conn: conn} do
      nick = "TogWin#{System.unique_integer([:positive])}"
      {:ok, view, html} = live(conn, "/chat?nickname=#{nick}")

      refute html =~ "notify-list-window"

      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-list-window"

      html = render_click(view, "toggle_notify_list")
      refute html =~ "notify-list-window"
    end

    test "notify_select highlights entry", %{conn: conn} do
      nick = "SelEntry#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => "SelectMe", "note" => ""})
      render_click(view, "toggle_notify_list")

      html = render_click(view, "notify_select", %{"nickname" => "SelectMe"})
      assert html =~ "SelectMe"
      # The selected entry row has highlighted styling (navy background)
      assert html =~ "#000080"
    end
  end

  # ── US5: /notify commands ──────────────────────────────────────

  describe "US5: /notify commands" do
    test "/notify opens window", %{conn: conn} do
      nick = "NotCmd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/notify"})

      Process.sleep(50)
      html = render(view)
      assert html =~ "notify-list-window"
    end

    test "/notify add creates entry", %{conn: conn} do
      nick = "NotAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add CmdBuddy some note"})

      Process.sleep(50)

      # Open notify list to see the entry
      html = render_click(view, "toggle_notify_list")
      assert html =~ "CmdBuddy"
    end

    test "/notify remove removes entry", %{conn: conn} do
      nick = "NotRm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add first
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add RmCmdBud"})

      Process.sleep(50)

      # Now remove
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify remove RmCmdBud"})

      Process.sleep(50)

      html = render_click(view, "toggle_notify_list")
      refute html =~ "notify-entry-RmCmdBud"
    end

    test "/notify list displays entries", %{conn: conn} do
      nick = "NotList#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add a couple of entries via command
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add ListBud1"})

      Process.sleep(50)

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add ListBud2"})

      Process.sleep(50)

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify list"})

      Process.sleep(50)
      html = render(view)

      # The /notify list command displays entries in the status window
      assert html =~ "ListBud1"
      assert html =~ "ListBud2"
    end
  end

  # ── US4: Auto-whois ───────────────────────────────────────────

  describe "US4: Auto-whois" do
    test "auto-whois toggle updates setting", %{conn: conn} do
      nick = "AutoWh#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Open notify list to see toggle
      render_click(view, "toggle_notify_list")

      # Toggle auto-whois on
      html = render_click(view, "toggle_auto_whois")
      assert html =~ "notify-auto-whois"
    end

    test "auto-whois on connect shows whois info", %{conn: conn} do
      nick = "AWConn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy and enable auto-whois
      render_click(view, "notify_add", %{"nickname" => "WBuddy", "note" => ""})
      render_click(view, "toggle_auto_whois")

      # Fire debounce for online
      send(view.pid, {:notify_debounce, "WBuddy", :online})

      Process.sleep(50)
      html = render(view)
      assert html =~ "[Auto-Whois] WBuddy"
      assert html =~ "Registered:"
    end

    test "auto-whois disabled does not show whois", %{conn: conn} do
      nick = "AWOff#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy but do NOT enable auto-whois
      render_click(view, "notify_add", %{"nickname" => "NWBuddy", "note" => ""})

      # Fire debounce for online
      send(view.pid, {:notify_debounce, "NWBuddy", :online})

      Process.sleep(50)
      html = render(view)
      # Should show online notification but NOT whois
      assert html =~ "online"
      refute html =~ "[Auto-Whois]"
    end

    test "auto-whois not triggered on disconnect", %{conn: conn} do
      nick = "AWDis#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy and enable auto-whois
      render_click(view, "notify_add", %{"nickname" => "DBuddy", "note" => ""})
      render_click(view, "toggle_auto_whois")

      # Fire debounce for offline
      send(view.pid, {:notify_debounce, "DBuddy", :offline})

      Process.sleep(50)
      html = render(view)
      assert html =~ "offline"
      refute html =~ "[Auto-Whois]"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
