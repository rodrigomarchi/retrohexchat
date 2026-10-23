defmodule RetroHexChatWeb.ChatLive.Components.SystemObanDialog do
  @moduledoc """
  Stateful island behind the Oban Health window.

  The island owns only the interaction state: which tab is focused, which
  recent-job filter is active and when to refresh. The underlying reading is
  handled by `Jobs.ObanHealth`, keeping Oban schema knowledge out of the
  LiveView.
  """

  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.ObanPanel

  alias RetroHexChat.Jobs.ObanHealth
  alias RetroHexChatWeb.ChatLive.AdminOps

  @default_tab "overview"
  @default_filter "active"
  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "system-oban-dialog",
    initial: %{
      snapshot: nil,
      snapshot_loading: false,
      snapshot_request: nil,
      filters: ObanHealth.job_filters(),
      active_tab: @default_tab,
      job_filter: @default_filter,
      job_queue_filter: "",
      job_worker_filter: ""
    }

  @tabs ~w(overview queues bots maintenance previews persistence)

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.snapshot || socket.assigns.snapshot_loading do
      {:ok, socket}
    else
      {:ok, refresh_async(socket)}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_oban_refresh", _params, socket) do
    AdminOps.guarded(socket, fn ->
      {:noreply, refresh_async(socket)}
    end)
  end

  def handle_event("system_oban_filter", params, socket) do
    AdminOps.guarded(socket, fn ->
      {:noreply,
       socket
       |> assign(:job_filter, Map.get(params, "filter", @default_filter))
       |> assign(:job_queue_filter, Map.get(params, "queue", ""))
       |> assign(:job_worker_filter, Map.get(params, "worker", ""))
       |> refresh_async()}
    end)
  end

  def handle_event("system_oban_tab", %{"tab" => tab}, socket) do
    AdminOps.guarded(socket, fn ->
      {:noreply, assign(socket, :active_tab, normalize_tab(tab))}
    end)
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.oban_panel
        id={@id}
        snapshot={@snapshot}
        loading={@snapshot_loading}
        filters={@filters}
        target={@myself}
        active_tab={@active_tab}
        on_refresh="system_oban_refresh"
        on_filter="system_oban_filter"
        on_tab="system_oban_tab"
      />
    </div>
    """
  end

  @impl true
  @spec handle_async(term(), term(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:oban_snapshot, {:ok, {request, snapshot}}, socket) do
    socket =
      if socket.assigns.snapshot_request == request do
        assign(socket,
          snapshot: snapshot,
          snapshot_loading: false,
          snapshot_request: nil,
          filters: ObanHealth.job_filters()
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_async(:oban_snapshot, {:exit, _reason}, socket) do
    {:noreply, assign(socket, snapshot_loading: false, snapshot_request: nil)}
  end

  defp refresh_async(socket) do
    request = snapshot_request(socket)
    {filter, queue, worker} = request

    socket
    |> assign(
      snapshot_loading: true,
      snapshot_request: request,
      filters: ObanHealth.job_filters()
    )
    |> start_async(:oban_snapshot, fn ->
      {request,
       ObanHealth.snapshot(
         filter: filter,
         queue: queue,
         worker: worker
       )}
    end)
  end

  defp snapshot_request(socket) do
    {socket.assigns.job_filter, socket.assigns.job_queue_filter, socket.assigns.job_worker_filter}
  end

  defp normalize_tab(tab) when tab in @tabs, do: tab
  defp normalize_tab(_tab), do: @default_tab
end
