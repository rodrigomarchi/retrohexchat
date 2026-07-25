defmodule RetroHexChatWeb.ChatLive.Components.UserModesDialog do
  @moduledoc """
  The User Modes window body: the IRC user modes on your own connection.

  Purely a view over the session — `wallops_enabled` is supplied by the parent
  as a template attr, and the form is handled on the parent's `UserModesEvents`,
  which runs `/umode`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.UserModesDialog

  @id "user-modes-dialog"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, wallops_enabled: false)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       wallops_enabled: Map.get(assigns, :wallops_enabled, socket.assigns.wallops_enabled)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.user_modes_panel id={@id} wallops_enabled={@wallops_enabled} />
    </div>
    """
  end
end
