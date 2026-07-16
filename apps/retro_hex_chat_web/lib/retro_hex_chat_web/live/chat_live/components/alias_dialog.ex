defmodule RetroHexChatWeb.ChatLive.Components.AliasDialog do
  @moduledoc """
  Stateful LiveComponent for the Alias editor window body — the inline-edit-list
  pattern. Mounted inside a server-managed desktop window (presence in the DOM
  means open; closing unmounts the island, resetting the draft); the `aliases`
  list is parent data passed through.

  The component owns the dialog's UI/draft state: `selected`, `editing`,
  `draft_name`, `draft_expansion`, `warning`, `error`. Pure-UI events
  (select/add/edit/cancel) are handled component-locally (`@myself`). Mutating
  events (save/delete) bubble to the parent (they need the session + persistence)
  carrying `selected` via `JS.push`; the parent reflects results back via
  `send_update/2`:

  - `{:saved, selected, warning}` — entry saved; show it selected, clear the draft
  - `{:error, message}`          — validation error inside the edit form
  - `:deleted`                   — entry removed; clear selection
  - `:reset`                     — close cleanup (clear all UI state)
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AliasDialog

  alias RetroHexChat.Chat.AliasList

  @id "alias-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       aliases: nil,
       selected: nil,
       editing: false,
       draft_name: "",
       draft_expansion: "",
       warning: nil,
       error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action} = assigns, socket) do
    {:ok, socket |> assign_passthrough(assigns) |> dispatch(action)}
  end

  def update(assigns, socket), do: {:ok, assign_passthrough(socket, assigns)}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("alias_select", %{"name" => name}, socket) do
    {:noreply, assign(socket, selected: name, editing: false)}
  end

  def handle_event("alias_dialog_add", _params, socket) do
    {:noreply,
     assign(socket,
       editing: true,
       selected: nil,
       draft_name: "",
       draft_expansion: "",
       warning: nil,
       error: nil
     )}
  end

  def handle_event("alias_dialog_edit", _params, socket) do
    entry =
      socket.assigns.selected &&
        AliasList.find_entry(socket.assigns.aliases, socket.assigns.selected)

    if entry do
      {:noreply,
       assign(socket,
         editing: true,
         draft_name: entry.name,
         draft_expansion: entry.expansion,
         error: nil
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("alias_dialog_cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false, draft_name: "", draft_expansion: "", error: nil)}
  end

  def handle_event("alias_dialog_close", _params, socket) do
    send(self(), {:close_window, "alias"})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :entries, entries(assigns.aliases))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.alias_panel
        id={@id}
        aliases={@entries}
        selected_alias={@selected}
        editing={@editing}
        draft_name={@draft_name}
        draft_expansion={@draft_expansion}
        warning_message={@warning}
        error_message={@error}
        on_select={JS.push("alias_select", target: @myself)}
        on_add={JS.push("alias_dialog_add", target: @myself)}
        on_edit={JS.push("alias_dialog_edit", target: @myself)}
        on_save={JS.push("alias_dialog_save", value: %{selected: @selected})}
        on_delete={JS.push("alias_dialog_delete", value: %{selected: @selected})}
        on_cancel_edit={JS.push("alias_dialog_cancel_edit", target: @myself)}
        on_close={JS.push("alias_dialog_close", target: @myself)}
      />
    </div>
    """
  end

  @spec assign_passthrough(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_passthrough(socket, assigns) do
    assign(socket,
      aliases: Map.get(assigns, :aliases, socket.assigns.aliases)
    )
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:saved, selected, warning}) do
    assign(socket,
      editing: false,
      selected: selected,
      draft_name: "",
      draft_expansion: "",
      warning: warning,
      error: nil
    )
  end

  defp dispatch(socket, {:error, message}), do: assign(socket, error: message)

  defp dispatch(socket, :deleted),
    do: assign(socket, selected: nil, editing: false, warning: nil, error: nil)

  defp dispatch(socket, :reset) do
    assign(socket,
      selected: nil,
      editing: false,
      draft_name: "",
      draft_expansion: "",
      warning: nil,
      error: nil
    )
  end

  defp dispatch(socket, _unknown), do: socket

  @spec entries(term()) :: [map()]
  defp entries(nil), do: []
  defp entries(aliases), do: AliasList.entries(aliases)
end
