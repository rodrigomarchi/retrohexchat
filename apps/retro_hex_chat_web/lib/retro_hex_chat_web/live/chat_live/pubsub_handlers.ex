defmodule RetroHexChatWeb.ChatLive.PubsubHandlers do
  @moduledoc """
  Handle PubSub broadcast messages received via handle_info.

  Covers: new_message, new_pm, typing/stop_typing, notices, CTCP request/reply/timeout,
  mode_changed, user_kicked/banned/unbanned, ban/invite exceptions, topic_changed,
  user_joined/left, nick_changed, force_disconnect/rename, nickserv_identified,
  user_connected/disconnected, link_preview_result, channel_invite.

  Attached as `attach_hook(:pubsub_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      notice_message: 2,
      push_status_message: 3,
      check_flood_and_auto_ignore: 4,
      maybe_highlight: 2,
      maybe_play_highlight_sound: 3,
      capture_urls: 5,
      maybe_send_ctcp_reply: 7,
      play_event_sound: 3,
      maybe_flash_channel: 4,
      part_channel_after_kick: 2,
      maybe_fire_autorespond: 5,
      maybe_persist_notify_list: 2,
      join_channel: 3,
      rebuild_nick_color_fn: 2,
      load_persisted_data: 2,
      start_notify_debounce: 3,
      push_whois_info: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server

  alias RetroHexChat.Chat.{
    CapturedURL,
    CtcpSettings,
    DuplicateTracker,
    FloodProtection,
    IgnoreList,
    LinkPreview
  }

  alias RetroHexChat.Presence.{NotifyList, Tracker}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.CommandDispatch

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
        {:halt, apply_new_pm(socket, payload, session)}
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

  # ── CTCP handle_info ──────────────────────────────────────────

  def handle_info(
        {:ctcp_request, %{type: type, sender: sender, request_id: req_id, sent_at: sent_at}},
        socket
      ) do
    session = socket.assigns.session
    settings = Session.get_ctcp_settings(session)
    type_upper = type |> Atom.to_string() |> String.upcase()

    socket =
      stream_insert(
        socket,
        :chat_messages,
        system_message("* CTCP #{type_upper} request from #{sender}")
      )

    socket = maybe_send_ctcp_reply(socket, session, settings, type, sender, req_id, sent_at)
    {:halt, socket}
  end

  def handle_info(
        {:ctcp_reply,
         %{type: type, replier: replier, request_id: req_id, value: value, sent_at: sent_at}},
        socket
      ) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, req_id) do
      {nil, _} ->
        {:halt, socket}

      {%{timer_ref: timer_ref}, remaining} ->
        Process.cancel_timer(timer_ref)
        type_upper = type |> Atom.to_string() |> String.upcase()

        display_value =
          case type do
            :ping ->
              latency = System.monotonic_time(:millisecond) - sent_at
              "#{latency}ms"

            _ ->
              value
          end

        {:halt,
         socket
         |> assign(ctcp_pending: remaining)
         |> stream_insert(
           :chat_messages,
           system_message("* CTCP #{type_upper} reply from #{replier}: #{display_value}")
         )}
    end
  end

  def handle_info({:ctcp_timeout, request_id}, socket) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, request_id) do
      {nil, _} ->
        {:halt, socket}

      {%{target: target}, remaining} ->
        {:halt,
         socket
         |> assign(ctcp_pending: remaining)
         |> stream_insert(
           :chat_messages,
           system_message("* No CTCP reply from #{target} (timed out)")
         )}
    end
  end

  # Test helpers for CTCP
  def handle_info({:_test_add_ctcp_pending, request_id, data}, socket) do
    pending = Map.put(socket.assigns.ctcp_pending, request_id, data)
    {:halt, assign(socket, ctcp_pending: pending)}
  end

  def handle_info({:_test_set_ctcp_enabled, enabled}, socket) do
    session = socket.assigns.session
    settings = CtcpSettings.set_enabled(session.ctcp_settings, enabled)
    new_session = Session.set_ctcp_settings(session, settings)
    {:halt, assign(socket, session: new_session)}
  end

  # ── Mode changes ──────────────────────────────────────────

  def handle_info(
        {:mode_changed, %{nickname: nick, mode_string: mode_string, params: params} = payload},
        socket
      ) do
    msg = "#{nick} sets mode #{mode_string}"
    users = apply_mode_to_users(socket.assigns.channel_users, mode_string, params)

    socket =
      socket
      |> assign(channel_users: users)
      |> maybe_update_current_modes(payload)
      |> stream_insert(:chat_messages, system_message(msg))

    {:halt, socket}
  end

  def handle_info({:mode_changed, %{nickname: nick, mode_string: mode_string} = payload}, socket) do
    msg = "#{nick} sets mode #{mode_string}"
    channel = Map.get(payload, :channel)

    socket =
      socket
      |> maybe_update_current_modes(payload)
      |> maybe_refresh_cc(channel)
      |> stream_insert(:chat_messages, system_message(msg))

    {:halt, socket}
  end

  # ── User kicked/banned/unbanned ───────────────────────────

  def handle_info({:user_kicked, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was kicked by #{op}" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == target))

    if target == socket.assigns.session.nickname do
      socket =
        socket
        |> assign(channel_users: users)
        |> play_event_sound(:kick, socket.assigns.session)
        |> part_channel_after_kick(socket.assigns.session.active_channel)
        |> stream_insert(:chat_messages, system_message(msg))

      {:halt, socket}
    else
      {:halt,
       socket
       |> assign(channel_users: users)
       |> play_event_sound(:kick, socket.assigns.session)
       |> stream_insert(:chat_messages, system_message(msg))}
    end
  end

  def handle_info(
        {:user_banned, %{operator: op, target: target, reason: reason} = payload},
        socket
      ) do
    msg = "#{target} was banned by #{op}" <> if(reason, do: " (#{reason})", else: "")
    channel = Map.get(payload, :channel)

    {:halt,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_unbanned, %{operator: op, target: target} = payload}, socket) do
    msg = "#{target} was unbanned by #{op}"
    channel = Map.get(payload, :channel)

    {:halt,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # ── Exception broadcasts ──────────────────────────────────

  def handle_info({:ban_exception_added, %{channel: channel}}, socket) do
    {:halt, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:ban_exception_removed, %{channel: channel}}, socket) do
    {:halt, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:invite_exception_added, %{channel: channel}}, socket) do
    {:halt, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:invite_exception_removed, %{channel: channel}}, socket) do
    {:halt, maybe_refresh_cc(socket, channel)}
  end

  # ── Topic changed ─────────────────────────────────────────

  def handle_info({:topic_changed, %{nickname: nick, topic: topic} = payload}, socket) do
    msg = "#{nick} changed the topic to: #{topic}"
    channel = Map.get(payload, :channel)

    socket =
      if channel && channel == socket.assigns.session.active_channel do
        assign(socket, current_topic: topic)
      else
        socket
      end

    {:halt,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # ── User joined/left/nick_changed ─────────────────────────

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = "#{nick} has joined the channel"
    role = Map.get(payload, :role, :regular)
    channel = Map.get(payload, :channel)
    user = %{nickname: nick, role: role, away: false}
    users = [user | socket.assigns.channel_users]

    {:halt,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:join, socket.assigns.session)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_join,
       channel,
       nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason} = payload}, socket) do
    msg = "#{nick} has left" <> if(reason, do: " (#{reason})", else: "")
    channel = Map.get(payload, :channel)
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == nick))

    {:halt,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:part, socket.assigns.session)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_part,
       channel,
       nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  def handle_info({:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    msg = "#{old_nick} is now known as #{new_nick}"

    socket =
      if NotifyList.tracking?(socket.assigns.session.notify_list, old_nick) do
        session = socket.assigns.session
        updated_list = NotifyList.update_nickname(session.notify_list, old_nick, new_nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          "* Your notify list buddy #{old_nick} is now known as #{new_nick}",
          :notify_rename
        )
      else
        socket
      end

    socket =
      if IgnoreList.get_entry(socket.assigns.session.ignore_list, old_nick) do
        session = socket.assigns.session
        updated_list = IgnoreList.update_nickname(session.ignore_list, old_nick, new_nick)
        new_session = Session.set_ignore_list(session, updated_list)
        assign(socket, session: new_session)
      else
        socket
      end

    {:halt,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_nick_change,
       socket.assigns.session.active_channel,
       new_nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  # ── Force disconnect/rename ───────────────────────────────

  def handle_info({:force_disconnect, %{reason: reason}}, socket) do
    cleanup_channels(socket.assigns.session)

    {:halt,
     socket
     |> Phoenix.LiveView.put_flash(:error, "Disconnected: #{reason}")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:force_rename, %{reason: reason}}, socket) do
    old_nickname = socket.assigns.session.nickname
    guest_nick = "Guest_#{:rand.uniform(99999)}"
    session = Session.update_nickname(socket.assigns.session, guest_nick)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nickname}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{guest_nick}")

    msg = "[NickServ] #{reason}. You are now #{guest_nick}"

    {:halt,
     socket
     |> assign(session: session)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # ── NickServ identified ───────────────────────────────────

  def handle_info({:nickserv_identified, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick == session.nickname do
      new_session =
        session
        |> Session.set_identified(true)
        |> load_persisted_data(nick)

      {:halt,
       socket
       |> assign(session: new_session)
       |> rebuild_nick_color_fn(new_session)
       |> push_status_message("You are now identified as #{nick}", :system)}
    else
      {:halt, socket}
    end
  end

  # ── Global presence events ────────────────────────────────

  def handle_info({:user_connected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick == session.nickname do
      {:halt, socket}
    else
      if NotifyList.tracking?(session.notify_list, nick) do
        {:halt, start_notify_debounce(socket, nick, :online)}
      else
        {:halt, socket}
      end
    end
  end

  def handle_info({:user_disconnected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if NotifyList.tracking?(session.notify_list, nick) do
      {:halt, start_notify_debounce(socket, nick, :offline)}
    else
      {:halt, socket}
    end
  end

  # ── Notify debounce timer ─────────────────────────────────

  def handle_info({:notify_debounce, nickname, status}, socket) do
    session = socket.assigns.session
    timers = Map.delete(socket.assigns.notify_debounce_timers, String.downcase(nickname))

    online? = status == :online
    updated_list = NotifyList.set_online(session.notify_list, nickname, online?)
    new_session = Session.set_notify_list(session, updated_list)

    msg =
      if online?,
        do: "* #{nickname} is now online",
        else: "* #{nickname} has gone offline"

    type = if online?, do: :notify_online, else: :notify_offline

    buddy_sound = if online?, do: :buddy_online, else: :buddy_offline

    socket =
      socket
      |> assign(session: new_session, notify_debounce_timers: timers)
      |> maybe_persist_notify_list(new_session)
      |> push_status_message(msg, type)
      |> play_event_sound(buddy_sound, new_session)

    socket =
      if online? && new_session.notify_list.settings.auto_whois do
        push_whois_info(socket, nickname)
      else
        socket
      end

    {:halt, socket}
  end

  # ── Link preview result ───────────────────────────────────

  def handle_info({:link_preview_result, url, {:ok, title}}, socket) do
    LinkPreview.Cache.put(url, title)

    updated_entries =
      Enum.map(socket.assigns.url_catcher_entries, fn entry ->
        if entry.url == url, do: CapturedURL.set_preview_title(entry, title), else: entry
      end)

    socket =
      socket
      |> assign(
        link_previews: Map.put(socket.assigns.link_previews, url, title),
        url_catcher_entries: updated_entries
      )
      |> push_event("link_preview", %{url: url, title: title})

    {:halt, socket}
  end

  def handle_info({:link_preview_result, url, {:error, _}}, socket) do
    LinkPreview.Cache.put_error(url)
    {:halt, socket}
  end

  # ── Channel invite ────────────────────────────────────────

  def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
    session = socket.assigns.session

    if Session.get_auto_join_on_invite(session) do
      socket =
        socket
        |> join_channel(channel, session)
        |> stream_insert(
          :chat_messages,
          system_message("* You have been invited to #{channel} by #{inviter} (auto-joined)")
        )

      {:halt, socket}
    else
      pending = socket.assigns.pending_invites
      {pending, _old} = cancel_existing_invite(pending, channel)
      timer_ref = Process.send_after(self(), {:invite_expired, channel}, 300_000)

      invite = %{
        channel: channel,
        inviter: inviter,
        invited_at: DateTime.utc_now(),
        timer_ref: timer_ref
      }

      {:halt, assign(socket, pending_invites: pending ++ [invite])}
    end
  end

  # ── Task/DOWN catch-all ───────────────────────────────────

  def handle_info({_ref, _result}, socket), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp apply_mode_to_users(users, "+o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :operator}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :regular}, else: user
    end)
  end

  defp apply_mode_to_users(users, "+v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :voiced}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :regular}, else: user
    end)
  end

  defp apply_mode_to_users(users, _mode, _params), do: users

  defp maybe_update_current_modes(socket, payload) do
    channel = Map.get(payload, :channel)

    if channel && channel == socket.assigns.session.active_channel do
      case Server.get_state(channel) do
        {:ok, state} -> assign(socket, current_modes: state.modes)
        {:error, _} -> socket
      end
    else
      socket
    end
  end

  defp maybe_refresh_cc(socket, channel) do
    if socket.assigns.show_channel_central and socket.assigns.channel_central_channel == channel do
      refresh_channel_central(socket)
    else
      socket
    end
  end

  defp refresh_channel_central(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname
          operator = nickname in state.operators

          assign(socket, channel_central_state: state, channel_central_operator: operator)

        {:error, _} ->
          assign(socket,
            show_channel_central: false,
            channel_central_tab: "general",
            channel_central_channel: nil,
            channel_central_state: nil,
            channel_central_operator: false,
            channel_central_ban_selected: nil,
            channel_central_ban_ex_selected: nil,
            channel_central_invite_ex_selected: nil,
            channel_central_modes_form: %{},
            show_cc_add_ban_dialog: false,
            show_cc_add_ban_ex_dialog: false,
            show_cc_add_invite_ex_dialog: false
          )
      end
    else
      socket
    end
  end

  defp route_notice(socket, session, sender, content) do
    notice = notice_message(sender, content)

    case Session.get_notice_routing(session) do
      :active ->
        stream_insert(socket, :chat_messages, notice)

      :status ->
        if socket.assigns.show_status_tab do
          push_status_message(socket, "-#{sender}- #{content}", :notice)
        else
          stream_insert(socket, :chat_messages, notice)
        end

      :sender ->
        if sender in session.pm_conversations do
          stream_insert(socket, :chat_messages, notice)
        else
          stream_insert(socket, :chat_messages, notice)
        end
    end
  end

  defp apply_new_message(socket, decorated, channel, session) do
    if channel == session.active_channel do
      stream_insert(socket, :chat_messages, decorated)
    else
      unread = MapSet.put(socket.assigns.unread_channels, channel)
      highlight = maybe_add_highlight_channel(socket, decorated, channel)
      is_highlighted = Map.get(decorated, :highlighted, false)
      flash_type = if is_highlighted, do: :highlight, else: :message

      socket =
        if not is_highlighted do
          play_event_sound(socket, :message, session)
        else
          socket
        end

      socket
      |> maybe_flash_channel(channel, flash_type, session)
      |> assign(unread_channels: unread, highlight_channels: highlight)
    end
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

    if session.active_pm == other_nick do
      stream_insert(socket, :chat_messages, pm_to_stream_item(payload))
    else
      unread = MapSet.put(socket.assigns.unread_channels, "pm:#{other_nick}")

      socket
      |> play_event_sound(:pm, session)
      |> maybe_flash_channel("pm:#{other_nick}", :pm, session)
      |> assign(unread_channels: unread)
    end
  end

  defp pm_other_nick(payload, my_nick) do
    if payload.sender == my_nick, do: payload.recipient, else: payload.sender
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

  defp cancel_existing_invite(pending, channel) do
    case Enum.split_with(pending, &(&1.channel == channel)) do
      {[existing], rest} ->
        Process.cancel_timer(existing.timer_ref)
        {rest, existing}

      {[], _} ->
        {pending, nil}
    end
  end

  defp cleanup_channels(session) do
    NickServ.cancel_identify_timer(session.nickname)

    Enum.each(session.channels, fn channel ->
      try do
        Tracker.untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, "Connection lost")
      rescue
        e ->
          require Logger
          Logger.warning("Failed to part #{channel} during cleanup: #{inspect(e)}")
          :ok
      end
    end)
  end
end
