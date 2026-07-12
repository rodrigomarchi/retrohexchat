defmodule RetroHexChatWeb.ChatLive.PubsubHandlers do
  @moduledoc """
  Route PubSub broadcast messages to focused sub-modules.

  Delegates to:
  - `Messages` — new_message, new_pm, typing/stop_typing, notices
  - `ChannelState` — mode_changed, kicked/banned/unbanned, ban/invite exceptions, topic,
    group-call presence
  - `Membership` — user_joined/left, nick_changed, force_disconnect/rename, nickserv
  - `Presence` — user_connected/disconnected, notify_debounce, link_preview, invite

  Attached as `attach_hook(:pubsub_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.IgnoreList

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

  def handle_info({:group_call_started, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:group_call_updated, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:group_call_moderation, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  def handle_info({:group_call_ended, _} = msg, socket),
    do: ChannelState.handle_info(msg, socket)

  # ── Membership: join/leave, nick change, disconnect ───────

  def handle_info({:user_joined, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:user_left, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:nick_changed, _} = msg, socket),
    do: Membership.handle_info(msg, socket)

  def handle_info({:user_away_changed, _} = msg, socket),
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

  # ── P2P lobby: invite notification ───────────────────────

  def handle_info(%{event: "lobby_invite"} = msg, socket) do
    import RetroHexChatWeb.ChatLive.Helpers, only: [push_status_message: 3]

    %{payload: %{from: from}} = msg

    if ignored_invite?(socket, from) do
      {:halt, socket}
    else
      {:halt,
       push_status_message(
         socket,
         dgettext("chat", "P2P invite from %{from} — accept it in your private messages.",
           from: from
         ),
         :system
       )}
    end
  end

  # ── Task/DOWN catch-all ───────────────────────────────────
  # Swallow stray async `Task` results (`{ref, result}`, ref is a reference) and
  # their `:DOWN`s so they don't fall through. The `is_reference/1` guard is load
  # bearing: without it this clause halts EVERY 2-tuple, swallowing island→parent
  # bubbles like `{:cc_system_error, msg}` before they reach the LiveView.

  def handle_info({ref, _result}, socket) when is_reference(ref), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ─────────────────────────────────────

  defp ignored_invite?(socket, from) do
    IgnoreList.ignored?(socket.assigns.session.ignore_list, from, :invite)
  end
end
