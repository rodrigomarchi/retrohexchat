defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialog do
  @moduledoc """
  Stateful island for the Address Book — the four-tab mini-app (Contacts, Notify,
  Nick Colors, Control/Ignore), each with its own selection, note/draft and modal
  sub-forms.

  Mounted inside a server-managed desktop window: closing unmounts the island
  (resetting tab, selections, drafts and sub-forms); opening on a specific tab
  is a `send_update(open: tab)` after the window mounts. Owns the tab, the four
  selections, the note drafts, the palette-edit index, and all seven sub-form
  flags, plus every event. The domain
  mutations (`ContactList`/`NickColors`/`IgnoreList`/`NotifyOps`) run here and
  produce a new `session`; the parent owns `session` (the central read-model) so
  the work bubbles up:

    * `{:ab_session, session, kind}` — parent assigns + persists; for `:nick_colors`
      it also rebuilds `nick_color_fn` and refreshes the active message stream.
    * `{:ab_status, level, msg}` — chat-surface status / system / error lines.
    * `{:ab_ignore_timer, op, ...}` — the parent owns the ignore debounce timers.

  Every event targets this component: the passed-in callbacks are `JS.push(..,
  target: @myself)` structs, and the seven window-scoped sub-form modals get
  `phx-target={@myself}` threaded through the design-system `address_book/1` so
  their typed inputs survive background re-renders (§0a-anti). The Nick-Color add
  sub-form additionally uses `phx-update="ignore"` because its in-form color
  picker re-renders this component (like the highlight dialog).

  The Notify tab shares its mutation logic with the standalone Notify List dialog
  via the pure `NotifyOps` helper — they are separate use cases over the same
  `session.notify_list`, each owning its own UI state.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.ChatLive.Helpers, only: [parse_dialog_duration: 1]

  alias Phoenix.LiveView.JS
  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.NotifyOps

  @id "address-book-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    address_book_tab: "contacts",
    contacts_selected: nil,
    selected_contact_note: "",
    show_contact_add_dialog: false,
    show_contact_edit_dialog: false,
    notify_selected: nil,
    selected_notify_note: "",
    show_notify_add_dialog: false,
    show_notify_edit_dialog: false,
    nick_colors_selected: nil,
    nick_palette_editing_index: nil,
    show_nick_color_add_dialog: false,
    show_nick_color_edit_dialog: false,
    control_selected: nil,
    show_control_add_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@initial)
     |> assign(session: nil, nick_color_fn: nil, timezone: "Etc/UTC")}
  end

  # ── Directives ───────────────────────────────────────────────────

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{open: tab}, socket) do
    {:ok, assign(socket, %{@initial | address_book_tab: tab || "contacts"})}
  end

  # passthrough context (session, nick_color_fn, timezone)
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Tab ──────────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("address_book_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, address_book_tab: tab)}
  end

  # ── Contacts ─────────────────────────────────────────────────────

  def handle_event("contact_select", %{"nickname" => nick}, socket) do
    note = contact_note(socket.assigns.session.contacts, nick)
    {:noreply, assign(socket, contacts_selected: nick, selected_contact_note: note)}
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
         |> put_session(Session.set_contacts(session, contacts), :contacts)
         |> bubble_status(
           :system,
           dgettext("chat", "Added %{nickname} to contacts", nickname: nickname)
         )}

      {:error, reason} ->
        {:noreply, bubble_status(socket, :system, contact_add_error(reason, nickname))}
    end
  end

  def handle_event("contact_edit_dialog", _params, socket) do
    note = contact_note(socket.assigns.session.contacts, socket.assigns.contacts_selected)
    {:noreply, assign(socket, show_contact_edit_dialog: true, selected_contact_note: note)}
  end

  def handle_event("contact_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_edit_dialog: false)}
  end

  def handle_event("contact_edit", %{"note" => note} = params, socket) do
    session = socket.assigns.session
    nickname = present_string(params["nickname"]) || socket.assigns.contacts_selected
    note = blank_to_nil(note)

    if is_nil(nickname) do
      {:noreply, bubble_status(socket, :system, dgettext("chat", "No contact selected"))}
    else
      case ContactList.update_note(session.contacts, nickname, note) do
        {:ok, contacts} ->
          {:noreply,
           socket
           |> assign(show_contact_edit_dialog: false, selected_contact_note: note || "")
           |> put_session(Session.set_contacts(session, contacts), :contacts)
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
    nick = params["nickname"] || socket.assigns.contacts_selected

    case ContactList.remove_entry(session.contacts, nick) do
      {:ok, contacts} ->
        {:noreply,
         socket
         |> assign(contacts_selected: nil)
         |> put_session(Session.set_contacts(session, contacts), :contacts)
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

  # ── Nick colors ──────────────────────────────────────────────────

  def handle_event("nick_color_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, nick_colors_selected: nick)}
  end

  def handle_event("nick_palette_pick", %{"index" => idx_str}, socket) do
    {:noreply, assign(socket, nick_palette_editing_index: String.to_integer(idx_str))}
  end

  def handle_event("nick_color_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_nick_color_add_dialog: true, nick_palette_editing_index: nil)}
  end

  def handle_event("nick_color_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_nick_color_add_dialog: false)}
  end

  def handle_event(
        "nick_color_add",
        %{"nickname" => nickname, "color_index" => color_str},
        socket
      ) do
    session = socket.assigns.session
    nickname = String.trim(nickname)

    case NickColors.add_entry(session.nick_colors, nickname, String.to_integer(color_str)) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_nick_color_add_dialog: false)
         |> put_session(Session.set_nick_colors(session, updated), :nick_colors)}

      {:error, reason} ->
        {:noreply, bubble_status(socket, :error, nick_color_add_error(reason, nickname))}
    end
  end

  def handle_event("nick_color_edit_dialog", _params, socket) do
    color =
      NickColors.color_index_for(
        socket.assigns.session.nick_colors,
        socket.assigns.nick_colors_selected
      )

    {:noreply,
     assign(socket, show_nick_color_edit_dialog: true, nick_palette_editing_index: color)}
  end

  def handle_event("nick_color_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_nick_color_edit_dialog: false)}
  end

  def handle_event("nick_color_edit", %{"color_index" => color_str} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.nick_colors_selected

    case NickColors.update_color(session.nick_colors, nickname, String.to_integer(color_str)) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_nick_color_edit_dialog: false)
         |> put_session(Session.set_nick_colors(session, updated), :nick_colors)}

      {:error, :not_found} ->
        {:noreply, bubble_status(socket, :error, dgettext("chat", "Nick color entry not found"))}

      {:error, :invalid_color} ->
        {:noreply, bubble_status(socket, :error, dgettext("chat", "Invalid color"))}
    end
  end

  def handle_event("nick_color_remove", params, socket) do
    session = socket.assigns.session
    nick = params["nickname"] || socket.assigns.nick_colors_selected

    case NickColors.remove_entry(session.nick_colors, nick) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(nick_colors_selected: nil)
         |> put_session(Session.set_nick_colors(session, updated), :nick_colors)
         |> bubble_status(
           :system,
           dgettext("chat", "Removed custom color for %{nickname}", nickname: nick)
         )}

      {:error, :not_found} ->
        {:noreply,
         bubble_status(
           socket,
           :system,
           dgettext("chat", "%{nickname} has no custom color", nickname: nick)
         )}
    end
  end

  # ── Control / Ignore ─────────────────────────────────────────────

  def handle_event("control_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, control_selected: nick)}
  end

  def handle_event("control_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_control_add_dialog: true)}
  end

  def handle_event("control_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_control_add_dialog: false)}
  end

  def handle_event("control_add_confirm", params, socket) do
    nick = params["nickname"]
    type = String.to_existing_atom(params["type"])
    duration_str = params["duration"]
    session = socket.assigns.session

    cond do
      String.downcase(String.trim(nick)) == String.downcase(session.nickname) ->
        {:noreply,
         bubble_status(socket, :error_event, dgettext("chat", "You cannot ignore yourself"))}

      duration_str not in [nil, ""] and match?({nil, nil}, parse_dialog_duration(duration_str)) ->
        {:noreply,
         bubble_status(
           socket,
           :error_event,
           dgettext("chat", "Invalid duration format. Use: 5m, 2h, or 1d")
         )}

      true ->
        {duration, expires_at} = parse_dialog_duration(duration_str)

        case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
          {:ok, updated_list} ->
            send(self(), {:ab_ignore_timer, :restart, nick, duration})

            {:noreply,
             socket
             |> assign(show_control_add_dialog: false)
             |> put_session(Session.set_ignore_list(session, updated_list), :ignore)
             |> bubble_status(
               :system_event,
               dgettext("chat", "* %{nickname} is now ignored (%{type})",
                 nickname: nick,
                 type: ignore_type_label(type)
               )
             )}

          {:error, reason} ->
            {:noreply,
             bubble_status(
               socket,
               :error_event,
               dgettext("chat", "Failed to add ignore: %{reason}", reason: reason)
             )}
        end
    end
  end

  def handle_event("control_remove", _params, socket) do
    nick = socket.assigns.control_selected
    session = socket.assigns.session

    with true <- nick != nil,
         {:ok, updated_list} <- IgnoreList.remove_entry(session.ignore_list, nick) do
      send(self(), {:ab_ignore_timer, :remove, nick})

      {:noreply,
       socket
       |> assign(control_selected: nil)
       |> put_session(Session.set_ignore_list(session, updated_list), :ignore)
       |> bubble_status(
         :system_event,
         dgettext("chat", "* %{nickname} is no longer ignored", nickname: nick)
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  # ── Notify tab (shares NotifyOps with the standalone dialog) ──────

  def handle_event("notify_select", %{"nickname" => nick}, socket) do
    note = NotifyOps.note_for(socket.assigns.session.notify_list, nick)
    {:noreply, assign(socket, notify_selected: nick, selected_notify_note: note)}
  end

  def handle_event("notify_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: true)}
  end

  def handle_event("notify_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: false)}
  end

  def handle_event("notify_edit_dialog", _params, socket) do
    note = NotifyOps.note_for(socket.assigns.session.notify_list, socket.assigns.notify_selected)
    {:noreply, assign(socket, show_notify_edit_dialog: true, selected_notify_note: note)}
  end

  def handle_event("notify_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_edit_dialog: false)}
  end

  def handle_event("notify_add", %{"nickname" => nick} = params, socket) do
    case NotifyOps.add(socket.assigns.session, nick, params["note"]) do
      {:ok, session, status} ->
        {:noreply,
         socket
         |> assign(show_notify_add_dialog: false)
         |> put_session(session, :notify)
         |> bubble_status(:system, status)}

      {:error, status} ->
        {:noreply, bubble_status(socket, :system, status)}
    end
  end

  def handle_event("notify_remove", params, socket) do
    nick = params["nickname"] || socket.assigns.notify_selected

    if nick do
      case NotifyOps.remove(socket.assigns.session, nick) do
        {:ok, session, status} ->
          send(self(), {:notify_dialog_cancel_timer, nick})

          {:noreply,
           socket
           |> assign(notify_selected: nil, selected_notify_note: "")
           |> put_session(session, :notify)
           |> bubble_status(:system, status)}

        {:error, status} ->
          {:noreply, bubble_status(socket, :system, status)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("notify_edit", %{"nickname" => nick, "note" => note}, socket) do
    case NotifyOps.update_note(socket.assigns.session, nick, note) do
      {:ok, session, status} ->
        {:noreply,
         socket
         |> assign(show_notify_edit_dialog: false, selected_notify_note: note || "")
         |> put_session(session, :notify)
         |> bubble_status(:system, status)}

      {:error, status} ->
        {:noreply, bubble_status(socket, :system, status)}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        contacts: ContactList.sorted_entries(session.contacts),
        notify_entries: NotifyList.sorted_entries(session.notify_list),
        nick_color_entries: NickColors.sorted_entries(session.nick_colors),
        control_entries: IgnoreList.sorted_entries(session.ignore_list)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.address_book_panel
        id={@id}
        target={@myself}
        selected_tab={@address_book_tab}
        contacts={@contacts}
        selected_index={@contacts_selected}
        notify_list={@notify_entries}
        nick_colors={@nick_color_entries}
        control_list={@control_entries}
        control_selected={@control_selected}
        show_contact_add_dialog={@show_contact_add_dialog}
        show_contact_edit_dialog={@show_contact_edit_dialog}
        show_notify_add_dialog={@show_notify_add_dialog}
        show_notify_edit_dialog={@show_notify_edit_dialog}
        show_nick_color_add_dialog={@show_nick_color_add_dialog}
        show_nick_color_edit_dialog={@show_nick_color_edit_dialog}
        show_control_add_dialog={@show_control_add_dialog}
        nick_color_fn={@nick_color_fn}
        timezone={@timezone}
        contacts_selected={@contacts_selected}
        nick_colors_selected={@nick_colors_selected}
        notify_selected={@notify_selected}
        selected_contact_note={@selected_contact_note}
        selected_notify_note={@selected_notify_note}
        nick_palette_editing_index={@nick_palette_editing_index}
        on_select="contact_select"
        on_add="contact_add_dialog"
        on_edit="contact_edit_dialog"
        on_remove="contact_remove"
        on_notify_select="notify_select"
        on_notify_add="notify_add_dialog"
        on_notify_edit="notify_edit_dialog"
        on_notify_remove="notify_remove"
        on_nick_color_select="nick_color_select"
        on_nick_color_add="nick_color_add_dialog"
        on_nick_color_edit="nick_color_edit_dialog"
        on_nick_color_remove="nick_color_remove"
        on_control_select="control_select"
        on_control_add="control_add_dialog"
        on_control_remove="control_remove"
        on_tab={JS.push("address_book_tab", target: @myself)}
      />
    </div>
    """
  end

  # ── Bubble helpers ───────────────────────────────────────────────

  defp put_session(socket, session, kind) do
    send(self(), {:ab_session, session, kind})
    assign(socket, session: session)
  end

  defp bubble_status(socket, level, message) do
    send(self(), {:ab_status, level, message})
    socket
  end

  # ── Local helpers (moved from address_book_events) ───────────────

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_value), do: nil

  defp blank_to_nil(value) when value in ["", nil], do: nil
  defp blank_to_nil(value), do: value

  defp ignore_type_label(:all), do: dgettext("chat", "all")
  defp ignore_type_label(:messages), do: dgettext("chat", "messages")
  defp ignore_type_label(:notices), do: dgettext("chat", "notices")
  defp ignore_type_label(:invites), do: dgettext("chat", "invites")
  defp ignore_type_label(type), do: to_string(type)

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

  defp nick_color_add_error(:duplicate, nick),
    do: dgettext("chat", "%{nickname} already has a custom color", nickname: nick)

  defp nick_color_add_error(:list_full, _nick),
    do: dgettext("chat", "Nick color list is full (max 50)")

  defp nick_color_add_error(:invalid_nickname, _nick), do: dgettext("chat", "Invalid nickname")
  defp nick_color_add_error(:invalid_color, _nick), do: dgettext("chat", "Invalid color")
end
