defmodule RetroHexChatWeb.ChatLive.Components.ChannelListDialog do
  @moduledoc """
  The Channel List dialog: a list of rooms searchable by name and narrowed by
  subject, each row its own door.

  Renders whatever `channels` the parent last supplied, with the filter that
  produced them — the `search` term and the `category` — and `loading`.

  `channel_list_filter` is received by `ChannelListEvents` on the root LiveView,
  which keeps the filter and lists the channels it selects. `channel_list_join`
  and `channel_list_knock` are handled by the parent, which joins the channel or
  opens the knock-request modal. The island is always mounted inside its desktop
  window: the window manager owns open/close, so the filter survives closes, by
  design.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChannelList

  use RetroHexChatWeb.ChatLive.Components.DialogIsland, id: "channel-list-dialog"

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       channels: [],
       loading: false,
       search: "",
       category: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       channels: Map.get(assigns, :channels, socket.assigns.channels),
       loading: Map.get(assigns, :loading, socket.assigns.loading),
       search: Map.get(assigns, :search, socket.assigns.search),
       category: Map.get(assigns, :category, socket.assigns.category)
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
        category={@category}
        loading={@loading}
        on_search="channel_list_filter"
        on_join="channel_list_join"
        on_knock="channel_list_knock"
      />
    </div>
    """
  end
end
