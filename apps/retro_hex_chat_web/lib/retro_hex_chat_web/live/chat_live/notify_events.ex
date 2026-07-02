defmodule RetroHexChatWeb.ChatLive.NotifyEvents do
  @moduledoc """
  Routes the standalone Notify List open trigger to its server-managed window.

  All Notify List state, events and the `NotifyOps` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.NotifyListDialog` (and the Address Book's
  Notify tab in `Components.AddressBookDialog`), mounted inside the window.

  Attached as `attach_hook(:notify_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("toggle_notify_list", _params, socket) do
    {:halt, Windows.open(socket, "notify-list")}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the standalone Notify List window (used by the `/notify` command)."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket), do: Windows.open(socket, "notify-list")
end
