defmodule RetroHexChatWeb.ChatLive.AddressBookEvents do
  @moduledoc """
  Handle events for the Address Book dialog (Contacts + Nick Colors).

  Covers: toggle_address_book, address_book_tab,
  contact_select, contact_add_dialog, contact_add_cancel, contact_add,
  contact_edit_dialog, contact_edit_cancel, contact_edit, contact_remove,
  nick_color_select, nick_color_add_dialog, nick_color_add_cancel, nick_color_add,
  nick_color_edit_dialog, nick_color_edit_cancel, nick_color_edit, nick_color_remove.

  Attached as `attach_hook(:address_book_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      maybe_persist_contacts: 2,
      maybe_persist_nick_colors: 2,
      rebuild_nick_color_fn: 2,
      push_status_message: 3
    ]

  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}

  def handle_event("toggle_address_book", _params, socket) do
    if socket.assigns.show_address_book do
      {:halt,
       assign(socket,
         show_address_book: false,
         address_book_tab: "contacts",
         contacts_selected: nil,
         show_contact_add_dialog: false,
         show_contact_edit_dialog: false,
         nick_colors_selected: nil,
         show_nick_color_add_dialog: false,
         show_nick_color_edit_dialog: false
       )}
    else
      {:halt, assign(socket, show_address_book: true)}
    end
  end

  def handle_event("address_book_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, address_book_tab: tab)}
  end

  # ── Contact CRUD events ─────────────────────────────────────

  def handle_event("contact_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, contacts_selected: nick)}
  end

  def handle_event("contact_add_dialog", _params, socket) do
    {:halt, assign(socket, show_contact_add_dialog: true)}
  end

  def handle_event("contact_add_cancel", _params, socket) do
    {:halt, assign(socket, show_contact_add_dialog: false)}
  end

  def handle_event("contact_add", %{"nickname" => nickname} = params, socket) do
    session = socket.assigns.session
    note = params["note"]
    note = if note == "", do: nil, else: note

    case ContactList.add_entry(session.contacts, session.nickname, nickname, note) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:halt,
         socket
         |> assign(session: new_session, show_contact_add_dialog: false)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Added #{nickname} to contacts", :system)}

      {:error, :self_add} ->
        {:halt, push_status_message(socket, "Cannot add yourself to contacts", :system)}

      {:error, :duplicate} ->
        {:halt, push_status_message(socket, "#{nickname} is already in your contacts", :system)}

      {:error, :list_full} ->
        {:halt, push_status_message(socket, "Contact list is full (max 100 entries)", :system)}

      {:error, :invalid_nickname} ->
        {:halt, push_status_message(socket, "Invalid nickname", :system)}
    end
  end

  def handle_event("contact_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_contact_edit_dialog: true)}
  end

  def handle_event("contact_edit_cancel", _params, socket) do
    {:halt, assign(socket, show_contact_edit_dialog: false)}
  end

  def handle_event("contact_edit", %{"note" => note} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.contacts_selected
    note = if note == "", do: nil, else: note

    case ContactList.update_note(session.contacts, nickname, note) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:halt,
         socket
         |> assign(session: new_session, show_contact_edit_dialog: false)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Updated note for #{nickname}", :system)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "#{nickname} is not in your contacts", :system)}
    end
  end

  def handle_event("contact_remove", params, socket) do
    session = socket.assigns.session
    nick = params["nickname"] || socket.assigns.contacts_selected

    case ContactList.remove_entry(session.contacts, nick) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:halt,
         socket
         |> assign(session: new_session, contacts_selected: nil)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Removed #{nick} from contacts", :system)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "#{nick} is not in your contacts", :system)}
    end
  end

  # ── Nick color CRUD events ──────────────────────────────────

  def handle_event("nick_color_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, nick_colors_selected: nick)}
  end

  def handle_event("nick_color_add_dialog", _params, socket) do
    {:halt, assign(socket, show_nick_color_add_dialog: true)}
  end

  def handle_event("nick_color_add_cancel", _params, socket) do
    {:halt, assign(socket, show_nick_color_add_dialog: false)}
  end

  def handle_event(
        "nick_color_add",
        %{"nickname" => nickname, "color_index" => color_str},
        socket
      ) do
    session = socket.assigns.session
    nickname = String.trim(nickname)
    color_index = String.to_integer(color_str)

    case NickColors.add_entry(session.nick_colors, nickname, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, show_nick_color_add_dialog: false)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)}

      {:error, :duplicate} ->
        {:halt, push_status_message(socket, "#{nickname} already has a custom color", :error)}

      {:error, :list_full} ->
        {:halt, push_status_message(socket, "Nick color list is full (max 50)", :error)}

      {:error, :invalid_nickname} ->
        {:halt, push_status_message(socket, "Invalid nickname", :error)}

      {:error, :invalid_color} ->
        {:halt, push_status_message(socket, "Invalid color", :error)}
    end
  end

  def handle_event("nick_color_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_nick_color_edit_dialog: true)}
  end

  def handle_event("nick_color_edit_cancel", _params, socket) do
    {:halt, assign(socket, show_nick_color_edit_dialog: false)}
  end

  def handle_event("nick_color_edit", %{"color_index" => color_str} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.nick_colors_selected
    color_index = String.to_integer(color_str)

    case NickColors.update_color(session.nick_colors, nickname, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, show_nick_color_edit_dialog: false)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "Nick color entry not found", :error)}

      {:error, :invalid_color} ->
        {:halt, push_status_message(socket, "Invalid color", :error)}
    end
  end

  def handle_event("nick_color_remove", params, socket) do
    session = socket.assigns.session
    nick = params["nickname"] || socket.assigns.nick_colors_selected

    case NickColors.remove_entry(session.nick_colors, nick) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, nick_colors_selected: nil)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)
         |> push_status_message("Removed custom color for #{nick}", :system)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "#{nick} has no custom color", :system)}
    end
  end

  # ── Catch-all ───────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
