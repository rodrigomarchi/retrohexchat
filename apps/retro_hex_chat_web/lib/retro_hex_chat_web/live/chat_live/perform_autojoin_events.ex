defmodule RetroHexChatWeb.ChatLive.PerformAutojoinEvents do
  @moduledoc """
  Routes the Perform open trigger to its server-managed desktop window.

  All Perform/AutoJoin state, events and `PerformList`/`AutoJoinList` business
  logic live in `RetroHexChatWeb.ChatLive.Components.PerformDialog`, mounted
  inside the window; closing the window unmounts the island. The
  perform/autojoin lists are persisted by the parent when the component bubbles
  a new session.

  Attached as `attach_hook(:perform_autojoin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Components.PerformDialog
  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_perform_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens/focuses the Perform window on a specific tab. The window mounts first
  (managed); the tab directive is deferred one hop via `Windows.open_with/4`
  so the client can patch the freshly mounted island.
  """
  @spec open(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket, tab \\ "commands") do
    Windows.open_with(socket, "perform", PerformDialog, id: PerformDialog.id(), open: tab)
  end
end
