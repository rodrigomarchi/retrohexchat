defmodule RetroHexChatWeb.ChatLive.Helpers.PathHelpers do
  @moduledoc """
  Dynamic path helpers for v1/v2 navigation.

  When shared handlers (command_dispatch, menu_toolbar_events, etc.) need to
  navigate, they call these helpers instead of hardcoding v1 paths. The `:v2`
  assign on the socket determines which prefix to use.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @spec connect_path(Phoenix.LiveView.Socket.t()) :: String.t()
  def connect_path(socket) do
    if socket.assigns[:v2], do: ~p"/v2/connect", else: ~p"/connect"
  end

  @spec session_clear_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def session_clear_path(socket, reason) do
    if socket.assigns[:v2],
      do: ~p"/v2/chat/session/clear?reason=#{reason}",
      else: ~p"/chat/session/clear?reason=#{reason}"
  end

  @spec activity_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def activity_path(socket, path) do
    if socket.assigns[:v2], do: "/v2#{path}", else: path
  end
end
