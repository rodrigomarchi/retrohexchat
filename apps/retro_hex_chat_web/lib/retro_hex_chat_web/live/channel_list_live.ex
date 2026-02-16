defmodule RetroHexChatWeb.ChannelListLive do
  @moduledoc """
  Win98-style dialog showing all active channels with name, topic, user count.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Commands.Autocomplete

  @impl true
  def mount(_params, session, socket) do
    viewer_channels = Map.get(session, "channels", [])
    nickname = Map.get(session, "chat_nickname", "")

    socket =
      assign(socket,
        channels: [],
        filtered: [],
        search: "",
        loading: true,
        channel_count: 0,
        viewer_channels: viewer_channels,
        nickname: nickname,
        join_channel: nil,
        page_title: "Channel List - RetroHexChat"
      )

    if connected?(socket) do
      send(self(), :load_channels)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_channels, socket) do
    channels = Autocomplete.list_visible_channels(socket.assigns.viewer_channels)

    {:noreply,
     assign(socket,
       channels: channels,
       filtered: channels,
       loading: false,
       channel_count: length(channels)
     )}
  end

  @impl true
  def handle_event("filter", %{"search" => search}, socket) do
    filtered =
      if search == "" do
        socket.assigns.channels
      else
        term = String.downcase(search)

        Enum.filter(socket.assigns.channels, fn ch ->
          String.contains?(String.downcase(ch.name), term) or
            String.contains?(String.downcase(ch.topic || ""), term)
        end)
      end

    {:noreply, assign(socket, search: search, filtered: filtered)}
  end

  def handle_event("join", %{"channel" => channel_name}, socket) do
    {:noreply,
     socket
     |> assign(join_channel: channel_name)
     |> push_event("submit_channel_join", %{})}
  end

  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(join_channel: nil)
     |> push_event("submit_channel_join", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="connect-dialog dialog-window--450"
      id="channel-list-root"
      phx-hook="ChannelListFormHook"
    >
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Channel List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <div class="u-mb-8">
            <input
              type="text"
              placeholder="Search channels..."
              value={@search}
              phx-keyup="filter"
              phx-debounce="200"
              name="search"
              class="u-w-full"
            />
          </div>
          <div :if={@loading} class="loading-spinner" data-testid="channel-list-loading">
            <div class="loading-spinner__bar" role="progressbar"></div>
            <span class="loading-spinner__text">
              Fetching channels... {@channel_count} found
            </span>
          </div>
          <div :if={!@loading} class="channel-list-scroll">
            <table class="table-standard">
              <thead>
                <tr>
                  <th>Channel</th>
                  <th>Topic</th>
                  <th class="u-text-right">Users</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={ch <- @filtered}>
                  <td>{ch.name}</td>
                  <td class="u-text-muted">{ch.topic || ""}</td>
                  <td class="u-text-right">{ch.user_count}</td>
                  <td>
                    <button
                      type="button"
                      phx-click="join"
                      phx-value-channel={ch.name}
                      class="btn-sm"
                    >
                      Join
                    </button>
                  </td>
                </tr>
                <tr :if={@filtered == []}>
                  <td colspan="4" class="table-empty">
                    No channels found
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="button-row u-mt-12">
            <button type="button" phx-click="close">Close</button>
          </div>
        </div>
      </div>
      <form
        id="channel-join-form"
        action={~p"/chat/session"}
        method="post"
        class="u-hidden"
      >
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <input type="hidden" name="nickname" value={@nickname} />
        <input :if={@join_channel} type="hidden" name="join_channel" value={@join_channel} />
      </form>
    </div>
    """
  end
end
