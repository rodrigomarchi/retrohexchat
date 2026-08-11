defmodule RetroHexChatWeb.ChatLive.Components.AutojoinDialog do
  @moduledoc """
  Stateful island for the Auto-Join window body — the editor for the channels
  joined automatically on connect, with add/edit/remove sub-form modals centered
  over the window. Mounted inside a server-managed desktop window: closing
  unmounts the island, resetting the selection and any open sub-form.

  Owns the selection and both sub-form `show_*` flags, every event, and the
  `AutoJoinList` business logic. Every UI event targets this component
  (`phx-target={@target}` threaded through the design-system `autojoin_panel/1`),
  so the add/edit sub-forms submit to the component that owns their DOM subtree —
  the component-id matches, so LiveView preserves the typed input across
  background re-renders (the modal-in-modal anti-pattern, §0a-anti).

  The auto-join list lives on the `session`, which is the central chat read-model
  (the connect flow auto-joins from it, and the slash commands read it) — so it
  stays in the parent (§1d). The island runs the list mutations and bubbles the
  new session up via `send(self(), {:autojoin_dialog_session, session})`; the
  parent assigns it and fires the fire-and-forget persistence. Validation errors
  that belong to the chat surface bubble via
  `send(self(), {:autojoin_system_error, msg})`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AutojoinDialog

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  @id "autojoin-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    selected: nil,
    show_add_dialog: false,
    show_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: DialogIsland.mount(socket, @id, @initial)

  # Opening is pure window mount — closing unmounts the island, so there is no
  # open directive to reset state that the next mount rebuilds anyway.
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: DialogIsland.update(socket, assigns)

  # ── Selection ────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("autojoin_select", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, selected: channel)}
  end

  # ── Sub-form open/close ──────────────────────────────────────────

  def handle_event("autojoin_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true)}
  end

  def handle_event("close_autojoin_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  def handle_event("autojoin_edit", _params, socket) do
    if socket.assigns.selected do
      {:noreply, assign(socket, show_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_autojoin_edit", _params, socket) do
    {:noreply, assign(socket, show_edit_dialog: false)}
  end

  def handle_event("autojoin_close", _params, socket) do
    send(self(), {:close_window, "autojoin"})
    {:noreply, socket}
  end

  # ── List mutations ───────────────────────────────────────────────

  def handle_event("autojoin_add_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = blank_to_nil(params["key"])

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_add_dialog: false)
         |> put_session(new_session)}

      {:error, reason} ->
        {:noreply,
         bubble_error(
           socket,
           dgettext("chat", "Failed to add auto-join channel: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("autojoin_edit_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = blank_to_nil(params["key"])

    case AutoJoinList.update_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_edit_dialog: false)
         |> put_session(new_session)}

      {:error, _} ->
        {:noreply, assign(socket, show_edit_dialog: false)}
    end
  end

  def handle_event("autojoin_remove", _params, socket) do
    channel = socket.assigns.selected
    session = socket.assigns.session

    with true <- channel != nil,
         {:ok, updated_list} <- AutoJoinList.remove_entry(session.autojoin_list, channel) do
      {:noreply,
       socket
       |> assign(selected: nil)
       |> put_session(Session.set_autojoin_list(session, updated_list))}
    else
      _ -> {:noreply, socket}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :entries, AutoJoinList.entries(assigns.session.autojoin_list))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.autojoin_panel
        id={@id}
        target={@myself}
        entries={@entries}
        selected={@selected}
        show_add_dialog={@show_add_dialog}
        show_edit_dialog={@show_edit_dialog}
        on_select="autojoin_select"
        on_add="autojoin_add"
        on_edit="autojoin_edit"
        on_remove="autojoin_remove"
        on_close="autojoin_close"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  # Optimistically reflect the new session locally (entries refresh this cycle)
  # while the parent assigns it as the canonical read-model and persists it.
  defp put_session(socket, session) do
    send(self(), {:autojoin_dialog_session, session})
    assign(socket, session: session)
  end

  defp bubble_error(socket, message) do
    send(self(), {:autojoin_system_error, message})
    socket
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
