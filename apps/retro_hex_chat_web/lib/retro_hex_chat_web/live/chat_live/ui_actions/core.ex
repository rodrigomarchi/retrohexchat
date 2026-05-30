defmodule RetroHexChatWeb.ChatLive.UiActions.Core do
  @moduledoc """
  Core UI actions: query, channel list, clear chat, away, topic, whois, help,
  mode, kick, ban.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream: 4]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
      error_event: 2,
      inline_help_event: 3,
      open_pm_conversation: 2,
      show_whois_text: 2,
      safe_update_away: 4
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Commands.Autocomplete

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_query, %{nickname: target}),
    do: open_pm_conversation(socket, target)

  def handle_ui_action(socket, :open_channel_list, _) do
    channels = Autocomplete.list_visible_channels(socket.assigns.session.channels)

    assign(socket,
      show_channel_list: true,
      channel_list_channels: channels,
      channel_list_filtered: channels,
      channel_list_selected: nil,
      channel_list_search: "",
      channel_list_loading: false,
      channel_list_count: length(channels)
    )
  end

  def handle_ui_action(socket, :clear_chat, _) do
    socket
    |> assign(
      oldest_message_id: nil,
      has_more: false,
      loading_more: false,
      loaded_message_count: 0
    )
    |> stream(:chat_messages, [], reset: true)
  end

  def handle_ui_action(socket, :set_away, %{message: message}) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    broadcast_away_change(session, true, message)

    socket
    |> system_event("You are now away: #{message}")
    |> assign(session: session, away_replied_to: MapSet.new())
  end

  def handle_ui_action(socket, :clear_away, _) do
    session = socket.assigns.session
    new_session = Session.set_away(session, nil)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, false, nil)
    end)

    broadcast_away_change(new_session, false, nil)

    socket
    |> system_event("You are no longer away")
    |> assign(session: new_session, away_replied_to: MapSet.new())
  end

  def handle_ui_action(socket, :set_topic, %{channel: channel, topic: topic}) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok -> socket
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :view_topic, %{channel: channel}) do
    case Server.get_state(channel) do
      {:ok, state} ->
        topic_text = if state.topic == "", do: "No topic set", else: state.topic

        system_event(socket, "Topic for #{channel}: #{topic_text}")

      {:error, _} ->
        socket
    end
  end

  def handle_ui_action(socket, :show_whois_info, %{nickname: target}),
    do: show_whois_text(socket, target)

  def handle_ui_action(socket, :show_help, %{commands: commands}) do
    text =
      "Available commands: " <>
        Enum.join(Enum.map(commands, &"/#{&1}"), ", ") <>
        "\nType /help <command> for details, or open Help Topics from the menu for the full help system."

    system_event(socket, text)
  end

  def handle_ui_action(socket, :show_command_help, %{help: help}) do
    topic_id = command_topic_id(help.name)

    case HelpTopics.get_topic(topic_id) do
      %{title: title} ->
        inline_help_event(socket, topic_id, title)

      nil ->
        text = "#{help.syntax} - #{help.description}"
        system_event(socket, text)
    end
  end

  def handle_ui_action(socket, :set_mode, %{
        channel: channel,
        mode_string: mode_string,
        params: params
      }) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode_string, params) do
      :ok -> socket
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :kick_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.kick(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :ban_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.ban(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :unban_user, %{channel: channel, target: target}) do
    case Server.unban(channel, socket.assigns.session.nickname, target) do
      :ok -> socket
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :channel_mute_user, %{channel: channel, target: target} = payload) do
    duration = Map.get(payload, :duration, :permanent)

    case Server.channel_mute(channel, socket.assigns.session.nickname, target, duration) do
      :ok -> system_event(socket, "#{target} has been muted in #{channel}.")
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :channel_unmute_user, %{channel: channel, target: target}) do
    case Server.channel_unmute(channel, socket.assigns.session.nickname, target) do
      :ok -> system_event(socket, "#{target} has been unmuted in #{channel}.")
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :transfer_ownership, %{channel: channel, target: target}) do
    nick = socket.assigns.session.nickname

    case Server.transfer_ownership(channel, nick, target) do
      :ok -> system_event(socket, "Channel ownership transferred to #{target}.")
      {:error, msg} -> error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :knock_channel, %{channel: channel} = payload) do
    message = Map.get(payload, :message)
    knock_timestamps = Map.get(socket.assigns, :knock_timestamps, %{})
    now = System.monotonic_time(:millisecond)

    if throttled_knock?(knock_timestamps, channel, now) do
      error_event(socket, "Please wait before knocking on #{channel} again")
    else
      case Server.knock(channel, socket.assigns.session.nickname, message) do
        :ok ->
          updated_timestamps = Map.put(knock_timestamps, channel, now)

          socket
          |> assign(knock_timestamps: updated_timestamps)
          |> system_event("Knock sent to #{channel}")

        {:error, msg} ->
          error_event(socket, msg)
      end
    end
  end

  defp command_topic_id("bot"), do: "bot-command"
  defp command_topic_id(command_name), do: "cmd-#{String.replace(command_name, "_", "-")}"

  defp broadcast_away_change(session, away, message) do
    Enum.each(session.channels, fn channel ->
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel}",
        {:user_away_changed,
         %{
           channel: channel,
           nickname: session.nickname,
           away: away,
           away_message: message
         }}
      )
    end)
  end

  defp throttled_knock?(knock_timestamps, channel, now) do
    case Map.fetch(knock_timestamps, channel) do
      {:ok, last_knock} -> now - last_knock < 60_000
      :error -> false
    end
  end
end
