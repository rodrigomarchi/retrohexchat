defmodule RetroHexChatWeb.ChatLive.Components.PerformDialog do
  @moduledoc """
  Stateful island for the Perform window body — the editor for the commands run
  automatically on connect, with add/edit/remove sub-form modals centered over
  the window. Mounted inside a server-managed desktop window: closing unmounts
  the island, resetting the selection and any open sub-form.

  Owns the selection and both sub-form `show_*` flags, every event, and the
  `PerformList` business logic. Every UI event targets this component
  (`phx-target={@target}` threaded through the design-system `perform_panel/1`),
  so the add/edit sub-forms submit to the component that owns their DOM subtree —
  the component-id matches, so LiveView preserves the typed input across
  background re-renders (the modal-in-modal anti-pattern, §0a-anti).

  The perform list lives on the `session`, which is the central chat read-model
  (the connect flow auto-runs perform, and the slash commands read it) — so it
  stays in the parent (§1d). The island runs the list mutations and bubbles the
  new session up via `send(self(), {:perform_dialog_session, session})`; the
  parent assigns it and fires the fire-and-forget persistence. Validation errors
  that belong to the chat surface bubble via
  `send(self(), {:perform_system_error, msg})`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.PerformDialog

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.PerformList

  @id "perform-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    selected: nil,
    show_add_dialog: false,
    show_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@initial)
     |> assign(session: nil)}
  end

  # Opening is pure window mount — closing unmounts the island, so there is no
  # open directive to reset state that the next mount rebuilds anyway.
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Selection ────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("perform_select", %{"position" => pos}, socket) do
    {:noreply, assign(socket, selected: String.to_integer(pos))}
  end

  # ── Sub-form open/close ──────────────────────────────────────────

  def handle_event("perform_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true)}
  end

  def handle_event("close_perform_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  def handle_event("perform_edit", _params, socket) do
    if socket.assigns.selected do
      {:noreply, assign(socket, show_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_perform_edit", _params, socket) do
    {:noreply, assign(socket, show_edit_dialog: false)}
  end

  def handle_event("perform_close", _params, socket) do
    send(self(), {:close_window, "perform"})
    {:noreply, socket}
  end

  # ── List mutations ───────────────────────────────────────────────

  def handle_event("perform_add_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_add_dialog: false)
         |> put_session(new_session)}

      {:error, reason} ->
        {:noreply,
         bubble_error(
           socket,
           dgettext("chat", "Failed to add perform command: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("perform_edit_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session
    position = socket.assigns.selected

    if position do
      updated_list = PerformList.update_entry(session.perform_list, position, command)
      new_session = Session.set_perform_list(session, updated_list)

      {:noreply,
       socket
       |> assign(show_edit_dialog: false)
       |> put_session(new_session)}
    else
      {:noreply, assign(socket, show_edit_dialog: false)}
    end
  end

  def handle_event("perform_remove", _params, socket) do
    position = socket.assigns.selected
    session = socket.assigns.session

    with true <- position != nil,
         {:ok, updated_list} <- PerformList.remove_entry(session.perform_list, position) do
      {:noreply,
       socket
       |> assign(selected: nil)
       |> put_session(Session.set_perform_list(session, updated_list))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("perform_move_up", _params, socket) do
    {:noreply, move(socket, -1)}
  end

  def handle_event("perform_move_down", _params, socket) do
    {:noreply, move(socket, +1)}
  end

  def handle_event("perform_toggle_enabled", _params, socket) do
    session = socket.assigns.session
    current = PerformList.enabled?(session.perform_list)
    updated_list = PerformList.set_enabled(session.perform_list, !current)

    {:noreply, put_session(socket, Session.set_perform_list(session, updated_list))}
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        entries: PerformList.entries(assigns.session.perform_list),
        enabled: PerformList.enabled?(assigns.session.perform_list)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.perform_panel
        id={@id}
        target={@myself}
        entries={@entries}
        selected={@selected}
        enabled={@enabled}
        show_add_dialog={@show_add_dialog}
        show_edit_dialog={@show_edit_dialog}
        on_select="perform_select"
        on_add="perform_add"
        on_edit="perform_edit"
        on_remove="perform_remove"
        on_move_up="perform_move_up"
        on_move_down="perform_move_down"
        on_toggle_enabled="perform_toggle_enabled"
        on_close="perform_close"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  defp move(socket, delta) do
    position = socket.assigns.selected
    session = socket.assigns.session
    target = if position, do: position + delta, else: nil

    with true <- valid_move?(position, session, delta),
         {:ok, updated_list} <- PerformList.move_entry(session.perform_list, position, target) do
      socket
      |> assign(selected: target)
      |> put_session(Session.set_perform_list(session, updated_list))
    else
      _ -> socket
    end
  end

  defp valid_move?(nil, _session, _delta), do: false
  defp valid_move?(position, _session, -1), do: position > 0

  defp valid_move?(position, session, +1),
    do: position < PerformList.count(session.perform_list) - 1

  # Optimistically reflect the new session locally (entries refresh this cycle)
  # while the parent assigns it as the canonical read-model and persists it.
  defp put_session(socket, session) do
    send(self(), {:perform_dialog_session, session})
    assign(socket, session: session)
  end

  defp bubble_error(socket, message) do
    send(self(), {:perform_system_error, message})
    socket
  end
end
