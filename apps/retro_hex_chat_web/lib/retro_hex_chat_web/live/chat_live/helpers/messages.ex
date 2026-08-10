defmodule RetroHexChatWeb.ChatLive.Helpers.Messages do
  @moduledoc """
  Message factory functions for building stream-insertable message maps.
  """

  import Phoenix.Component, only: [assign: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Page
  alias RetroHexChatWeb.ChatLive.Components.{MessageViewport, StatusViewport}

  @spec visible_channel_messages([map()], map()) :: [map()]
  def visible_channel_messages(messages, ignore_list) do
    Enum.filter(messages, &visible_channel_message?(&1, ignore_list))
  end

  @spec visible_private_messages([map()], map()) :: [map()]
  def visible_private_messages(messages, ignore_list) do
    Enum.filter(messages, &visible_private_message?(&1, ignore_list))
  end

  @doc """
  Hides ignored authors from a page **without touching its pagination state**.

  Going through `Page.filter/2` rather than rebuilding the struct is what keeps
  an ignored author from ending pagination for the whole channel.
  """
  @spec visible_channel_page(Page.t(), map()) :: Page.t()
  def visible_channel_page(%Page{} = page, ignore_list) do
    Page.filter(page, &visible_channel_message?(&1, ignore_list))
  end

  @spec visible_private_page(Page.t(), map()) :: Page.t()
  def visible_private_page(%Page{} = page, ignore_list) do
    Page.filter(page, &visible_private_message?(&1, ignore_list))
  end

  @spec visible_channel_message?(map(), map()) :: boolean()
  def visible_channel_message?(msg, ignore_list) do
    not ignored_author?(ignore_list, channel_author(msg), channel_message_type(msg))
  end

  @spec visible_private_message?(map(), map()) :: boolean()
  def visible_private_message?(msg, ignore_list) do
    not ignored_author?(ignore_list, private_sender(msg), private_message_type(msg))
  end

  @spec system_message(String.t()) :: map()
  def system_message(content) do
    %{
      id: "system-#{System.unique_integer([:positive])}",
      author: dgettext("chat", "System"),
      content: content,
      content_format: "irc",
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
      content_format: "irc",
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
      content_format: "irc",
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
      content_format: "irc",
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

    socket = StatusViewport.insert(socket, msg)

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
    |> MessageViewport.insert(system_message(content))
    |> push_status_message(content, :system)
  end

  @spec error_event(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def error_event(socket, content) do
    socket
    |> MessageViewport.insert(error_message(content))
    |> push_status_message(content, :error)
  end

  @spec service_event(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def service_event(socket, author, content) do
    socket
    |> MessageViewport.insert(service_message(author, content))
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
    |> MessageViewport.insert(inline_help_message(topic_id, topic_title))
    |> push_status_message(dgettext("chat", "Help: %{topic}", topic: topic_title), :system)
  end

  @stream_types ~w(message action system service error notice announcement inline_help arcade_link p2p_invite p2p_system)a
  @stream_type_by_string Map.new(@stream_types, fn type -> {Atom.to_string(type), type} end)

  @spec stream_type(atom() | String.t() | nil) :: atom()
  def stream_type(type) when is_atom(type) do
    if type in @stream_types, do: type, else: :message
  end

  def stream_type(type) when is_binary(type) do
    Map.get(@stream_type_by_string, type, :message)
  end

  def stream_type(_type), do: :message

  @doc """
  Whether a channel message was written before the reader cleared that channel.

  Clearing is per reader and per channel, and it hides rather than deletes: the
  messages stay on the server for everyone else, and the reader's own cutoff is
  what keeps them off this screen. Both the page loaded from history and the
  message arriving live have to answer this the same way, or clearing a channel
  would hold only until the next message redrew it.

  A message states when it was written under one of two names depending on where
  it came from — `inserted_at` from the database, `timestamp` from a broadcast —
  and one that states neither is treated as newer than any cutoff, so an
  unreadable timestamp shows the message rather than swallowing it.
  """
  @spec cleared_from_channel?(Phoenix.LiveView.Socket.t(), String.t(), map()) :: boolean()
  def cleared_from_channel?(socket, channel, message) do
    case Map.get(socket.assigns[:cleared_channel_cutoffs] || %{}, channel) do
      nil -> false
      cutoff -> compare_written_at(written_at(message), cutoff) != :gt
    end
  end

  defp written_at(%{timestamp: written_at}), do: written_at
  defp written_at(%{inserted_at: written_at}), do: written_at
  defp written_at(_message), do: nil

  defp compare_written_at(%DateTime{} = written_at, %DateTime{} = cutoff) do
    DateTime.compare(written_at, cutoff)
  end

  defp compare_written_at(%NaiveDateTime{} = written_at, %DateTime{} = cutoff) do
    NaiveDateTime.compare(written_at, DateTime.to_naive(cutoff))
  end

  defp compare_written_at(%DateTime{} = written_at, %NaiveDateTime{} = cutoff) do
    NaiveDateTime.compare(DateTime.to_naive(written_at), cutoff)
  end

  defp compare_written_at(%NaiveDateTime{} = written_at, %NaiveDateTime{} = cutoff) do
    NaiveDateTime.compare(written_at, cutoff)
  end

  defp compare_written_at(_written_at, _cutoff), do: :gt

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
