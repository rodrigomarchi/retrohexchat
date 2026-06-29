defmodule RetroHexChatWeb.ChatLive.Components.ChannelListDialog do
  @moduledoc """
  The Channel List dialog: a searchable list of joinable channels with Join and
  Request-Access actions.

  Owns the view state — the `search` term and the `selected` channel name — and
  derives the displayed rows by filtering `channels` (the full list supplied by
  the parent together with `loading` and `visible`) on name and topic.

  `channel_list_filter` and `channel_list_select` are received by
  `ChannelListEvents` on the root LiveView and forwarded here via `send_update`.
  `channel_list_join`, `channel_list_knock` and `close_channel_list` are handled
  by the parent, which joins the channel, opens the knock-request dialog, or hides
  the window; `show_channel_list` lives on the parent because the Escape handler
  reads it.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChannelList

  @id "channel-list-dialog"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Filters channels by name/topic substring (case-insensitive)."
  @spec filter_channels([map()], String.t()) :: [map()]
  def filter_channels(channels, ""), do: channels

  def filter_channels(channels, search) do
    term = String.downcase(search)

    Enum.filter(channels, fn ch ->
      String.contains?(String.downcase(ch.name), term) or
        String.contains?(String.downcase(ch.topic || ""), term)
    end)
  end

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       visible: false,
       channels: [],
       loading: false,
       search: "",
       selected: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: :open}, socket) do
    {:ok, assign(socket, search: "", selected: nil)}
  end

  def update(%{action: {:filter, search}}, socket) do
    filtered = filter_channels(socket.assigns.channels, search)

    selected =
      if Enum.any?(filtered, &(&1.name == socket.assigns.selected)),
        do: socket.assigns.selected

    {:ok, assign(socket, search: search, selected: selected)}
  end

  def update(%{action: {:select, channel}}, socket) do
    {:ok, assign(socket, selected: channel)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       visible: Map.get(assigns, :visible, socket.assigns.visible),
       channels: Map.get(assigns, :channels, socket.assigns.channels),
       loading: Map.get(assigns, :loading, socket.assigns.loading)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, filtered: filter_channels(assigns.channels, assigns.search))

    ~H"""
    <div id={"#{@id}-mount"}>
      <.channel_list
        id={@id}
        show={@visible}
        channels={@filtered}
        search={@search}
        selected_channel={@selected}
        loading={@loading}
        on_search="channel_list_filter"
        on_select="channel_list_select"
        on_join="channel_list_join"
        on_knock="channel_list_knock"
        on_close="close_channel_list"
      />
    </div>
    """
  end
end
