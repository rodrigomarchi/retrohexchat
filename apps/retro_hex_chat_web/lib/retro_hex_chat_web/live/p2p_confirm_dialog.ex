defmodule RetroHexChatWeb.Live.P2PConfirmDialog do
  @moduledoc """
  The confirmation in front of every irreversible thing a P2P session can do.

  It is rendered by two LiveViews, not one: the session surface asks before you
  end or close a session, and the chat asks before it swaps the session you are
  in for another peer's. Same component, same dialog, two hosts —
  `send_update/2` reaches whichever process rendered it, so neither host needs
  to know about the other.

  It is scoped to the window it is rendered inside, so a confirmation blocks
  the session and nothing else.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.P2PConfirmDialog

  @id "p2p-confirm-dialog"

  @doc """
  The id the session surface renders it under, and addresses `send_update/2` to.

  A host that renders a second copy — the chat, which only ever asks about
  swapping one peer's session for another — passes an id of its own: two
  elements with the same id in one document is undefined behaviour, and both
  hosts are on screen at the same time whenever the session is embedded.
  """
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, scope: :viewport, show: false, mode: :end, peer: nil, new_peer: nil)}
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

  # The host declares, on every render, whether the dialog blocks the whole
  # viewport or just the window it lives in. `send_update/2` carries actions;
  # this carries the shape of the host.
  def update(%{scope: scope} = assigns, socket) when scope in [:viewport, :window] do
    {:ok, assign(socket, id: assigns.id, scope: scope)}
  end

  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.p2p_confirm_dialog
        id={@id}
        show={@show}
        scope={@scope}
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
