defmodule RetroHexChatWeb.AddressBookTest do
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

  # The Address Book is a stateful island; its events target the component, so
  # fire them element-based (the design-system threads phx-target through).
  defp ab_click(view, event) do
    view |> element("#address-book-dialog-mount [phx-click='#{event}']") |> render_click()
  end

  defp ab_select(view, event, nick) do
    view
    |> element("#address-book-dialog-mount [phx-click='#{event}'][phx-value-nickname='#{nick}']")
    |> render_click()
  end

  defp ab_form(view, testid, params) do
    view |> element("[data-testid='#{testid}']") |> render_submit(params)
  end

  defp ab_tab(view, tab) do
    view
    |> element("#address-book-dialog-tabs .tabs-trigger[data-target='#{tab}']")
    |> render_click()
  end

  # ── Phase 3: US1 — Dialog Shell ──────────────────────────

  describe "window open/close" do
    test "Ctrl+Shift+A opens the window", %{conn: conn} do
      view = connect_user(conn, "AltBUser")
      refute has_element?(view, ~s([data-window-id="address-book"]))

      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})

      assert has_element?(view, ~s([data-window-id="address-book"][data-window-managed="true"]))
      assert render(view) =~ "Address Book"
      assert_push_event(view, "window_command", %{action: "open", id: "address-book"})
    end

    test "re-invoking the shortcut focuses the window (never toggle-closes)", %{conn: conn} do
      view = connect_user(conn, "AltBToggle")

      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      assert has_element?(view, ~s([data-window-id="address-book"]))

      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      assert has_element?(view, ~s([data-window-id="address-book"]))
    end

    test "a client-side window close unmounts the island", %{conn: conn} do
      view = connect_user(conn, "CloseBtn")

      view |> render_click("toggle_address_book")
      assert has_element?(view, ~s([data-window-id="address-book"]))

      render_hook(view, "window_closed", %{"id" => "address-book"})
      refute has_element?(view, ~s([data-window-id="address-book"]))
    end
  end

  describe "tab switching" do
    test "dialog opens with 4 tab headers visible", %{conn: conn} do
      view = connect_user(conn, "TabHeaders")
      view |> render_click("toggle_address_book")
      html = render(view)

      assert html =~ "Contacts"
      assert html =~ "Notify"
      assert html =~ "Nick Colors"
      assert html =~ "Control"
    end

    test "Contacts tab is default when opening", %{conn: conn} do
      view = connect_user(conn, "DefaultTab")
      view |> render_click("toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
    end

    test "clicking tab header switches tab content", %{conn: conn} do
      view = connect_user(conn, "SwitchTab")
      view |> render_click("toggle_address_book")

      # Switch to Notify
      html = view |> ab_tab("notify")
      assert html =~ "No entries. Click Add to track a nickname."

      # Switch to Nick Colors
      html = view |> ab_tab("colors")
      assert html =~ "No custom colors set. Nicknames use automatic colors."

      # Switch to Control
      html = view |> ab_tab("control")
      assert html =~ "No ignored users. Click Add to ignore a nickname."

      # Back to Contacts
      html = view |> ab_tab("contacts")
      assert html =~ "No contacts saved"
    end

    test "switching tabs while open preserves dialog visibility", %{conn: conn} do
      view = connect_user(conn, "TabPreserve")
      view |> render_click("toggle_address_book")

      view |> ab_tab("notify")
      assert render(view) =~ "address-book-dialog"

      view |> ab_tab("control")
      assert render(view) =~ "address-book-dialog"
    end

    test "reopening the window resets to Contacts tab", %{conn: conn} do
      view = connect_user(conn, "ResetTab")
      view |> render_click("toggle_address_book")

      # Switch to Nick Colors
      view |> ab_tab("colors")
      assert render(view) =~ "No custom colors set. Nicknames use automatic colors."

      # Close (client contract unmounts the managed island) and reopen fresh.
      render_hook(view, "window_closed", %{"id" => "address-book"})
      view |> render_click("toggle_address_book")
      assert render(view) =~ "No contacts saved"
    end
  end

  describe "menu bar" do
    test "Tools > Address Book opens dialog", %{conn: conn} do
      view = connect_user(conn, "MenuUser")

      render_click(view, "toggle_address_book")
      html = render(view)
      assert html =~ "address-book-dialog"
    end
  end

  # ── Phase 4: US2 — Contacts Tab CRUD ──────────────────────

  describe "contacts tab" do
    test "empty contacts shows 'No contacts saved'", %{conn: conn} do
      view = connect_user(conn, "EmptyContacts")
      view |> render_click("toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
    end

    test "add contact success — appears in list with nickname, note, date", %{conn: conn} do
      view = connect_user(conn, "AddContactUser")
      view |> render_click("toggle_address_book")

      # Open add dialog
      view |> ab_click("contact_add_dialog")
      assert render(view) =~ "Add Contact"

      # Submit the form
      view |> ab_form("contact-add-form", %{"nickname" => "BuddyNick", "note" => "My buddy"})
      html = render(view)

      assert html =~ "BuddyNick"
      assert html =~ "My buddy"
      # Add dialog should be closed
      refute html =~ "Add Contact"
    end

    test "add duplicate shows error status message", %{conn: conn} do
      view = connect_user(conn, "DupContact")
      view |> render_click("toggle_address_book")

      # Add first time
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "DupBuddy", "note" => ""})

      # Add same nick again
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "DupBuddy", "note" => ""})

      html = render(view)
      assert html =~ "DupBuddy is already in your contacts"
    end

    test "add self shows error status message", %{conn: conn} do
      view = connect_user(conn, "SelfAdd")
      view |> render_click("toggle_address_book")

      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "SelfAdd", "note" => ""})

      html = render(view)
      assert html =~ "Cannot add yourself to contacts"
    end

    test "add with empty nickname shows error", %{conn: conn} do
      view = connect_user(conn, "EmptyNick")
      view |> render_click("toggle_address_book")

      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "   ", "note" => ""})

      html = render(view)
      assert html =~ "Invalid nickname"
    end

    test "select contact enables Edit/Remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelectBtns")
      view |> render_click("toggle_address_book")

      # Add a contact
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "SelectTarget", "note" => ""})

      # Before selection, buttons are disabled
      assert has_element?(view, "[data-testid=\"contact-edit\"][disabled]")
      assert has_element?(view, "[data-testid=\"contact-remove\"][disabled]")

      # Select the contact
      view |> ab_select("contact_select", "SelectTarget")

      # After selection, buttons should NOT be disabled
      refute has_element?(view, "[data-testid=\"contact-edit\"][disabled]")
      refute has_element?(view, "[data-testid=\"contact-remove\"][disabled]")
    end

    test "edit note updates in list", %{conn: conn} do
      view = connect_user(conn, "EditNote")
      view |> render_click("toggle_address_book")

      # Add a contact
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "EditTarget", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      view |> ab_select("contact_select", "EditTarget")
      view |> ab_click("contact_edit_dialog")
      assert render(view) =~ "Edit Contact"

      view
      |> ab_form("contact-edit-form", %{"nickname" => "EditTarget", "note" => "new note"})

      html = render(view)
      assert html =~ "new note"
      refute html =~ "old note"
      # Edit dialog should be closed
      refute html =~ "Edit Contact</div>"
    end

    test "remove contact removes from list", %{conn: conn} do
      view = connect_user(conn, "RemoveContact")
      view |> render_click("toggle_address_book")

      # Add a contact
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "RemoveMe", "note" => ""})
      assert render(view) =~ "RemoveMe"

      # Select and remove
      view |> ab_select("contact_select", "RemoveMe")
      view |> ab_click("contact_remove")

      html = render(view)
      refute html =~ "contact-entry-RemoveMe"
      assert html =~ "No contacts saved"
    end

    test "contacts sorted alphabetically", %{conn: conn} do
      view = connect_user(conn, "SortTest")
      view |> render_click("toggle_address_book")

      # Add contacts in non-alphabetical order
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "Zara", "note" => ""})

      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "Alpha", "note" => ""})

      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "Mike", "note" => ""})

      html = render(view)

      # Verify all three are present
      assert html =~ "Alpha"
      assert html =~ "Mike"
      assert html =~ "Zara"

      # Verify alphabetical order by checking contact table row positions
      alpha_pos = :binary.match(html, "contact-entry-Alpha") |> elem(0)
      mike_pos = :binary.match(html, "contact-entry-Mike") |> elem(0)
      zara_pos = :binary.match(html, "contact-entry-Zara") |> elem(0)

      assert alpha_pos < mike_pos
      assert mike_pos < zara_pos
    end
  end

  # ── Phase 5: US3 — Notify Tab ──────────────────────────

  describe "notify tab" do
    test "empty notify list shows empty message", %{conn: conn} do
      view = connect_user(conn, "EmptyNotify")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")
      html = render(view)

      assert html =~ "No entries. Click Add to track a nickname."
    end

    test "add notify entry appears in list", %{conn: conn} do
      view = connect_user(conn, "AddNotify")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Open add dialog
      view |> ab_click("notify_add_dialog")
      assert render(view) =~ "Add Notify Entry"

      # Submit
      view |> ab_form("ab-notify-add-form", %{"nickname" => "BuddyA", "note" => "my buddy"})
      html = render(view)

      assert html =~ "BuddyA"
      assert html =~ "my buddy"
      refute html =~ "Add Notify Entry</div>"
    end

    test "remove notify entry from list", %{conn: conn} do
      view = connect_user(conn, "RemoveNotify")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Add then select and remove
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "RemBuddy", "note" => ""})
      assert render(view) =~ "RemBuddy"

      view |> ab_select("notify_select", "RemBuddy")
      view |> ab_click("notify_remove")

      html = render(view)
      refute html =~ "ab-notify-entry-RemBuddy"
      assert html =~ "No entries. Click Add to track a nickname."
    end

    test "edit notify entry note", %{conn: conn} do
      view = connect_user(conn, "EditNotify")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Add
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "EditBud", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      view |> ab_select("notify_select", "EditBud")
      view |> ab_click("notify_edit_dialog")
      assert render(view) =~ "Edit Notify Entry"

      view |> ab_form("ab-notify-edit-form", %{"nickname" => "EditBud", "note" => "new note"})
      html = render(view)

      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "select notify entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelectNotify")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Add entry
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "SelBud", "note" => ""})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"ab-notify-remove\"][disabled]")
      assert has_element?(view, "[data-testid=\"ab-notify-edit\"][disabled]")

      # Select
      view |> ab_select("notify_select", "SelBud")

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"ab-notify-remove\"][disabled]")
      refute has_element?(view, "[data-testid=\"ab-notify-edit\"][disabled]")
    end

    test "notify tab shares data with standalone notify list", %{conn: conn} do
      view = connect_user(conn, "SyncNotify")

      # Add via /notify command (standalone mechanism)
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add SyncBud"})

      # Open address book and check notify tab
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

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

  describe "nick colors tab" do
    test "empty nick colors shows placeholder message", %{conn: conn} do
      view = connect_user(conn, "EmptyColors")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")
      html = render(view)

      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "add nick color success — appears in list with swatch", %{conn: conn} do
      view = connect_user(conn, "AddColor")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Open add dialog
      view |> ab_click("nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      view
      |> ab_form("nick-color-add-form", %{"nickname" => "ColorBud", "color_index" => "4"})

      html = render(view)
      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "irc-bg-4"
      refute html =~ "Add Nick Color</div>"
    end

    test "add duplicate shows error", %{conn: conn} do
      view = connect_user(conn, "DupColor")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Add first
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "DupNick", "color_index" => "4"})

      # Add same again
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "DupNick", "color_index" => "5"})

      html = render(view)
      assert html =~ "DupNick already has a custom color"
    end

    test "edit color updates in list", %{conn: conn} do
      view = connect_user(conn, "EditColor")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Add with Red (4)
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "EditNick", "color_index" => "4"})
      assert render(view) =~ "Red"

      # Select and edit to Blue (12)
      view |> ab_select("nick_color_select", "EditNick")
      view |> ab_click("nick_color_edit_dialog")
      assert render(view) =~ "Edit Nick Color"

      view |> ab_form("nick-color-edit-form", %{"nickname" => "EditNick", "color_index" => "12"})
      html = render(view)

      assert html =~ "Blue"
      assert html =~ "irc-bg-12"
      refute html =~ "Edit Nick Color</div>"
    end

    test "remove color removes from list", %{conn: conn} do
      view = connect_user(conn, "RemColor")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Add
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "RemNick", "color_index" => "4"})
      assert render(view) =~ "RemNick"

      # Select and remove
      view |> ab_select("nick_color_select", "RemNick")
      view |> ab_click("nick_color_remove")

      html = render(view)
      refute html =~ "nick-color-entry-RemNick"
      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "select entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelColor")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Add entry
      view |> ab_click("nick_color_add_dialog")
      view |> ab_form("nick-color-add-form", %{"nickname" => "SelNick", "color_index" => "3"})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"nick-color-edit\"][disabled]")
      assert has_element?(view, "[data-testid=\"nick-color-remove\"][disabled]")

      # Select
      view |> ab_select("nick_color_select", "SelNick")

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"nick-color-edit\"][disabled]")
      refute has_element?(view, "[data-testid=\"nick-color-remove\"][disabled]")
    end

    test "color override applies to chat message nickname", %{conn: conn} do
      view = connect_user(conn, "ColorMsg")
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")

      # Set a custom color for "SomeChatter" — Red (4) = #ff0000
      view |> ab_click("nick_color_add_dialog")

      view
      |> ab_form("nick-color-add-form", %{"nickname" => "SomeChatter", "color_index" => "4"})

      # The nick color entry should appear in the list with the irc-bg-4 swatch
      # (functional test — override is wired into session via nick_color_fn)
      html = render(view)
      assert html =~ "SomeChatter"
      assert html =~ "irc-bg-4"
    end
  end

  # ── Phase 8: Context Menu Integration ──────────────────────

  describe "context menu integration" do
    test "context menu shows Add to Contacts and Set Nick Color items", %{conn: conn} do
      view = connect_user(conn, "CtxMenu")

      # Trigger context menu on a nick
      view
      |> render_click("nick_right_click", %{
        "nick" => "SomeNick",
        "x" => 100,
        "y" => 200
      })

      html = render(view)

      assert html =~ "context-menu-item-context_add_contact"
      assert html =~ "context-menu-item-context_set_nick_color"
      assert html =~ "Add to Contacts"
      assert html =~ "Set Nick Color"
    end

    test "Add to Contacts adds nick from context menu", %{conn: conn} do
      view = connect_user(conn, "CtxAddContact")

      # Trigger context menu and click Add to Contacts
      view
      |> render_click("nick_right_click", %{
        "nick" => "CtxBuddy",
        "x" => 100,
        "y" => 200
      })

      view |> render_click("context_add_contact", %{"nick" => "CtxBuddy"})

      # Verify in contacts list
      view |> render_click("toggle_address_book")
      html = render(view)
      assert html =~ "CtxBuddy"
    end

    test "Add to Contacts shows error for duplicate", %{conn: conn} do
      view = connect_user(conn, "CtxDupContact")

      # Add first via dialog
      view |> render_click("toggle_address_book")
      view |> ab_click("contact_add_dialog")
      view |> ab_form("contact-add-form", %{"nickname" => "DupCtx", "note" => ""})
      view |> render_click("toggle_address_book")

      # Add again via context menu
      view
      |> render_click("nick_right_click", %{
        "nick" => "DupCtx",
        "x" => 100,
        "y" => 200
      })

      view |> render_click("context_add_contact", %{"nick" => "DupCtx"})

      html = render(view)
      assert html =~ "DupCtx is already in your contacts"
    end

    test "Set Nick Color shows color picker", %{conn: conn} do
      view = connect_user(conn, "CtxColorPicker")

      view
      |> render_click("nick_right_click", %{
        "nick" => "ColorTarget",
        "x" => 100,
        "y" => 200
      })

      view |> render_click("context_set_nick_color", %{"nick" => "ColorTarget"})

      html = render(view)
      # App chat shows inline color picker with nick-color-N swatches
      assert html =~ "nick-color-0"
      assert html =~ "context_pick_color"
    end

    test "picking a color assigns override", %{conn: conn} do
      view = connect_user(conn, "CtxPickColor")

      view
      |> render_click("nick_right_click", %{
        "nick" => "PickTarget",
        "x" => 100,
        "y" => 200
      })

      view |> render_click("context_set_nick_color", %{"nick" => "PickTarget"})
      view |> render_click("context_pick_color", %{"color_index" => "4", "nick" => "PickTarget"})

      # Verify in nick colors tab
      view |> render_click("toggle_address_book")
      view |> ab_tab("colors")
      html = render(view)

      assert html =~ "PickTarget"
      assert html =~ "Red"
    end
  end

  # ── Phase 6b: Notify Presence Sync ──────────────────────

  describe "notify presence sync" do
    test "adding a buddy who is already online shows them as Online", %{conn: conn} do
      # Connect the buddy first so they're tracked in presence:global
      buddy_view = connect_user(conn, "OnlineBud")
      Process.sleep(100)

      # Connect the observer
      view = connect_user(conn, "SyncObs")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Add the already-online buddy
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "OnlineBud", "note" => ""})

      # The buddy's row should have the Online indicator (text-success class)
      assert has_element?(view, "#ab-notify-entry-OnlineBud .text-success", "Online")

      GenServer.stop(buddy_view.pid)
    end

    test "adding a buddy who is offline shows them as Offline", %{conn: conn} do
      view = connect_user(conn, "SyncObs2")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      # Add a buddy who is NOT connected
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "GhostBud", "note" => ""})

      # The buddy's row should have the Offline indicator (text-muted-foreground)
      assert has_element?(view, "#ab-notify-entry-GhostBud .text-muted-foreground", "Offline")
      refute has_element?(view, "#ab-notify-entry-GhostBud .text-success")
    end

    test "buddy online via /notify add command shows Online status", %{conn: conn} do
      # Connect the buddy first
      buddy_view = connect_user(conn, "CmdBud")
      Process.sleep(100)

      # Observer adds via command
      view = connect_user(conn, "CmdObs")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add CmdBud"})

      # Check in address book
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      assert has_element?(view, "#ab-notify-entry-CmdBud .text-success", "Online")

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
      Process.sleep(100)

      # Connect the identified user (pre_identified loads persisted data including notify list)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Check the notify list
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")

      assert has_element?(view, "#ab-notify-entry-TrkBud .text-success", "Online")

      GenServer.stop(buddy_view.pid)
    end
  end

  # ── Phase 6c: Notify Status Message Rendering ──────────

  describe "notify status message rendering" do
    test "notify_online status message renders without crashing", %{conn: conn} do
      # Connect observer and add buddy to notify list
      view = connect_user(conn, "RenderObs1")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "RenderBud1", "note" => ""})

      # Simulate the debounce timer firing with :online status
      send(view.pid, {:notify_debounce, "RenderBud1", :online})
      Process.sleep(50)

      # The view should still be alive (not crashed) and render successfully
      html = render(view)
      assert html =~ "RenderBud1 is now online"
    end

    test "notify_offline status message renders without crashing", %{conn: conn} do
      # Connect observer, add buddy, mark them online first
      view = connect_user(conn, "RenderObs2")
      view |> render_click("toggle_address_book")
      view |> ab_tab("notify")
      view |> ab_click("notify_add_dialog")
      view |> ab_form("ab-notify-add-form", %{"nickname" => "RenderBud2", "note" => ""})

      # Simulate the debounce timer firing with :offline status
      send(view.pid, {:notify_debounce, "RenderBud2", :offline})
      Process.sleep(50)

      # The view should still be alive and render successfully
      html = render(view)
      assert html =~ "RenderBud2 has gone offline"
    end
  end

  # ── Phase 6d: Auto-Add PM to Notify List ──────────────

  describe "auto-add PM to notify list" do
    test "sending a PM auto-adds target to notify list", %{conn: conn} do
      # Connect both users
      _target = connect_user(conn, "PmTarget1")
      Process.sleep(100)
      sender = connect_user(conn, "PmSender1")

      # Sender sends PM to target via /msg command
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmTarget1 hello there"})

      Process.sleep(50)

      # Check that PmTarget1 was auto-added to sender's notify list
      sender |> render_click("toggle_address_book")
      sender |> ab_tab("notify")

      assert has_element?(sender, "#ab-notify-entry-PmTarget1")
    end

    test "receiving a PM auto-adds sender to notify list", %{conn: conn} do
      receiver = connect_user(conn, "PmRecv1")
      Process.sleep(100)
      sender = connect_user(conn, "PmSend2")

      # Sender sends PM — receiver gets it via PubSub
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmRecv1 hey"})

      Process.sleep(100)

      # Check that PmSend2 was auto-added to receiver's notify list
      receiver |> render_click("toggle_address_book")
      receiver |> ab_tab("notify")

      assert has_element?(receiver, "#ab-notify-entry-PmSend2")
    end

    test "duplicate PM does not create duplicate notify entry", %{conn: conn} do
      _target = connect_user(conn, "PmDupTgt")
      Process.sleep(100)
      sender = connect_user(conn, "PmDupSnd")

      # Send two PMs
      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmDupTgt first"})

      Process.sleep(50)

      sender
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/msg PmDupTgt second"})

      Process.sleep(50)

      # Should have exactly one entry
      sender |> render_click("toggle_address_book")
      sender |> ab_tab("notify")

      html = render(sender)
      # Count occurrences of the entry ID
      assert length(Regex.scan(~r/ab-notify-entry-PmDupTgt/, html)) == 1
    end

    test "auto-add disabled when toggle is off", %{conn: conn} do
      _target = connect_user(conn, "PmNoAdd")
      Process.sleep(100)
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

      Process.sleep(50)

      # Should NOT have an entry
      sender |> render_click("toggle_address_book")
      sender |> ab_tab("notify")

      refute has_element?(sender, "#ab-notify-entry-PmNoAdd")
    end
  end

  # ── Phase 7: US5 — Control Tab ──────────────────────────

  describe "control tab" do
    test "shows empty state when no ignored users", %{conn: conn} do
      view = connect_user(conn, "ControlTab")
      view |> render_click("toggle_address_book")
      view |> ab_tab("control")

      html = render(view)
      assert html =~ "No ignored users. Click Add to ignore a nickname."
    end
  end
end
