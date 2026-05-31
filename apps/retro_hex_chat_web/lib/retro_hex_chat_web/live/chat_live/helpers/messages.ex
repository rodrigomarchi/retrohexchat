defmodule RetroHexChatWeb.ChatLive.Helpers.Messages do
  @moduledoc """
  Message factory functions for building stream-insertable message maps.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream_insert: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.IgnoreList

  @spec visible_channel_messages([map()], map()) :: [map()]
  def visible_channel_messages(messages, ignore_list) do
    Enum.reject(messages, fn msg ->
      ignored_author?(ignore_list, channel_author(msg), channel_message_type(msg))
    end)
  end

  @spec visible_private_messages([map()], map()) :: [map()]
  def visible_private_messages(messages, ignore_list) do
    Enum.reject(messages, fn msg ->
      ignored_author?(ignore_list, private_sender(msg), private_message_type(msg))
    end)
  end

  @spec system_message(String.t()) :: map()
  def system_message(content) do
    %{
      id: "system-#{System.unique_integer([:positive])}",
      author: dgettext("chat", "System"),
      content: content,
      type: :system,
      timestamp: DateTime.utc_now()
    }
  end

  @spec error_message(String.t()) :: map()
  def error_message(content) do
    %{
      id: "error-#{System.unique_integer([:positive])}",
      author: dgettext("chat", "System"),
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

  @spec inline_help_message(String.t(), String.t()) :: map()
  def inline_help_message(topic_id, topic_title) do
    %{
      id: "help-#{System.unique_integer([:positive])}",
      author: dgettext("chat", "Help"),
      content: topic_id,
      type: :inline_help,
      topic_id: topic_id,
      topic_title: topic_title,
      timestamp: DateTime.utc_now()
    }
  end

  @spec inline_help_event(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def inline_help_event(socket, topic_id, topic_title) do
    socket
    |> stream_insert(:chat_messages, inline_help_message(topic_id, topic_title))
    |> push_status_message(dgettext("chat", "Help: %{topic}", topic: topic_title), :system)
  end

  defp ignored_author?(_ignore_list, nil, _type), do: false

  defp ignored_author?(ignore_list, author, type),
    do: IgnoreList.ignored?(ignore_list, author, type)

  defp channel_author(msg), do: Map.get(msg, :author_nickname) || Map.get(msg, :author)

  defp private_sender(msg), do: Map.get(msg, :sender_nickname) || Map.get(msg, :sender)

  defp private_message_type(%{type: type}), do: normalize_private_type(type)
  defp private_message_type(_msg), do: :pm

  defp normalize_private_type(:p2p_invite), do: :invite
  defp normalize_private_type("p2p_invite"), do: :invite
  defp normalize_private_type(_type), do: :pm

  defp channel_message_type(%{type: type}) when is_atom(type), do: normalize_channel_type(type)
  defp channel_message_type(%{type: type}) when is_binary(type), do: normalize_channel_type(type)
  defp channel_message_type(_msg), do: :message

  defp normalize_channel_type(:action), do: :action
  defp normalize_channel_type("action"), do: :action
  defp normalize_channel_type(:notice), do: :notice
  defp normalize_channel_type("notice"), do: :notice
  defp normalize_channel_type(_type), do: :message
end
