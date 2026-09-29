defmodule RetroHexChatWeb.ChatLive.Components.ChannelListDialog do
  @moduledoc """
  The Channel List dialog: a searchable list of rooms, each row its own door.

  Owns one piece of view state, the `search` term, and renders whatever
  `channels` the parent last supplied together with `loading`.

  `channel_list_filter` is received by `ChannelListEvents` on the root LiveView
  and forwarded here via `send_update`. `channel_list_join` and
  `channel_list_knock` are handled by the parent, which joins the channel or
  opens the knock-request modal. The island is always mounted inside its desktop
  window: the window manager owns open/close, so the search filter survives
  closes, by design.
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
       search: ""
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  # Reopening keeps the previous search filter, which is pre-state the reader
  # typed and did not undo.
  def update(%{action: :open}, socket) do
    {:ok, socket}
  end

  def update(%{action: {:filter, search, channels}}, socket) do
    {:ok, assign(socket, search: search, channels: channels)}
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
        loading={@loading}
        on_search="channel_list_filter"
        on_join="channel_list_join"
        on_knock="channel_list_knock"
      />
    </div>
    """
  end
end
