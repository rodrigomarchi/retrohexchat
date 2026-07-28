defmodule RetroHexChatWeb.ChatLive.Components.ChannelListDialog do
  @moduledoc """
  The Channel List dialog: a searchable list of joinable channels with Join and
  Request-Access actions.

  Owns the view state — the `search` term and the `selected` channel name — and
  derives the displayed rows by filtering `channels` (the full list supplied by
  the parent together with `loading`) on name and topic.

  `channel_list_filter` and `channel_list_select` are received by
  `ChannelListEvents` on the root LiveView and forwarded here via `send_update`.
  `channel_list_join` and `channel_list_knock` are handled by the parent, which
  joins the channel or opens the knock-request modal. The island is always
  mounted inside its desktop window: the window manager owns open/close, so the
  search filter survives closes (by design); `:open` only resets the selection.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChannelList

  @id "channel-list-dialog"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       channels: [],
       loading: false,
       search: "",
       selected: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  # Reopening keeps the previous search filter (pre-state) but drops the selection
  # so Join/Request-Access starts disabled until the user picks a row again.
  def update(%{action: :open}, socket) do
    {:ok, assign(socket, selected: nil)}
  end

  def update(%{action: {:filter, search, channels}}, socket) do
    selected =
      if Enum.any?(channels, &(&1.name == socket.assigns.selected)),
        do: socket.assigns.selected

    {:ok, assign(socket, search: search, channels: channels, selected: selected)}
  end

  def update(%{action: {:select, channel}}, socket) do
    {:ok, assign(socket, selected: channel)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       channels: Map.get(assigns, :channels, socket.assigns.channels),
       loading: Map.get(assigns, :loading, socket.assigns.loading)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.channel_list_panel
        id={@id}
        channels={@channels}
        search={@search}
        selected_channel={@selected}
        loading={@loading}
        on_search="channel_list_filter"
        on_select="channel_list_select"
        on_join="channel_list_join"
        on_knock="channel_list_knock"
      />
    </div>
    """
  end
end
