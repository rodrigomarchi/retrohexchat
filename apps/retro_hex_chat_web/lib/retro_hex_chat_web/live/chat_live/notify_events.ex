defmodule RetroHexChatWeb.ChatLive.NotifyEvents do
  @moduledoc """
  Routes the standalone Notify List dialog open/toggle trigger to its island.

  All Notify List state, events and the `NotifyOps` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.NotifyListDialog` (and the Address Book's
  Notify tab in `Components.AddressBookDialog`). This hook only reflects the
  menu/toolbar/status-bar/`/notify` open trigger into the island via `send_update`.

  Attached as `attach_hook(:notify_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.NotifyListDialog

  def handle_event("toggle_notify_list", _params, socket) do
    send_update(NotifyListDialog, id: NotifyListDialog.id(), toggle: true)
    {:halt, socket}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens the standalone Notify List island (used by the `/notify` command)."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    send_update(NotifyListDialog, id: NotifyListDialog.id(), open: true)
    socket
  end
end
