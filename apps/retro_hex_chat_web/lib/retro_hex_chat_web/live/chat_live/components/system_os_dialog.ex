defmodule RetroHexChatWeb.ChatLive.Components.SystemOsDialog do
  @moduledoc """
  Stateful island behind the OS Data window.

  Reads the host on mount and on demand. CPU utilisation is a delta since the
  previous call, so the first reading after the window opens describes the
  interval since whatever last asked — which is why the panel labels it as
  measured since the previous reading rather than presenting it as an instant.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.OsPanel

  alias RetroHexChat.SystemInfo
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "system-os-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(os: nil, available: false)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.os, do: {:ok, socket}, else: {:ok, read(socket)}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_os_refresh", _params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, read(socket)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.os_panel
        id={@id}
        os={@os}
        available={@available}
        target={@myself}
        on_refresh="system_os_refresh"
      />
    </div>
    """
  end

  defp read(socket) do
    assign(socket, os: SystemInfo.os(), available: SystemInfo.os_available?())
  end
end
