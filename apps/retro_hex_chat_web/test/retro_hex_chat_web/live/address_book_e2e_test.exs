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
      refute render(view) =~ "address-book-dialog"

      html = render_click(view, "toggle_address_book")
      assert html =~ "address-book-dialog"
    end

    test "four tab headers visible", %{conn: conn} do
      view = connect_user(conn, "E2EAbTabs#{uid()}")
      render_click(view, "toggle_address_book")
      html = render(view)

      assert html =~ "address-book-tab-contacts"
      assert html =~ "address-book-tab-notify"
      assert html =~ "address-book-tab-nick-colors"
      assert html =~ "address-book-tab-control"
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
      html = render_click(view, "address_book_tab", %{"tab" => "nick_colors"})
      assert html =~ "No custom colors set. Nicknames use automatic colors."

      # Switch to Control
      html = render_click(view, "address_book_tab", %{"tab" => "control"})
      assert html =~ "Ignore management will be available in a future update."

      # Back to Contacts
      html = render_click(view, "address_book_tab", %{"tab" => "contacts"})
      assert html =~ "No contacts saved"
    end

    test "close button (toggle_address_book again) closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbClose#{uid()}")

      render_click(view, "toggle_address_book")
      assert render(view) =~ "address-book-dialog"

      render_click(view, "toggle_address_book")
      refute render(view) =~ "address-book-dialog"
    end

    test "Alt+B toggle opens and closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAltB#{uid()}")
      refute render(view) =~ "address-book-dialog"

      # Open
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "b", "altKey" => true})

      assert render(view) =~ "address-book-dialog"

      # Close
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "b", "altKey" => true})

      refute render(view) =~ "address-book-dialog"
    end

    test "toolbar button opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbTool#{uid()}")

      html =
        view
        |> element("[data-testid=\"toolbar-address-book\"]")
        |> render_click()

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

      today = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d")
      assert html =~ today
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

      view
      |> element("[data-testid=\"contact-remove-btn\"]")
      |> render_click()

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
      |> element("form.chat-input-form")
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
      assert render(view) =~ "Add to Notify List"

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

      view
      |> element("[data-testid=\"ab-notify-btn-remove\"]")
      |> render_click()

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
      render_click(view, "address_book_tab", %{"tab" => "nick_colors"})

      # Open add dialog
      render_click(view, "nick_color_add_dialog")
      assert render(view) =~ "Add Nick Color"

      # Submit with color 4 (Red)
      render_submit(view, "nick_color_add", %{"nickname" => "ColorBud", "color_index" => "4"})
      html = render(view)

      assert html =~ "ColorBud"
      assert html =~ "Red"
      assert html =~ "#ff0000"
    end

    test "edit color", %{conn: conn} do
      view = connect_user(conn, "E2ENcEdit#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "nick_colors"})

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
      assert html =~ "#0000fc"
    end

    test "remove override", %{conn: conn} do
      view = connect_user(conn, "E2ENcRm#{uid()}")
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "nick_colors"})

      # Add
      render_click(view, "nick_color_add_dialog")
      render_submit(view, "nick_color_add", %{"nickname" => "RmClr", "color_index" => "4"})
      assert render(view) =~ "RmClr"

      # Select and remove
      render_click(view, "nick_color_select", %{"nickname" => "RmClr"})

      view
      |> element("[data-testid=\"nick-color-remove-btn\"]")
      |> render_click()

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
      assert html =~ "Ignore management will be available in a future update."
    end

    test "context menu 'Add to Contacts' adds nick to contacts", %{conn: conn} do
      view = connect_user(conn, "E2ECtxAdd#{uid()}")

      # Trigger context menu on a nick
      render_click(view, "nick_right_click", %{
        "nick" => "CtxFriend",
        "clientX" => "100",
        "clientY" => "200"
      })

      # Click "Add to Contacts"
      render_click(view, "context_add_contact", %{"nick" => "CtxFriend"})

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
        "clientX" => "100",
        "clientY" => "200"
      })

      # Click "Set Nick Color"
      render_click(view, "context_set_nick_color", %{"nick" => "ClrTarget"})
      html = render(view)
      assert html =~ "ctx-color-picker"
      assert html =~ "Pick color for ClrTarget"

      # Pick a color (Red = 4)
      render_click(view, "context_pick_color", %{"color_index" => "4"})

      # Verify in nick colors tab
      render_click(view, "toggle_address_book")
      render_click(view, "address_book_tab", %{"tab" => "nick_colors"})
      html = render(view)

      assert html =~ "ClrTarget"
      assert html =~ "Red"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
