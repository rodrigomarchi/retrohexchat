defmodule RetroHexChatWeb.ChatLive.Components.NotifyListDialog do
  @moduledoc """
  Stateful island for the standalone Notify List dialog — the tracked-buddy list
  with Add/Edit/Remove sub-forms and the auto-whois / auto-add-PM toggles.

  Mounted inside a server-managed desktop window (closing unmounts the island,
  resetting selection and sub-forms). Owns selection, note draft and both
  sub-form flags.
  It is a SEPARATE use case from the Address Book's Notify tab (they never open at
  once) — both read/mutate the same `session.notify_list` (the shared read-model)
  but neither leaks selection into the other because each owns its state locally.
  The mutation logic is shared through the pure `NotifyOps` helper.

  Every event targets this component (`phx-target={@target}` threaded through the
  design-system `notify_list/1`), so the window-scoped Add/Edit sub-form modals submit
  to the component that owns their DOM — the typed input survives the presence
  re-renders that flip buddies online/offline (§0a-anti).

  Session lives on the parent (the central read-model). The dialog runs the
  `NotifyOps` mutation and bubbles: `{:notify_dialog_session, session}` (parent
  assigns + persists), `{:notify_dialog_status, msg}` (status bar), and
  `{:notify_dialog_cancel_timer, nick}` on remove (the parent owns the debounce
  timers).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.NotifyList

  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.NotifyOps

  @id "notify-list-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    notify_selected: nil,
    selected_note: "",
    show_notify_add_dialog: false,
    show_notify_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@initial)
     |> assign(session: nil)}
  end

  # passthrough context (session)
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Selection / sub-form open-close ──────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("notify_select", %{"nickname" => nick}, socket) do
    note = NotifyOps.note_for(socket.assigns.session.notify_list, nick)
    {:noreply, assign(socket, notify_selected: nick, selected_note: note)}
  end

  def handle_event("notify_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: true)}
  end

  def handle_event("notify_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: false)}
  end

  def handle_event("notify_edit_dialog", _params, socket) do
    note = NotifyOps.note_for(socket.assigns.session.notify_list, socket.assigns.notify_selected)
    {:noreply, assign(socket, show_notify_edit_dialog: true, selected_note: note)}
  end

  def handle_event("notify_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_edit_dialog: false)}
  end

  # ── Mutations ────────────────────────────────────────────────────

  def handle_event("notify_add", %{"nickname" => nick} = params, socket) do
    case NotifyOps.add(socket.assigns.session, nick, params["note"]) do
      {:ok, session, status} ->
        {:noreply,
         socket
         |> assign(show_notify_add_dialog: false)
         |> put_session(session)
         |> bubble_status(status)}

      {:error, status} ->
        {:noreply, bubble_status(socket, status)}
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
           |> assign(notify_selected: nil, selected_note: "")
           |> put_session(session)
           |> bubble_status(status)}

        {:error, status} ->
          {:noreply, bubble_status(socket, status)}
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
         |> assign(show_notify_edit_dialog: false, selected_note: note || "")
         |> put_session(session)
         |> bubble_status(status)}

      {:error, status} ->
        {:noreply, bubble_status(socket, status)}
    end
  end

  def handle_event("toggle_auto_whois", _params, socket) do
    {:noreply, put_session(socket, NotifyOps.toggle_auto_whois(socket.assigns.session))}
  end

  def handle_event("toggle_auto_add_pm", _params, socket) do
    {:noreply, put_session(socket, NotifyOps.toggle_auto_add_pm(socket.assigns.session))}
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    notify_list = assigns.session.notify_list

    assigns =
      assign(assigns,
        entries: NotifyList.sorted_entries(notify_list),
        auto_whois: notify_list.settings.auto_whois,
        auto_add_pm: NotifyList.auto_add_pm?(notify_list)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.notify_panel
        id={@id}
        target={@myself}
        entries={@entries}
        selected_entry={@notify_selected}
        selected_note={@selected_note}
        auto_whois={@auto_whois}
        auto_add_pm={@auto_add_pm}
        show_add_dialog={@show_notify_add_dialog}
        show_edit_dialog={@show_notify_edit_dialog}
        on_select="notify_select"
        on_add="notify_add_dialog"
        on_edit="notify_edit_dialog"
        on_remove="notify_remove"
        on_toggle_auto_whois="toggle_auto_whois"
        on_toggle_auto_add_pm="toggle_auto_add_pm"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  defp put_session(socket, session) do
    send(self(), {:notify_dialog_session, session})
    assign(socket, session: session)
  end

  defp bubble_status(socket, message) do
    send(self(), {:notify_dialog_status, message})
    socket
  end
end
