defmodule RetroHexChatWeb.ChatLive.Helpers.Messages do
  @moduledoc """
  Message factory functions for building stream-insertable message maps.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream_insert: 3]

  @spec system_message(String.t()) :: map()
  def system_message(content) do
    %{
      id: "system-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :system,
      timestamp: DateTime.utc_now()
    }
  end

  @spec error_message(String.t()) :: map()
  def error_message(content) do
    %{
      id: "error-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :error,
      timestamp: DateTime.utc_now()
    }
  end

  @spec service_message(String.t(), String.t()) :: map()
  def service_message(author, content) do
    %{
      id: "service-#{System.unique_integer([:positive])}",
      author: author,
      content: content,
      type: :service,
      timestamp: DateTime.utc_now()
    }
  end

  @spec notice_message(String.t(), String.t()) :: map()
  def notice_message(author, content) do
    %{
      id: "notice-#{System.unique_integer([:positive])}",
      author: author,
      content: content,
      type: :notice,
      timestamp: DateTime.utc_now()
    }
  end

  @spec push_status_message(Phoenix.LiveView.Socket.t(), String.t(), atom()) ::
          Phoenix.LiveView.Socket.t()
  def push_status_message(socket, content, type) do
    msg = %{
      id: "status-#{System.unique_integer([:positive])}",
      content: content,
      type: type,
      timestamp: DateTime.utc_now()
    }

    socket = stream_insert(socket, :status_messages, msg)

    if socket.assigns.show_status_tab do
      socket
    else
      assign(socket, :status_unread, true)
    end
  end

  # ── Dual-write helpers (chat + status) ─────────────────────

  @spec system_event(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def system_event(socket, content) do
    socket
    |> stream_insert(:chat_messages, system_message(content))
    |> push_status_message(content, :system)
  end

  @spec error_event(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def error_event(socket, content) do
    socket
    |> stream_insert(:chat_messages, error_message(content))
    |> push_status_message(content, :error)
  end

  @spec service_event(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def service_event(socket, author, content) do
    socket
    |> stream_insert(:chat_messages, service_message(author, content))
    |> push_status_message(content, :system)
  end
end
