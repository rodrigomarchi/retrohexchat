defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialog do
  @moduledoc """
  Stateful island for the Address Book — the saved-contacts list with its
  selection, note draft and add/edit sub-form modals.

  Mounted inside a server-managed desktop window: closing unmounts the island,
  resetting the selection, the note draft and any open sub-form. The
  `ContactList` mutations run here and produce a new `session`; the parent owns
  `session` (the central read-model), so the work bubbles up:

    * `{:ab_session, session, :contacts}` — parent assigns + persists.
    * `{:ab_status, level, msg}` — chat-surface status / system / error lines.

  Every event targets this component, and the two window-scoped sub-form modals
  get `phx-target={@myself}` threaded through the design-system
  `address_book_panel/1` so their typed inputs survive background re-renders
  (§0a-anti).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AddressBook

  alias RetroHexChat.Accounts.{ContactList, Session}

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
     |> assign(session: nil, nick_color_fn: nil, timezone: "Etc/UTC")}
  end

  # Opening is pure window mount — closing unmounts the island, so there is no
  # open directive to reset state that the next mount rebuilds anyway.
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Contacts ─────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("contact_select", %{"nickname" => nick}, socket) do
    note = contact_note(socket.assigns.session.contacts, nick)
    {:noreply, assign(socket, selected: nick, selected_contact_note: note)}
  end

  def handle_event("contact_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: true)}
  end

  def handle_event("contact_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: false)}
  end

  def handle_event("contact_add", %{"nickname" => nickname} = params, socket) do
    session = socket.assigns.session
    note = blank_to_nil(params["note"])

    case ContactList.add_entry(session.contacts, session.nickname, nickname, note) do
      {:ok, contacts} ->
        {:noreply,
         socket
         |> assign(show_contact_add_dialog: false)
         |> put_session(Session.set_contacts(session, contacts))
         |> bubble_status(
           :system,
           dgettext("chat", "Added %{nickname} to contacts", nickname: nickname)
         )}

      {:error, reason} ->
        {:noreply, bubble_status(socket, :system, contact_add_error(reason, nickname))}
    end
  end

  def handle_event("contact_edit_dialog", _params, socket) do
    note = contact_note(socket.assigns.session.contacts, socket.assigns.selected)
    {:noreply, assign(socket, show_contact_edit_dialog: true, selected_contact_note: note)}
  end

  def handle_event("contact_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_edit_dialog: false)}
  end

  def handle_event("contact_edit", %{"note" => note} = params, socket) do
    session = socket.assigns.session
    nickname = present_string(params["nickname"]) || socket.assigns.selected
    note = blank_to_nil(note)

    if is_nil(nickname) do
      {:noreply, bubble_status(socket, :system, dgettext("chat", "No contact selected"))}
    else
      case ContactList.update_note(session.contacts, nickname, note) do
        {:ok, contacts} ->
          {:noreply,
           socket
           |> assign(show_contact_edit_dialog: false, selected_contact_note: note || "")
           |> put_session(Session.set_contacts(session, contacts))
           |> bubble_status(
             :system,
             dgettext("chat", "Updated note for %{nickname}", nickname: nickname)
           )}

        {:error, :not_found} ->
          {:noreply,
           bubble_status(
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
         |> bubble_status(
           :system,
           dgettext("chat", "Removed %{nickname} from contacts", nickname: nick)
         )}

      {:error, :not_found} ->
        {:noreply,
         bubble_status(
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
        timezone={@timezone}
        selected_contact_note={@selected_contact_note}
        on_select="contact_select"
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
    assign(socket, session: session)
  end

  defp bubble_status(socket, level, message) do
    send(self(), {:ab_status, level, message})
    socket
  end

  # ── Local helpers ────────────────────────────────────────────────

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_value), do: nil

  defp blank_to_nil(value) when value in ["", nil], do: nil
  defp blank_to_nil(value), do: value

  defp contact_note(contact_list, nick) when is_binary(nick) do
    downcased = String.downcase(nick)

    contact_list.entries
    |> Enum.find(&(String.downcase(&1.contact_nickname) == downcased))
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
