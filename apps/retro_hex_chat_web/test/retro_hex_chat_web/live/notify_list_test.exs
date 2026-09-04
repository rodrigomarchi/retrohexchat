defmodule RetroHexChatWeb.NotifyListTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Presence.{NotifyEntry, NotifyList}
  alias RetroHexChat.Services.NickServ

  setup do
    case RetroHexChat.Channels.Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> ChannelSupervisor.start_child("#lobby")
    end

    :ok
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  # The Notify List is a stateful island; its events target the component, so
  # fire them element-based (the design-system threads phx-target through).
  #
  # These cases moved here with the Address Book's Notify tab, which the
  # standalone window absorbed.
  defp ab_click(view, event) do
    view |> element("#notify-list-dialog-mount [phx-click='#{event}']") |> render_click()
  end

  defp ab_select(view, event, nick) do
    view
    |> element("#notify-list-dialog-mount [phx-click='#{event}'][phx-value-nickname='#{nick}']")
    |> render_click()
  end

  defp ab_form(view, testid, params) do
    view |> element("[data-testid='#{testid}']") |> render_submit(params)
  end

  # ── Phase 3: US1 — Dialog Shell ──────────────────────────

  describe "notify tab" do
    test "empty notify list shows empty message", %{conn: conn} do
      view = connect_user(conn, "EmptyNotify")
      view |> render_click("toggle_notify_list")
      html = render(view)

      assert html =~ "No notify nicks yet. Add a nick to track online status."
    end

    test "add notify entry appears in list", %{conn: conn} do
      view = connect_user(conn, "AddNotify")
      view |> render_click("toggle_notify_list")

      # Open add dialog
      view |> ab_click("notify_add_dialog")
      assert render(view) =~ "Add Notify Entry"

      # Submit
      view |> ab_form("notify-add-form", %{"nickname" => "BuddyA", "note" => "my buddy"})
      html = render(view)

      assert html =~ "BuddyA"
      assert html =~ "my buddy"
      refute html =~ "Add Notify Entry</div>"
    end

    test "remove notify entry from list", %{conn: conn} do
      view = connect_user(conn, "RemoveNotify")
      view |> render_click("toggle_notify_list")

      # Add then select and remove
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "RemBuddy", "note" => ""})
      assert render(view) =~ "RemBuddy"

      view |> ab_select("notify_select", "RemBuddy")
      view |> ab_click("notify_remove")

      html = render(view)
      refute html =~ "notify-list-row-RemBuddy"
      assert html =~ "No notify nicks yet. Add a nick to track online status."
    end

    test "edit notify entry note", %{conn: conn} do
      view = connect_user(conn, "EditNotify")
      view |> render_click("toggle_notify_list")

      # Add
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "EditBud", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      view |> ab_select("notify_select", "EditBud")
      view |> ab_click("notify_edit_dialog")
      assert render(view) =~ "Edit Notify Entry"

      view |> ab_form("notify-edit-form", %{"nickname" => "EditBud", "note" => "new note"})
      html = render(view)

      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "select notify entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelectNotify")
      view |> render_click("toggle_notify_list")

      # Add entry
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "SelBud", "note" => ""})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"notify-list-remove\"][disabled]")
      assert has_element?(view, "[data-testid=\"notify-list-edit\"][disabled]")

      # Select
      view |> ab_select("notify_select", "SelBud")

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"notify-list-remove\"][disabled]")
      refute has_element?(view, "[data-testid=\"notify-list-edit\"][disabled]")
    end

    test "notify tab shares data with standalone notify list", %{conn: conn} do
      view = connect_user(conn, "SyncNotify")

      # Add via /notify command (standalone mechanism)
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add SyncBud"})

      # Open address book and check notify tab
      view |> render_click("toggle_notify_list")

      html = render(view)
      assert html =~ "SyncBud"
    end

    test "auto_whois checkbox toggles", %{conn: conn} do
      view = connect_user(conn, "AutoWhois")
      # auto_whois is in the standalone notify list dialog
      view |> render_click("toggle_notify_list")

      html = render(view)
      assert html =~ "auto_whois" || html =~ "auto-whois"

      # Toggle auto-whois (checkbox owned by the NotifyListDialog island)
      view |> element("#notify-list-dialog-auto-whois") |> render_click()

      # Still open
      html = render(view)
      assert html =~ "Notify"
    end
  end

  # ── Phase 6: US4 — Nick Colors Tab ──────────────────────

  describe "notify presence sync" do
    test "adding a buddy who is already online shows them as Online", %{conn: conn} do
      # Connect the buddy first so they're tracked in presence:global
      buddy_view = connect_user(conn, "OnlineBud")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(buddy_view.pid)

      # Connect the observer
      view = connect_user(conn, "SyncObs")
      view |> render_click("toggle_notify_list")

      # Add the already-online buddy
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "OnlineBud", "note" => ""})

      # The buddy's row should have the Online indicator (text-success class)
      assert has_element?(
               view,
               ~s([data-testid="notify-list-row-OnlineBud"] .nl-status--online),
               "Online"
             )

      GenServer.stop(buddy_view.pid)
    end

    test "adding a buddy who is offline shows them as Offline", %{conn: conn} do
      view = connect_user(conn, "SyncObs2")
      view |> render_click("toggle_notify_list")

      # Add a buddy who is NOT connected
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "GhostBud", "note" => ""})

      # The buddy's row should have the Offline indicator (text-muted-foreground)
      assert has_element?(
               view,
               ~s([data-testid="notify-list-row-GhostBud"] .nl-status--offline),
               "Offline"
             )

      refute has_element?(view, ~s([data-testid="notify-list-row-GhostBud"] .nl-status--online))
    end

    test "buddy online via /notify add command shows Online status", %{conn: conn} do
      # Connect the buddy first
      buddy_view = connect_user(conn, "CmdBud")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(buddy_view.pid)

      # Observer adds via command
      view = connect_user(conn, "CmdObs")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add CmdBud"})

      # Check in address book
      view |> render_click("toggle_notify_list")

      assert has_element?(
               view,
               ~s([data-testid="notify-list-row-CmdBud"] .nl-status--online),
               "Online"
             )

      GenServer.stop(buddy_view.pid)
    end

    test "notify list syncs presence on session load for identified users", %{conn: conn} do
      nick = "SyncId#{uid()}"

      # Register and identify the user
      NickServ.register(nick, "pass123")
      NickServ.identify(nick, "pass123")

      # Add a notify entry in the DB
      NotifyList.save_entry(nick, %NotifyEntry{
        tracked_nickname: "TrkBud",
        note: nil,
        last_seen_at: nil,
        online: false
      })

      # Connect the tracked buddy so they're in the Tracker
      buddy_view = connect_user(conn, "TrkBud")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(buddy_view.pid)

      # Connect the identified user (pre_identified loads persisted data including notify list)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Check the notify list
      view |> render_click("toggle_notify_list")

      assert has_element?(
               view,
               ~s([data-testid="notify-list-row-TrkBud"] .nl-status--online),
               "Online"
             )

      GenServer.stop(buddy_view.pid)
    end
  end

  # ── Phase 6c: Notify Status Message Rendering ──────────

  describe "notify status message rendering" do
    test "notify_online status message renders without crashing", %{conn: conn} do
      # Connect observer and add buddy to notify list
      view = connect_user(conn, "RenderObs1")
      view |> render_click("toggle_notify_list")
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "RenderBud1", "note" => ""})

      # Simulate the debounce timer firing with :online status
      send(view.pid, {:notify_debounce, "RenderBud1", :online})
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)

      # The view should still be alive (not crashed) and render successfully
      html = render(view)
      assert html =~ "RenderBud1 is now online"
    end

    test "notify_offline status message renders without crashing", %{conn: conn} do
      # Connect observer, add buddy, mark them online first
      view = connect_user(conn, "RenderObs2")
      view |> render_click("toggle_notify_list")
      view |> ab_click("notify_add_dialog")
      view |> ab_form("notify-add-form", %{"nickname" => "RenderBud2", "note" => ""})

      # Simulate the debounce timer firing with :offline status
      send(view.pid, {:notify_debounce, "RenderBud2", :offline})
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)

      # The view should still be alive and render successfully
      html = render(view)
      assert html =~ "RenderBud2 has gone offline"
    end
  end

  # ── Phase 6d: Auto-Add PM to Notify List ──────────────

  describe "auto-add PM to notify list" do
    test "sending a PM auto-adds target to notify list", %{conn: conn} do
      # Connect both users
      target = connect_user(conn, "PmTarget1")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(target.pid)
      sender = connect_user(conn, "PmSender1")

      # Sender sends PM to target via /msg command
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmTarget1 hello there"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(sender.pid)

      # Check that PmTarget1 was auto-added to sender's notify list
      sender |> render_click("toggle_notify_list")

      assert has_element?(sender, ~s([data-testid="notify-list-row-PmTarget1"]))
    end

    test "receiving a PM auto-adds sender to notify list", %{conn: conn} do
      receiver = connect_user(conn, "PmRecv1")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(receiver.pid)
      sender = connect_user(conn, "PmSend2")

      # Sender sends PM — receiver gets it via PubSub
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmRecv1 hey"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(sender.pid)
      _ = :sys.get_state(receiver.pid)

      # Check that PmSend2 was auto-added to receiver's notify list
      receiver |> render_click("toggle_notify_list")

      assert has_element?(receiver, ~s([data-testid="notify-list-row-PmSend2"]))
    end

    test "duplicate PM does not create duplicate notify entry", %{conn: conn} do
      target = connect_user(conn, "PmDupTgt")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(target.pid)
      sender = connect_user(conn, "PmDupSnd")

      # Send two PMs
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmDupTgt first"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(sender.pid)

      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmDupTgt second"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(sender.pid)

      # Should have exactly one entry
      sender |> render_click("toggle_notify_list")

      html = render(sender)
      # Count occurrences of the entry ID
      assert length(Regex.scan(~r/notify-list-row-PmDupTgt/, html)) == 1
    end

    test "auto-add disabled when toggle is off", %{conn: conn} do
      target = connect_user(conn, "PmNoAdd")
      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(target.pid)
      sender = connect_user(conn, "PmTogOff")

      # Disable auto-add via the standalone Notify List window (managed: the
      # island mounts when the window opens; the checkbox is owned by the
      # NotifyListDialog island, so fire it element-based).
      sender |> render_click("toggle_notify_list")
      sender |> element("#notify-list-dialog-auto-add-pm") |> render_click()

      # Send PM
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmNoAdd hi"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(sender.pid)

      # Should NOT have an entry
      sender |> render_click("toggle_notify_list")

      refute has_element?(sender, ~s([data-testid="notify-list-row-PmNoAdd"]))
    end
  end

  # ── Phase 7: US5 — Control Tab ──────────────────────────
end
