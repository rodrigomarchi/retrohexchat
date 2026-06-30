defmodule RetroHexChatWeb.ChatLive.HighlightEvents do
  @moduledoc """
  Routes the Highlight Words dialog open/close triggers to the stateful island.

  All Highlight Words state, events and `HighlightWords` business logic live in
  `RetroHexChatWeb.ChatLive.Components.HighlightDialog`. This hook only opens the
  dialog (toolbar/menu action) and reflects the main dialog's Close/OK/Cancel and
  its own Escape/click-away back into the island via `send_update`; the highlight
  words are persisted by the parent when the component bubbles a new session.

  Attached as `attach_hook(:highlight_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.HighlightDialog

  def handle_event("open_highlight_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("close_highlight_dialog", _params, socket) do
    send_update(HighlightDialog, id: HighlightDialog.id(), close: true)
    {:halt, socket}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens the Highlight Words dialog by driving the island."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    send_update(HighlightDialog, id: HighlightDialog.id(), open: true)
    socket
  end

  @doc "Toggles the Highlight Words dialog open/closed (keyboard shortcut)."
  @spec toggle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def toggle(socket) do
    send_update(HighlightDialog, id: HighlightDialog.id(), toggle: true)
    socket
  end
end
