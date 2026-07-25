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

  describe "the window carries contacts only" do
    test "opens on the contacts list, with no sibling-window content", %{conn: conn} do
      view = connect_user(conn, "AbScope")
      view |> render_click("toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
      refute html =~ "No entries. Click Add to track a nickname."
      refute html =~ "No custom colors set. Nicknames use automatic colors."
      refute html =~ "No ignored users. Click Add to ignore a nickname."
    end

    test "reopening the window resets the selection", %{conn: conn} do
      view = connect_user(conn, "AbReset")
      view |> render_click("toggle_address_book")

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
      view |> render_click("open_nick_colors_dialog")
      html = render(view)

      assert html =~ "PickTarget"
      assert html =~ "Red"
    end
  end

  # ── Phase 6b: Notify Presence Sync ──────────────────────
end
