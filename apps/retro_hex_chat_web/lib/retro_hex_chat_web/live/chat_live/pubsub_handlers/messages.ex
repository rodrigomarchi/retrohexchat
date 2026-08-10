defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Messages do
  @moduledoc """
  PubSub handlers for channel messages, PMs, typing indicators, and notices.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      notice_message: 2,
      check_flood_and_auto_ignore: 4,
      maybe_highlight: 2,
      maybe_play_highlight_sound: 3,
      capture_urls: 6,
      play_event_sound: 3,
      maybe_flash_channel: 4,
      push_status_message: 3
    ]

  alias RetroHexChat.Accounts.Session

  alias RetroHexChat.Chat.{
    DuplicateTracker,
    FloodProtection,
    IgnoreList,
    Queries,
    Service,
    UnreadTracker
  }

  alias RetroHexChat.Observability
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages, as: MessageHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.PM
  alias RetroHexChatWeb.ChatLive.P2PSessionEvents
  alias RetroHexChatWeb.ChatLive.StreamItem

  # ── Channel messages ──────────────────────────────────────

  def handle_info(%{event: "new_message", payload: payload}, socket) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :receive],
      receive_metadata(:channel, payload, socket),
      fn -> do_handle_new_message(payload, socket) end
    )
  end

  def handle_info(%{event: "new_pm", payload: payload}, socket) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :receive],
      receive_metadata(:private, payload, socket),
      fn -> do_handle_new_pm(payload, socket) end
    )
  end

  # ── PM Typing PubSub Handlers ─────────────────────────────

  def handle_info(%{event: "typing", payload: %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick != session.nickname and
         session.active_pm == nick and
         not IgnoreList.ignored?(session.ignore_list, nick, :pm) do
      if socket.assigns.pm_typing_timer do
        Process.cancel_timer(socket.assigns.pm_typing_timer)
      end

      timer = Process.send_after(self(), :clear_typing_indicator, 5_000)

      {:halt, assign(socket, pm_typing_from: nick, pm_typing_timer: timer)}
    else
      {:halt, socket}
    end
  end

  def handle_info(%{event: "stop_typing", payload: %{nickname: nick}}, socket) do
    if socket.assigns.pm_typing_from == nick do
      if socket.assigns.pm_typing_timer do
        Process.cancel_timer(socket.assigns.pm_typing_timer)
      end

      {:halt, assign(socket, pm_typing_from: nil, pm_typing_timer: nil)}
    else
      {:halt, socket}
    end
  end

  # ── Message edited ───────────────────────────────────────

  def handle_info(%{event: "message_edited", payload: payload}, socket) do
    session = socket.assigns.session
    is_active = active_context?(payload, session)

    if is_active do
      case stream_item_for_message_event(payload, session) do
        nil -> {:halt, socket}
        updated_item -> {:halt, MessageViewport.insert(socket, updated_item)}
      end
    else
      {:halt, socket}
    end
  end

  # ── Message deleted ─────────────────────────────────────

  def handle_info(%{event: "message_deleted", payload: payload}, socket) do
    session = socket.assigns.session
    is_active = active_context?(payload, session)

    if is_active do
      case stream_item_for_message_event(payload, session) do
        nil -> {:halt, socket}
        deleted_item -> {:halt, MessageViewport.insert(socket, deleted_item)}
      end
    else
      {:halt, socket}
    end
  end

  # ── Reply quote updated ─────────────────────────────────

  def handle_info(
        %{event: "reply_quote_updated", payload: %{reply_ids: reply_ids}},
        socket
      ) do
    Enum.reduce(reply_ids, socket, fn reply_id, acc ->
      case stream_item_for_reply_quote(reply_id, acc.assigns.session) do
        nil -> acc
        item -> MessageViewport.insert(acc, item)
      end
    end)
    |> then(&{:halt, &1})
  end

  # ── Notices ───────────────────────────────────────────────

  def handle_info({:new_notice, %{sender: sender, content: content}}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, sender, :notice) do
      {:halt, socket}
    else
      {:halt, route_notice(socket, session, sender, content)}
    end
  end

  def handle_info(
        %{event: "new_notice", payload: %{author: author, content: content, channel: channel}},
        socket
      ) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, author, :notice) do
      {:halt, socket}
    else
      if channel == session.active_channel do
        {:halt, MessageViewport.insert(socket, notice_message(author, content))}
      else
        {:halt, socket}
      end
    end
  end

  # ── PM activity (sidebar/unread) ───────────────────────────

  def handle_info({:pm_activity, payload}, socket) do
    session = socket.assigns.session
    peer = Map.get(payload, :peer)
    direction = Map.get(payload, :direction, :incoming)
    msg_type = private_ignore_type(Map.get(payload, :type, :pm))

    cond do
      not is_binary(peer) ->
        {:halt, socket}

      IgnoreList.ignored?(session.ignore_list, peer, msg_type) ->
        {:halt, socket}

      true ->
        # Asked before the tab is opened, because opening it is what subscribes.
        first_of_conversation? = not PM.subscribed_to_pm?(socket, peer)

        socket =
          socket
          |> record_pm_activity(peer)
          |> maybe_open_pm_activity_tab(peer, direction, msg_type)
          |> maybe_capture_first_pm(payload, peer, direction, first_of_conversation?)
          |> maybe_mark_pm_activity_unread(peer, direction)
          |> maybe_refresh_p2p_pm_read_model(peer, msg_type)
          |> PM.maybe_auto_add_to_notify(peer)

        session = socket.assigns.session

        if direction == :incoming do
          {:halt, maybe_away_auto_reply(socket, peer, session)}
        else
          {:halt, socket}
        end
    end
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp do_handle_new_message(payload, socket) do
    session = socket.assigns.session

    msg_type =
      case payload.type do
        :action -> :action
        :notice -> :notice
        _ -> :message
      end

    if IgnoreList.ignored?(session.ignore_list, payload.author, msg_type) do
      {:halt, socket}
    else
      socket = check_channel_duplicate(socket, payload)

      if payload.type != :system and
           DuplicateTracker.duplicate?(
             socket.assigns.duplicate_tracker,
             payload.author,
             {:channel, payload.channel},
             payload.content,
             FloodProtection.get_spam_threshold(session.flood_protection),
             FloodProtection.get_spam_window_seconds(session.flood_protection)
           ) do
        {:halt, socket}
      else
        socket = check_flood_and_auto_ignore(socket, payload.author, payload.type, session)
        decorated = maybe_highlight(payload, session)

        socket =
          socket
          |> maybe_play_highlight_sound(decorated, session)
          |> capture_urls(
            payload.content,
            payload.channel,
            :channel,
            payload.author,
            payload_content_format(payload)
          )
          |> maybe_push_highlight_tip(decorated)

        {:halt, apply_new_message(socket, decorated, payload.channel, session)}
      end
    end
  end

  defp do_handle_new_pm(payload, socket) do
    session = socket.assigns.session
    msg_type = private_ignore_type(payload.type)

    if IgnoreList.ignored?(session.ignore_list, payload.sender, msg_type) do
      {:halt, socket}
    else
      socket = check_pm_duplicate(socket, payload)

      if DuplicateTracker.duplicate?(
           socket.assigns.duplicate_tracker,
           payload.sender,
           {:pm, payload.sender},
           payload.content,
           FloodProtection.get_spam_threshold(session.flood_protection),
           FloodProtection.get_spam_window_seconds(session.flood_protection)
         ) do
        {:halt, socket}
      else
        {:halt,
         socket
         |> push_event("tip_trigger", %{tip: "first_pm"})
         |> apply_new_pm(payload, session)}
      end
    end
  end

  defp route_notice(socket, _session, sender, content) do
    notice = notice_message(sender, content)
    MessageViewport.insert(socket, notice)
  end

  defp private_ignore_type(:p2p_invite), do: :invite
  defp private_ignore_type("p2p_invite"), do: :invite
  defp private_ignore_type(:invite), do: :invite
  defp private_ignore_type(_type), do: :pm

  defp maybe_push_highlight_tip(socket, %{highlighted: true}),
    do: push_event(socket, "tip_trigger", %{tip: "first_highlight"})

  defp maybe_push_highlight_tip(socket, _decorated), do: socket

  defp apply_new_message(socket, decorated, channel, session) do
    if channel == session.active_channel do
      apply_active_channel_message(socket, decorated, channel, session)
    else
      apply_background_message(socket, decorated, channel, session)
    end
  end

  defp apply_active_channel_message(socket, decorated, channel, session) do
    if MessageHelpers.cleared_from_channel?(socket, channel, decorated) do
      socket
    else
      apply_visible_channel_message(socket, decorated, session)
    end
  end

  # An own message echoes back with the persisted id that the optimistic row was
  # already keyed by, so `stream_insert` updates that row in place (clearing its
  # `pending` status). A message from anyone else carries a new id and appends.
  # Either way a plain insert is correct — no reconciliation bookkeeping needed.
  defp apply_visible_channel_message(socket, decorated, _session) do
    MessageViewport.insert(socket, decorated)
  end

  defp apply_background_message(socket, decorated, channel, session) do
    unread_counts = UnreadTracker.increment(socket.assigns.unread_counts, channel)
    highlight = maybe_add_highlight_channel(socket, decorated, channel)

    socket
    |> maybe_notify_unmuted(decorated, channel, session)
    |> assign(unread_counts: unread_counts, highlight_channels: highlight)
  end

  defp maybe_notify_unmuted(socket, decorated, channel, session) do
    is_muted = MapSet.member?(socket.assigns.muted_channels, channel)
    if is_muted, do: socket, else: notify_channel(socket, decorated, channel, session)
  end

  defp notify_channel(socket, decorated, channel, session) do
    is_highlighted = Map.get(decorated, :highlighted, false)
    flash_type = if is_highlighted, do: :highlight, else: :message

    socket
    |> maybe_play_sound(is_highlighted, session)
    |> maybe_flash_channel(channel, flash_type, session)
  end

  defp maybe_play_sound(socket, true = _is_highlighted, _session), do: socket

  defp maybe_play_sound(socket, false = _is_highlighted, session) do
    play_event_sound(socket, :message, session)
  end

  defp maybe_add_highlight_channel(socket, decorated, channel) do
    if Map.get(decorated, :highlighted),
      do: MapSet.put(socket.assigns.highlight_channels, channel),
      else: socket.assigns.highlight_channels
  end

  defp apply_new_pm(socket, payload, session) do
    socket = check_flood_and_auto_ignore(socket, payload.sender, :message, session)
    other_nick = pm_other_nick(payload, session.nickname)

    socket =
      capture_urls(
        socket,
        payload.content,
        other_nick,
        :pm,
        payload.sender,
        payload_content_format(payload)
      )

    socket =
      if socket.assigns.pm_typing_from == payload.sender do
        if socket.assigns.pm_typing_timer,
          do: Process.cancel_timer(socket.assigns.pm_typing_timer)

        assign(socket, pm_typing_from: nil, pm_typing_timer: nil)
      else
        socket
      end

    # The row is built before it is decorated, which is what lets a highlight
    # word reach a private conversation the way it reaches a channel: the row
    # that goes on screen is the one that was checked. Sound and tip fire even
    # when the conversation is not the one on screen, since a highlight the
    # reader cannot see yet is exactly the one worth announcing.
    decorated =
      payload
      |> StreamItem.from_private_message()
      |> maybe_highlight(session)

    socket =
      socket
      |> maybe_play_highlight_sound(decorated, session)
      |> maybe_push_highlight_tip(decorated)

    if session.active_pm == other_nick do
      MessageViewport.insert(socket, decorated)
    else
      socket
    end
  end

  # Exactly one message per conversation is captured here: the one that opened
  # it. Every later message reaches `do_handle_new_pm` on the conversation's own
  # topic and is captured there, so capturing again would file the same link
  # twice.
  defp maybe_capture_first_pm(socket, payload, peer, :incoming, true) do
    case Map.get(payload, :content) do
      content when is_binary(content) ->
        capture_urls(
          socket,
          content,
          peer,
          :pm,
          peer,
          Map.get(payload, :content_format) || "irc"
        )

      _ ->
        socket
    end
  end

  defp maybe_capture_first_pm(socket, _payload, _peer, _direction, _first?), do: socket

  defp record_pm_activity(socket, peer) do
    session = socket.assigns.session
    assign(socket, session: Session.add_pm_conversation(session, peer))
  end

  defp maybe_open_pm_activity_tab(socket, peer, _direction, _type),
    do: PM.ensure_pm_tab(socket, peer)

  defp maybe_mark_pm_activity_unread(socket, sender, :incoming) do
    session = socket.assigns.session

    if session.active_pm == sender do
      socket
    else
      pm_key = "pm:#{sender}"
      unread_counts = UnreadTracker.increment(socket.assigns.unread_counts, pm_key)

      socket
      |> maybe_notify_pm_unmuted(pm_key, session)
      |> assign(unread_counts: unread_counts)
    end
  end

  defp maybe_mark_pm_activity_unread(socket, _sender, _direction), do: socket

  defp maybe_refresh_p2p_pm_read_model(socket, peer, :invite),
    do: P2PSessionEvents.refresh_pm_session_read_model(socket, peer)

  defp maybe_refresh_p2p_pm_read_model(socket, _peer, _type), do: socket

  defp maybe_notify_pm_unmuted(socket, pm_key, session) do
    if MapSet.member?(socket.assigns.muted_channels, pm_key) do
      socket
    else
      socket
      |> play_event_sound(:pm, session)
      |> maybe_flash_channel(pm_key, :pm, session)
    end
  end

  defp maybe_away_auto_reply(socket, sender, session) do
    replied_to = socket.assigns.away_replied_to

    if session.away && sender != session.nickname &&
         not MapSet.member?(replied_to, sender) do
      away_msg = session.away_message

      reply =
        dgettext("chat", "%{nickname} is away: %{message}",
          nickname: session.nickname,
          message: away_msg
        )

      case Service.send_private_message(session.nickname, sender, reply, "system") do
        {:ok, _pm} ->
          socket
          |> assign(away_replied_to: MapSet.put(replied_to, sender))
          |> push_status_message(
            dgettext("chat", "* Sent away auto-reply to %{sender}", sender: sender),
            :system
          )

        {:error, _reason} ->
          socket
      end
    else
      socket
    end
  end

  defp pm_other_nick(payload, my_nick) do
    if payload.sender == my_nick, do: payload.recipient, else: payload.sender
  end

  defp payload_content_format(payload), do: Map.get(payload, :content_format) || "irc"

  defp stream_item_for_message_event(%{channel: _channel, id: id}, _session) do
    case Queries.get_message(id) do
      nil -> nil
      message -> StreamItem.from_message(message)
    end
  end

  defp stream_item_for_message_event(%{sender: _sender, id: id}, _session) do
    case Queries.get_private_message(id) do
      nil -> nil
      pm -> StreamItem.from_private_message(pm)
    end
  end

  defp stream_item_for_message_event(_payload, _session), do: nil

  defp stream_item_for_reply_quote(reply_id, %{active_pm: nil, active_channel: channel}) do
    case Queries.get_message(reply_id) do
      %{channel_name: ^channel} = message -> StreamItem.from_message(message)
      _ -> nil
    end
  end

  defp stream_item_for_reply_quote(reply_id, %{active_pm: active_pm, nickname: nickname})
       when not is_nil(active_pm) do
    case Queries.get_private_message(reply_id) do
      nil ->
        nil

      pm ->
        participants = MapSet.new([pm.sender_nickname, pm.recipient_nickname])

        if participants == MapSet.new([nickname, active_pm]) do
          StreamItem.from_private_message(pm)
        end
    end
  end

  defp stream_item_for_reply_quote(_reply_id, _session), do: nil

  defp check_channel_duplicate(socket, %{type: :system}), do: socket

  defp check_channel_duplicate(socket, payload) do
    tracker =
      DuplicateTracker.record_message(
        socket.assigns.duplicate_tracker,
        payload.author,
        {:channel, payload.channel},
        payload.content
      )

    assign(socket, duplicate_tracker: tracker)
  end

  defp check_pm_duplicate(socket, payload) do
    tracker =
      DuplicateTracker.record_message(
        socket.assigns.duplicate_tracker,
        payload.sender,
        {:pm, payload.sender},
        payload.content
      )

    assign(socket, duplicate_tracker: tracker)
  end

  defp active_context?(payload, session) do
    cond do
      Map.has_key?(payload, :channel) -> payload.channel == session.active_channel
      Map.has_key?(payload, :sender) -> session.active_pm != nil
      true -> false
    end
  end

  defp receive_metadata(:channel, payload, socket) do
    session = socket.assigns.session

    %{
      "chat.channel" => Map.get(payload, :channel),
      "chat.message.id" => Map.get(payload, :id),
      conversation_type: "channel",
      message_type: normalize_message_type(Map.get(payload, :type)),
      message_size_bytes: payload_size(payload),
      active_context: Map.get(payload, :channel) == session.active_channel
    }
  end

  defp receive_metadata(:private, payload, socket) do
    session = socket.assigns.session
    other_nick = pm_other_nick(payload, session.nickname)

    %{
      "chat.message.id" => Map.get(payload, :id),
      conversation_type: "private",
      message_type: normalize_message_type(Map.get(payload, :type)),
      message_size_bytes: payload_size(payload),
      active_context: session.active_pm == other_nick
    }
  end

  defp payload_size(%{content: content}) when is_binary(content), do: byte_size(content)
  defp payload_size(_payload), do: 0

  defp normalize_message_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_message_type(type) when is_binary(type), do: type
  defp normalize_message_type(_type), do: "unknown"
end
