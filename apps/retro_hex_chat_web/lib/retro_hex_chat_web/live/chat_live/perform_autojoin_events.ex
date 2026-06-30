defmodule RetroHexChatWeb.ChatLive.PerformAutojoinEvents do
  @moduledoc """
  Routes the Perform dialog open/close triggers to the stateful island.

  All Perform/AutoJoin state, events and `PerformList`/`AutoJoinList` business
  logic live in `RetroHexChatWeb.ChatLive.Components.PerformDialog`. This hook only
  opens the dialog (toolbar/menu action) and reflects the main dialog's
  Close/OK/Cancel and its own Escape/click-away back into the island via
  `send_update`; the perform/autojoin lists are persisted by the parent when the
  component bubbles a new session.

  Attached as `attach_hook(:perform_autojoin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.PerformDialog

  def handle_event("open_perform_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("close_perform_dialog", _params, socket) do
    send_update(PerformDialog, id: PerformDialog.id(), close: true)
    {:halt, socket}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens the Perform dialog (optionally on a specific tab) by driving the island.
  """
  @spec open(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket, tab \\ "commands") do
    send_update(PerformDialog, id: PerformDialog.id(), open: tab)
    socket
  end

  @doc """
  Toggles the Perform dialog open/closed (keyboard shortcut).
  """
  @spec toggle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def toggle(socket) do
    send_update(PerformDialog, id: PerformDialog.id(), toggle: true)
    socket
  end
end
