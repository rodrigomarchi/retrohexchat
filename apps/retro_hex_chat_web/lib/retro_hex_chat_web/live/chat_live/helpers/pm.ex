defmodule RetroHexChatWeb.ChatLive.Helpers.PM do
  @moduledoc """
  Private message conversation management and plain message/notice sending.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [maybe_persist_notify_list: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{Queries, Service}
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.SessionCard

  @spec load_pm_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  @spec load_pm_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t(), pos_integer()) ::
          Phoenix.LiveView.Socket.t()
  def load_pm_messages_with_pagination(socket, target, limit \\ 50) do
    session = socket.assigns.session
    raw_messages = Queries.list_private_messages(session.nickname, target, limit: limit)

    stream_pm_page(socket, raw_messages,
      has_more: length(raw_messages) == limit,
      loading_more: false
    )
  end

  @spec prepend_older_pm_messages(Phoenix.LiveView.Socket.t(), list()) ::
          Phoenix.LiveView.Socket.t()
  def prepend_older_pm_messages(socket, []) do
    assign(socket, loading_more: false, has_more: false)
  end

  def prepend_older_pm_messages(socket, older_messages) do
    new_oldest = List.last(older_messages)

    stream_items =
      older_messages
      |> Messages.visible_private_messages(socket.assigns.session.ignore_list)
      |> Enum.reverse()
      |> Enum.map(&pm_to_stream_item/1)

    socket
    |> assign(
      loading_more: false,
      oldest_message_id: new_oldest.id,
      has_more: length(older_messages) == 50,
      loaded_message_count: (socket.assigns[:loaded_message_count] || 50) + length(older_messages)
    )
    |> push_event("prepend_start", %{})
    |> MessageViewport.prepend(stream_items)
  end

  @spec open_pm_conversation(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def open_pm_conversation(socket, target) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    new_session =
      session
      |> Session.add_pm_conversation(target)
      |> Session.set_active_pm(target)

    socket
    |> assign(session: new_session, show_status_tab: false)
    |> tap(fn _ -> send_update(Composer, id: Composer.id(), reset_input: true) end)
    |> load_pm_messages_with_pagination(target)
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

        socket
        |> assign(session: new_session)
        |> maybe_auto_add_to_notify(target)

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
          dgettext("chat", "Cannot send text to status window. Use /commands."),
          :error
        )

      session.active_pm ->
        handle_pm_send(socket, session.active_pm, text)

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, text) do
          {:ok, _id} ->
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
      case Server.send_message(channel, session.nickname, content, :notice) do
        {:ok, _id} -> socket
        {:error, reason} -> Messages.error_event(socket, reason)
      end
    else
      Messages.error_event(
        socket,
        dgettext("chat", "You must be a member of %{channel} to send notices there",
          channel: channel
        )
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
          {:ok, _id} ->
            socket

          {:error, reason} ->
            Messages.error_event(socket, reason)
        end

      true ->
        socket
    end
  end

  @spec maybe_auto_add_to_notify(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_auto_add_to_notify(socket, other_nick) do
    session = socket.assigns.session

    if NotifyList.auto_add_pm?(session.notify_list) do
      case NotifyList.add_entry_with_rotation(
             session.notify_list,
             session.nickname,
             other_nick
           ) do
        {:ok, updated_list} ->
          updated_list = NotifyList.set_online(updated_list, other_nick, true)
          new_session = Session.set_notify_list(session, updated_list)

          socket
          |> assign(session: new_session)
          |> maybe_persist_notify_list(new_session)

        # :noop (already tracked) or {:error, :self_add}
        _skip ->
          socket
      end
    else
      socket
    end
  end

  # Private helpers

  defp stream_pm_page(socket, raw_messages, opts) do
    oldest_id =
      case List.last(raw_messages) do
        nil -> nil
        msg -> pm_field(msg, [:id])
      end

    stream_items =
      raw_messages
      |> Messages.visible_private_messages(socket.assigns.session.ignore_list)
      |> Enum.reverse()
      |> Enum.map(&pm_to_stream_item/1)

    assigns =
      opts
      |> Keyword.put(:oldest_message_id, oldest_id)
      |> Keyword.put(:loaded_message_count, length(raw_messages))
      |> maybe_put_clear_token(stream_items)

    socket
    |> maybe_clear_empty_stream(stream_items)
    |> assign(assigns)
    |> MessageViewport.reset(stream_items)
  end

  defp maybe_clear_empty_stream(socket, []), do: push_event(socket, "clear_chat_messages", %{})
  defp maybe_clear_empty_stream(socket, _stream_items), do: socket

  defp maybe_put_clear_token(assigns, []),
    do: Keyword.put(assigns, :chat_clear_token, System.unique_integer([:positive]))

  defp maybe_put_clear_token(assigns, _stream_items), do: assigns

  @doc """
  Live invite card (plan §4.7): re-enriches the P2P invite row for the given
  session and re-inserts it in place (same dom id), so the card never keeps
  promising an Accept that would fail. Only matters when the PM with that
  peer is on screen — a buffer opened later re-enriches on load anyway.
  """
  @spec refresh_p2p_invite_card(Phoenix.LiveView.Socket.t(), String.t() | nil, String.t()) ::
          Phoenix.LiveView.Socket.t()
  def refresh_p2p_invite_card(socket, peer_nick, token) when is_binary(peer_nick) do
    active = socket.assigns.session.active_pm

    with true <- is_binary(active),
         true <- String.downcase(active) == String.downcase(peer_nick),
         %{} = pm <-
           Queries.get_p2p_invite_between(socket.assigns.session.nickname, peer_nick, token) do
      MessageViewport.insert(socket, pm_to_stream_item(pm))
    else
      _ -> socket
    end
  end

  def refresh_p2p_invite_card(socket, _peer_nick, _token), do: socket

  defp pm_to_stream_item(pm) do
    base = %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:timestamp, :inserted_at])
    }

    base
    |> maybe_add_field(pm, :reply_to_id)
    |> maybe_add_field(pm, :reply_to_author)
    |> maybe_add_field(pm, :reply_to_preview)
    |> maybe_add_field(pm, :edited_at)
    |> maybe_add_field(pm, :deleted_at)
    |> SessionCard.enrich()
  end

  defp pm_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp maybe_add_field(map, source, key) do
    case Map.get(source, key) do
      nil -> map
      value -> Map.put(map, key, value)
    end
  end

  defp pm_resolve_type(%{type: type}), do: Messages.stream_type(type)
  defp pm_resolve_type(_), do: :message
end
