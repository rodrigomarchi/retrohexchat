defmodule RetroHexChatWeb.ChatLive.Components.AwayDialog do
  @moduledoc """
  The Away window body: the away flag and the message others see in `/whois`.

  Purely a view over the session — both fields are supplied by the parent as
  template attrs, and the forms are handled on the parent's `AwayEvents`, which
  runs `/away` and remembers the last message for the status-bar toggle.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AwayDialog

  @id "away-dialog"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, away: false, away_message: "")}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       away: Map.get(assigns, :away, socket.assigns.away),
       away_message: Map.get(assigns, :away_message, socket.assigns.away_message)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.away_panel id={@id} away={@away} away_message={@away_message || ""} />
    </div>
    """
  end
end
