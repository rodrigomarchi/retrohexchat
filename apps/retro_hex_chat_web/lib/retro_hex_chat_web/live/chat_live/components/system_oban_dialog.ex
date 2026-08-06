defmodule RetroHexChatWeb.ChatLive.Components.SystemObanDialog do
  @moduledoc """
  Stateful island behind the Oban Health window.

  The island owns only the interaction state: which recent-job filter is active
  and when to refresh. The underlying reading is handled by `Jobs.ObanHealth`,
  keeping Oban schema knowledge out of the LiveView.
  """

  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.ObanPanel

  alias RetroHexChat.Jobs.ObanHealth
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "system-oban-dialog"
  @default_filter "active"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(
       snapshot: nil,
       filters: ObanHealth.job_filters(),
       job_filter: @default_filter,
       job_queue_filter: "",
       job_worker_filter: ""
     )}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.snapshot do
      {:ok, socket}
    else
      {:ok, refresh(socket)}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_oban_refresh", _params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, refresh(socket)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  def handle_event("system_oban_filter", params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply,
       socket
       |> assign(:job_filter, Map.get(params, "filter", @default_filter))
       |> assign(:job_queue_filter, Map.get(params, "queue", ""))
       |> assign(:job_worker_filter, Map.get(params, "worker", ""))
       |> refresh()}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.oban_panel
        id={@id}
        snapshot={@snapshot}
        filters={@filters}
        target={@myself}
        on_refresh="system_oban_refresh"
        on_filter="system_oban_filter"
      />
    </div>
    """
  end

  defp refresh(socket) do
    assign(socket,
      snapshot:
        ObanHealth.snapshot(
          filter: socket.assigns.job_filter,
          queue: socket.assigns.job_queue_filter,
          worker: socket.assigns.job_worker_filter
        ),
      filters: ObanHealth.job_filters()
    )
  end
end
