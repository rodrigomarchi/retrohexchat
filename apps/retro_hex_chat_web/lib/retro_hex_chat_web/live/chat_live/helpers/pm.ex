defmodule RetroHexChatWeb.ChatLive.Helpers.PM do
  @moduledoc """
  Private message conversation management and plain message/notice sending.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream: 4]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{Queries, Service}
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @spec open_pm_conversation(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def open_pm_conversation(socket, target) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    new_session =
      session
      |> Session.add_pm_conversation(target)
      |> Session.set_active_pm(target)

    messages = load_pm_messages(new_session.nickname, target)

    socket
    |> assign(session: new_session, input: "", show_status_tab: false)
    |> stream(:chat_messages, messages, reset: true)
  end

  @spec handle_pm_send(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_pm_send(socket, target, content) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    case Service.send_private_message(session.nickname, target, content) do
      {:ok, _pm} ->
        new_session =
          session
          |> Session.add_pm_conversation(target)
          |> Session.move_pm_to_front(target)

        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:incoming_pm_notify, %{sender: session.nickname}}
        )

        assign(socket, session: new_session)

      {:error, reason} ->
        Messages.error_event(socket, reason)
    end
  end

  @spec ensure_pm_subscription(String.t(), String.t()) :: :ok
  def ensure_pm_subscription(nick_a, nick_b) do
    topic = "pm:#{pm_topic(nick_a, nick_b)}"
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
  end

  @spec pm_topic(String.t(), String.t()) :: String.t()
  def pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  @spec send_plain_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def send_plain_message(socket, session, text) do
    cond do
      socket.assigns.show_status_tab ->
        Messages.push_status_message(
          socket,
          "Cannot send text to status window. Use /commands.",
          :error
        )

      session.active_pm ->
        handle_pm_send(socket, session.active_pm, text)

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, text) do
          :ok ->
            socket

          {:error, reason} ->
            Messages.error_event(socket, reason)
        end

      true ->
        socket
    end
  end

  @spec handle_notice_send(Phoenix.LiveView.Socket.t(), Session.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_notice_send(socket, session, "#" <> _ = channel, content) do
    if channel in session.channels do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel}",
        %{
          event: "new_notice",
          payload: %{
            author: session.nickname,
            content: content,
            channel: channel,
            timestamp: DateTime.utc_now()
          }
        }
      )

      socket
    else
      Messages.error_event(
        socket,
        "You must be a member of #{channel} to send notices there"
      )
    end
  end

  def handle_notice_send(socket, session, target, content) do
    alias RetroHexChatWeb.ChatLive.Helpers.Channel

    case Channel.validate_target_online(target) do
      :ok ->
        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:new_notice,
           %{sender: session.nickname, content: content, timestamp: DateTime.utc_now()}}
        )

        socket

      {:error, msg} ->
        Messages.error_event(socket, msg)
    end
  end

  @spec handle_action_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_action_message(socket, session, content) do
    cond do
      session.active_pm ->
        case Service.send_private_message(session.nickname, session.active_pm, content, "action") do
          {:ok, _pm} ->
            socket

          {:error, reason} ->
            Messages.error_event(socket, reason)
        end

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, content, :action) do
          :ok ->
            socket

          {:error, reason} ->
            Messages.error_event(socket, reason)
        end

      true ->
        socket
    end
  end

  # Private helpers

  defp load_pm_messages(my_nick, other_nick) do
    Queries.list_private_messages(my_nick, other_nick, limit: 50)
    |> Enum.reverse()
    |> Enum.map(&pm_to_stream_item/1)
  end

  defp pm_to_stream_item(pm) do
    %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:timestamp, :inserted_at])
    }
  end

  defp pm_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp pm_resolve_type(%{type: type}) when is_atom(type), do: type
  defp pm_resolve_type(%{type: type}) when is_binary(type), do: String.to_existing_atom(type)
  defp pm_resolve_type(_), do: :message
end
