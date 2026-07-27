defmodule RetroHexChatWeb.ChatLive.Helpers.PathHelpers do
  @moduledoc """
  Path helpers for chat navigation.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @spec connect_path(Phoenix.LiveView.Socket.t()) :: String.t()
  def connect_path(_socket) do
    ~p"/connect"
  end

  @spec session_clear_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def session_clear_path(socket, reason), do: session_clear_path(socket, reason, [])

  @spec session_clear_path(Phoenix.LiveView.Socket.t(), String.t(), keyword()) :: String.t()
  def session_clear_path(_socket, reason, opts) do
    if Keyword.get(opts, :forget_device, false) do
      ~p"/chat/session/clear?reason=#{reason}&forget_device=true"
    else
      ~p"/chat/session/clear?reason=#{reason}"
    end
  end

  @spec activity_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def activity_path(_socket, path) do
    path
  end
end
