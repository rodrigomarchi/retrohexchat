defmodule RetroHexChatWeb.ChatLive.KickEvents do
  @moduledoc """
  Handle kick dialog dismiss events.

  Dequeues the first kick event when the user clicks OK.
  Attached as `attach_hook(:kick_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def handle_event("kick_dialog_dismiss", _params, socket) do
    kick_queue =
      case socket.assigns.kick_queue do
        [_ | rest] -> rest
        [] -> []
      end

    {:halt, assign(socket, kick_queue: kick_queue)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
