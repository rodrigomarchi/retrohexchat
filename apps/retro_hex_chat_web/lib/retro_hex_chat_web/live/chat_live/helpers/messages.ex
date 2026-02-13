defmodule RetroHexChatWeb.ChatLive.Helpers.Messages do
  @moduledoc """
  Message factory functions for building stream-insertable message maps.
  """

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

    stream_insert(socket, :status_messages, msg)
  end
end
