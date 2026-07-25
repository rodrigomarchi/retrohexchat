defmodule RetroHexChatWeb.ChatLive.IgnoreListEvents do
  @moduledoc """
  Routes the Ignore List open trigger to its server-managed desktop window.

  All state, events and the `IgnoreList` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.IgnoreListDialog`, mounted inside the
  window; closing the window unmounts the island. The expiry timers stay on the
  parent, which the island drives with `{:ab_ignore_timer, ...}`.

  Attached as `attach_hook(:ignore_list_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_ignore_list_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the Ignore List window."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket), do: Windows.open(socket, "ignore-list")
end
