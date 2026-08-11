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
  alias RetroHexChat.Chat.{Queries, Service, UnreadTracker}
  alias RetroHexChat.Page
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers
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
    stream_items =
      page
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
    socket = ensure_pm_subscription(socket, target)
    session = socket.assigns.session

    new_session =
      session
      |> Session.add_pm_conversation(target)
      |> Session.set_active_pm(target)

    # Bringing the conversation on screen reads it, exactly as switching to its
    # tab does — every entry point here (/query, nick double-click, hover card,
    # context menus, user lookup) would otherwise leave a stale unread badge on
    # the conversation being read.
    key = "pm:#{target}"

    socket
    |> open_pm_tab(target)
    |> assign(
      session: new_session,
      show_status_tab: false,
      unread_counts: UnreadTracker.reset(socket.assigns.unread_counts, key),
      flash_channels: MapSet.delete(socket.assigns.flash_channels, key)
    )
    |> tap(fn _ -> send_update(Composer, id: Composer.id(), reset_input: true) end)
    |> load_pm_messages_with_pagination(target)
    |> SessionHelpers.push_reconnect_state()
  end

  @spec open_pm_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open_pm_tab(socket, target) when is_binary(target) do
    open_tabs = socket.assigns[:open_pm_tabs] || []
    assign(socket, open_pm_tabs: [target | List.delete(open_tabs, target)])
  end

  # Subscribing here and not only when the reader opens the tab is what makes the
  # *first* message of a conversation behave like every later one. The tab is
  # created by the `pm_activity` broadcast that accompanies that first message,
  # and until this call the process was not on the conversation's topic at all —
  # so the message that opened the tab never reached `handle_info`, and its links
  # were never captured or previewed.
  @spec ensure_pm_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def ensure_pm_tab(socket, target) when is_binary(target) do
    socket = ensure_pm_subscription(socket, target)
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
  # The sender joins the conversation's topic before sending, so its own message
  # comes back through the same path the recipient's does. Without this the
  # sender was never on the topic at all: the message appeared because the
  # composer draws it, while everything the broadcast drives — URL capture, the
  # link card — only ever happened for the other person.
  def handle_pm_send(socket, target, content) do
    socket = ensure_pm_subscription(socket, target)
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
    case socket.assigns[:p2p_session] do
      %{token: token, peer_nick: peer} when is_binary(peer) ->
        if String.downcase(peer) == String.downcase(target),
          do: RetroHexChat.Lobby.record_activity(token)

        socket

      _ ->
        socket
    end
  end

  @doc """
  Subscribes this process to a conversation, at most once.

  `Phoenix.PubSub.subscribe/2` is not idempotent: three calls deliver every
  broadcast three times. This is called from seven places — opening a tab,
  switching to one, a nick change, three timer paths, a reconnect — so a reader
  who returned to the same conversation four times was running `capture_urls`,
  the flood tracker and the duplicate tracker four times per incoming message.
  Nothing showed it, because the message stream is keyed by id and simply
  replaced the row it had already drawn.

  The set of topics this connection holds is socket state, so it is an assign
  rather than something read back out of the registry.
  """
  @spec ensure_pm_subscription(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def ensure_pm_subscription(socket, peer) when is_binary(peer) do
    topic = "pm:#{pm_topic(socket.assigns.session.nickname, peer)}"
    subscribed = socket.assigns[:pm_subscriptions] || MapSet.new()

    if MapSet.member?(subscribed, topic) do
      socket
    else
      :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
      assign(socket, pm_subscriptions: MapSet.put(subscribed, topic))
    end
  end

  def ensure_pm_subscription(socket, _peer), do: socket

  @doc "Whether this connection is already on a conversation's topic."
  @spec subscribed_to_pm?(Phoenix.LiveView.Socket.t(), String.t()) :: boolean()
  def subscribed_to_pm?(socket, peer) when is_binary(peer) do
    topic = "pm:#{pm_topic(socket.assigns.session.nickname, peer)}"
    MapSet.member?(socket.assigns[:pm_subscriptions] || MapSet.new(), topic)
  end

  def subscribed_to_pm?(_socket, _peer), do: false

  @doc """
  Drops a conversation's subscription, so a later `ensure` really re-subscribes.

  Used when a peer renames: the old topic is gone and the new one has to be
  joined, which cannot happen if the socket still believes it is subscribed.
  """
  @spec drop_pm_subscription(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def drop_pm_subscription(socket, peer) when is_binary(peer) do
    topic = "pm:#{pm_topic(socket.assigns.session.nickname, peer)}"
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, topic)

    assign(
      socket,
      pm_subscriptions: MapSet.delete(socket.assigns[:pm_subscriptions] || MapSet.new(), topic)
    )
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
