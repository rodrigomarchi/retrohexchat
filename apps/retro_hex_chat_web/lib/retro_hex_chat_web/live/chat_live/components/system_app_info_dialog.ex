defmodule RetroHexChatWeb.ChatLive.Components.SystemAppInfoDialog do
  @moduledoc """
  Stateful island behind the App Info window.

  Reads occupancy on mount and on demand. The reading walks every live channel,
  so it stays a deliberate action rather than a timer — on a busy server that
  walk is the most expensive thing any of these windows does.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.AppInfoPanel

  alias RetroHexChat.SystemInfo
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "system-app-info-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(instance: nil, table: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.instance, do: {:ok, socket}, else: {:ok, read(socket)}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_app_info_refresh", _params, socket) do
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
      <.app_info_panel
        id={@id}
        instance={@instance}
        table={@table}
        target={@myself}
        on_refresh="system_app_info_refresh"
      />
    </div>
    """
  end

  defp read(socket) do
    instance = SystemInfo.instance()

    assign(socket, instance: instance, table: SystemInfo.channel_table(instance))
  end
end
