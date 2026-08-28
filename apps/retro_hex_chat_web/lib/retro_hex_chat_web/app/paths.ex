defmodule RetroHexChatWeb.App.Paths do
  @moduledoc """
  The app's own routes, built once.

  These were chat helpers until a surface that is not the chat — a call, a
  space, a game in its own tab — needed the same two paths: where a session
  goes when it is cleared, and where someone goes when they have no session.
  Both are properties of the app, not of the chat, and a second copy of
  `/chat/session/clear` is a string nobody would think to keep in step.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @spec connect_path(Phoenix.LiveView.Socket.t()) :: String.t()
  def connect_path(_socket) do
    ~p"/connect"
  end

  @spec connect_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def connect_path(_socket, reason) do
    ~p"/connect?reason=#{reason}"
  end

  @doc "Where every surface's way back points."
  @spec chat_path(Phoenix.LiveView.Socket.t()) :: String.t()
  def chat_path(_socket) do
    ~p"/chat"
  end

  @doc "A conference at an address of its own, by its room token."
  @spec call_path(String.t()) :: String.t()
  def call_path(room_token), do: ~p"/call/#{room_token}"

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
