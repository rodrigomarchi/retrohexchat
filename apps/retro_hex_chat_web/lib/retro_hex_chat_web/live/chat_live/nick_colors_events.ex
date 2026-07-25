defmodule RetroHexChatWeb.ChatLive.NickColorsEvents do
  @moduledoc """
  Routes the Nick Colors open trigger to its server-managed desktop window.

  All state, events and the `NickColors` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.NickColorsDialog`, mounted inside the
  window; closing the window unmounts the island.

  Attached as `attach_hook(:nick_colors_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_nick_colors_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the Nick Colors window."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket), do: Windows.open(socket, "nick-colors")
end
