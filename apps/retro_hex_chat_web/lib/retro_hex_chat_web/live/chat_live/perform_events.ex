defmodule RetroHexChatWeb.ChatLive.PerformEvents do
  @moduledoc """
  Routes the Perform open trigger to its server-managed desktop window.

  All Perform state, events and `PerformList` business logic live in
  `RetroHexChatWeb.ChatLive.Components.PerformDialog`, mounted inside the window;
  closing the window unmounts the island. The perform list is persisted by the
  parent when the component bubbles a new session.

  Attached as `attach_hook(:perform_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_perform_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens/focuses the Perform window.
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    Windows.open(socket, "perform")
  end
end
