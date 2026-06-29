defmodule RetroHexChatWeb.ChatLive.Components.DisconnectConfirmDialog do
  @moduledoc """
  The disconnect-confirmation dialog. Owns its open state.

  The dialog is opened from the File menu / toolbar, whose generic action
  dispatch fires the `disconnect` server event. `MenuToolbarEvents` drives the
  component via `send_update/2` (`:open`/`:close`), and `confirm_disconnect` is
  handled on the parent, which performs the session cleanup and redirect.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.DisconnectConfirmDialog

  @id "disconnect-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, show: false)}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: :open}, socket), do: {:ok, assign(socket, show: true)}
  def update(%{action: :close}, socket), do: {:ok, assign(socket, show: false)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.disconnect_confirm_dialog
        id={@id}
        show={@show}
        on_confirm="confirm_disconnect"
        on_cancel="cancel_disconnect"
      />
    </div>
    """
  end
end
