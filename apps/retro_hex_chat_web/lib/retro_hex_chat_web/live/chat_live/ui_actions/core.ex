defmodule RetroHexChatWeb.ChatLive.UiActions.Core do
  @moduledoc """
  Core UI actions: query, channel list, clear chat, away, topic, whois, help,
  mode, kick, ban.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, stream: 4]

  use Gettext, backend: RetroHexChatWeb.Gettext

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
    channel = socket.assigns.session.active_channel

    cleared_channel_cutoffs =
      if channel do
        Map.put(socket.assigns.cleared_channel_cutoffs || %{}, channel, DateTime.utc_now())
      else
        socket.assigns.cleared_channel_cutoffs || %{}
      end

    socket
    |> assign(
      cleared_channel_cutoffs: cleared_channel_cutoffs,
      chat_clear_token: System.unique_integer([:positive]),
      oldest_message_id: nil,
      has_more: false,
      loading_more: false,
      loaded_message_count: 0
    )
    |> stream(:chat_messages, [], reset: true)
    |> push_event("clear_chat_messages", %{})
  end

  def handle_ui_action(socket, :set_away, %{message: message}) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    broadcast_away_change(session, true, message)

    socket
    |> system_event(dgettext("chat", "You are now away: %{message}", message: message))
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
    |> system_event(dgettext("chat", "You are no longer away"))
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
        topic_text = if state.topic == "", do: dgettext("chat", "No topic set"), else: state.topic

        system_event(
          socket,
          dgettext("chat", "Topic for %{channel}: %{topic}", channel: channel, topic: topic_text)
        )

      {:error, _} ->
        socket
    end
  end

  def handle_ui_action(socket, :show_whois_info, %{nickname: target}),
    do: show_whois_text(socket, target)

  def handle_ui_action(socket, :show_help, %{commands: commands}) do
    command_list = Enum.join(Enum.map(commands, &"/#{&1}"), ", ")

    text =
      dgettext(
        "chat",
        "Available commands: %{commands}\nType /help <command> for details, or open Help Topics from the menu for the full help system.",
        commands: command_list
      )

    system_event(socket, text)
  end

  def handle_ui_action(socket, :show_command_help, %{help: help}) do
    topic_id = command_topic_id(help.name)

    case HelpTopics.get_topic(topic_id) do
      %{title: title} ->
        inline_help_event(socket, topic_id, title)

      nil ->
        text =
          dgettext("chat", "%{syntax} - %{description}",
            syntax: help.syntax,
            description: help.description
          )

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
      :ok ->
        system_event(
          socket,
          dgettext("chat", "%{target} has been muted in %{channel}.",
            target: target,
            channel: channel
          )
        )

      {:error, msg} ->
        error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :channel_unmute_user, %{channel: channel, target: target}) do
    case Server.channel_unmute(channel, socket.assigns.session.nickname, target) do
      :ok ->
        system_event(
          socket,
          dgettext("chat", "%{target} has been unmuted in %{channel}.",
            target: target,
            channel: channel
          )
        )

      {:error, msg} ->
        error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :transfer_ownership, %{channel: channel, target: target}) do
    nick = socket.assigns.session.nickname

    case Server.transfer_ownership(channel, nick, target) do
      :ok ->
        system_event(
          socket,
          dgettext("chat", "Channel ownership transferred to %{target}.", target: target)
        )

      {:error, msg} ->
        error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :knock_channel, %{channel: channel} = payload) do
    message = Map.get(payload, :message)

    case knock_channel(socket, channel, message) do
      {:ok, socket} -> socket
      {:error, socket, _message} -> socket
    end
  end

  @spec knock_channel(Phoenix.LiveView.Socket.t(), String.t(), String.t() | nil) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t(), String.t()}
  def knock_channel(socket, channel, message \\ nil) do
    knock_timestamps = Map.get(socket.assigns, :knock_timestamps, %{})
    now = System.monotonic_time(:millisecond)
    message = normalize_knock_message(message)

    cond do
      not valid_knock_channel?(channel) ->
        message = dgettext("chat", "Channel not found")
        {:error, error_event(socket, message), message}

      not channel_exists?(channel) ->
        message = dgettext("chat", "Channel not found")
        {:error, error_event(socket, message), message}

      throttled_knock?(knock_timestamps, channel, now) ->
        message =
          dgettext("chat", "Please wait before knocking on %{channel} again", channel: channel)

        {:error, error_event(socket, message), message}

      true ->
        case Server.knock(channel, socket.assigns.session.nickname, message) do
          :ok ->
            updated_timestamps = Map.put(knock_timestamps, channel, now)

            {:ok,
             socket
             |> assign(knock_timestamps: updated_timestamps)
             |> system_event(dgettext("chat", "Knock sent to %{channel}", channel: channel))}

          {:error, msg} ->
            {:error, error_event(socket, msg), msg}
        end
    end
  end

  defp valid_knock_channel?(channel) when is_binary(channel), do: String.trim(channel) != ""
  defp valid_knock_channel?(_channel), do: false

  defp channel_exists?(channel) do
    match?({:ok, _state}, Server.get_state(channel))
  end

  defp normalize_knock_message(message) when is_binary(message) do
    case String.trim(message) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_knock_message(_message), do: nil

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
