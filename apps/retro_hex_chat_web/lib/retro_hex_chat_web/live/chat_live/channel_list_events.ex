defmodule RetroHexChatWeb.ChatLive.ChannelListEvents do
  @moduledoc """
  Handle events for the Channel List dialog.

  Covers: channel_list (open), toggle_channel_list (close),
  channel_list_filter, channel_list_select, channel_list_join.

  Attached as `attach_hook(:channel_list_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("channel_list", _params, socket) do
    channels = Autocomplete.list_visible_channels(socket.assigns.session.channels)

    {:halt,
     assign(socket,
       show_channel_list: true,
       channel_list_channels: channels,
       channel_list_filtered: channels,
       channel_list_selected: nil,
       channel_list_search: "",
       channel_list_loading: false,
       channel_list_count: length(channels)
     )}
  end

  def handle_event("toggle_channel_list", _params, socket) do
    if socket.assigns.show_channel_list do
      {:halt, close_channel_list(socket)}
    else
      handle_event("channel_list", %{}, socket)
    end
  end

  def handle_event("close_channel_list", _params, socket) do
    {:halt, close_channel_list(socket)}
  end

  def handle_event("channel_list_filter", %{"search" => search}, socket) do
    filtered =
      if search == "" do
        socket.assigns.channel_list_channels
      else
        term = String.downcase(search)

        Enum.filter(socket.assigns.channel_list_channels, fn ch ->
          String.contains?(String.downcase(ch.name), term) or
            String.contains?(String.downcase(ch.topic || ""), term)
        end)
      end

    selected =
      if Enum.any?(filtered, &(&1.name == socket.assigns.channel_list_selected)) do
        socket.assigns.channel_list_selected
      end

    {:halt,
     assign(socket,
       channel_list_search: search,
       channel_list_filtered: filtered,
       channel_list_selected: selected
     )}
  end

  def handle_event("channel_list_select", %{"channel" => channel_name}, socket) do
    {:halt, assign(socket, channel_list_selected: channel_name)}
  end

  def handle_event("channel_list_join", %{"channel" => channel_name}, socket) do
    socket =
      socket
      |> assign(
        show_channel_list: false,
        channel_list_channels: [],
        channel_list_filtered: [],
        channel_list_selected: nil,
        channel_list_search: "",
        channel_list_loading: false,
        channel_list_count: 0
      )
      |> ChannelHelpers.join_channel(channel_name, socket.assigns.session)

    {:halt, socket}
  end

  # Catch-all — pass through all non-channel-list events
  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp close_channel_list(socket) do
    assign(socket,
      show_channel_list: false,
      channel_list_selected: nil,
      channel_list_loading: false
    )
  end
end
