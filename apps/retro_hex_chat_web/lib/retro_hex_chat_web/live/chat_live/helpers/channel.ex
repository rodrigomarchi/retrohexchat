defmodule RetroHexChatWeb.ChatLive.Helpers.Channel do
  @moduledoc """
  Channel management helpers: join, part, load users, load messages.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  require Logger

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{Queries, UnreadTracker}
  alias RetroHexChat.Page
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.StreamItem
  alias RetroHexChatWeb.ChatLive.TabOrder

  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel
  alias RetroHexChatWeb.ChatLive.GroupCallEvents
  alias RetroHexChatWeb.ChatLive.Helpers.Presence, as: PresenceHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers

  @spec join_channel(Phoenix.LiveView.Socket.t(), String.t(), Session.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def join_channel(socket, channel_name, session, password \\ nil) do
    do_join_channel(socket, channel_name, session, password, :activate)
  end

  @spec join_channel_in_background(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          Session.t(),
          String.t() | nil
        ) ::
          Phoenix.LiveView.Socket.t()
  def join_channel_in_background(socket, channel_name, session, password \\ nil) do
    do_join_channel(socket, channel_name, session, password, :background)
  end

  defp do_join_channel(socket, channel_name, session, password, join_mode) do
    case ensure_channel_exists(channel_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start channel #{channel_name}: #{inspect(reason)}")
    end

    case Server.join(channel_name, session.nickname, password, identified: session.identified) do
      {:ok, _state} ->
        setup_joined_channel(socket, channel_name, session, join_mode)

      {:error, reason} when reason == "Already in channel" ->
        Logger.debug("Rejoining channel #{channel_name} (already a member in server)")
        setup_joined_channel(socket, channel_name, session, join_mode)

      {:error, reason} ->
        Messages.error_event(socket, reason)
    end
  end

  defp setup_joined_channel(socket, channel_name, session, :activate) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    client_meta = Map.get(socket.assigns, :client_info, %{})
    PresenceHelpers.safe_track_user("channel:#{channel_name}", session.nickname, client_meta)

    new_session =
      session
      |> Session.add_channel(channel_name)
      |> Session.set_active_channel(channel_name)

    socket
    |> assign(
      session: new_session,
      loading_channel: channel_name,
      show_status_tab: false
    )
    |> GroupCallEvents.refresh_channel_call_state(channel_name)
    |> GroupCallEvents.rehydrate()
    |> tap(fn _ -> send_update(Composer, id: Composer.id(), reset_input: true) end)
    |> load_channel_users(channel_name)
    |> load_channel_user_count(channel_name)
    |> load_channel_messages_with_pagination(channel_name)
    |> assign(loading_channel: nil)
    |> maybe_show_welcome(channel_name, new_session)
    |> push_event("tip_trigger", %{tip: "first_join"})
    |> push_event("channel_joined_flash", %{channel: channel_name})
    |> SessionHelpers.push_reconnect_state()
    |> ConversationsReadModel.load_popular_channels()
  end

  defp setup_joined_channel(socket, channel_name, session, :background) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    client_meta = Map.get(socket.assigns, :client_info, %{})
    PresenceHelpers.safe_track_user("channel:#{channel_name}", session.nickname, client_meta)

    new_session = Session.add_channel(session, channel_name)

    socket
    |> assign(session: new_session)
    |> GroupCallEvents.refresh_channel_call_state(channel_name)
    |> GroupCallEvents.rehydrate()
    |> load_channel_user_count(channel_name)
    |> push_event("channel_joined_flash", %{channel: channel_name})
    |> SessionHelpers.push_reconnect_state()
    |> ConversationsReadModel.load_popular_channels()
  end

  @spec part_channel(Phoenix.LiveView.Socket.t(), String.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def part_channel(socket, channel_name, reason \\ nil) do
    session = socket.assigns.session

    try do
      Server.part(channel_name, session.nickname, reason)
    rescue
      e ->
        Logger.warning("Failed to part #{channel_name}: #{inspect(e)}")
        :ok
    end

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    PresenceHelpers.safe_untrack_user("channel:#{channel_name}", session.nickname)
    new_session = Session.remove_channel(session, channel_name)

    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, channel_name)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel_name)
    flash = MapSet.delete(socket.assigns.flash_channels, channel_name)

    socket =
      assign(socket,
        session: new_session,
        unread_counts: unread_counts,
        highlight_channels: highlight,
        flash_channels: flash,
        tab_order: TabOrder.drop(socket.assigns[:tab_order] || [], :channel, channel_name)
      )
      |> GroupCallEvents.mark_channel_call_inactive(channel_name)

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
        |> MessageViewport.reset([])
        |> Nicklist.reset([])
      end

    socket
    |> SessionHelpers.push_reconnect_state()
    |> ConversationsReadModel.load_popular_channels()
  end

  @spec part_channel_after_kick(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def part_channel_after_kick(socket, channel_name) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    PresenceHelpers.safe_untrack_user("channel:#{channel_name}", socket.assigns.session.nickname)
    new_session = Session.remove_channel(socket.assigns.session, channel_name)

    socket =
      socket
      |> assign(
        session: new_session,
        tab_order: TabOrder.drop(socket.assigns[:tab_order] || [], :channel, channel_name)
      )
      |> GroupCallEvents.mark_channel_call_inactive(channel_name)

    if new_session.active_channel do
      socket
      |> load_channel_users(new_session.active_channel)
      |> load_channel_messages_with_pagination(new_session.active_channel)
      |> ConversationsReadModel.load_popular_channels()
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false, current_topic: nil, current_modes: nil)
      |> MessageViewport.reset([])
      |> ConversationsReadModel.load_popular_channels()
    end
  end

  @spec load_channel_users(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def load_channel_users(socket, channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        presence_by_nick = channel_presence_by_nick(channel_name)
        muted_nicks = MapSet.new(Map.get(state, :channel_mutes, []))

        users =
          Enum.map(state.members, fn {nick, role} ->
            presence = Map.get(presence_by_nick, String.downcase(nick), %{})

            %{
              nickname: nick,
              role: role,
              away: Map.get(presence, :away, false),
              away_message: Map.get(presence, :away_message),
              muted: MapSet.member?(muted_nicks, nick)
            }
          end)

        socket
        |> assign(
          channel_users: users,
          current_topic: state.topic,
          current_modes: state.modes
        )
        |> Nicklist.reset(users)

      {:error, _} ->
        socket
        |> assign(channel_users: [], current_topic: nil, current_modes: nil)
        |> Nicklist.reset([])
    end
  end

  defp channel_presence_by_nick(channel_name) do
    "channel:#{channel_name}"
    |> Tracker.list_users()
    |> Map.new(fn user -> {String.downcase(user.nickname), user} end)
  end

  @spec load_channel_user_count(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def load_channel_user_count(socket, channel_name) do
    counts = socket.assigns.channel_user_counts

    count =
      case Server.get_state(channel_name) do
        {:ok, state} -> state.member_count
        {:error, _} -> 0
      end

    assign(socket, channel_user_counts: Map.put(counts, channel_name, count))
  end

  @spec load_all_channel_user_counts(Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def load_all_channel_user_counts(socket) do
    counts =
      socket.assigns.session.channels
      |> Enum.reduce(%{}, fn channel, acc ->
        case Server.get_state(channel) do
          {:ok, state} -> Map.put(acc, channel, state.member_count)
          _ -> acc
        end
      end)

    assign(socket, channel_user_counts: counts)
  end

  @spec load_channel_messages_with_pagination(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  @spec load_channel_messages_with_pagination(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          pos_integer()
        ) ::
          Phoenix.LiveView.Socket.t()
  def load_channel_messages_with_pagination(socket, channel_name, limit \\ 50) do
    # Both filters go through `Page.filter/2`, so neither can shorten the page
    # into claiming there is nothing older. `has_more` and the cursor come from
    # what the database returned, before anything was hidden.
    page =
      channel_name
      |> Queries.list_messages(limit: limit)
      |> Page.filter(&(not Messages.cleared_from_conversation?(socket, channel_name, &1)))
      |> Messages.visible_channel_page(socket.assigns.session.ignore_list)

    stream_items =
      page.items
      |> Enum.reverse()
      |> Enum.map(&StreamItem.from_message/1)

    socket
    |> assign(
      oldest_message_id: page.next_cursor,
      has_more: page.has_more,
      loaded_message_count: length(page.items)
    )
    |> MessageViewport.reset(stream_items)
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
          |> Messages.system_event(dgettext("chat", "[Welcome] %{message}", message: message))
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

  @spec handle_set_topic(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_set_topic(socket, channel, topic) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok ->
        socket

      {:error, msg} ->
        Messages.error_event(socket, msg)
    end
  end

  @spec cleanup_channels(Session.t(), String.t() | nil) :: :ok
  def cleanup_channels(session, reason \\ nil) do
    alias RetroHexChat.Services.NickServ
    NickServ.cancel_identify_timer(session.nickname)

    reason = reason || dgettext("chat", "Connection lost")
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
          {:error, dgettext("chat", "* User '%{target}' not found", target: target)}
        end

      {:error, _} ->
        {:error, dgettext("chat", "* User '%{target}' not found", target: target)}
    end
  end
end
