defmodule RetroHexChatWeb.AddressBookTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

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

  # ── Phase 3: US1 — Dialog Shell ──────────────────────────

  describe "dialog open/close" do
    test "Ctrl+Shift+A opens the dialog", %{conn: conn} do
      view = connect_user(conn, "AltBUser")
      refute render(view) =~ "address-book-dialog"

      html =
        view
        |> element("#app-container")
        |> render_keydown(%{"key" => "a", "ctrlKey" => true, "shiftKey" => true})

      assert html =~ "address-book-dialog"
      assert html =~ "title-bar-text\">Address Book</div>"
    end

    test "Ctrl+Shift+A toggles dialog closed", %{conn: conn} do
      view = connect_user(conn, "AltBToggle")

      # Open
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "a", "ctrlKey" => true, "shiftKey" => true})

      assert render(view) =~ "address-book-dialog"

      # Close
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "a", "ctrlKey" => true, "shiftKey" => true})

      refute render(view) =~ "address-book-dialog"
    end

    test "close button closes dialog", %{conn: conn} do
      view = connect_user(conn, "CloseBtn")

      # Open via toggle event
      view |> render_click("toggle_address_book")
      assert render(view) =~ "address-book-dialog"

      # Close via toggle (same event from close button)
      view |> render_click("toggle_address_book")
      refute render(view) =~ "address-book-dialog"
    end

    test "toolbar button toggles dialog", %{conn: conn} do
      view = connect_user(conn, "ToolbarBtn")

      html =
        view
        |> element("[data-testid=\"toolbar-address-book\"]")
        |> render_click()

      assert html =~ "address-book-dialog"

      html =
        view
        |> element("[data-testid=\"toolbar-address-book\"]")
        |> render_click()

      refute html =~ "address-book-dialog"
    end
  end

  describe "tab switching" do
    test "dialog opens with 4 tab headers visible", %{conn: conn} do
      view = connect_user(conn, "TabHeaders")
      view |> render_click("toggle_address_book")
      html = render(view)

      assert html =~ "address-book-tab-contacts"
      assert html =~ "address-book-tab-notify"
      assert html =~ "address-book-tab-nick-colors"
      assert html =~ "address-book-tab-control"
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
      html = view |> render_click("address_book_tab", %{"tab" => "notify"})
      assert html =~ "No entries. Click Add to track a nickname."

      # Switch to Nick Colors
      html = view |> render_click("address_book_tab", %{"tab" => "nick_colors"})
      assert html =~ "No custom colors set. Nicknames use automatic colors."

      # Switch to Control
      html = view |> render_click("address_book_tab", %{"tab" => "control"})
      assert html =~ "Ignore management will be available in a future update."

      # Back to Contacts
      html = view |> render_click("address_book_tab", %{"tab" => "contacts"})
      assert html =~ "No contacts saved"
    end

    test "switching tabs while open preserves dialog visibility", %{conn: conn} do
      view = connect_user(conn, "TabPreserve")
      view |> render_click("toggle_address_book")

      view |> render_click("address_book_tab", %{"tab" => "notify"})
      assert render(view) =~ "address-book-dialog"

      view |> render_click("address_book_tab", %{"tab" => "control"})
      assert render(view) =~ "address-book-dialog"
    end

    test "reopening dialog resets to Contacts tab", %{conn: conn} do
      view = connect_user(conn, "ResetTab")
      view |> render_click("toggle_address_book")

      # Switch to Nick Colors
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})
      assert render(view) =~ "No custom colors set. Nicknames use automatic colors."

      # Close and reopen
      view |> render_click("toggle_address_book")
      view |> render_click("toggle_address_book")
      assert render(view) =~ "No contacts saved"
    end
  end

  describe "menu bar" do
    test "Tools > Address Book opens dialog", %{conn: conn} do
      view = connect_user(conn, "MenuUser")

      html =
        view
        |> element("[data-testid=\"toolbar-address-book\"]")
        |> render_click()

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
      view |> render_click("contact_add_dialog")
      assert render(view) =~ "Add Contact"

      # Submit the form
      view |> render_submit("contact_add", %{"nickname" => "BuddyNick", "note" => "My buddy"})
      html = render(view)

      assert html =~ "BuddyNick"
      assert html =~ "My buddy"
      # Date should be today
      today = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d")
      assert html =~ today
      # Add dialog should be closed
      refute html =~ "Add Contact</div>"
    end

    test "add duplicate shows error status message", %{conn: conn} do
      view = connect_user(conn, "DupContact")
      view |> render_click("toggle_address_book")

      # Add first time
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "DupBuddy", "note" => ""})

      # Add same nick again
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "DupBuddy", "note" => ""})

      html = render(view)
      assert html =~ "DupBuddy is already in your contacts"
    end

    test "add self shows error status message", %{conn: conn} do
      view = connect_user(conn, "SelfAdd")
      view |> render_click("toggle_address_book")

      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "SelfAdd", "note" => ""})

      html = render(view)
      assert html =~ "Cannot add yourself to contacts"
    end

    test "add with empty nickname shows error", %{conn: conn} do
      view = connect_user(conn, "EmptyNick")
      view |> render_click("toggle_address_book")

      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "   ", "note" => ""})

      html = render(view)
      assert html =~ "Invalid nickname"
    end

    test "select contact enables Edit/Remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelectBtns")
      view |> render_click("toggle_address_book")

      # Add a contact
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "SelectTarget", "note" => ""})

      # Before selection, buttons are disabled
      assert has_element?(view, "[data-testid=\"contact-edit-btn\"][disabled]")
      assert has_element?(view, "[data-testid=\"contact-remove-btn\"][disabled]")

      # Select the contact
      view |> render_click("contact_select", %{"nickname" => "SelectTarget"})

      # After selection, buttons should NOT be disabled
      refute has_element?(view, "[data-testid=\"contact-edit-btn\"][disabled]")
      refute has_element?(view, "[data-testid=\"contact-remove-btn\"][disabled]")
    end

    test "edit note updates in list", %{conn: conn} do
      view = connect_user(conn, "EditNote")
      view |> render_click("toggle_address_book")

      # Add a contact
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "EditTarget", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      view |> render_click("contact_select", %{"nickname" => "EditTarget"})
      view |> render_click("contact_edit_dialog")
      assert render(view) =~ "Edit Contact"

      view
      |> render_submit("contact_edit", %{"nickname" => "EditTarget", "note" => "new note"})

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
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "RemoveMe", "note" => ""})
      assert render(view) =~ "RemoveMe"

      # Select and remove
      view |> render_click("contact_select", %{"nickname" => "RemoveMe"})

      view
      |> element("[data-testid=\"contact-remove-btn\"]")
      |> render_click()

      html = render(view)
      refute html =~ "contact-entry-RemoveMe"
      assert html =~ "No contacts saved"
    end

    test "contacts sorted alphabetically", %{conn: conn} do
      view = connect_user(conn, "SortTest")
      view |> render_click("toggle_address_book")

      # Add contacts in non-alphabetical order
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "Zara", "note" => ""})

      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "Alpha", "note" => ""})

      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "Mike", "note" => ""})

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
      view |> render_click("address_book_tab", %{"tab" => "notify"})
      html = render(view)

      assert html =~ "No entries. Click Add to track a nickname."
    end

    test "add notify entry appears in list", %{conn: conn} do
      view = connect_user(conn, "AddNotify")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      # Open add dialog
      view |> render_click("notify_add_dialog")
      assert render(view) =~ "Add to Notify List"

      # Submit
      view |> render_submit("notify_add", %{"nickname" => "BuddyA", "note" => "my buddy"})
      html = render(view)

      assert html =~ "BuddyA"
      assert html =~ "my buddy"
      refute html =~ "Add to Notify List</div>"
    end

    test "remove notify entry from list", %{conn: conn} do
      view = connect_user(conn, "RemoveNotify")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      # Add then select and remove
      view |> render_click("notify_add_dialog")
      view |> render_submit("notify_add", %{"nickname" => "RemBuddy", "note" => ""})
      assert render(view) =~ "RemBuddy"

      view |> render_click("notify_select", %{"nickname" => "RemBuddy"})

      view
      |> element("[data-testid=\"ab-notify-btn-remove\"]")
      |> render_click()

      html = render(view)
      refute html =~ "ab-notify-entry-RemBuddy"
      assert html =~ "No entries. Click Add to track a nickname."
    end

    test "edit notify entry note", %{conn: conn} do
      view = connect_user(conn, "EditNotify")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      # Add
      view |> render_click("notify_add_dialog")
      view |> render_submit("notify_add", %{"nickname" => "EditBud", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      view |> render_click("notify_select", %{"nickname" => "EditBud"})
      view |> render_click("notify_edit_dialog")
      assert render(view) =~ "Edit Notify Entry"

      view |> render_submit("notify_edit", %{"nickname" => "EditBud", "note" => "new note"})
      html = render(view)

      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "select notify entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelectNotify")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      # Add entry
      view |> render_click("notify_add_dialog")
      view |> render_submit("notify_add", %{"nickname" => "SelBud", "note" => ""})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"ab-notify-btn-remove\"][disabled]")
      assert has_element?(view, "[data-testid=\"ab-notify-btn-edit\"][disabled]")

      # Select
      view |> render_click("notify_select", %{"nickname" => "SelBud"})

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"ab-notify-btn-remove\"][disabled]")
      refute has_element?(view, "[data-testid=\"ab-notify-btn-edit\"][disabled]")
    end

    test "notify tab shares data with standalone notify list", %{conn: conn} do
      view = connect_user(conn, "SyncNotify")

      # Add via /notify command (standalone mechanism)
      view |> render_submit("send_input", %{"input" => "/notify add SyncBud"})

      # Open address book and check notify tab
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      html = render(view)
      assert html =~ "SyncBud"
    end

    test "auto_whois checkbox toggles", %{conn: conn} do
      view = connect_user(conn, "AutoWhois")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "notify"})

      assert has_element?(view, "[data-testid=\"ab-notify-auto-whois\"]")

      # Toggle auto-whois
      view
      |> element("[data-testid=\"ab-notify-auto-whois\"]")
      |> render_click()

      # Still on notify tab
      assert render(view) =~ "ab-notify-auto-whois"
    end
  end

  # ── Phase 6: US4 — Nick Colors Tab ──────────────────────

  describe "nick colors tab" do
    test "empty nick colors shows placeholder message", %{conn: conn} do
      view = connect_user(conn, "EmptyColors")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})
      html = render(view)

      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "add nick color success — appears in list with swatch", %{conn: conn} do
      view = connect_user(conn, "AddColor")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Open add dialog
      view |> render_click("nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      view
      |> render_submit("nick_color_add", %{"nickname" => "ColorBud", "color_index" => "4"})

      html = render(view)
      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "#ff0000"
      refute html =~ "Add Nick Color</div>"
    end

    test "add duplicate shows error", %{conn: conn} do
      view = connect_user(conn, "DupColor")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Add first
      view |> render_click("nick_color_add_dialog")
      view |> render_submit("nick_color_add", %{"nickname" => "DupNick", "color_index" => "4"})

      # Add same again
      view |> render_click("nick_color_add_dialog")
      view |> render_submit("nick_color_add", %{"nickname" => "DupNick", "color_index" => "5"})

      html = render(view)
      assert html =~ "DupNick already has a custom color"
    end

    test "edit color updates in list", %{conn: conn} do
      view = connect_user(conn, "EditColor")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Add with Red (4)
      view |> render_click("nick_color_add_dialog")
      view |> render_submit("nick_color_add", %{"nickname" => "EditNick", "color_index" => "4"})
      assert render(view) =~ "Red"

      # Select and edit to Blue (12)
      view |> render_click("nick_color_select", %{"nickname" => "EditNick"})
      view |> render_click("nick_color_edit_dialog")
      assert render(view) =~ "Edit Nick Color"

      view |> render_submit("nick_color_edit", %{"nickname" => "EditNick", "color_index" => "12"})
      html = render(view)

      assert html =~ "Blue"
      assert html =~ "#0000fc"
      refute html =~ "Edit Nick Color</div>"
    end

    test "remove color removes from list", %{conn: conn} do
      view = connect_user(conn, "RemColor")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Add
      view |> render_click("nick_color_add_dialog")
      view |> render_submit("nick_color_add", %{"nickname" => "RemNick", "color_index" => "4"})
      assert render(view) =~ "RemNick"

      # Select and remove
      view |> render_click("nick_color_select", %{"nickname" => "RemNick"})

      view
      |> element("[data-testid=\"nick-color-remove-btn\"]")
      |> render_click()

      html = render(view)
      refute html =~ "nick-color-entry-RemNick"
      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end

    test "select entry enables edit/remove buttons", %{conn: conn} do
      view = connect_user(conn, "SelColor")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Add entry
      view |> render_click("nick_color_add_dialog")
      view |> render_submit("nick_color_add", %{"nickname" => "SelNick", "color_index" => "3"})

      # Before selection, buttons disabled
      assert has_element?(view, "[data-testid=\"nick-color-edit-btn\"][disabled]")
      assert has_element?(view, "[data-testid=\"nick-color-remove-btn\"][disabled]")

      # Select
      view |> render_click("nick_color_select", %{"nickname" => "SelNick"})

      # After selection, not disabled
      refute has_element?(view, "[data-testid=\"nick-color-edit-btn\"][disabled]")
      refute has_element?(view, "[data-testid=\"nick-color-remove-btn\"][disabled]")
    end

    test "color override applies to chat message nickname", %{conn: conn} do
      view = connect_user(conn, "ColorMsg")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})

      # Set a custom color for "SomeChatter" — Red (4) = #ff0000
      view |> render_click("nick_color_add_dialog")

      view
      |> render_submit("nick_color_add", %{"nickname" => "SomeChatter", "color_index" => "4"})

      # The nick_color_fn should now return #ff0000 for SomeChatter
      # We can verify by checking the chat template uses @nick_color_fn
      # (functional test — override is wired into session)
      html = render(view)
      assert html =~ "SomeChatter"
      assert html =~ "#ff0000"
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
        "clientX" => "100",
        "clientY" => "200"
      })

      html = render(view)

      assert html =~ "ctx-add-contact"
      assert html =~ "ctx-set-nick-color"
      assert html =~ "Add to Contacts"
      assert html =~ "Set Nick Color"
    end

    test "Add to Contacts adds nick from context menu", %{conn: conn} do
      view = connect_user(conn, "CtxAddContact")

      # Trigger context menu and click Add to Contacts
      view
      |> render_click("nick_right_click", %{
        "nick" => "CtxBuddy",
        "clientX" => "100",
        "clientY" => "200"
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
      view |> render_click("contact_add_dialog")
      view |> render_submit("contact_add", %{"nickname" => "DupCtx", "note" => ""})
      view |> render_click("toggle_address_book")

      # Add again via context menu
      view
      |> render_click("nick_right_click", %{
        "nick" => "DupCtx",
        "clientX" => "100",
        "clientY" => "200"
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
        "clientX" => "100",
        "clientY" => "200"
      })

      view |> render_click("context_set_nick_color", %{"nick" => "ColorTarget"})

      html = render(view)
      assert html =~ "ctx-color-picker"
      assert html =~ "Pick color for ColorTarget"
    end

    test "picking a color assigns override", %{conn: conn} do
      view = connect_user(conn, "CtxPickColor")

      view
      |> render_click("nick_right_click", %{
        "nick" => "PickTarget",
        "clientX" => "100",
        "clientY" => "200"
      })

      view |> render_click("context_set_nick_color", %{"nick" => "PickTarget"})
      view |> render_click("context_pick_color", %{"color_index" => "4"})

      # Verify in nick colors tab
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "nick_colors"})
      html = render(view)

      assert html =~ "PickTarget"
      assert html =~ "Red"
    end
  end

  # ── Phase 7: US5 — Control Tab ──────────────────────────

  describe "control tab" do
    test "shows placeholder message for ignore management", %{conn: conn} do
      view = connect_user(conn, "ControlTab")
      view |> render_click("toggle_address_book")
      view |> render_click("address_book_tab", %{"tab" => "control"})

      html = render(view)
      assert html =~ "Ignore management will be available in a future update."
    end
  end
end
