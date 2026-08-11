defmodule RetroHexChatWeb.ChatLive.Components.AdminTurnDialog do
  @moduledoc """
  Stateful island for the Admin TURN window.

  Owns the two telemetry panes. Mounted inside a server-managed window:
  presence in the DOM means open, so closing unmounts the island.

  Read-only, and deliberately pull-only: the numbers are a snapshot from when
  Refresh was last pressed, not a live feed.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AdminTurnDialog

  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  @id "admin-turn-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{stats: nil, allocations: nil, result: nil, loaded?: false}

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: DialogIsland.mount(socket, @id, @initial)

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: DialogIsland.load_once(socket, assigns, &assign_snapshot(&1))

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_turn_refresh", _params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, assign_snapshot(socket)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, can_refresh: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_turn_panel
        id={@id}
        target={@myself}
        stats={@stats}
        allocations={@allocations}
        result={@result}
        can_refresh={@can_refresh}
        on_refresh="admin_turn_refresh"
      />
    </div>
    """
  end

  defp assign_snapshot(socket) do
    stats = AdminOps.dispatch(socket, "admin", ["turn", "stats"])
    allocations = AdminOps.dispatch(socket, "admin", ["turn", "allocations"])

    assign(socket,
      stats: AdminOps.result_message(stats),
      allocations: AdminOps.result_message(allocations),
      result: AdminOps.first_error_entry([stats, allocations])
    )
  end
end
