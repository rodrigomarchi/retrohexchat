defmodule RetroHexChatWeb.AddressBookE2ETest do
  @moduledoc """
  End-to-end tests for the Address Book feature (003).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Dialog Shell (T042)
  # ══════════════════════════════════════════════════════════════

  describe "US1: Dialog Shell" do
    test "toggle_address_book opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbOpen#{uid()}")
      refute has_element?(view, "#address-book-dialog-show-trigger")

      html = render_click(view, "toggle_address_book")
      assert html =~ "address-book-dialog"
    end

    test "four tab headers visible", %{conn: conn} do
      view = connect_user(conn, "E2EAbTabs#{uid()}")
      render_click(view, "toggle_address_book")
      html = render(view)

      assert html =~ "Contacts"
      assert html =~ "Notify"
      assert html =~ "Colors"
      assert html =~ "Control"
    end

    test "tab switching works — each tab shows its content", %{conn: conn} do
      view = connect_user(conn, "E2EAbSwitch#{uid()}")
      render_click(view, "toggle_address_book")

      # Default is contacts
      assert render(view) =~ "No contacts saved"

      # Switch to Notify
      html = render_click(view, "address_book_tab", %{"tab" => "notify"})
      assert html =~ "No entries. Click Add to track a nickname."

      # Switch to Nick Colors
      html = render_click(view, "address_book_tab", %{"tab" => "colors"})
      assert html =~ "No custom colors set. Nicknames use automatic colors."

      # Switch to Control
      html = render_click(view, "address_book_tab", %{"tab" => "control"})
      assert html =~ "No ignored users. Click Add to ignore a nickname."

      # Back to Contacts
      html = render_click(view, "address_book_tab", %{"tab" => "contacts"})
      assert html =~ "No contacts saved"
    end

    test "close button (toggle_address_book again) closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbClose#{uid()}")

      render_click(view, "toggle_address_book")
      assert render(view) =~ "address-book-dialog"

      render_click(view, "toggle_address_book")
      refute has_element?(view, "#address-book-dialog-show-trigger")
    end

    test "Ctrl+Shift+A toggle opens and closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAltB#{uid()}")
      refute has_element?(view, "#address-book-dialog-show-trigger")

      # Open
      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      assert render(view) =~ "address-book-dialog"

      # Close
      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      refute has_element?(view, "#address-book-dialog-show-trigger")
    end

    test "toggle_address_book event opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbTool#{uid()}")

      render_click(view, "toggle_address_book")
      html = render(view)
      assert html =~ "address-book-dialog"
    end

    test "Contacts is default tab", %{conn: conn} do
      view = connect_user(conn, "E2EAbDef#{uid()}")
      render_click(view, "toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Contacts Tab (T043)
  # ══════════════════════════════════════════════════════════════

  describe "US2: Contacts Tab" do
    test "add contact end-to-end", %{conn: conn} do
      view = connect_user(conn, "E2ECtAdd#{uid()}")
      render_click(view, "toggle_address_book")

      # Open add dialog
      render_click(view, "contact_add_dialog")
      assert render(view) =~ "Add Contact"

      # Submit the form
      render_submit(view, "contact_add", %{"nickname" => "E2EBuddy", "note" => "My E2E buddy"})
      html = render(view)

      assert html =~ "E2EBuddy"
      assert html =~ "My E2E buddy"
    end

    test "edit contact note", %{conn: conn} do
      view = connect_user(conn, "E2ECtEdit#{uid()}")
      render_click(view, "toggle_address_book")

      # Add a contact
      render_click(view, "contact_add_dialog")
      render_submit(view, "contact_add", %{"nickname" => "EditMe", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      render_click(view, "contact_select", %{"nickname" => "EditMe"})
      render_click(view, "contact_edit_dialog")
      assert render(view) =~ "Edit Contact"

      render_submit(view, "contact_edit", %{"nickname" => "EditMe", "note" => "new note"})
      html = render(view)

      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "remove contact", %{conn: conn} do
      view = connect_user(conn, "E2ECtRm#{uid()}")
      render_click(view, "toggle_address_book")

      # Add a contact
      render_click(view, "contact_add_dialog")
      render_submit(view, "contact_add", %{"nickname" => "RemoveMe", "note" => ""})
      assert render(view) =~ "RemoveMe"

      # Select and remove
      render_click(view, "contact_select", %{"nickname" => "RemoveMe"})
      render_click(view, "contact_remove")

      html = render(view)
      refute html =~ "contact-entry-RemoveMe"
      assert html =~ "No contacts saved"
    end

    test "duplicate error", %{conn: conn} do
      view = connect_user(conn, "E2ECtDup#{uid()}")
      render_click(view, "toggle_address_book")

      # Add first time
      render_click(view, "contact_add_dialog")
      render_submit(view, "contact_add", %{"nickname" => "DupNick", "note" => ""})

      # Add same nick again
      render_click(view, "contact_add_dialog")
      render_submit(view, "contact_add", %{"nickname" => "DupNick", "note" => ""})

      html = render(view)
      assert html =~ "already in your contacts"
    end

    test "empty state shows 'No contacts saved'", %{conn: conn} do
      view = connect_user(conn, "E2ECtEmp#{uid()}")
      render_click(view, "toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Notify Tab (T044)
  # ══════════════════════════════════════════════════════════════

  describe "US3: Notify Tab" do
    test "notify tab shows existing buddies added via /notify command", %{conn: conn} do
      view = connect_user(conn, "E2ENtSync#{uid()}")

      # Add buddy via /notify command
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/notify add SyncBud"})

      Process.sleep(50)

      # Open address book and switch to notify tab
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "notify"})

      html = render(view)
      assert html =~ "SyncBud"
    end

    test "add buddy via notify tab", %{conn: conn} do
      view = connect_user(conn, "E2ENtAdd#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "notify"})

      # Open add dialog
      render_click(view, "notify_add_dialog")
      assert render(view) =~ "Add Notify Entry"

      # Submit
      render_submit(view, "notify_add", %{"nickname" => "NtBuddy", "note" => "my notify buddy"})
      html = render(view)

      assert html =~ "NtBuddy"
      assert html =~ "my notify buddy"
    end

    test "remove buddy via notify tab", %{conn: conn} do
      view = connect_user(conn, "E2ENtRm#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "notify"})

      # Add then select and remove
      render_click(view, "notify_add_dialog")
      render_submit(view, "notify_add", %{"nickname" => "RmNotify", "note" => ""})
      assert render(view) =~ "RmNotify"

      render_click(view, "notify_select", %{"nickname" => "RmNotify"})
      render_click(view, "notify_remove", %{"nickname" => "RmNotify"})

      html = render(view)
      refute html =~ "ab-notify-entry-RmNotify"
      assert html =~ "No entries. Click Add to track a nickname."
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Nick Colors Tab (T045)
  # ══════════════════════════════════════════════════════════════

  describe "US4: Nick Colors Tab" do
    test "add nick color override", %{conn: conn} do
      view = connect_user(conn, "E2ENcAdd#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "colors"})

      # Open add dialog
      render_click(view, "nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      render_submit(view, "nick_color_add", %{"nickname" => "ColorBud", "color_index" => "4"})
      html = render(view)

      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "irc-bg-4"
    end

    test "edit color", %{conn: conn} do
      view = connect_user(conn, "E2ENcEdit#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "colors"})

      # Add with Red (4)
      render_click(view, "nick_color_add_dialog")
      render_submit(view, "nick_color_add", %{"nickname" => "EditClr", "color_index" => "4"})
      assert render(view) =~ "Red"

      # Select and edit to Blue (12)
      render_click(view, "nick_color_select", %{"nickname" => "EditClr"})
      render_click(view, "nick_color_edit_dialog")
      assert render(view) =~ "Edit Nick Color"

      render_submit(view, "nick_color_edit", %{"nickname" => "EditClr", "color_index" => "12"})
      html = render(view)

      assert html =~ "Blue"
      assert html =~ "irc-bg-12"
    end

    test "remove override", %{conn: conn} do
      view = connect_user(conn, "E2ENcRm#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "colors"})

      # Add
      render_click(view, "nick_color_add_dialog")
      render_submit(view, "nick_color_add", %{"nickname" => "RmClr", "color_index" => "4"})
      assert render(view) =~ "RmClr"

      # Select and remove
      render_click(view, "nick_color_select", %{"nickname" => "RmClr"})
      render_click(view, "nick_color_remove")

      html = render(view)
      refute html =~ "nick-color-entry-RmClr"
      assert html =~ "No custom colors set. Nicknames use automatic colors."
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 + Context Menu (T046)
  # ══════════════════════════════════════════════════════════════

  describe "US5: Control Tab and Context Menu" do
    test "control tab placeholder message", %{conn: conn} do
      view = connect_user(conn, "E2ECtrl#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "control"})

      html = render(view)
      assert html =~ "No ignored users. Click Add to ignore a nickname."
    end

    test "context menu 'Add to Contacts' adds nick to contacts", %{conn: conn} do
      view = connect_user(conn, "E2ECtxAdd#{uid()}")

      # Trigger context menu on a nick
      render_click(view, "nick_right_click", %{
        "nick" => "CtxFriend",
        "x" => "100",
        "y" => "200"
      })

      # Click "Add to Contacts" via nicklist context menu action dispatcher
      render_click(view, "nicklist_context_action", %{"action" => "context_add_contact"})

      # Open address book and verify contact is present
      render_click(view, "toggle_address_book")
      html = render(view)
      assert html =~ "CtxFriend"
    end

    test "context menu 'Set Nick Color' -> color picker -> color applied", %{conn: conn} do
      view = connect_user(conn, "E2ECtxClr#{uid()}")

      # Trigger context menu
      render_click(view, "nick_right_click", %{
        "nick" => "ClrTarget",
        "x" => "100",
        "y" => "200"
      })

      # Click "Set Nick Color" via nicklist context menu action dispatcher
      render_click(view, "nicklist_context_action", %{"action" => "context_set_nick_color"})
      html = render(view)
      assert html =~ "color-swatch-"

      # Pick a color (Red = 4) via nicklist context menu action dispatcher
      render_click(view, "nicklist_context_action", %{
        "action" => "context_pick_color",
        "color_index" => "4"
      })

      # Verify in nick colors tab
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "colors"})
      html = render(view)

      assert html =~ "ClrTarget"
      assert html =~ "Red"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
