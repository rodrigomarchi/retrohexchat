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
      check_flood_and_auto_ignore: 5,
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
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel
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
      socket =
        remember_for_duplicates(socket, payload, payload.author, {:channel, payload.channel})

      if spam?(socket, payload, payload.author, {:channel, payload.channel}, session) do
        {:halt, socket}
      else
        socket =
          check_flood_and_auto_ignore(
            socket,
            payload.author,
            payload.type,
            {:channel, payload.channel},
            session
          )

        # Built before it is decorated, and built by the same thing that builds
        # every other row. Assembling a live channel message by hand would give
        # it the shape the broadcast happened to have, not the shape a row has.
        decorated =
          payload
          |> StreamItem.from_message()
          |> maybe_highlight(session)

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

  # A private message is delivered once to each of the two people in it, and
  # everything that message causes — the row, the tab, the unread badge, the
  # sound — happens here. One delivery on one topic in one shape is the whole
  # point: split it across two and the seam is where the first message of a
  # conversation, its link previews and its highlight fall through, because one
  # half cannot reach a conversation the reader has not opened yet and the other
  # carries half the fields.
  defp do_handle_new_pm(payload, socket) do
    session = socket.assigns.session

    if unwanted?(payload, session) do
      {:halt, socket}
    else
      socket = remember_for_duplicates(socket, payload, payload.sender, {:pm, payload.sender})

      if spam?(socket, payload, payload.sender, {:pm, payload.sender}, session) do
        {:halt, socket}
      else
        {:halt, apply_new_pm(socket, payload, session)}
      end
    end
  end

  # Somebody can be refused; oneself cannot. The two halves of this used to
  # disagree about that — a message written to an ignored person drew its row
  # while its tab, its place in the conversation list and its notify-list entry
  # were all dropped.
  defp unwanted?(%{direction: :incoming, peer: peer} = payload, session),
    do: IgnoreList.ignored?(session.ignore_list, peer, private_ignore_type(payload.type))

  defp unwanted?(_payload, _session), do: false

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
    socket = ConversationsReadModel.touch_channel_activity(socket, channel)

    if channel == session.active_channel do
      apply_active_channel_message(socket, decorated, channel, session)
    else
      apply_background_message(socket, decorated, channel, session)
    end
  end

  defp apply_active_channel_message(socket, decorated, channel, session) do
    if MessageHelpers.cleared_from_conversation?(socket, channel, decorated) do
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

  defp apply_new_pm(socket, %{peer: peer} = payload, session) do
    socket =
      socket
      |> assign(session: Session.add_pm_conversation(session, peer))
      |> PM.ensure_pm_tab(peer)
      |> check_flood_and_auto_ignore(payload.sender, :message, {:private, peer}, session)
      |> capture_urls(
        payload.content,
        peer,
        :pm,
        payload.sender,
        payload_content_format(payload)
      )
      |> clear_typing_indicator(payload.sender)
      |> push_event("tip_trigger", %{tip: "first_pm"})

    # The row is built before it is decorated, which is what lets a highlight
    # word reach a private conversation the way it reaches a channel: the row
    # that goes on screen is the one that was checked. Sound and tip fire even
    # when the conversation is not the one on screen, since a highlight the
    # reader cannot see yet is exactly the one worth announcing.
    decorated =
      payload
      |> StreamItem.from_private_message()
      |> maybe_highlight(session)

    socket
    |> maybe_play_highlight_sound(decorated, session)
    |> maybe_push_highlight_tip(decorated)
    |> place_pm_row(decorated, payload)
    |> maybe_refresh_p2p_pm_read_model(peer, private_ignore_type(payload.type))
    |> PM.maybe_auto_add_to_notify(peer)
    |> maybe_away_auto_reply(payload)
  end

  defp clear_typing_indicator(socket, sender) do
    if socket.assigns.pm_typing_from == sender do
      if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)
      assign(socket, pm_typing_from: nil, pm_typing_timer: nil)
    else
      socket
    end
  end

  defp place_pm_row(socket, decorated, %{peer: peer} = payload) do
    if socket.assigns.session.active_pm == peer do
      if MessageHelpers.cleared_from_conversation?(socket, "pm:#{peer}", decorated),
        do: socket,
        else: MessageViewport.insert(socket, decorated)
    else
      mark_pm_background(socket, decorated, payload)
    end
  end

  # A conversation nobody is looking at is marked the way a channel is: the
  # sidebar reads one set of unread counts, one set of flashes and one set of
  # highlights for both kinds of conversation. Only what somebody else wrote is
  # unread — a message of one's own arrives here too, from another window.
  defp mark_pm_background(socket, decorated, %{peer: peer} = payload) do
    key = "pm:#{peer}"
    socket = maybe_count_pm_unread(socket, key, payload)

    assign(socket, highlight_channels: maybe_add_highlight_channel(socket, decorated, key))
  end

  defp maybe_count_pm_unread(socket, key, %{direction: :incoming}) do
    session = socket.assigns.session
    unread_counts = UnreadTracker.increment(socket.assigns.unread_counts, key)

    socket
    |> maybe_notify_pm_unmuted(key, session)
    |> assign(unread_counts: unread_counts)
  end

  defp maybe_count_pm_unread(socket, _key, _decorated), do: socket

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

  defp maybe_away_auto_reply(socket, %{direction: :incoming, peer: peer}),
    do: away_auto_reply(socket, peer, socket.assigns.session)

  defp maybe_away_auto_reply(socket, _payload), do: socket

  defp away_auto_reply(socket, sender, session) do
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

  defp payload_content_format(payload), do: Map.get(payload, :content_format) || "irc"

  # An edit, a delete or a reply quote is broadcast on its own conversation's
  # topic, and this connection holds every topic whose tab is open — not only
  # the one on screen. The row is built only if it belongs to the conversation
  # being looked at, which is a question about the message rather than about the
  # broadcast: a private payload names one participant, and a conversation is
  # the pair.
  defp stream_item_for_message_event(%{channel: _channel, id: id}, session) do
    id |> Queries.get_message() |> stream_item_if_active(session, &StreamItem.from_message/1)
  end

  defp stream_item_for_message_event(%{sender: _sender, id: id}, session) do
    id
    |> Queries.get_private_message()
    |> stream_item_if_active(session, &StreamItem.from_private_message/1)
  end

  defp stream_item_for_message_event(_payload, _session), do: nil

  defp stream_item_for_reply_quote(reply_id, %{active_pm: nil} = session) do
    reply_id
    |> Queries.get_message()
    |> stream_item_if_active(session, &StreamItem.from_message/1)
  end

  defp stream_item_for_reply_quote(reply_id, session) do
    reply_id
    |> Queries.get_private_message()
    |> stream_item_if_active(session, &StreamItem.from_private_message/1)
  end

  defp stream_item_if_active(nil, _session, _build), do: nil

  defp stream_item_if_active(message, session, build) do
    if MessageHelpers.in_active_conversation?(message, session), do: build.(message)
  end

  # Spam protection is about people, so the system is exempt from both halves:
  # its lines are neither counted towards a repeat nor dropped as one, on the
  # private path exactly as on the channel one. Without the exemption here,
  # three identical `p2p_system` lines inside the spam window lose the third.
  defp remember_for_duplicates(socket, payload, sender, target_key) do
    if MessageHelpers.from_system?(payload) do
      socket
    else
      tracker =
        DuplicateTracker.record_message(
          socket.assigns.duplicate_tracker,
          sender,
          target_key,
          payload.content
        )

      assign(socket, duplicate_tracker: tracker)
    end
  end

  defp spam?(socket, payload, sender, target_key, session) do
    not MessageHelpers.from_system?(payload) and
      DuplicateTracker.duplicate?(
        socket.assigns.duplicate_tracker,
        sender,
        target_key,
        payload.content,
        FloodProtection.get_spam_threshold(session.flood_protection),
        FloodProtection.get_spam_window_seconds(session.flood_protection)
      )
  end

  # A cheap filter that avoids a database read for a conversation nobody is
  # looking at. It is deliberately loose for a private one — the payload names a
  # single participant, which does not identify the conversation — so the answer
  # it gives is "possibly", and `stream_item_for_message_event/2` settles it once
  # it has the row.
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
    %{
      "chat.message.id" => Map.get(payload, :id),
      conversation_type: "private",
      message_type: normalize_message_type(Map.get(payload, :type)),
      message_size_bytes: payload_size(payload),
      active_context: socket.assigns.session.active_pm == Map.get(payload, :peer)
    }
  end

  defp payload_size(%{content: content}) when is_binary(content), do: byte_size(content)
  defp payload_size(_payload), do: 0

  defp normalize_message_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_message_type(type) when is_binary(type), do: type
  defp normalize_message_type(_type), do: "unknown"
end
