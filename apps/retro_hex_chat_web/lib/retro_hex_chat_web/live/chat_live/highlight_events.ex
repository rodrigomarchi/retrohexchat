defmodule RetroHexChatWeb.ChatLive.HighlightEvents do
  @moduledoc """
  Routes the Highlight Words open trigger to its server-managed desktop window.

  All Highlight Words state, events and `HighlightWords` business logic live in
  `RetroHexChatWeb.ChatLive.Components.HighlightDialog`, mounted inside the
  window; closing the window unmounts the island. The highlight words are
  persisted by the parent when the component bubbles a new session.

  Attached as `attach_hook(:highlight_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_highlight_dialog", _params, socket) do
    {:halt, Windows.open(socket, "highlight")}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}
end
