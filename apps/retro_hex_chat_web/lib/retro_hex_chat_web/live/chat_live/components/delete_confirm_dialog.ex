defmodule RetroHexChatWeb.ChatLive.Components.DeleteConfirmDialog do
  @moduledoc """
  The delete-message confirmation dialog. Owns the target message id while the
  dialog is open.

  `CoreEvents` opens/closes it via `send_update/2` (`{:open, message_id}` /
  `:close`). The confirm button carries the `message_id` via `JS.push` value, so
  the delete itself (`confirm_delete`) is handled on the parent, where the session
  and `Service` are reachable.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.DeleteConfirmDialog

  @id "delete-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, message_id: nil)}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open, message_id}}, socket),
    do: {:ok, assign(socket, message_id: message_id)}

  def update(%{action: :close}, socket), do: {:ok, assign(socket, message_id: nil)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.delete_confirm_dialog
        id={@id}
        show={@message_id != nil}
        message_id={@message_id}
        on_confirm={JS.push("confirm_delete", value: %{message_id: @message_id})}
        on_cancel="cancel_delete"
      />
    </div>
    """
  end
end
