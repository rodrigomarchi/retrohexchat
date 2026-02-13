defmodule RetroHexChatWeb.ChatLive.UiActions.Core do
  @moduledoc """
  Core UI actions: query, channel list, clear chat, away, topic, whois, help,
  mode, kick, ban.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2, stream: 4, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      error_message: 1,
      open_pm_conversation: 2,
      show_whois_text: 2,
      safe_update_away: 4
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_query, %{nickname: target}),
    do: open_pm_conversation(socket, target)

  def handle_ui_action(socket, :open_channel_list, _),
    do: push_navigate(socket, to: ~p"/channels")

  def handle_ui_action(socket, :clear_chat, _),
    do: stream(socket, :chat_messages, [], reset: true)

  def handle_ui_action(socket, :set_away, %{message: message}) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now away: #{message}"))
    |> assign(session: session)
  end

  def handle_ui_action(socket, :clear_away, _) do
    session = socket.assigns.session
    new_session = Session.set_away(session, nil)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, false, nil)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are no longer away"))
    |> assign(session: new_session)
  end

  def handle_ui_action(socket, :set_topic, %{channel: channel, topic: topic}) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :view_topic, %{channel: channel}) do
    case Server.get_state(channel) do
      {:ok, state} ->
        topic_text = if state.topic == "", do: "No topic set", else: state.topic

        stream_insert(
          socket,
          :chat_messages,
          system_message("Topic for #{channel}: #{topic_text}")
        )

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
        "\nType /help <command> for details, or press F1 for the full help system."

    stream_insert(socket, :chat_messages, system_message(text))
  end

  def handle_ui_action(socket, :show_command_help, %{help: help}) do
    text = "#{help.syntax} - #{help.description}"
    stream_insert(socket, :chat_messages, system_message(text))
  end

  def handle_ui_action(socket, :set_mode, %{
        channel: channel,
        mode_string: mode_string,
        params: params
      }) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode_string, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :kick_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.kick(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :ban_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.ban(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :knock_channel, %{channel: channel} = payload) do
    message = Map.get(payload, :message)
    knock_timestamps = Map.get(socket.assigns, :knock_timestamps, %{})
    now = System.monotonic_time(:millisecond)
    last_knock = Map.get(knock_timestamps, channel, 0)

    if now - last_knock < 60_000 do
      stream_insert(
        socket,
        :chat_messages,
        error_message("Please wait before knocking on #{channel} again")
      )
    else
      case Server.knock(channel, socket.assigns.session.nickname, message) do
        :ok ->
          updated_timestamps = Map.put(knock_timestamps, channel, now)

          socket
          |> assign(knock_timestamps: updated_timestamps)
          |> stream_insert(:chat_messages, system_message("Knock sent to #{channel}"))

        {:error, msg} ->
          stream_insert(socket, :chat_messages, error_message(msg))
      end
    end
  end
end
