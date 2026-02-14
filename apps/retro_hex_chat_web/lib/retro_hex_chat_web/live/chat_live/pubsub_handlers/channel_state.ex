defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.ChannelState do
  @moduledoc """
  PubSub handlers for channel state changes: mode changes, kicks, bans,
  ban/invite exceptions, and topic changes.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_message: 1, play_event_sound: 3, part_channel_after_kick: 2]

  alias RetroHexChat.Channels.Server

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
      kick_event = %{
        channel: socket.assigns.session.active_channel,
        operator: op,
        reason: reason
      }

      socket =
        socket
        |> assign(channel_users: users, kick_queue: socket.assigns.kick_queue ++ [kick_event])
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

  # ── Knock notification ────────────────────────────────────

  def handle_info({:knock, %{nickname: nick, channel: channel, message: message}}, socket) do
    # Only show knock notifications to operators and owners
    my_nick = socket.assigns.session.nickname

    is_privileged =
      Enum.any?(socket.assigns.channel_users, fn user ->
        user.nickname == my_nick and user.role in [:owner, :operator]
      end)

    if is_privileged do
      msg =
        if message && message != "" do
          "* #{nick} has knocked on #{channel} (#{message})"
        else
          "* #{nick} has knocked on #{channel}"
        end

      {:halt, stream_insert(socket, :chat_messages, system_message(msg))}
    else
      {:halt, socket}
    end
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp apply_mode_to_users(users, "+q", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :owner}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-q", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :regular}, else: user
    end)
  end

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

  defp apply_mode_to_users(users, "+h", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :half_operator}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-h", params) do
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

          operator =
            nickname in state.operators or nickname in Map.get(state, :owners, [])

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
end
