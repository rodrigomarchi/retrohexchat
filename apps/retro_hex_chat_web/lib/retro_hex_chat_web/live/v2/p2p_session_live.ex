defmodule RetroHexChatWeb.V2.P2PSessionLive do
  @moduledoc """
  v2 P2P session — uses new UI components.
  Stub: will be implemented in Phase 3.
  """
  use Phoenix.LiveView

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "P2P Session - RetroHexChat v2")}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen">
      <p class="text-sm">v2 P2P Session — stub (Phase 3)</p>
    </div>
    """
  end
end
