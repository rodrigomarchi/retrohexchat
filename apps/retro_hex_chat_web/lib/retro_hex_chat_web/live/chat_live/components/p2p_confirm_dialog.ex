defmodule RetroHexChatWeb.ChatLive.Components.P2PConfirmDialog do
  @moduledoc """
  The P2P end/switch confirmation dialog. Owns its open state.

  `P2PSessionEvents` drives it via `send_update/2` (`{:open_end, peer}`,
  `{:open_switch, peer, new_peer}`, `:close`); the confirm/cancel events are
  handled on the parent, which performs the actual session teardown/switch.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.P2PConfirmDialog

  @id "p2p-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, show: false, mode: :end, peer: nil, new_peer: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open_end, peer}}, socket) do
    {:ok, assign(socket, show: true, mode: :end, peer: peer, new_peer: nil)}
  end

  def update(%{action: {:open_close, peer}}, socket) do
    {:ok, assign(socket, show: true, mode: :close, peer: peer, new_peer: nil)}
  end

  def update(%{action: {:open_switch, peer, new_peer}}, socket) do
    {:ok, assign(socket, show: true, mode: :switch, peer: peer, new_peer: new_peer)}
  end

  def update(%{action: :close}, socket), do: {:ok, assign(socket, show: false)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.p2p_confirm_dialog
        id={@id}
        show={@show}
        mode={@mode}
        peer={@peer}
        new_peer={@new_peer}
        on_confirm={
          if @mode == :switch,
            do: "p2p_confirm_switch",
            else: "p2p_confirm_end"
        }
        on_cancel="p2p_confirm_cancel"
      />
    </div>
    """
  end
end
