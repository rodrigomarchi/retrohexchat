defmodule RetroHexChatWeb.ChatLive.ConnectionEvents do
  @moduledoc """
  Handle connection-related events: ping/pong latency measurement, lag updates,
  and adopting the browser's RUM session id.

  Attached as `attach_hook(:connection_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  require Logger

  alias RetroHexChatWeb.ChatLive.Helpers.Connection

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def handle_event("ping", params, socket) do
    {:halt, Connection.handle_ping(socket, params)}
  end

  # The browser reports the Faro session it is recording under, once its SDK has
  # booted. Stamping it into this process's Logger metadata is what lets a
  # browser session and the server work it caused be read side by side in Loki:
  # the chat is a websocket, so no request header ever carries this across.
  def handle_event("rum_session", %{"id" => id}, socket)
      when is_binary(id) and id != "" and byte_size(id) <= 64 do
    Logger.metadata(rum_session_id: id)
    # One line per mount, and the only one guaranteed to exist: a session that
    # goes on to log nothing would otherwise leave no record that the two sides
    # were ever joined.
    Logger.info("rum_session_adopted")
    {:halt, socket}
  end

  def handle_event("rum_session", _params, socket), do: {:halt, socket}

  def handle_event("lag_update", params, socket) do
    {:halt, Connection.handle_lag_update(socket, params)}
  end

  def handle_event(_event, _params, socket) do
    {:cont, socket}
  end
end
