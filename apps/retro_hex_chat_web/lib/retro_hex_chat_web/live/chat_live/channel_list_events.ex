defmodule RetroHexChatWeb.ChatLive.ChannelListEvents do
  @moduledoc """
  Handle events for the Channel List dialog.

  Covers: channel_list (open), toggle_channel_list (close),
  channel_list_filter, channel_list_select, channel_list_join.

  Attached as `attach_hook(:channel_list_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.UiActions.Core

  @max_knock_message_length 200

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

  def handle_event("channel_list_knock", params, socket) do
    channel_name = Map.get(params, "channel") || socket.assigns.channel_list_selected

    {:halt,
     socket
     |> close_channel_list()
     |> open_knock_request_dialog(channel_name)}
  end

  def handle_event("knock_request_change", params, socket) do
    {:halt,
     assign(socket,
       show_knock_request_dialog: true,
       knock_request_channel: Map.get(params, "channel") || socket.assigns.knock_request_channel,
       knock_request_message: Map.get(params, "message", ""),
       knock_request_error: nil
     )}
  end

  def handle_event("knock_request_submit", params, socket) do
    channel = Map.get(params, "channel") || socket.assigns.knock_request_channel
    message = Map.get(params, "message", "")

    if String.length(message) > @max_knock_message_length do
      {:halt,
       assign(socket,
         show_knock_request_dialog: true,
         knock_request_channel: channel,
         knock_request_message: message,
         knock_request_error: dgettext("chat", "Message must be 200 characters or less")
       )}
    else
      case Core.knock_channel(socket, channel, message) do
        {:ok, socket} ->
          {:halt, close_knock_request_dialog(socket)}

        {:error, socket, error} ->
          {:halt,
           assign(socket,
             show_knock_request_dialog: true,
             knock_request_channel: channel,
             knock_request_message: message,
             knock_request_error: error
           )}
      end
    end
  end

  def handle_event("knock_request_cancel", _params, socket) do
    {:halt, close_knock_request_dialog(socket)}
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

  defp open_knock_request_dialog(socket, channel_name) do
    assign(socket,
      show_knock_request_dialog: true,
      knock_request_channel: channel_name,
      knock_request_message: "",
      knock_request_error: nil
    )
  end

  defp close_knock_request_dialog(socket) do
    assign(socket,
      show_knock_request_dialog: false,
      knock_request_channel: nil,
      knock_request_message: "",
      knock_request_error: nil
    )
  end
end
