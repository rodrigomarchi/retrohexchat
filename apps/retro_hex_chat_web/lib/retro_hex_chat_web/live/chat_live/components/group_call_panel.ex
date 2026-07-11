defmodule RetroHexChatWeb.ChatLive.Components.GroupCallPanel do
  @moduledoc """
  Desktop-window body for the channel group call.

  The WebRTC hook is mounted inside a stable ignored subtree so the raw channel,
  peer connection, and media streams survive ordinary LiveView patches.
  """

  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.GroupCall.Panel

  @id "group-call-panel"

  @doc "Stable DOM/component id used by the host LiveView."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, call: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <.group_call_panel id={"#{@id}-surface"} call={@call} />
    </div>
    """
  end
end
