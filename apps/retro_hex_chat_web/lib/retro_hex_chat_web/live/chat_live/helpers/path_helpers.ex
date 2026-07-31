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
    query =
      [reason: reason]
      |> maybe_put_query(:forget_device, "true", Keyword.get(opts, :forget_device, false))
      |> maybe_put_query(
        :disconnected_by_session_ref,
        Keyword.get(opts, :disconnected_by_session_ref),
        true
      )

    ~p"/chat/session/clear?#{query}"
  end

  @spec activity_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def activity_path(_socket, path) do
    path
  end

  defp maybe_put_query(query, key, value, true) when is_binary(value) and value != "" do
    Keyword.put(query, key, value)
  end

  defp maybe_put_query(query, _key, _value, _condition), do: query
end
