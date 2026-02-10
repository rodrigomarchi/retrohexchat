defmodule RetroHexChatWeb.ChatLive do
  @moduledoc """
  Main chat interface with MDI layout: treebar, chat area, nicklist, status bar.
  """
  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Accounts.{NicknameValidator, Session}
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.{Queries, Search, Service}
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Commands.Registry, as: CmdRegistry
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ

  @impl true
  def mount(params, _session, socket) do
    nickname = params["nickname"] || "Guest_#{:rand.uniform(99999)}"

    case NicknameValidator.validate(nickname) do
      :ok ->
        session = Session.new(nickname)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")

          socket =
            socket
            |> assign_defaults(session)
            |> join_channel("#lobby", session)
            |> maybe_join_from_params(params)
            |> maybe_start_nickserv_timer(nickname)

          {:ok, socket}
        else
          {:ok,
           socket
           |> assign_defaults(session)
           |> stream(:chat_messages, [])}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp assign_defaults(socket, session) do
    assign(socket,
      channel_users: [],
      command_history: [],
      command_palette_filter: "",
      command_palette_visible: false,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil},
      has_more: true,
      history_index: -1,
      input: "",
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      oldest_message_id: nil,
      page_title: "RetroHexChat",
      search_current_index: 0,
      search_query: "",
      search_result_count: 0,
      search_results: [],
      search_visible: false,
      session: session,
      show_about: false,
      show_nicklist: true,
      show_treebar: true,
      show_whois: false,
      unread_channels: MapSet.new(),
      whois_target: nil
    )
  end

  # ── Event handlers ──────────────────────────────────────────

  @impl true
  def handle_event("send_input", %{"input" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_input", %{"input" => input}, socket) do
    session = socket.assigns.session
    history = [input | socket.assigns.command_history] |> Enum.take(50)

    case Parser.parse(input) do
      {:message, text} ->
        socket = send_plain_message(socket, session, text)
        {:noreply, assign(socket, input: "", command_history: history, history_index: -1)}

      {:command, name, args} ->
        socket = dispatch_command(socket, session, name, args)
        {:noreply, assign(socket, input: "", command_history: history, history_index: -1)}
    end
  end

  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    session = Session.set_active_channel(socket.assigns.session, channel)
    unread = MapSet.delete(socket.assigns.unread_channels, channel)

    {:noreply,
     socket
     |> assign(session: session, unread_channels: unread)
     |> load_channel_users(channel)
     |> load_channel_messages_with_pagination(channel)}
  end

  def handle_event("switch_pm", %{"nickname" => nickname}, socket) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    messages = load_pm_messages(session.nickname, nickname)
    unread = MapSet.delete(socket.assigns.unread_channels, "pm:#{nickname}")

    {:noreply,
     socket
     |> assign(session: session, unread_channels: unread)
     |> stream(:chat_messages, messages, reset: true)}
  end

  def handle_event("close_dialog", _params, socket) do
    {:noreply, assign(socket, show_about: false, show_whois: false, whois_target: nil)}
  end

  def handle_event("load_more", _params, socket) do
    %{loading_more: loading_more, has_more: has_more, oldest_message_id: oldest_id} =
      socket.assigns

    if loading_more or not has_more or is_nil(oldest_id) do
      {:noreply, socket}
    else
      {:noreply, do_load_more(socket, oldest_id)}
    end
  end

  def handle_event("scroll_to_bottom", _params, socket) do
    {:noreply, assign(socket, new_messages_indicator: false)}
  end

  def handle_event("toggle_search", _params, socket) do
    visible = !socket.assigns.search_visible

    if visible do
      {:noreply, assign(socket, search_visible: true)}
    else
      {:noreply, clear_search_state(socket)}
    end
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    {:noreply, do_search(socket, query)}
  end

  def handle_event("search_next", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx >= count, do: 1, else: idx + 1
      {:noreply, assign(socket, search_current_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_prev", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx <= 1, do: count, else: idx - 1
      {:noreply, assign(socket, search_current_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_search", _params, socket) do
    {:noreply, clear_search_state(socket)}
  end

  def handle_event("window_keydown", %{"key" => "f", "ctrlKey" => true}, socket) do
    {:noreply, assign(socket, search_visible: true)}
  end

  def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
    if socket.assigns.search_visible do
      {:noreply, clear_search_state(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("window_keydown", _params, socket) do
    {:noreply, socket}
  end

  # Context menu events (Phase 12)
  def handle_event("nick_right_click", %{"nick" => nick} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:noreply, assign(socket, context_menu: %{visible: true, x: x, y: y, target_nick: nick})}
  end

  def handle_event("close_context_menu", _params, socket) do
    {:noreply, close_context_menu(socket)}
  end

  def handle_event("context_query", %{"nick" => nick}, socket) do
    {:noreply,
     socket
     |> close_context_menu()
     |> open_pm_conversation(nick)}
  end

  def handle_event("context_whois", %{"nick" => nick}, socket) do
    {:noreply,
     socket
     |> close_context_menu()
     |> assign(show_whois: true, whois_target: nick)}
  end

  def handle_event("context_kick", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_kick(channel, nick)}
  end

  def handle_event("context_ban", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_ban(channel, nick)}
  end

  def handle_event("context_op", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+o", [nick])}
  end

  def handle_event("context_voice", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+v", [nick])}
  end

  # Menu bar events (Phase 14)
  def handle_event("quit_chat", _params, socket) do
    cleanup_channels(socket.assigns.session)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("open_search", _params, socket) do
    {:noreply, assign(socket, search_visible: true)}
  end

  def handle_event("settings", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_treebar", _params, socket) do
    {:noreply, assign(socket, show_treebar: !socket.assigns.show_treebar)}
  end

  def handle_event("toggle_nicklist", _params, socket) do
    {:noreply, assign(socket, show_nicklist: !socket.assigns.show_nicklist)}
  end

  def handle_event("show_about", _params, socket) do
    {:noreply, assign(socket, show_about: true)}
  end

  # Command palette events
  def handle_event("open_command_palette", _params, socket) do
    {:noreply, assign(socket, command_palette_visible: true, command_palette_filter: "")}
  end

  def handle_event("close_command_palette", _params, socket) do
    {:noreply, assign(socket, command_palette_visible: false, command_palette_filter: "")}
  end

  def handle_event("filter_command_palette", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, command_palette_filter: filter)}
  end

  def handle_event("select_command", %{"command" => command}, socket) do
    {:noreply,
     assign(socket,
       input: "/#{command} ",
       command_palette_visible: false,
       command_palette_filter: ""
     )}
  end

  # Keyboard shortcut events
  def handle_event("history_navigate", %{"direction" => direction}, socket) do
    history = socket.assigns.command_history
    index = socket.assigns[:history_index] || -1

    case direction do
      "up" ->
        new_index = min(index + 1, length(history) - 1)

        if new_index >= 0 and new_index < length(history) do
          {:noreply, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:noreply, socket}
        end

      "down" ->
        new_index = max(index - 1, -1)

        if new_index >= 0 do
          {:noreply, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:noreply, assign(socket, input: "", history_index: -1)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("tab_complete", %{"partial" => partial}, socket) do
    users = socket.assigns.channel_users
    matches = Enum.filter(users, &String.starts_with?(&1.nickname, partial))

    case matches do
      [match] -> {:noreply, assign(socket, input: match.nickname <> ": ")}
      _ -> {:noreply, socket}
    end
  end

  # Toolbar events (Phase 14)
  def handle_event("disconnect", _params, socket) do
    cleanup_channels(socket.assigns.session)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("channel_list", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/channels")}
  end

  # ── PubSub handlers ────────────────────────────────────────

  @impl true
  def handle_info(%{event: "new_message", payload: payload}, socket) do
    if payload.channel == socket.assigns.session.active_channel do
      {:noreply, stream_insert(socket, :chat_messages, payload)}
    else
      unread = MapSet.put(socket.assigns.unread_channels, payload.channel)
      {:noreply, assign(socket, unread_channels: unread)}
    end
  end

  def handle_info(%{event: "new_pm", payload: payload}, socket) do
    session = socket.assigns.session
    other_nick = pm_other_nick(payload, session.nickname)

    if session.active_pm == other_nick do
      {:noreply, stream_insert(socket, :chat_messages, pm_to_stream_item(payload))}
    else
      unread = MapSet.put(socket.assigns.unread_channels, "pm:#{other_nick}")
      {:noreply, assign(socket, unread_channels: unread)}
    end
  end

  def handle_info(
        {:mode_changed, %{nickname: nick, mode_string: mode_string, params: params}},
        socket
      ) do
    msg = "#{nick} sets mode #{mode_string}"
    users = apply_mode_to_users(socket.assigns.channel_users, mode_string, params)

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:mode_changed, %{nickname: nick, mode_string: mode_string}}, socket) do
    msg = "#{nick} sets mode #{mode_string}"
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:user_kicked, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was kicked by #{op}" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == target))

    if target == socket.assigns.session.nickname do
      socket =
        socket
        |> assign(channel_users: users)
        |> part_channel_after_kick(socket.assigns.session.active_channel)
        |> stream_insert(:chat_messages, system_message(msg))

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(channel_users: users)
       |> stream_insert(:chat_messages, system_message(msg))}
    end
  end

  def handle_info({:user_banned, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was banned by #{op}" <> if(reason, do: " (#{reason})", else: "")
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:topic_changed, %{nickname: nick, topic: topic}}, socket) do
    msg = "#{nick} changed the topic to: #{topic}"
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = "#{nick} has joined the channel"
    role = Map.get(payload, :role, :regular)
    user = %{nickname: nick, role: role, away: false}
    users = [user | socket.assigns.channel_users]

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason}}, socket) do
    msg = "#{nick} has left" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == nick))

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    # Update nicklist if this is from another user
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    msg = "#{old_nick} is now known as #{new_nick}"

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:force_disconnect, %{reason: reason}}, socket) do
    cleanup_channels(socket.assigns.session)

    {:noreply,
     socket
     |> put_flash(:error, "Disconnected: #{reason}")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:force_rename, %{reason: reason}}, socket) do
    old_nickname = socket.assigns.session.nickname
    guest_nick = "Guest_#{:rand.uniform(99999)}"
    session = Session.update_nickname(socket.assigns.session, guest_nick)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nickname}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{guest_nick}")

    msg = "[NickServ] #{reason}. You are now #{guest_nick}"

    {:noreply,
     socket
     |> assign(session: session)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]
    if session, do: cleanup_channels(session)
    :ok
  end

  defp cleanup_channels(session) do
    NickServ.cancel_identify_timer(session.nickname)

    Enum.each(session.channels, fn channel ->
      try do
        safe_untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, "Connection lost")
      rescue
        e ->
          Logger.warning("Failed to part #{channel} during cleanup: #{inspect(e)}")
          :ok
      end
    end)
  end

  # -- Private helpers --

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

  defp close_context_menu(socket) do
    assign(socket, context_menu: %{visible: false, x: 0, y: 0, target_nick: nil})
  end

  defp context_ban(socket, nil, _nick), do: socket

  defp context_ban(socket, channel, nick) do
    case Server.ban(channel, socket.assigns.session.nickname, nick, nil) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp context_kick(socket, nil, _nick), do: socket

  defp context_kick(socket, channel, nick) do
    case Server.kick(channel, socket.assigns.session.nickname, nick, nil) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp context_set_mode(socket, nil, _mode, _params), do: socket

  defp context_set_mode(socket, channel, mode, params) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp maybe_start_nickserv_timer(socket, nickname) do
    if NickServ.registered?(nickname) do
      NickServ.start_identify_timer(nickname)

      notice =
        "[NickServ] This nickname is registered. " <>
          "You have 60 seconds to identify via /ns identify <password> or you will be renamed."

      stream_insert(socket, :chat_messages, service_message("NickServ", notice))
    else
      socket
    end
  end

  defp dispatch_command(socket, session, name, args) do
    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      operator_in: channels_where_operator(session)
    }

    result = Dispatcher.dispatch(name, args, context)
    handle_dispatch_result(socket, session, result)
  end

  defp handle_dispatch_result(socket, session, {:ok, :join, channel_name, password}),
    do: join_channel(socket, channel_name, session, password)

  defp handle_dispatch_result(socket, session, {:ok, :join, channel_name}),
    do: join_channel(socket, channel_name, session)

  defp handle_dispatch_result(socket, _session, {:ok, :part, channel_name, _msg}),
    do: part_channel(socket, channel_name)

  defp handle_dispatch_result(
         socket,
         _session,
         {:ok, :message, %{target: target, content: content}}
       ),
       do: handle_pm_send(socket, target, content)

  defp handle_dispatch_result(socket, session, {:ok, :action, %{content: content}}),
    do: handle_action_message(socket, session, content)

  defp handle_dispatch_result(socket, _session, {:ok, :nick_change, new_nick}),
    do: handle_nick_change(socket, new_nick)

  defp handle_dispatch_result(socket, _session, {:ok, :quit, reason}),
    do: handle_quit(socket, reason)

  defp handle_dispatch_result(socket, _session, {:ok, :ui_action, action, payload}),
    do: handle_ui_action(socket, action, payload)

  defp handle_dispatch_result(socket, _session, {:ok, :system, %{content: text}}),
    do: stream_insert(socket, :chat_messages, service_message(detect_service_author(text), text))

  defp handle_dispatch_result(socket, _session, {:error, msg}),
    do: stream_insert(socket, :chat_messages, error_message(msg))

  defp handle_dispatch_result(socket, _session, _other), do: socket

  defp handle_ui_action(socket, :open_query, %{nickname: target}),
    do: open_pm_conversation(socket, target)

  defp handle_ui_action(socket, :open_channel_list, _),
    do: push_navigate(socket, to: ~p"/channels")

  defp handle_ui_action(socket, :clear_chat, _),
    do: stream(socket, :chat_messages, [], reset: true)

  defp handle_ui_action(socket, :set_away, %{message: message}),
    do: handle_set_away(socket, message)

  defp handle_ui_action(socket, :clear_away, _),
    do: handle_clear_away(socket)

  defp handle_ui_action(socket, :set_topic, %{channel: channel, topic: topic}),
    do: handle_set_topic(socket, channel, topic)

  defp handle_ui_action(socket, :view_topic, %{channel: channel}),
    do: handle_view_topic(socket, channel)

  defp handle_ui_action(socket, :open_whois, %{nickname: target}),
    do: assign(socket, show_whois: true, whois_target: target)

  defp handle_ui_action(socket, :show_help, %{commands: commands}),
    do: show_help_message(socket, commands)

  defp handle_ui_action(socket, :show_command_help, %{help: help}),
    do: show_command_help_message(socket, help)

  defp handle_ui_action(socket, :set_mode, %{
         channel: channel,
         mode_string: mode_string,
         params: params
       }) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode_string, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :kick_user, %{
         channel: channel,
         reason: reason,
         target: target
       }) do
    case Server.kick(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :ban_user, %{
         channel: channel,
         reason: reason,
         target: target
       }) do
    case Server.ban(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, _action, _payload), do: socket

  defp maybe_join_from_params(socket, %{"join" => channel_name})
       when is_binary(channel_name) and channel_name != "" do
    join_channel(socket, channel_name, socket.assigns.session)
  end

  defp maybe_join_from_params(socket, _params), do: socket

  defp join_channel(socket, channel_name, session, password \\ nil) do
    case ensure_channel_exists(channel_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start channel #{channel_name}: #{inspect(reason)}")
    end

    case Server.join(channel_name, session.nickname, password) do
      {:ok, _state} ->
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
        safe_track_user("channel:#{channel_name}", session.nickname)

        new_session =
          session
          |> Session.add_channel(channel_name)
          |> Session.set_active_channel(channel_name)

        socket
        |> assign(session: new_session, input: "")
        |> load_channel_users(channel_name)
        |> load_channel_messages_with_pagination(channel_name)

      {:error, reason} ->
        stream_insert(socket, :chat_messages, error_message(reason))
    end
  end

  defp part_channel(socket, channel_name) do
    session = socket.assigns.session

    try do
      Server.part(channel_name, session.nickname, nil)
    rescue
      e ->
        Logger.warning("Failed to part #{channel_name}: #{inspect(e)}")
        :ok
    end

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    safe_untrack_user("channel:#{channel_name}", session.nickname)
    new_session = Session.remove_channel(session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      socket
      |> load_channel_users(new_session.active_channel)
      |> load_channel_messages_with_pagination(new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false, channel_users: [])
      |> stream(:chat_messages, [], reset: true)
    end
  end

  defp part_channel_after_kick(socket, channel_name) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    safe_untrack_user("channel:#{channel_name}", socket.assigns.session.nickname)
    new_session = Session.remove_channel(socket.assigns.session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      load_channel_messages_with_pagination(socket, new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false)
      |> stream(:chat_messages, [], reset: true)
    end
  end

  defp load_channel_users(socket, channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        users =
          Enum.map(state.members, fn {nick, role} ->
            %{nickname: nick, role: role, away: false}
          end)

        assign(socket, channel_users: users)

      {:error, _} ->
        assign(socket, channel_users: [])
    end
  end

  defp ensure_channel_exists(channel_name) do
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

  defp channels_where_operator(session) do
    Enum.filter(session.channels, fn channel_name ->
      case Server.get_state(channel_name) do
        {:ok, state} -> session.nickname in state.operators
        {:error, _} -> false
      end
    end)
  end

  defp viewer_is_op?(session) do
    case session.active_channel do
      nil ->
        false

      channel ->
        case Server.get_state(channel) do
          {:ok, state} -> session.nickname in state.operators
          {:error, _} -> false
        end
    end
  rescue
    e ->
      Logger.warning("Failed to check operator status: #{inspect(e)}")
      false
  end

  defp send_plain_message(socket, session, text) do
    cond do
      session.active_pm ->
        handle_pm_send(socket, session.active_pm, text)

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, text) do
          :ok ->
            socket

          {:error, reason} ->
            stream_insert(socket, :chat_messages, error_message(reason))
        end

      true ->
        socket
    end
  end

  defp handle_pm_send(socket, target, content) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    case Service.send_private_message(session.nickname, target, content) do
      {:ok, _pm} ->
        new_session = Session.add_pm_conversation(session, target)
        assign(socket, session: new_session)

      {:error, reason} ->
        stream_insert(socket, :chat_messages, error_message(reason))
    end
  end

  defp open_pm_conversation(socket, target) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    new_session =
      session
      |> Session.add_pm_conversation(target)
      |> Session.set_active_pm(target)

    messages = load_pm_messages(new_session.nickname, target)

    socket
    |> assign(session: new_session, input: "")
    |> stream(:chat_messages, messages, reset: true)
  end

  defp ensure_pm_subscription(nick_a, nick_b) do
    topic = "pm:#{pm_topic(nick_a, nick_b)}"
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
  end

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp pm_other_nick(payload, my_nick) do
    if payload.sender == my_nick, do: payload.recipient, else: payload.sender
  end

  defp load_pm_messages(my_nick, other_nick) do
    Queries.list_private_messages(my_nick, other_nick, limit: 50)
    |> Enum.reverse()
    |> Enum.map(&pm_to_stream_item/1)
  end

  defp pm_to_stream_item(pm) do
    %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:timestamp, :inserted_at])
    }
  end

  defp pm_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp pm_resolve_type(%{type: type}) when is_atom(type), do: type
  defp pm_resolve_type(%{type: type}) when is_binary(type), do: String.to_existing_atom(type)
  defp pm_resolve_type(_), do: :message

  defp do_load_more(socket, oldest_id) do
    channel = socket.assigns.session.active_channel
    older_messages = Queries.list_messages(channel, limit: 50, before_id: oldest_id)
    prepend_older_messages(assign(socket, loading_more: true), older_messages)
  end

  defp prepend_older_messages(socket, []) do
    assign(socket, loading_more: false, has_more: false)
  end

  defp prepend_older_messages(socket, older_messages) do
    new_oldest = List.last(older_messages)

    stream_items =
      older_messages
      |> Enum.reverse()
      |> Enum.map(&message_to_stream_item/1)

    socket =
      socket
      |> assign(
        loading_more: false,
        oldest_message_id: new_oldest.id,
        has_more: length(older_messages) == 50
      )
      |> push_event("prepend_start", %{})

    Enum.reduce(stream_items, socket, fn item, acc ->
      stream_insert(acc, :chat_messages, item, at: 0)
    end)
  end

  defp load_channel_messages_with_pagination(socket, channel_name) do
    raw_messages = Queries.list_messages(channel_name, limit: 50)

    # raw_messages is in desc order; last element is the oldest
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

  defp message_to_stream_item(msg) do
    %{
      id: msg.id,
      author: msg.author_nickname,
      content: msg.content,
      type: String.to_existing_atom(msg.type),
      timestamp: msg.inserted_at
    }
  end

  # -- Search helpers --

  defp do_search(socket, "") do
    clear_search_state(socket)
  end

  defp do_search(socket, query) do
    channel = socket.assigns.session.active_channel

    if channel do
      count = Search.count_matches(channel, query)
      results = Search.search_messages(channel, query)

      assign(socket,
        search_query: query,
        search_results: results,
        search_result_count: count,
        search_current_index: min(1, count)
      )
    else
      assign(socket, search_query: query, search_results: [], search_result_count: 0)
    end
  end

  defp clear_search_state(socket) do
    assign(socket,
      search_visible: false,
      search_query: "",
      search_results: [],
      search_result_count: 0,
      search_current_index: 0
    )
  end

  # -- US4 command dispatch helpers --

  defp handle_action_message(socket, session, content) do
    cond do
      session.active_pm ->
        case Service.send_private_message(session.nickname, session.active_pm, content, "action") do
          {:ok, _pm} -> socket
          {:error, reason} -> stream_insert(socket, :chat_messages, error_message(reason))
        end

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, content, :action) do
          :ok -> socket
          {:error, reason} -> stream_insert(socket, :chat_messages, error_message(reason))
        end

      true ->
        socket
    end
  end

  defp handle_nick_change(socket, new_nick) do
    old_nick = socket.assigns.session.nickname
    session = Session.update_nickname(socket.assigns.session, new_nick)

    # Update Server membership for all channels
    Enum.each(session.channels, fn channel ->
      try do
        Server.rename_user(channel, old_nick, new_nick)
      rescue
        e ->
          Logger.warning("Failed to rename #{old_nick}->#{new_nick} in #{channel}: #{inspect(e)}")
      end
    end)

    # Broadcast nick change to all shared channels
    Enum.each(session.channels, fn channel ->
      case Phoenix.PubSub.broadcast(
             RetroHexChat.PubSub,
             "channel:#{channel}",
             {:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}
           ) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "PubSub nick_changed broadcast to channel:#{channel} failed: #{inspect(reason)}"
          )
      end
    end)

    # Update Presence: untrack old, track new
    Enum.each(session.channels, fn channel ->
      safe_untrack_user("channel:#{channel}", old_nick)
      safe_track_user("channel:#{channel}", new_nick)
    end)

    # Resubscribe user topic
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nick}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{new_nick}")

    # Update nicklist
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now known as #{new_nick}"))
    |> assign(session: session, channel_users: users)
  end

  defp handle_quit(socket, _reason) do
    cleanup_channels(socket.assigns.session)
    push_navigate(socket, to: ~p"/")
  end

  defp handle_set_away(socket, message) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now away: #{message}"))
    |> assign(session: session)
  end

  defp handle_clear_away(socket) do
    session = socket.assigns.session
    new_session = Session.set_away(session, nil)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, false, nil)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are no longer away"))
    |> assign(session: new_session)
  end

  defp handle_set_topic(socket, channel, topic) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok ->
        socket

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_view_topic(socket, channel) do
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

  defp show_help_message(socket, commands) do
    text = "Available commands: " <> Enum.join(Enum.map(commands, &"/#{&1}"), ", ")
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp show_command_help_message(socket, help) do
    text = "#{help.syntax} - #{help.description}"
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp safe_track_user(topic, nickname) do
    case Tracker.track_user(topic, nickname) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.track_user(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  defp safe_untrack_user(topic, nickname) do
    Tracker.untrack_user(topic, nickname)
  rescue
    e -> Logger.warning("Tracker.untrack_user(#{topic}, #{nickname}): #{inspect(e)}")
  end

  defp safe_update_away(topic, nickname, away, message) do
    case Tracker.update_away(topic, nickname, away, message) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.update_away(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  defp system_message(content) do
    %{
      id: "system-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :system,
      timestamp: DateTime.utc_now()
    }
  end

  defp error_message(content) do
    %{
      id: "error-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :error,
      timestamp: DateTime.utc_now()
    }
  end

  defp detect_service_author("[ChanServ]" <> _), do: "ChanServ"
  defp detect_service_author("[NickServ]" <> _), do: "NickServ"
  defp detect_service_author(_), do: "Service"

  defp service_message(author, content) do
    %{
      id: "service-#{System.unique_integer([:positive])}",
      author: author,
      content: content,
      type: :service,
      timestamp: DateTime.utc_now()
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="app-container"
      phx-click="close_context_menu"
      phx-window-keydown="window_keydown"
      id="app-container"
      phx-hook="SoundHook"
    >
      <RetroHexChatWeb.Components.TitleBar.title_bar />
      <RetroHexChatWeb.Components.MenuBar.menu_bar />
      <RetroHexChatWeb.Components.Toolbar.toolbar connected={true} />

      <div class="mdi-layout">
        <RetroHexChatWeb.Components.Treebar.treebar
          :if={@show_treebar}
          channels={@session.channels}
          active_channel={@session.active_channel}
          unread_channels={MapSet.to_list(@unread_channels)}
          pm_conversations={@session.pm_conversations}
          active_pm={@session.active_pm}
        />

        <div class="chat-area" style="position: relative;">
          <RetroHexChatWeb.Components.SearchBar.search_bar
            visible={@search_visible}
            query={@search_query}
            result_count={@search_result_count}
            current_index={@search_current_index}
          />

          <RetroHexChatWeb.Components.ScrollLoader.scroll_loader loading={@loading_more} />

          <div class="chat-messages" id="chat-messages" phx-update="stream" phx-hook="ScrollHook">
            <div
              :for={{dom_id, msg} <- @streams.chat_messages}
              id={dom_id}
              class={"chat-message chat-message--#{msg.type}"}
            >
              <span class="chat-timestamp">[{format_time(msg.timestamp)}]</span>
              <%= case msg.type do %>
                <% :action -> %>
                  <span class="chat-action">* {msg.author} {msg.content}</span>
                <% :system -> %>
                  <span class="chat-system">* {msg.content}</span>
                <% :service -> %>
                  <span class="chat-service">{msg.content}</span>
                <% :error -> %>
                  <span class="chat-error">{msg.content}</span>
                <% _ -> %>
                  <span class="chat-nick" style={"color: #{nick_color(msg.author)}"}>
                    &lt;{msg.author}&gt;
                  </span>
                  <span class="chat-content">{msg.content}</span>
              <% end %>
            </div>
          </div>

          <div class="chat-input-area" style="position: relative;">
            <RetroHexChatWeb.Components.CommandPalette.command_palette
              visible={@command_palette_visible}
              commands={CmdRegistry.list_commands()}
              filter={@command_palette_filter}
            />
            <form phx-submit="send_input" class="chat-input-form">
              <input
                type="text"
                name="input"
                id="chat-input"
                value={@input}
                placeholder="Type a message or /command..."
                autocomplete="off"
                autofocus
                phx-hook="CommandPaletteHook"
              />
              <button type="submit">Send</button>
            </form>
          </div>
        </div>

        <RetroHexChatWeb.Components.Nicklist.nicklist
          :if={@show_nicklist && !@session.active_pm}
          users={@channel_users}
        />
      </div>

      <RetroHexChatWeb.Components.ContextMenu.context_menu
        visible={@context_menu.visible}
        x={@context_menu.x}
        y={@context_menu.y}
        target_nick={@context_menu.target_nick}
        viewer_is_op={viewer_is_op?(@session)}
      />

      <RetroHexChatWeb.Components.Dialog.dialog
        title="About RetroHexChat"
        visible={@show_about}
        on_close="close_dialog"
      >
        <p>RetroHexChat v1.0</p>
        <p>A retro IRC-style chat with Windows 98 aesthetics.</p>
        <p>Built with Elixir, Phoenix LiveView, and 98.css.</p>
      </RetroHexChatWeb.Components.Dialog.dialog>

      <RetroHexChatWeb.Components.StatusBar.status_bar
        nickname={@session.nickname}
        channel={@session.active_pm || @session.active_channel}
        user_count={length(@channel_users)}
      />
    </div>
    """
  end

  @nick_colors ~w(#e74c3c #3498db #2ecc71 #e67e22 #9b59b6 #1abc9c #f39c12 #e91e63 #00bcd4 #8bc34a #ff5722 #607d8b)

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  defp format_time(_), do: "--:--"

  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end
end
