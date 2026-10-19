defmodule RetroHexChatWeb.ChatLive.GameEvents do
  @moduledoc """
  The game channel's strip, pressed.

  "Find a partner" is `/lfg` with no mode, run through the same command
  pipeline as when it is typed — the strip is a shortcut to the command, not a
  second way of opening a seat.

  Attached as `attach_hook(:game_events, :handle_event, ...)` in DesktopLive.
  """

  alias RetroHexChatWeb.ChatLive.CommandDispatch

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("game_lfg", _params, socket),
    do: {:halt, CommandDispatch.dispatch_command(socket, socket.assigns.session, "lfg", [])}

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
