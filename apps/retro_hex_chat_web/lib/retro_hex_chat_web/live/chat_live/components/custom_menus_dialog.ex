defmodule RetroHexChatWeb.ChatLive.Components.CustomMenusDialog do
  @moduledoc """
  Stateful LiveComponent for the Custom Menus editor — the inline-edit-
  list pattern (see `AliasDialog`), with an extra `tab` dimension. Mounted inside a server-managed
  desktop window (closing unmounts the island, resetting the draft); the whole
  `custom_menus` struct is passed through so the component computes the entries for
  the currently selected tab itself.

  Owned UI/draft state: `tab`, `selected`, `editing`, `draft_label`,
  `draft_command`, `error`. Pure-UI events (tab/select/add/edit/cancel) are
  component-local; save/delete bubble to the parent carrying `selected` + `tab`.
  Parent reflects results back via `send_update/2`:

  - `{:saved, selected}` — entry saved; show it selected, leave edit mode
  - `{:error, message}`  — validation error inside the edit form
  - `:deleted`           — entry removed; clear selection
  - `:reset`             — close cleanup
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.CustomMenusDialog

  alias RetroHexChat.Chat.CustomMenus

  @id "custom-menus-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       custom_menus: nil,
       tab: :nicklist,
       selected: nil,
       editing: false,
       draft_label: "",
       draft_command: "",
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
  def handle_event("custom_menus_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: String.to_existing_atom(tab), selected: nil, editing: false)}
  end

  def handle_event("custom_menu_select", %{"label" => label}, socket) do
    {:noreply, assign(socket, selected: label, editing: false)}
  end

  def handle_event("custom_menu_dialog_add", _params, socket) do
    {:noreply,
     assign(socket,
       editing: true,
       selected: nil,
       draft_label: "",
       draft_command: "",
       error: nil
     )}
  end

  def handle_event("custom_menu_dialog_edit", _params, socket) do
    entry =
      socket.assigns.selected &&
        Enum.find(
          entries(socket.assigns.custom_menus, socket.assigns.tab),
          &(&1.label == socket.assigns.selected)
        )

    if entry do
      {:noreply,
       assign(socket,
         editing: true,
         draft_label: entry.label,
         draft_command: entry.command,
         error: nil
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("custom_menu_dialog_cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false, draft_label: "", draft_command: "", error: nil)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :entries, entries(assigns.custom_menus, assigns.tab))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.custom_menus_panel
        id={@id}
        active_tab={@tab}
        entries={@entries}
        selected_item={@selected}
        editing={@editing}
        draft_label={@draft_label}
        draft_command={@draft_command}
        error_message={@error}
        on_tab={JS.push("custom_menus_tab", target: @myself)}
        on_select={JS.push("custom_menu_select", target: @myself)}
        on_add={JS.push("custom_menu_dialog_add", target: @myself)}
        on_edit={JS.push("custom_menu_dialog_edit", target: @myself)}
        on_save={JS.push("custom_menu_dialog_save", value: %{selected: @selected, tab: @tab})}
        on_delete={JS.push("custom_menu_dialog_delete", value: %{selected: @selected, tab: @tab})}
        on_cancel_edit={JS.push("custom_menu_dialog_cancel_edit", target: @myself)}
      />
    </div>
    """
  end

  @spec assign_passthrough(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_passthrough(socket, assigns) do
    assign(socket,
      custom_menus: Map.get(assigns, :custom_menus, socket.assigns.custom_menus)
    )
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:saved, selected}),
    do: assign(socket, editing: false, selected: selected, error: nil)

  defp dispatch(socket, {:error, message}), do: assign(socket, error: message)

  defp dispatch(socket, :deleted),
    do: assign(socket, selected: nil, editing: false, error: nil)

  defp dispatch(socket, :reset) do
    assign(socket,
      selected: nil,
      editing: false,
      draft_label: "",
      draft_command: "",
      error: nil
    )
  end

  defp dispatch(socket, _unknown), do: socket

  @spec entries(term(), atom()) :: [map()]
  defp entries(nil, _tab), do: []
  defp entries(custom_menus, tab), do: CustomMenus.entries_for(custom_menus, tab)
end
