defmodule RetroHexChatWeb.ChatLive.ChannelCentralEvents do
  @moduledoc """
  Routes the Channel Central open trigger to the stateful island.

  All Channel Central state, events and privileged `Server`/`ChanServ` work live
  in `RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog`. This hook only
  resolves the target channel for the `open_channel_central` toolbar/menu action
  and drives the component via `send_update`; the other open entry points
  (`ctx_chat_channel_info`, `ctx_conversations_settings`) call `open/2` directly.

  Attached as `attach_hook(:channel_central_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog

  def handle_event("open_channel_central", params, socket) do
    channel = params["cc_channel"] || socket.assigns.session.active_channel
    {:halt, open(socket, channel)}
  end

  # Programmatic close: resets the island, which also pushes the client-side
  # window close. (The window X only hides the window client-side.)
  def handle_event("close_channel_central", _params, socket) do
    send_update(ChannelCentralDialog, id: ChannelCentralDialog.id(), close: true)
    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens Channel Central for `channel` by driving the island. The component loads
  the snapshot, runs the membership/permission gate, and bubbles a system error
  back if the viewer cannot open it.
  """
  @spec open(Phoenix.LiveView.Socket.t(), String.t() | nil) :: Phoenix.LiveView.Socket.t()
  def open(socket, nil), do: socket

  def open(socket, channel) do
    send_update(ChannelCentralDialog, id: ChannelCentralDialog.id(), open: channel)
    socket
  end
end
