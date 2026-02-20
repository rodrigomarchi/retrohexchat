defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Messages do
  @moduledoc """
  PubSub handlers for channel messages, PMs, typing indicators, and notices.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      notice_message: 2,
      check_flood_and_auto_ignore: 4,
      maybe_highlight: 2,
      maybe_play_highlight_sound: 3,
      capture_urls: 5,
      play_event_sound: 3,
      maybe_flash_channel: 4,
      maybe_push_notification: 3
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{DuplicateTracker, FloodProtection, IgnoreList, UnreadTracker}
  alias RetroHexChatWeb.ChatLive.Helpers.PM

  # ── Channel messages ──────────────────────────────────────

  def handle_info(%{event: "new_message", payload: payload}, socket) do
    session = socket.assigns.session
    msg_type = if payload.type == :action, do: :action, else: :message

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
          |> capture_urls(payload.content, payload.channel, :channel, payload.author)
          |> maybe_push_highlight_tip(decorated)

        {:halt, apply_new_message(socket, decorated, payload.channel, session)}
      end
    end
  end

  def handle_info(%{event: "new_pm", payload: payload}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, payload.sender, :pm) do
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
      updated_item = %{
        id: payload.id,
        content: payload.content,
        edited_at: payload.edited_at
      }

      {:halt, stream_insert(socket, :chat_messages, updated_item)}
    else
      {:halt, socket}
    end
  end

  # ── Message deleted ─────────────────────────────────────

  def handle_info(%{event: "message_deleted", payload: payload}, socket) do
    session = socket.assigns.session
    is_active = active_context?(payload, session)

    if is_active do
      deleted_item = %{
        id: payload.id,
        deleted_at: payload.deleted_at
      }

      {:halt, stream_insert(socket, :chat_messages, deleted_item)}
    else
      {:halt, socket}
    end
  end

  # ── Reply quote updated ─────────────────────────────────

  def handle_info(
        %{event: "reply_quote_updated", payload: %{reply_ids: reply_ids, new_preview: preview}},
        socket
      ) do
    Enum.reduce(reply_ids, socket, fn reply_id, acc ->
      stream_insert(acc, :chat_messages, %{
        id: reply_id,
        reply_to_preview: preview
      })
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
        {:halt, stream_insert(socket, :chat_messages, notice_message(author, content))}
      else
        {:halt, socket}
      end
    end
  end

  # ── Incoming PM notification (auto-open + away auto-reply) ──

  def handle_info({:incoming_pm_notify, %{sender: sender}}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, sender, :pm) do
      {:halt, socket}
    else
      socket = maybe_auto_open_incoming_pm(socket, session, sender)
      session = socket.assigns.session
      {:halt, maybe_away_auto_reply(socket, sender, session)}
    end
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp route_notice(socket, _session, sender, content) do
    notice = notice_message(sender, content)
    stream_insert(socket, :chat_messages, notice)
  end

  defp maybe_push_highlight_tip(socket, %{highlighted: true}),
    do: push_event(socket, "tip_trigger", %{tip: "first_highlight"})

  defp maybe_push_highlight_tip(socket, _decorated), do: socket

  defp apply_new_message(socket, decorated, channel, session) do
    if channel == session.active_channel do
      stream_insert(socket, :chat_messages, decorated)
    else
      apply_background_message(socket, decorated, channel, session)
    end
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
    event_type = if is_highlighted, do: :mention, else: :channel_message

    socket
    |> maybe_play_sound(is_highlighted, session)
    |> maybe_flash_channel(channel, flash_type, session)
    |> maybe_push_notification(event_type, %{
      channel: channel,
      sender: Map.get(decorated, :author, "Unknown"),
      content: Map.get(decorated, :content, ""),
      highlighted: is_highlighted
    })
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
    socket = capture_urls(socket, payload.content, other_nick, :pm, payload.sender)

    socket =
      if socket.assigns.pm_typing_from == payload.sender do
        if socket.assigns.pm_typing_timer,
          do: Process.cancel_timer(socket.assigns.pm_typing_timer)

        assign(socket, pm_typing_from: nil, pm_typing_timer: nil)
      else
        socket
      end

    # Reorder by recency — move to front on every message
    session = Session.move_pm_to_front(session, other_nick)
    socket = assign(socket, session: session)

    if session.active_pm == other_nick do
      stream_insert(socket, :chat_messages, pm_to_stream_item(payload))
    else
      unread_counts = UnreadTracker.increment(socket.assigns.unread_counts, "pm:#{other_nick}")

      socket
      |> play_event_sound(:pm, session)
      |> maybe_flash_channel("pm:#{other_nick}", :pm, session)
      |> maybe_push_notification(:pm, %{
        channel: nil,
        sender: payload.sender,
        content: payload.content,
        highlighted: true
      })
      |> assign(unread_counts: unread_counts)
    end
  end

  defp maybe_auto_open_incoming_pm(socket, session, sender) do
    if sender in session.pm_conversations do
      socket
    else
      PM.ensure_pm_subscription(session.nickname, sender)
      new_session = Session.add_pm_conversation(session, sender)
      assign(socket, session: new_session)
    end
  end

  defp maybe_away_auto_reply(socket, sender, session) do
    replied_to = socket.assigns.away_replied_to

    if session.away && sender != session.nickname &&
         not MapSet.member?(replied_to, sender) do
      away_msg = session.away_message
      reply = "#{session.nickname} is away: #{away_msg}"
      topic = "pm:#{pm_topic(session.nickname, sender)}"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, %{
        event: "new_pm",
        payload: %{
          id: System.unique_integer([:positive]),
          sender: session.nickname,
          recipient: sender,
          content: reply,
          type: :system,
          timestamp: DateTime.utc_now()
        }
      })

      assign(socket, away_replied_to: MapSet.put(replied_to, sender))
    else
      socket
    end
  end

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp pm_other_nick(payload, my_nick) do
    if payload.sender == my_nick, do: payload.recipient, else: payload.sender
  end

  defp pm_to_stream_item(pm) do
    base = %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:timestamp, :inserted_at])
    }

    reply_to_id = Map.get(pm, :reply_to_id)

    if reply_to_id do
      Map.merge(base, %{
        reply_to_id: reply_to_id,
        reply_to_author: Map.get(pm, :reply_to_author),
        reply_to_preview: Map.get(pm, :reply_to_preview)
      })
    else
      base
    end
  end

  defp pm_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp pm_resolve_type(%{type: type}) when is_atom(type), do: type
  defp pm_resolve_type(%{type: type}) when is_binary(type), do: String.to_existing_atom(type)
  defp pm_resolve_type(_), do: :message

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
      true -> true
    end
  end
end
