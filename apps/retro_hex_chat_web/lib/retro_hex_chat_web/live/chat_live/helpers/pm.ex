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
  alias RetroHexChat.Page
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.P2PReadModel
  alias RetroHexChatWeb.ChatLive.StreamItem

  @spec load_pm_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  @spec load_pm_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t(), pos_integer()) ::
          Phoenix.LiveView.Socket.t()
  def load_pm_messages_with_pagination(socket, target, limit \\ 50) do
    session = socket.assigns.session
    conversation = "pm:#{target}"

    # Through `Page.filter/2` so hiding what was cleared cannot shorten the page
    # into claiming there is nothing older — the same reason the channel loader
    # filters this way.
    page =
      session.nickname
      |> Queries.list_private_messages(target, limit: limit)
      |> Page.filter(&(not Messages.cleared_from_conversation?(socket, conversation, &1)))

    stream_pm_page(socket, page)
  end

  @spec prepend_older_pm_messages(Phoenix.LiveView.Socket.t(), Page.t()) ::
          Phoenix.LiveView.Socket.t()
  def prepend_older_pm_messages(socket, %Page{items: []} = page) do
    assign(socket, has_more: page.has_more)
  end

  def prepend_older_pm_messages(socket, %Page{} = page) do
    conversation = Messages.conversation_key(socket.assigns.session)

    stream_items =
      page
      |> Page.filter(&(not Messages.cleared_from_conversation?(socket, conversation, &1)))
      |> Messages.visible_private_page(socket.assigns.session.ignore_list)
      |> Map.fetch!(:items)
      |> Enum.reverse()
      |> Enum.map(&StreamItem.from_private_message/1)

    socket
    |> assign(
      oldest_message_id: page.next_cursor,
      has_more: page.has_more,
      loaded_message_count: (socket.assigns[:loaded_message_count] || 50) + length(page.items)
    )
    |> push_event("prepend_start", %{})
    |> MessageViewport.prepend(stream_items)
  end

  @spec open_pm_conversation(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def open_pm_conversation(socket, target) do
    # Opening a conversation from somewhere else — /query, a nick double-click, a
    # hover card, a context menu, the user lookup — is switching to it plus one
    # thing: the composer starts empty, the way joining a channel does. Switching
    # between conversations already on screen carries a half-typed line along.
    socket
    |> Conversation.activate_pm(target)
    |> tap(fn _ -> send_update(Composer, id: Composer.id(), reset_input: true) end)
  end

  @spec open_pm_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open_pm_tab(socket, target) when is_binary(target) do
    open_tabs = socket.assigns[:open_pm_tabs] || []
    assign(socket, open_pm_tabs: [target | List.delete(open_tabs, target)])
  end

  @doc "Opens the tab a message arrived in, if it was not open already."
  @spec ensure_pm_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def ensure_pm_tab(socket, target) when is_binary(target) do
    open_tabs = socket.assigns[:open_pm_tabs] || []

    if target in open_tabs do
      socket
    else
      assign(socket, open_pm_tabs: open_tabs ++ [target])
    end
  end

  @spec close_pm_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def close_pm_tab(socket, target) when is_binary(target) do
    open_tabs = socket.assigns[:open_pm_tabs] || []
    assign(socket, open_pm_tabs: List.delete(open_tabs, target))
  end

  @spec pm_tab_open?(Phoenix.LiveView.Socket.t(), String.t()) :: boolean()
  def pm_tab_open?(socket, target) when is_binary(target) do
    target in (socket.assigns[:open_pm_tabs] || [])
  end

  @spec handle_pm_send(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_pm_send(socket, target, content) do
    session = socket.assigns.session

    case Service.send_private_message(session.nickname, target, content) do
      {:ok, _pm} ->
        new_session =
          session
          |> Session.add_pm_conversation(target)
          |> Session.move_pm_to_front(target)

        socket
        |> assign(session: new_session)
        |> maybe_auto_add_to_notify(target)
        |> touch_p2p_session(target)

      {:error, reason} ->
        Messages.error_event(socket, reason)
    end
  end

  # A PM to the P2P peer counts as session activity: it resets the
  # pre-connection inactivity timers (no-op once connected).
  defp touch_p2p_session(socket, target) do
    case Map.get(P2PReadModel.pm_sessions(socket), String.downcase(target)) do
      %{token: token} when is_binary(token) -> RetroHexChat.Lobby.record_activity(token)
      _none -> :ok
    end

    socket
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

  defp stream_pm_page(socket, %Page{} = page) do
    stream_items =
      page
      |> Messages.visible_private_page(socket.assigns.session.ignore_list)
      |> Map.fetch!(:items)
      |> Enum.reverse()
      |> Enum.map(&StreamItem.from_private_message/1)

    assigns =
      [
        oldest_message_id: page.next_cursor,
        has_more: page.has_more,
        loaded_message_count: length(page.items)
      ]
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
  Refreshes the P2P invite transcript row for the given session and re-inserts
  it in place (same dom id). Only matters when the PM with that peer is on
  screen — a buffer opened later re-enriches on load anyway.
  """
  @spec refresh_p2p_invite_row(Phoenix.LiveView.Socket.t(), String.t() | nil, String.t()) ::
          Phoenix.LiveView.Socket.t()
  def refresh_p2p_invite_row(socket, peer_nick, token) when is_binary(peer_nick) do
    active = socket.assigns.session.active_pm

    with true <- is_binary(active),
         true <- String.downcase(active) == String.downcase(peer_nick),
         %{} = pm <-
           Queries.get_p2p_invite_between(socket.assigns.session.nickname, peer_nick, token) do
      MessageViewport.insert(socket, StreamItem.from_private_message(pm))
    else
      _ -> socket
    end
  end

  def refresh_p2p_invite_row(socket, _peer_nick, _token), do: socket
end
