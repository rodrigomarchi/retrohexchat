defmodule RetroHexChatWeb.ChatLive.AutojoinEvents do
  @moduledoc """
  Routes the Auto-Join open trigger to its server-managed desktop window.

  All Auto-Join state, events and `AutoJoinList` business logic live in
  `RetroHexChatWeb.ChatLive.Components.AutojoinDialog`, mounted inside the
  window; closing the window unmounts the island. The auto-join list is
  persisted by the parent when the component bubbles a new session.

  Attached as `attach_hook(:autojoin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_autojoin_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens/focuses the Auto-Join window.
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    Windows.open(socket, "autojoin")
  end
end
