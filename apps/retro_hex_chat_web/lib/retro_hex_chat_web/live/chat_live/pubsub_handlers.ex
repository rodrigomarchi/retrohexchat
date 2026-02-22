defmodule RetroHexChatWeb.ChatLive.PubsubHandlers do
  @moduledoc """
  Route PubSub broadcast messages to focused sub-modules.

  Delegates to:
  - `Messages` — new_message, new_pm, typing/stop_typing, notices
  - `Ctcp` — ctcp_request, ctcp_reply, ctcp_timeout, test helpers
  - `ChannelState` — mode_changed, kicked/banned/unbanned, ban/invite exceptions, topic
  - `Membership` — user_joined/left, nick_changed, force_disconnect/rename, nickserv
  - `Presence` — user_connected/disconnected, notify_debounce, link_preview, invite

  Attached as `attach_hook(:pubsub_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  alias __MODULE__.{ChannelState, Ctcp, Membership, Messages, Presence, ServerMessages}

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

  # ── CTCP ──────────────────────────────────────────────────

  def handle_info({:ctcp_request, _} = msg, socket),
    do: Ctcp.handle_info(msg, socket)

  def handle_info({:ctcp_reply, _} = msg, socket),
    do: Ctcp.handle_info(msg, socket)

  def handle_info({:ctcp_timeout, _} = msg, socket),
    do: Ctcp.handle_info(msg, socket)

  def handle_info({:_test_add_ctcp_pending, _, _} = msg, socket),
    do: Ctcp.handle_info(msg, socket)

  def handle_info({:_test_set_ctcp_enabled, _} = msg, socket),
    do: Ctcp.handle_info(msg, socket)

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

  def handle_info({:user_channel_muted, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:user_channel_unmuted, _} = msg, socket),
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
    import Phoenix.LiveView, only: [push_event: 3]

    %{payload: %{token: token, from: from, session_type: session_type}} = msg

    body =
      case session_type do
        "audio_call" -> "#{from} wants to start an audio call"
        "video_call" -> "#{from} wants to start a video call"
        "file_transfer" -> "#{from} wants to send a file"
        _ -> "#{from} wants to start a P2P session"
      end

    socket =
      push_event(socket, "notify", %{
        id: "p2p_invite_#{token}",
        title: "P2P Invite",
        body: body,
        type: "p2p_invite",
        token: token,
        from: from,
        session_type: session_type,
        persistent: true
      })

    {:halt, socket}
  end

  # ── Task/DOWN catch-all ───────────────────────────────────

  def handle_info({_ref, _result}, socket), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}
end
