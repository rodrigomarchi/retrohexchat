defmodule RetroHexChatWeb.Live.P2PConfirmDialog do
  @moduledoc """
  The confirmation in front of the one irreversible thing a P2P session can do:
  ending it.

  It used to be rendered by two LiveViews, because the chat also asked before
  swapping the session you were in for another peer's. A session lives at its
  own address now — several at once, one tab each — so there is no swap to ask
  about and the session's own page is the only host.

  It is scoped to the window it is rendered inside, so a confirmation blocks
  the session and nothing else.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.P2PConfirmDialog

  @id "p2p-confirm-dialog"

  @doc "The id the session's page renders it under, and `send_update/2` addresses."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, scope: :viewport, show: false, peer: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open_end, peer}}, socket) do
    {:ok, assign(socket, show: true, peer: peer)}
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
        peer={@peer}
        on_confirm="p2p_confirm_end"
        on_cancel="p2p_confirm_cancel"
      />
    </div>
    """
  end
end
