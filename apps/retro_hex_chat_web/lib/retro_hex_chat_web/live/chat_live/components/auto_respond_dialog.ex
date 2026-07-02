defmodule RetroHexChatWeb.ChatLive.Components.AutoRespondDialog do
  @moduledoc """
  Stateful LiveComponent for the Auto-Respond Rules editor — the
  inline-edit-list pattern (see `AliasDialog`). Selection is an integer `position`.
  Mounted inside a server-managed desktop window (closing unmounts the
  island, resetting the draft); the `autorespond_rules` struct is passed through.

  Owned UI/draft state: `selected` (position), `editing`, `draft_trigger`,
  `draft_channel`, `draft_command`, `error`. Pure-UI events
  (select/add/edit/cancel) are component-local; save/delete bubble to the parent
  carrying `selected`, and the enable/disable `toggle` bubbles too (it only mutates
  the session). Parent reflects results back via `send_update/2`:

  - `{:saved}`          — entry saved; leave edit mode, clear selection
  - `{:error, message}` — validation error inside the edit form
  - `:deleted`          — entry removed; clear selection
  - `:reset`            — close cleanup
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AutoRespondDialog

  alias RetroHexChat.Chat.AutoRespondRules

  @id "autorespond-dialog"
  @default_trigger "on_join"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       rules: nil,
       selected: nil,
       editing: false,
       draft_trigger: @default_trigger,
       draft_channel: "",
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
  def handle_event("autorespond_select", %{"position" => pos_str}, socket) do
    {pos, _} = Integer.parse(pos_str)
    {:noreply, assign(socket, selected: pos)}
  end

  def handle_event("autorespond_dialog_add", _params, socket) do
    {:noreply,
     assign(socket,
       editing: true,
       selected: nil,
       draft_trigger: @default_trigger,
       draft_channel: "",
       draft_command: "",
       error: nil
     )}
  end

  def handle_event("autorespond_dialog_edit", _params, socket) do
    entry =
      socket.assigns.selected &&
        Enum.find(entries(socket.assigns.rules), &(&1.position == socket.assigns.selected))

    if entry do
      {:noreply,
       assign(socket,
         editing: true,
         draft_trigger: Atom.to_string(entry.trigger_event),
         draft_channel: entry.channel_filter || "",
         draft_command: entry.command,
         error: nil
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("autorespond_dialog_cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false, error: nil)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :entries, entries(assigns.rules))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.auto_respond_panel
        id={@id}
        rules={@entries}
        selected_position={@selected}
        editing={@editing}
        draft_trigger={@draft_trigger}
        draft_channel={@draft_channel}
        draft_command={@draft_command}
        error_message={@error}
        on_select={JS.push("autorespond_select", target: @myself)}
        on_toggle="autorespond_toggle"
        on_add={JS.push("autorespond_dialog_add", target: @myself)}
        on_edit={JS.push("autorespond_dialog_edit", target: @myself)}
        on_save={JS.push("autorespond_dialog_save", value: %{selected: @selected})}
        on_delete={JS.push("autorespond_dialog_delete", value: %{selected: @selected})}
        on_cancel_edit={JS.push("autorespond_dialog_cancel_edit", target: @myself)}
      />
    </div>
    """
  end

  @spec assign_passthrough(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_passthrough(socket, assigns) do
    assign(socket,
      rules: Map.get(assigns, :rules, socket.assigns.rules)
    )
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:saved}),
    do: assign(socket, editing: false, selected: nil, error: nil)

  defp dispatch(socket, {:error, message}), do: assign(socket, error: message)

  defp dispatch(socket, :deleted),
    do: assign(socket, selected: nil, editing: false, error: nil)

  defp dispatch(socket, :reset) do
    assign(socket,
      selected: nil,
      editing: false,
      draft_trigger: @default_trigger,
      draft_channel: "",
      draft_command: "",
      error: nil
    )
  end

  defp dispatch(socket, _unknown), do: socket

  @spec entries(term()) :: [map()]
  defp entries(nil), do: []
  defp entries(rules), do: AutoRespondRules.entries(rules)
end
