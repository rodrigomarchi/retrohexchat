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
  new session up via `send(self(), {:dialog_session, session, :autojoin})`; the
  parent assigns it and fires the fire-and-forget persistence. Validation errors
  that belong to the chat surface bubble via
  `DialogIsland.bubble/3`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AutojoinDialog

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChat.Text
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "autojoin-dialog",
    initial: %{
      selected: nil,
      show_add_dialog: false,
      show_edit_dialog: false
    }

  # Opening is pure window mount — closing unmounts the island, so there is no
  # open directive to reset state that the next mount rebuilds anyway.
  # ── Selection ────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  # ── Sub-form open/close ──────────────────────────────────────────

  def handle_event("autojoin_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true)}
  end

  def handle_event("close_autojoin_add", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  # The row press names the channel and opens it for editing.
  def handle_event("autojoin_edit", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, selected: channel, show_edit_dialog: true)}
  end

  def handle_event("close_autojoin_edit", _params, socket) do
    {:noreply, assign(socket, show_edit_dialog: false)}
  end

  # ── List mutations ───────────────────────────────────────────────

  def handle_event("autojoin_add_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = Text.blank_to_nil(params["key"])

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_add_dialog: false)
         |> put_session(new_session)}

      {:error, reason} ->
        {:noreply,
         DialogIsland.bubble_error(
           socket,
           dgettext("chat", "Failed to add auto-join channel: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("autojoin_edit_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = Text.blank_to_nil(params["key"])

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

  def handle_event("autojoin_remove", %{"channel" => channel}, socket) do
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
        on_add="autojoin_add"
        on_edit="autojoin_edit"
        on_remove="autojoin_remove"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  # Optimistically reflect the new session locally (entries refresh this cycle)
  # while the parent assigns it as the canonical read-model and persists it.
  defp put_session(socket, session) do
    send(self(), {:dialog_session, session, :autojoin})
    assign(socket, session: session)
  end
end
