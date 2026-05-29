defmodule RetroHexChatWeb.ChatLive.PubsubHandlers do
  @moduledoc """
  Route PubSub broadcast messages to focused sub-modules.

  Delegates to:
  - `Messages` — new_message, new_pm, typing/stop_typing, notices
  - `ChannelState` — mode_changed, kicked/banned/unbanned, ban/invite exceptions, topic
  - `Membership` — user_joined/left, nick_changed, force_disconnect/rename, nickserv
  - `Presence` — user_connected/disconnected, notify_debounce, link_preview, invite

  Attached as `attach_hook(:pubsub_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  alias __MODULE__.{ChannelState, Membership, Messages, Presence, ServerMessages}

  # ── Messages: channel messages, PMs, typing, notices ──────

  def handle_info(%{event: "new_message"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "new_pm"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "typing"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "stop_typing"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info({:new_notice, _} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "new_notice"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info({:incoming_pm_notify, _} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "message_edited"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "message_deleted"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  def handle_info(%{event: "reply_quote_updated"} = msg, socket),
    do: Messages.handle_info(msg, socket)

  # ── Channel state: modes, kicks, bans, exceptions, topic ─

  def handle_info({:mode_changed, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_kicked, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_banned, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_unbanned, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:ban_exception_added, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:ban_exception_removed, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:invite_exception_added, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:invite_exception_removed, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:topic_changed, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:channel_deleted, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:channel_purged, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_channel_muted, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_channel_unmuted, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:knock, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  # ── Membership: join/leave, nick change, disconnect ───────

  def handle_info({:user_joined, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:user_left, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:nick_changed, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:force_disconnect, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:force_rename, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:nickserv_identified, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  # ── Admin: rename, role change, mute/unmute ───────────────

  def handle_info({:admin_rename, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:role_changed, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:user_muted, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:user_unmuted, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:server_setting_changed, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:system_nuked, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  # ── Presence: connect/disconnect, notify, previews, invite

  def handle_info({:user_connected, _} = msg, socket),
    do: Presence.handle_info(msg, socket)

  def handle_info({:user_disconnected, _} = msg, socket),
    do: Presence.handle_info(msg, socket)

  def handle_info({:notify_debounce, _, _} = msg, socket),
    do: Presence.handle_info(msg, socket)

  def handle_info({:link_preview_result, _, _} = msg, socket),
    do: Presence.handle_info(msg, socket)

  def handle_info({:channel_invite, _} = msg, socket),
    do: Presence.handle_info(msg, socket)

  # ── Server messages: announcements, wallops, MOTD, welcome ─

  def handle_info({:announcement, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:wallops, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:motd_updated, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  def handle_info({:welcome_changed, _} = msg, socket),
    do: ServerMessages.handle_info(msg, socket)

  # ── P2P: invite notification ─────────────────────────────

  def handle_info(%{event: "p2p_invite"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: %{token: token, from: from, session_type: session_type}} = msg

    label =
      case session_type do
        "audio_call" -> "Audio call from #{from}"
        "video_call" -> "Video call from #{from}"
        "file_transfer" -> "File transfer from #{from}"
        _ -> "P2P invite from #{from}"
      end

    {:halt, push_status_message(socket, "#{label} — /p2p/#{token}", :system)}
  end

  # ── Games: invite notification ────────────────────────────

  def handle_info(%{event: "game_invite"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: %{token: token, from: from}} = msg

    {:halt, push_status_message(socket, "Game invite from #{from} — /game/#{token}", :system)}
  end

  # ── P2P/Game: session ended ─────────────────────────────

  def handle_info(%{event: "p2p_session_ended"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: %{peer_nick: peer, session_type: type, reason: reason, duration_seconds: secs}} =
      msg

    label =
      case type do
        "audio_call" -> "Audio call"
        "video_call" -> "Video call"
        "file_transfer" -> "File transfer"
        _ -> "P2P session"
      end

    text = "#{label} with #{peer} ended (#{format_duration(secs)}) — #{humanize_reason(reason)}"
    {:halt, push_status_message(socket, text, :system)}
  end

  def handle_info(%{event: "game_session_ended"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: payload} = msg
    peer = payload.peer_nick
    game_label = payload.game_name || "Game"
    reason = payload.reason
    duration = payload[:duration_seconds]
    result = payload[:game_result]

    base =
      case reason do
        r when r in ["finished", "game_over"] -> "#{game_label} with #{peer} finished"
        _ -> "#{game_label} with #{peer} ended — #{humanize_reason(reason)}"
      end

    parts = [base]
    parts = if duration, do: parts ++ ["(#{format_duration(duration)})"], else: parts
    result_text = format_game_result(result)
    parts = if result_text != "", do: parts ++ [result_text], else: parts

    {:halt, push_status_message(socket, Enum.join(parts, " "), :system)}
  end

  def handle_info(%{event: "bot_notice", payload: payload}, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]
    import Phoenix.LiveView, only: [stream_insert: 3]

    msg = %{
      id: "system-#{System.unique_integer([:positive])}",
      author: "System",
      content: payload.content,
      type: :arcade_link,
      timestamp: DateTime.utc_now()
    }

    socket =
      socket
      |> stream_insert(:chat_messages, msg)
      |> push_status_message("#{payload.bot}: Arcade session ready!", :system)

    {:halt, socket}
  end

  def handle_info(%{event: "arcade_session_ended"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: payload} = msg
    game_label = payload.game_name || "Arcade game"
    reason = payload.reason
    duration = payload[:duration_seconds]

    base =
      case reason do
        r when r in ["finished", "game_over"] -> "#{game_label} finished"
        _ -> "#{game_label} ended — #{humanize_reason(reason)}"
      end

    parts = [base]
    parts = if duration, do: parts ++ ["(#{format_duration(duration)})"], else: parts

    {:halt, push_status_message(socket, Enum.join(parts, " "), :system)}
  end

  # ── Task/DOWN catch-all ───────────────────────────────────

  def handle_info({_ref, _result}, socket), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ─────────────────────────────────────

  defp format_duration(secs) when is_integer(secs) and secs >= 3600 do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    "#{h}h #{m}m"
  end

  defp format_duration(secs) when is_integer(secs) and secs >= 60 do
    m = div(secs, 60)
    s = rem(secs, 60)
    "#{m}m #{s}s"
  end

  defp format_duration(secs) when is_integer(secs), do: "#{secs}s"
  defp format_duration(_), do: "0s"

  defp format_game_result(%{"score" => %{"p1" => p1, "p2" => p2}, "winner" => w}),
    do: "— #{p1} × #{p2}#{format_winner(w)}"

  defp format_game_result(%{"score_p1" => p1, "score_p2" => p2, "winner" => w}),
    do: "— #{p1} × #{p2}#{format_winner(w)}"

  defp format_game_result(_), do: ""

  defp format_winner("draw"), do: ", draw"
  defp format_winner(0), do: ", draw"
  defp format_winner(_), do: ""

  defp humanize_reason("user_closed"), do: "closed by user"
  defp humanize_reason("disconnected"), do: "disconnected"
  defp humanize_reason("expired"), do: "expired"
  defp humanize_reason("pending_timeout"), do: "invite expired"
  defp humanize_reason("failed"), do: "connection failed"
  defp humanize_reason("lobby_inactivity"), do: "inactivity timeout"
  defp humanize_reason("game_ended"), do: "ended"
  defp humanize_reason("game_over"), do: "game over"
  defp humanize_reason(reason) when is_binary(reason), do: reason
  defp humanize_reason(_), do: "ended"
end
