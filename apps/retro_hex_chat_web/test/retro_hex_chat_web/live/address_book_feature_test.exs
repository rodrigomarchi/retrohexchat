defmodule RetroHexChatWeb.AddressBookFeatureTest do
  @moduledoc """
  End-to-end tests for the Address Book feature (003).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # The Address Book is a stateful island; events target the component, so fire
  # them element-based (scoped to the dialog — notify_* collide with the
  # standalone Notify dialog).
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

  # ══════════════════════════════════════════════════════════════
  # US1 — Dialog Shell (T042)
  # ══════════════════════════════════════════════════════════════

  describe "US1: Dialog Shell" do
    test "toggle_address_book opens dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAbOpen#{uid()}")
      refute has_element?(view, ~s([data-window-id="address-book"]))

      html = render_click(view, "toggle_address_book")
      assert html =~ "address-book-dialog"
    end

    test "the window carries contacts only", %{conn: conn} do
      view = connect_user(conn, "E2EAbScope#{uid()}")
      render_click(view, "toggle_address_book")
      html = render(view)

      assert html =~ "No contacts saved"
      refute html =~ "No entries. Click Add to track a nickname."
      refute html =~ "No custom colors set. Nicknames use automatic colors."
      refute html =~ "No ignored users. Click Add to ignore a nickname."
    end

    test "the window X reports the close and the island unmounts", %{conn: conn} do
      view = connect_user(conn, "E2EAbClose#{uid()}")

      render_click(view, "toggle_address_book")
      assert has_element?(view, ~s([data-window-id="address-book"]))

      render_hook(view, "window_closed", %{"id" => "address-book"})
      refute has_element?(view, ~s([data-window-id="address-book"]))
    end

    test "Ctrl+Shift+A toggle opens and closes dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAltB#{uid()}")
      refute has_element?(view, ~s([data-window-id="address-book"]))

      # Open
      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      assert has_element?(view, ~s([data-window-id="address-book"]))

      # Re-invoking focuses (never toggle-closes); the client contract closes.
      render_click(view, "window_keydown", %{"key" => "a", "ctrlKey" => true, "shiftKey" => true})
      assert has_element?(view, ~s([data-window-id="address-book"]))

      render_hook(view, "window_closed", %{"id" => "address-book"})
      refute has_element?(view, ~s([data-window-id="address-book"]))
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
      ab_click(view, "contact_add_dialog")
      assert render(view) =~ "Add Contact"

      # Submit the form
      ab_form(view, "contact-add-form", %{"nickname" => "E2EBuddy", "note" => "My E2E buddy"})
      html = render(view)

      assert html =~ "E2EBuddy"
      assert html =~ "My E2E buddy"
    end

    test "edit contact note", %{conn: conn} do
      view = connect_user(conn, "E2ECtEdit#{uid()}")
      render_click(view, "toggle_address_book")

      # Add a contact
      ab_click(view, "contact_add_dialog")
      ab_form(view, "contact-add-form", %{"nickname" => "EditMe", "note" => "old note"})
      assert render(view) =~ "old note"

      # Select and edit
      ab_select(view, "contact_select", "EditMe")
      ab_click(view, "contact_edit_dialog")
      assert render(view) =~ "Edit Contact"

      ab_form(view, "contact-edit-form", %{"nickname" => "EditMe", "note" => "new note"})
      html = render(view)

      assert html =~ "new note"
      refute html =~ "old note"
    end

    test "remove contact", %{conn: conn} do
      view = connect_user(conn, "E2ECtRm#{uid()}")
      render_click(view, "toggle_address_book")

      # Add a contact
      ab_click(view, "contact_add_dialog")
      ab_form(view, "contact-add-form", %{"nickname" => "RemoveMe", "note" => ""})
      assert render(view) =~ "RemoveMe"

      # Select and remove
      ab_select(view, "contact_select", "RemoveMe")
      ab_click(view, "contact_remove")

      html = render(view)
      refute html =~ "contact-entry-RemoveMe"
      assert html =~ "No contacts saved"
    end

    test "duplicate error", %{conn: conn} do
      view = connect_user(conn, "E2ECtDup#{uid()}")
      render_click(view, "toggle_address_book")

      # Add first time
      ab_click(view, "contact_add_dialog")
      ab_form(view, "contact-add-form", %{"nickname" => "DupNick", "note" => ""})

      # Add same nick again
      ab_click(view, "contact_add_dialog")
      ab_form(view, "contact-add-form", %{"nickname" => "DupNick", "note" => ""})

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
