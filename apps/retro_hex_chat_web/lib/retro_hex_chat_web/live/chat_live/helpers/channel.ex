defmodule RetroHexChatWeb.ChatLive.Helpers.Channel do
  @moduledoc """
  Channel management helpers: join, part, load users, load messages.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, stream: 4]

  require Logger

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{NotificationPreferences, Queries, UserPreferences}
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence
  alias RetroHexChatWeb.ChatLive.Helpers.Presence, as: PresenceHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers

  @spec join_channel(Phoenix.LiveView.Socket.t(), String.t(), Session.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def join_channel(socket, channel_name, session, password \\ nil) do
    case ensure_channel_exists(channel_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start channel #{channel_name}: #{inspect(reason)}")
    end

    case Server.join(channel_name, session.nickname, password, identified: session.identified) do
      {:ok, _state} ->
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
        PresenceHelpers.safe_track_user("channel:#{channel_name}", session.nickname)

        new_session =
          session
          |> Session.add_channel(channel_name)
          |> Session.set_active_channel(channel_name)

        socket
        |> assign(session: new_session, input: "", loading_channel: channel_name)
        |> load_channel_users(channel_name)
        |> load_channel_messages_with_pagination(channel_name)
        |> assign(loading_channel: nil)
        |> maybe_show_welcome(channel_name, new_session)
        |> push_event("tip_trigger", %{tip: "first_join"})
        |> push_event("channel_joined_flash", %{channel: channel_name})
        |> SessionHelpers.push_reconnect_state()

      {:error, reason} ->
        Phoenix.LiveView.stream_insert(
          socket,
          :chat_messages,
          Messages.error_message(reason)
        )
    end
  end

  @spec part_channel(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def part_channel(socket, channel_name) do
    session = socket.assigns.session

    try do
      Server.part(channel_name, session.nickname, nil)
    rescue
      e ->
        Logger.warning("Failed to part #{channel_name}: #{inspect(e)}")
        :ok
    end

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    PresenceHelpers.safe_untrack_user("channel:#{channel_name}", session.nickname)
    new_session = Session.remove_channel(session, channel_name)
    new_session = cleanup_channel_notification_level(new_session, channel_name)

    socket =
      socket
      |> assign(session: new_session)
      |> Persistence.maybe_persist_user_preferences(new_session)

    socket =
      if new_session.active_channel do
        socket
        |> load_channel_users(new_session.active_channel)
        |> load_channel_messages_with_pagination(new_session.active_channel)
      else
        socket
        |> assign(
          oldest_message_id: nil,
          has_more: false,
          channel_users: [],
          current_topic: nil,
          current_modes: nil
        )
        |> stream(:chat_messages, [], reset: true)
      end

    SessionHelpers.push_reconnect_state(socket)
  end

  @spec part_channel_after_kick(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def part_channel_after_kick(socket, channel_name) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    PresenceHelpers.safe_untrack_user("channel:#{channel_name}", socket.assigns.session.nickname)
    new_session = Session.remove_channel(socket.assigns.session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      socket
      |> load_channel_users(new_session.active_channel)
      |> load_channel_messages_with_pagination(new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false, current_topic: nil, current_modes: nil)
      |> stream(:chat_messages, [], reset: true)
    end
  end

  @spec load_channel_users(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def load_channel_users(socket, channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        users =
          Enum.map(state.members, fn {nick, role} ->
            %{nickname: nick, role: role, away: false}
          end)

        assign(socket,
          channel_users: users,
          current_topic: state.topic,
          current_modes: state.modes
        )

      {:error, _} ->
        assign(socket, channel_users: [], current_topic: nil, current_modes: nil)
    end
  end

  @spec load_channel_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def load_channel_messages_with_pagination(socket, channel_name) do
    raw_messages = Queries.list_messages(channel_name, limit: 50)

    oldest_id =
      case List.last(raw_messages) do
        nil -> nil
        msg -> msg.id
      end

    stream_items =
      raw_messages
      |> Enum.reverse()
      |> Enum.map(&message_to_stream_item/1)

    socket
    |> assign(
      oldest_message_id: oldest_id,
      has_more: length(raw_messages) == 50,
      loading_more: false,
      new_messages_indicator: false
    )
    |> stream(:chat_messages, stream_items, reset: true)
  end

  defp maybe_show_welcome(socket, channel_name, session) do
    case Server.get_welcome(channel_name) do
      {:ok, nil} ->
        socket

      {:ok, %{message: message, set_by: set_by}} ->
        if session.nickname != set_by and not Session.welcomed_channel?(session, channel_name) do
          new_session = Session.add_welcomed_channel(session, channel_name)

          socket
          |> assign(session: new_session)
          |> Phoenix.LiveView.stream_insert(
            :chat_messages,
            Messages.system_message("[Welcome] #{message}")
          )
        else
          socket
        end
    end
  rescue
    _ -> socket
  end

  @spec ensure_channel_exists(String.t()) :: :ok | {:error, term()}
  def ensure_channel_exists(channel_name) do
    alias RetroHexChat.Channels.{Registry, Supervisor}

    case Registry.lookup(channel_name) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_child(channel_name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec channels_where_operator(Session.t()) :: [String.t()]
  def channels_where_operator(session) do
    Enum.filter(session.channels, fn channel_name ->
      case Server.get_state(channel_name) do
        {:ok, state} ->
          session.nickname in state.operators or
            session.nickname in Map.get(state, :owners, [])

        {:error, _} ->
          false
      end
    end)
  end

  @spec handle_set_topic(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_set_topic(socket, channel, topic) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok ->
        socket

      {:error, msg} ->
        Phoenix.LiveView.stream_insert(socket, :chat_messages, Messages.error_message(msg))
    end
  end

  @spec cleanup_channels(Session.t(), String.t()) :: :ok
  def cleanup_channels(session, reason \\ "Connection lost") do
    alias RetroHexChat.Services.NickServ
    NickServ.cancel_identify_timer(session.nickname)

    truncated = String.slice(reason, 0, 200)

    Enum.each(session.channels, fn channel ->
      try do
        PresenceHelpers.safe_untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, truncated)
      rescue
        e ->
          Logger.warning("Failed to part #{channel} during cleanup: #{inspect(e)}")
          :ok
      end
    end)
  end

  @spec validate_target_online(String.t()) :: :ok | {:error, String.t()}
  def validate_target_online(target) do
    case Server.get_state("#lobby") do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if target in member_nicks do
          :ok
        else
          {:error, "* User '#{target}' not found"}
        end

      {:error, _} ->
        {:error, "* User '#{target}' not found"}
    end
  end

  @spec cleanup_channel_notification_level(Session.t(), String.t()) :: Session.t()
  defp cleanup_channel_notification_level(session, channel_name) do
    prefs = session.user_preferences
    notif = prefs.notifications
    updated_notif = NotificationPreferences.remove_channel_level(notif, channel_name)
    updated_prefs = UserPreferences.set_notifications(prefs, updated_notif)
    Session.set_user_preferences(session, updated_prefs)
  end

  @spec message_to_stream_item(map()) :: map()
  def message_to_stream_item(msg) do
    %{
      id: msg.id,
      author: msg.author_nickname,
      content: msg.content,
      type: String.to_existing_atom(msg.type),
      timestamp: msg.inserted_at
    }
  end
end
