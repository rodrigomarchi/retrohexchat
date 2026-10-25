defmodule RetroHexChatWeb.ChatLive.WindowOpenEvents do
  @moduledoc """
  The menu, toolbar and Start menu events that only open (or focus) a window.

  Each window's state and events live in its dialog island, mounted inside the
  window; this hook only turns the event into the window's id for
  `ChatLive.Windows.open/2`. The events are the `opener:` of the windows
  `WindowRegistry` declares without the admin gate.

  Attached as `attach_hook(:window_open_events, :handle_event, ...)` in DesktopLive.
  """

  alias RetroHexChatWeb.ChatLive.{WindowRegistry, Windows}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event(event, _params, socket) do
    case Map.fetch(WindowRegistry.openers(:plain), event) do
      {:ok, window} -> {:halt, Windows.open(socket, window)}
      :error -> {:cont, socket}
    end
  end
end
