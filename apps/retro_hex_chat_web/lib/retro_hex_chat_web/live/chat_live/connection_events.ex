defmodule RetroHexChatWeb.ChatLive.ConnectionEvents do
  @moduledoc """
  Handle connection-related events: ping/pong latency measurement, lag updates.

  Attached as `attach_hook(:connection_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.Helpers.Connection

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def handle_event("ping", params, socket) do
    {:halt, Connection.handle_ping(socket, params)}
  end

  def handle_event("lag_update", params, socket) do
    {:halt, Connection.handle_lag_update(socket, params)}
  end

  def handle_event(_event, _params, socket) do
    {:cont, socket}
  end
end
