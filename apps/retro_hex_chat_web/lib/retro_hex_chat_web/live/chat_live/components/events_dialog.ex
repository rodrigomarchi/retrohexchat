defmodule RetroHexChatWeb.ChatLive.Components.EventsDialog do
  @moduledoc """
  Stateful island behind the Events window.

  Shows what the channel on screen has coming up. It loads on the first
  `update/2` rather than on a message after mount: a window that asks for its
  contents afterwards races the patch that put it on screen, and the reader
  watches an empty list blink into a full one.

  A channel switch is a different calendar, so it reloads; so is somebody
  saying they will be there, which is why the host asks for a reload after an
  answer rather than the island guessing.

  The times are turned into words here, once per row, using the session's zone.
  Doing it in the row component would put a clock inside a pure component and
  make it the second place that decides whose clock it is.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.EventsDialog

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Page
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.PaginatedList

  @id "events-dialog"
  @page_size 25

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       channel: nil,
       viewer: nil,
       timezone: "Etc/UTC",
       can_schedule: false,
       loaded?: false
     )
     |> PaginatedList.init(:events,
       page_size: @page_size,
       dom_id: &"events-row-#{&1.card.event_id}"
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    previous = socket.assigns.channel
    reload? = Map.get(assigns, :reload, false)
    socket = socket |> assign(Map.delete(assigns, :reload))

    if socket.assigns.loaded? and socket.assigns.channel == previous and not reload? do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> load_first_page()}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("events_load_more", _params, socket) do
    {:noreply, PaginatedList.load(socket, :events, &fetch(socket, &1))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.events_panel
        id={@id}
        events={@streams.events}
        state={@paginated.events}
        target={@myself}
        can_schedule={@can_schedule}
      />
    </div>
    """
  end

  @spec load_first_page(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_first_page(socket) do
    PaginatedList.reset(socket, :events, fetch(socket, limit: @page_size))
  end

  @spec fetch(Phoenix.LiveView.Socket.t(), keyword()) :: Page.t()
  defp fetch(socket, opts) do
    case socket.assigns.channel do
      nil ->
        Page.empty()

      channel ->
        page = ScheduledEvents.list(channel, opts)
        going = attending(socket, page.items)

        Page.map(page, &row(&1, going, socket.assigns.timezone))
    end
  end

  defp attending(%{assigns: %{viewer: viewer}}, items) when is_binary(viewer) do
    ScheduledEvents.attending_many(viewer, Enum.map(items, & &1.id))
  end

  defp attending(_socket, _items), do: MapSet.new()

  defp row(event, going, timezone) do
    card = ScheduledEvents.card(event)

    %{
      card: card,
      when_text: ChatHelpers.format_datetime(card.starts_at, timezone),
      relative_text: TimeFormatter.format_until(card.starts_at),
      attending: MapSet.member?(going, card.event_id)
    }
  end
end
