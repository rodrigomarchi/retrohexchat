defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialog do
  @moduledoc """
  Stateful island for the Address Book — the saved-contacts list with its
  selection, note draft and add/edit sub-form modals.

  Mounted inside a server-managed desktop window: closing unmounts the island,
  resetting the selection, the note draft and any open sub-form. The
  `ContactList` mutations run here and produce a new `session`; the parent owns
  `session` (the central read-model), so the work bubbles up:

    * `{:ab_session, session, :contacts}` — parent assigns + persists.
    * `DialogIsland.bubble/3` — chat-surface status / system / error lines.

  Every event targets this component, and the two window-scoped sub-form modals
  get `phx-target={@myself}` threaded through the design-system
  `address_book_panel/1` so their typed inputs survive background re-renders
  (§0a-anti).
  """

  alias RetroHexChat.Nickname
  alias RetroHexChat.Text
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AddressBook

  alias RetroHexChat.Accounts.{ContactList, Session}
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags

  @id "address-book-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    selected: nil,
    selected_contact_note: "",
    show_contact_add_dialog: false,
    show_contact_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@initial)
     |> assign(session: nil, nick_color_fn: nil, timezone: "Etc/UTC")
     |> assign(contact_locales: %{}, contact_locales_cache: nil)}
  end

  # Opening is pure window mount — closing unmounts the island, so there is no
  # open directive to reset state that the next mount rebuilds anyway.
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, socket |> assign(assigns) |> put_locales()}

  # ── Contacts ─────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("contact_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: true)}
  end

  def handle_event("contact_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: false)}
  end

  def handle_event("contact_add", %{"nickname" => nickname} = params, socket) do
    session = socket.assigns.session
    note = Text.blank_to_nil(params["note"])

    case ContactList.add_entry(session.contacts, Session.owner(session), nickname, note) do
      {:ok, contacts} ->
        {:noreply,
         socket
         |> assign(show_contact_add_dialog: false)
         |> put_session(Session.set_contacts(session, contacts))
         |> DialogIsland.bubble(
           :system,
           dgettext("chat", "Added %{nickname} to contacts", nickname: nickname)
         )}

      {:error, reason} ->
        {:noreply, DialogIsland.bubble(socket, :system, contact_add_error(reason, nickname))}
    end
  end

  # The row's Edit names the contact and opens it: the sub-form needs no
  # selection made beforehand.
  def handle_event("contact_edit_dialog", %{"nickname" => nick}, socket) do
    note = contact_note(socket.assigns.session.contacts, nick)

    {:noreply,
     assign(socket, selected: nick, show_contact_edit_dialog: true, selected_contact_note: note)}
  end

  def handle_event("contact_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_edit_dialog: false)}
  end

  def handle_event("contact_edit", %{"note" => note} = params, socket) do
    session = socket.assigns.session
    nickname = present_string(params["nickname"]) || socket.assigns.selected
    note = Text.blank_to_nil(note)

    if is_nil(nickname) do
      {:noreply, DialogIsland.bubble(socket, :system, dgettext("chat", "No contact selected"))}
    else
      case ContactList.update_note(session.contacts, nickname, note) do
        {:ok, contacts} ->
          {:noreply,
           socket
           |> assign(show_contact_edit_dialog: false, selected_contact_note: note || "")
           |> put_session(Session.set_contacts(session, contacts))
           |> DialogIsland.bubble(
             :system,
             dgettext("chat", "Updated note for %{nickname}", nickname: nickname)
           )}

        {:error, :not_found} ->
          {:noreply,
           DialogIsland.bubble(
             socket,
             :system,
             dgettext("chat", "%{nickname} is not in your contacts", nickname: nickname)
           )}
      end
    end
  end

  def handle_event("contact_remove", params, socket) do
    session = socket.assigns.session
    nick = params["nickname"] || socket.assigns.selected

    case ContactList.remove_entry(session.contacts, nick) do
      {:ok, contacts} ->
        {:noreply,
         socket
         |> assign(selected: nil)
         |> put_session(Session.set_contacts(session, contacts))
         |> DialogIsland.bubble(
           :system,
           dgettext("chat", "Removed %{nickname} from contacts", nickname: nick)
         )}

      {:error, :not_found} ->
        {:noreply,
         DialogIsland.bubble(
           socket,
           :system,
           dgettext("chat", "%{nickname} is not in your contacts", nickname: nick)
         )}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :contacts, ContactList.sorted_entries(assigns.session.contacts))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.address_book_panel
        id={@id}
        target={@myself}
        contacts={@contacts}
        selected={@selected}
        show_contact_add_dialog={@show_contact_add_dialog}
        show_contact_edit_dialog={@show_contact_edit_dialog}
        nick_color_fn={@nick_color_fn}
        locales={@contact_locales}
        timezone={@timezone}
        selected_contact_note={@selected_contact_note}
        on_add="contact_add_dialog"
        on_edit="contact_edit_dialog"
        on_remove="contact_remove"
      />
    </div>
    """
  end

  # ── Bubble helpers ───────────────────────────────────────────────

  defp put_session(socket, session) do
    send(self(), {:ab_session, session, :contacts})
    socket |> assign(session: session) |> put_locales()
  end

  # The flag beside each contact, asked for again only when the contacts are
  # different people — not on every re-render the parent sends down.
  defp put_locales(%{assigns: %{session: nil}} = socket), do: socket

  defp put_locales(socket) do
    nicks = Enum.map(socket.assigns.session.contacts.entries, & &1.contact_nickname)
    NickFlags.assign_locales(socket, nicks, :contact_locales, :contact_locales_cache)
  end

  # ── Local helpers ────────────────────────────────────────────────

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_value), do: nil

  defp contact_note(contact_list, nick) when is_binary(nick) do
    downcased = Nickname.key(nick)

    contact_list.entries
    |> Enum.find(&(Nickname.key(&1.contact_nickname) == downcased))
    |> case do
      nil -> ""
      entry -> Map.get(entry, :note) || ""
    end
  end

  defp contact_note(_contact_list, _nick), do: ""

  defp contact_add_error(:self_add, _nick),
    do: dgettext("chat", "Cannot add yourself to contacts")

  defp contact_add_error(:duplicate, nick),
    do: dgettext("chat", "%{nickname} is already in your contacts", nickname: nick)

  defp contact_add_error(:list_full, _nick),
    do: dgettext("chat", "Contact list is full (max 100 entries)")

  defp contact_add_error(:invalid_nickname, _nick), do: dgettext("chat", "Invalid nickname")
end
