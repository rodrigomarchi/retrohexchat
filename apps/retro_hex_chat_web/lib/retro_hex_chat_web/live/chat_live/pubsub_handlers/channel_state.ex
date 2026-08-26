defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.ChannelState do
  @moduledoc """
  PubSub handlers for channel state changes: mode changes, kicks, bans,
  ban/invite exceptions, and topic changes.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
      play_event_sound: 3,
      part_channel_after_kick: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Roster
  alias RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog
  alias RetroHexChatWeb.ChatLive.Components.KickQueueDialog
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.GroupCallEvents

  # ── Mode changes ──────────────────────────────────────────

  def handle_info(
        {:mode_changed, %{nickname: nick, mode_string: mode_string, params: params} = payload},
        socket
      ) do
    msg = dgettext("chat", "%{nickname} sets mode %{mode}", nickname: nick, mode: mode_string)
    users = apply_mode_to_users(socket.assigns.conversation_members, mode_string, params)

    socket =
      socket
      |> assign(conversation_members: users)
      |> Nicklist.reset(users)
      |> maybe_update_current_modes(payload)
      |> system_event(msg)

    {:halt, socket}
  end

  def handle_info({:mode_changed, %{nickname: nick, mode_string: mode_string} = payload}, socket) do
    msg = dgettext("chat", "%{nickname} sets mode %{mode}", nickname: nick, mode: mode_string)
    channel = Map.get(payload, :channel)

    socket =
      socket
      |> maybe_update_current_modes(payload)
      |> maybe_refresh_cc(channel)
      |> system_event(msg)

    {:halt, socket}
  end

  # ── User kicked/banned/unbanned ───────────────────────────

  def handle_info(
        {:user_kicked, %{operator: op, target: target, reason: reason} = payload},
        socket
      ) do
    channel = Map.get(payload, :channel) || socket.assigns.session.active_channel

    msg =
      append_reason(
        dgettext("chat", "%{target} was kicked by %{operator}", target: target, operator: op),
        reason
      )

    users = Enum.reject(socket.assigns.conversation_members, &(&1.nickname == target))

    if target == socket.assigns.session.nickname do
      kick_event = %{
        channel: channel,
        operator: op,
        reason: reason
      }

      send_update(KickQueueDialog, id: KickQueueDialog.id(), action: {:enqueue, kick_event})

      socket =
        socket
        |> assign(conversation_members: users)
        |> play_event_sound(:kick, socket.assigns.session)
        |> part_channel_after_kick(channel)
        |> GroupCallEvents.leave_channel_call(kick_event.channel, "channel_kick")
        |> system_event(msg)

      {:halt, socket}
    else
      {:halt,
       socket
       |> assign(conversation_members: users)
       |> Nicklist.remove(target)
       |> play_event_sound(:kick, socket.assigns.session)
       |> system_event(msg)}
    end
  end

  def handle_info(
        {:user_banned, %{operator: op, target: target, reason: reason} = payload},
        socket
      ) do
    msg =
      append_reason(
        dgettext("chat", "%{target} was banned by %{operator}", target: target, operator: op),
        reason
      )

    channel = Map.get(payload, :channel)

    {:halt,
     socket
     |> maybe_refresh_cc(channel)
     |> system_event(msg)}
  end

  def handle_info({:user_unbanned, %{operator: op, target: target} = payload}, socket) do
    msg = dgettext("chat", "%{target} was unbanned by %{operator}", target: target, operator: op)
    channel = Map.get(payload, :channel)

    {:halt,
     socket
     |> maybe_refresh_cc(channel)
     |> system_event(msg)}
  end

  # ── Exception broadcasts ──────────────────────────────────

  def handle_info(
        {:ban_exception_added, %{channel: channel, nickname: nick, added_by: op}},
        socket
      ) do
    socket =
      socket
      |> maybe_refresh_cc(channel)
      |> system_event(
        dgettext("chat", "%{operator} added ban exception for %{nickname} in %{channel}",
          operator: op,
          nickname: nick,
          channel: channel
        )
      )

    {:halt, socket}
  end

  def handle_info(
        {:ban_exception_removed, %{channel: channel, nickname: nick, removed_by: op}},
        socket
      ) do
    socket =
      socket
      |> maybe_refresh_cc(channel)
      |> system_event(
        dgettext("chat", "%{operator} removed ban exception for %{nickname} in %{channel}",
          operator: op,
          nickname: nick,
          channel: channel
        )
      )

    {:halt, socket}
  end

  def handle_info(
        {:invite_exception_added, %{channel: channel, nickname: nick, added_by: op}},
        socket
      ) do
    socket =
      socket
      |> maybe_refresh_cc(channel)
      |> system_event(
        dgettext("chat", "%{operator} added invite exception for %{nickname} in %{channel}",
          operator: op,
          nickname: nick,
          channel: channel
        )
      )

    {:halt, socket}
  end

  def handle_info(
        {:invite_exception_removed, %{channel: channel, nickname: nick, removed_by: op}},
        socket
      ) do
    socket =
      socket
      |> maybe_refresh_cc(channel)
      |> system_event(
        dgettext("chat", "%{operator} removed invite exception for %{nickname} in %{channel}",
          operator: op,
          nickname: nick,
          channel: channel
        )
      )

    {:halt, socket}
  end

  # ── Topic changed ─────────────────────────────────────────

  def handle_info({:topic_changed, %{nickname: nick, topic: topic} = payload}, socket) do
    msg =
      dgettext("chat", "%{nickname} changed the topic to: %{topic}", nickname: nick, topic: topic)

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
     |> system_event(msg)}
  end

  # ── Admin channel events ──────────────────────────────────

  def handle_info({:channel_deleted, %{channel: channel, admin: admin}}, socket) do
    if channel == socket.assigns.session.active_channel do
      {:halt,
       socket
       |> system_event(
         dgettext("chat", "Channel %{channel} has been deleted by %{admin}.",
           channel: channel,
           admin: admin
         )
       )
       |> part_channel_after_kick(channel)}
    else
      {:halt,
       system_event(
         socket,
         dgettext("chat", "Channel %{channel} has been deleted by %{admin}.",
           channel: channel,
           admin: admin
         )
       )}
    end
  end

  def handle_info({:channel_purged, %{channel: channel, admin: admin, from: from}}, socket) do
    if channel == socket.assigns.session.active_channel do
      msg =
        if from,
          do:
            dgettext("chat", "Channel %{channel} history from %{from} was purged by %{admin}.",
              channel: channel,
              from: from,
              admin: admin
            ),
          else:
            dgettext("chat", "Channel %{channel} history was purged by %{admin}.",
              channel: channel,
              admin: admin
            )

      {:halt,
       socket
       |> load_channel_messages_with_pagination(channel)
       |> system_event(msg)}
    else
      {:halt, socket}
    end
  end

  def handle_info({:user_channel_muted, %{target: target, channel: channel}}, socket) do
    users = update_channel_user_muted(socket.assigns.conversation_members, target, true)

    {:halt,
     socket
     |> assign(conversation_members: users)
     |> Nicklist.reset(users)
     |> system_event(
       dgettext("chat", "%{target} has been muted in %{channel}.",
         target: target,
         channel: channel
       )
     )}
  end

  def handle_info({:user_channel_unmuted, %{target: target, channel: channel}}, socket) do
    users = update_channel_user_muted(socket.assigns.conversation_members, target, false)

    {:halt,
     socket
     |> assign(conversation_members: users)
     |> Nicklist.reset(users)
     |> system_event(
       dgettext("chat", "%{target} has been unmuted in %{channel}.",
         target: target,
         channel: channel
       )
     )}
  end

  # ── Knock notification ────────────────────────────────────

  def handle_info({:knock, %{nickname: nick, channel: channel, message: message}}, socket) do
    # Only show knock notifications to operators and owners
    my_nick = socket.assigns.session.nickname

    is_privileged =
      Enum.any?(socket.assigns.conversation_members, fn user ->
        user.nickname == my_nick and user.role in [:owner, :operator]
      end)

    if is_privileged do
      msg =
        if message && message != "" do
          dgettext("chat", "* %{nickname} has knocked on %{channel} (%{message})",
            nickname: nick,
            channel: channel,
            message: message
          )
        else
          dgettext("chat", "* %{nickname} has knocked on %{channel}",
            nickname: nick,
            channel: channel
          )
        end

      {:halt, system_event(socket, msg)}
    else
      {:halt, socket}
    end
  end

  # ── Group call presence ───────────────────────────────────

  def handle_info({:group_call_started, %{channel: channel} = payload}, socket) do
    socket =
      socket
      |> GroupCallEvents.mark_channel_call_active(channel, Map.get(payload, :summary))
      |> maybe_group_call_system_event(
        channel,
        dgettext("group_call", "Conference started in %{channel}.", channel: channel)
      )

    {:halt, socket}
  end

  def handle_info({:group_call_updated, %{channel: channel} = payload}, socket) do
    {:halt, GroupCallEvents.mark_channel_call_active(socket, channel, Map.get(payload, :summary))}
  end

  def handle_info({:group_call_moderation, %{channel: channel} = payload}, socket) do
    socket =
      maybe_group_call_system_event(
        socket,
        channel,
        group_call_moderation_message(payload)
      )

    {:halt, socket}
  end

  def handle_info({:group_call_ended, %{channel: channel}}, socket) do
    socket =
      socket
      |> GroupCallEvents.mark_channel_call_inactive(channel)
      |> maybe_group_call_system_event(
        channel,
        dgettext("group_call", "Conference ended in %{channel}.", channel: channel)
      )

    {:halt, socket}
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp append_reason(message, nil), do: message
  defp append_reason(message, ""), do: message

  defp append_reason(message, reason),
    do: dgettext("chat", "%{message} (%{reason})", message: message, reason: reason)

  defp maybe_group_call_system_event(socket, channel, message) do
    if socket.assigns.session.active_channel == channel and !socket.assigns.show_status_tab do
      system_event(socket, message)
    else
      socket
    end
  end

  defp group_call_moderation_message(%{
         action: :mute_all,
         actor: actor,
         changed_count: count
       }) do
    dngettext(
      "group_call",
      "%{actor} muted %{count} conference microphone.",
      "%{actor} muted %{count} conference microphones.",
      count,
      actor: actor
    )
  end

  defp group_call_moderation_message(%{
         action: :camera_off_all,
         actor: actor,
         changed_count: count
       }) do
    dngettext(
      "group_call",
      "%{actor} turned off %{count} conference camera.",
      "%{actor} turned off %{count} conference cameras.",
      count,
      actor: actor
    )
  end

  defp group_call_moderation_message(%{
         action: :unmute_all,
         actor: actor,
         changed_count: count
       }) do
    dngettext(
      "group_call",
      "%{actor} allowed %{count} conference microphone.",
      "%{actor} allowed %{count} conference microphones.",
      count,
      actor: actor
    )
  end

  defp group_call_moderation_message(%{
         action: :camera_on_all,
         actor: actor,
         changed_count: count
       }) do
    dngettext(
      "group_call",
      "%{actor} allowed %{count} conference camera.",
      "%{actor} allowed %{count} conference cameras.",
      count,
      actor: actor
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_muted,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} muted %{target}'s conference microphone.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_unmuted,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} allowed %{target}'s conference microphone.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_camera_blocked,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} turned off %{target}'s conference camera.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_camera_unblocked,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} allowed %{target}'s conference camera.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :screen_share_started,
         target: target
       }) do
    dgettext("group_call", "%{target} started sharing a screen.", target: target)
  end

  defp group_call_moderation_message(%{
         action: :screen_share_stopped,
         target: target
       }) do
    dgettext("group_call", "%{target} stopped sharing a screen.", target: target)
  end

  defp group_call_moderation_message(%{
         action: :screen_share_blocked,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} stopped %{target}'s screen share.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :screen_share_unblocked,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} allowed %{target} to share a screen again.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_speak_allowed,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} allowed %{target} to speak.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{
         action: :participant_kicked,
         actor: actor,
         target: target
       }) do
    dgettext("group_call", "%{actor} removed %{target} from the conference.",
      actor: actor,
      target: target
    )
  end

  defp group_call_moderation_message(%{action: :lock_call, actor: actor}) do
    dgettext("group_call", "%{actor} locked the conference.", actor: actor)
  end

  defp group_call_moderation_message(%{action: :unlock_call, actor: actor}) do
    dgettext("group_call", "%{actor} unlocked the conference.", actor: actor)
  end

  defp group_call_moderation_message(_payload),
    do: dgettext("group_call", "Conference moderation updated.")

  defp apply_mode_to_users(users, "+q", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :owner), else: user
    end)
  end

  defp apply_mode_to_users(users, "-q", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :regular), else: user
    end)
  end

  defp apply_mode_to_users(users, "+o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :operator), else: user
    end)
  end

  defp apply_mode_to_users(users, "-o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :regular), else: user
    end)
  end

  defp apply_mode_to_users(users, "+h", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :half_operator), else: user
    end)
  end

  defp apply_mode_to_users(users, "-h", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :regular), else: user
    end)
  end

  defp apply_mode_to_users(users, "+v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :voiced), else: user
    end)
  end

  defp apply_mode_to_users(users, "-v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: Roster.put_role(user, :regular), else: user
    end)
  end

  defp apply_mode_to_users(users, _mode, _params), do: users

  defp update_channel_user_muted(users, target, muted) do
    Enum.map(users, fn user ->
      if user.nickname == target, do: Map.put(user, :muted, muted), else: user
    end)
  end

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

  # Channel Central is a stateful island that self-guards on the open channel;
  # blindly drive its refresh and let it no-op when closed or on another channel.
  defp maybe_refresh_cc(socket, channel) do
    send_update(ChannelCentralDialog, id: ChannelCentralDialog.id(), refresh: channel)
    socket
  end
end
