defmodule RetroHexChatWeb.ChatLive.TimerHandlers do
  @moduledoc """
  Handle timer and scheduled message callbacks via handle_info.

  Covers: clear_typing_indicator, user_timer_fired, ignore_expired, auto_ignore_expired,
  execute_perform, execute_autojoin, execute_favorites_autojoin, execute_rejoin,
  invite_expired.

  Attached as `attach_hook(:timer_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream: 4, stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      error_message: 1,
      maybe_persist_ignore_list: 2,
      join_channel: 4,
      load_channel_users: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Accounts.Session

  alias RetroHexChat.Chat.{
    AliasExpander,
    AutoJoinList,
    Favorites,
    FloodTracker,
    IgnoreList,
    PerformList,
    Queries
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.Parser
  alias RetroHexChatWeb.ChatLive.CommandDispatch

  # ── Typing indicator timer ────────────────────────────────

  def handle_info(:clear_typing_indicator, socket) do
    {:halt, assign(socket, pm_typing_from: nil, pm_typing_timer: nil)}
  end

  # ── User timer fired ──────────────────────────────────────

  def handle_info({:user_timer_fired, name}, socket) do
    timers = socket.assigns.user_timers

    case Map.get(timers, name) do
      nil ->
        {:halt, socket}

      %{type: type, interval: interval, command: command} ->
        session = socket.assigns.session
        expand_context = %{nick: session.nickname, chan: session.active_channel}
        expanded = AliasExpander.expand(command, [], expand_context)

        socket =
          case Parser.parse(expanded) do
            {:command, cmd_name, cmd_args} ->
              dispatch_command(socket, session, cmd_name, cmd_args)

            {:message, text} ->
              send_plain_message(socket, session, text)
          end

        socket =
          case type do
            :repeat ->
              ref = Process.send_after(self(), {:user_timer_fired, name}, interval * 1000)

              new_timers =
                Map.put(timers, name, %{
                  type: :repeat,
                  interval: interval,
                  command: command,
                  ref: ref
                })

              assign(socket, user_timers: new_timers)

            :once ->
              assign(socket, user_timers: Map.delete(timers, name))
          end

        {:halt, socket}
    end
  end

  # ── Ignore expired ────────────────────────────────────────

  def handle_info({:ignore_expired, nickname}, socket) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nickname) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        timers = Map.delete(socket.assigns.ignore_timers, String.downcase(nickname))

        {:halt,
         socket
         |> assign(session: new_session, ignore_timers: timers)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(
           :chat_messages,
           system_message("* #{nickname} is no longer ignored (timer expired)")
         )}

      {:error, :not_found} ->
        {:halt, socket}
    end
  end

  # ── Auto-ignore expired ──────────────────────────────────

  def handle_info({:auto_ignore_expired, nickname}, socket) do
    session = socket.assigns.session
    sender_key = String.downcase(nickname)
    auto_state = socket.assigns.auto_ignore_state

    case IgnoreList.remove_entry(session.ignore_list, nickname) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)
        new_active = Map.delete(auto_state.active, sender_key)
        new_auto_state = %{auto_state | active: new_active}

        new_tracker = FloodTracker.reset_sender(socket.assigns.flood_tracker, nickname)

        {:halt,
         socket
         |> assign(
           session: new_session,
           auto_ignore_state: new_auto_state,
           flood_tracker: new_tracker
         )
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(
           :chat_messages,
           system_message("* #{nickname} is no longer auto-ignored")
         )}

      {:error, :not_found} ->
        new_active = Map.delete(auto_state.active, sender_key)
        new_auto_state = %{auto_state | active: new_active}
        {:halt, assign(socket, auto_ignore_state: new_auto_state)}
    end
  end

  # ── Execute perform ───────────────────────────────────────

  def handle_info({:execute_perform, index}, socket) do
    session = socket.assigns.session
    entries = PerformList.entries(session.perform_list)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      masked = PerformList.mask_command(entry.command)

      socket =
        socket
        |> stream_insert(:chat_messages, system_message("* Performing: #{masked}"))
        |> execute_perform_command(session, entry.command)

      Process.send_after(self(), {:execute_perform, index + 1}, 100)
      {:halt, socket}
    else
      send(self(), {:execute_autojoin, 0})
      {:halt, socket}
    end
  end

  # ── Execute autojoin ──────────────────────────────────────

  def handle_info({:execute_autojoin, index}, socket) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      channel = entry.channel_name
      key = entry.channel_key

      socket =
        socket
        |> stream_insert(:chat_messages, system_message("* Auto-joining #{channel}..."))
        |> join_channel(channel, session, key)

      Process.send_after(self(), {:execute_autojoin, index + 1}, 100)
      {:halt, socket}
    else
      send(self(), {:execute_favorites_autojoin, 0})
      {:halt, socket}
    end
  end

  # ── Execute favorites autojoin ────────────────────────────

  def handle_info({:execute_favorites_autojoin, index}, socket) do
    session = socket.assigns.session
    entries = Favorites.auto_join_entries(session.favorites)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      channel = entry.channel_name

      socket =
        if channel in session.channels do
          socket
        else
          socket
          |> stream_insert(
            :chat_messages,
            system_message("* Auto-joining favorite #{channel}...")
          )
          |> join_channel(channel, session, entry.password)
        end

      Process.send_after(self(), {:execute_favorites_autojoin, index + 1}, 100)
      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  # ── Execute rejoin ────────────────────────────────────────

  def handle_info({:execute_rejoin, index, channels}, socket) do
    session = socket.assigns.session

    if index < length(channels) do
      channel = Enum.at(channels, index)

      socket =
        if channel in session.channels do
          socket
        else
          socket
          |> stream_insert(:chat_messages, system_message("* Rejoining #{channel}..."))
          |> join_channel(channel, session, nil)
        end

      Process.send_after(self(), {:execute_rejoin, index + 1, channels}, 100)
      {:halt, socket}
    else
      {:halt, maybe_restore_active_tab(socket)}
    end
  end

  # ── Invite expired ────────────────────────────────────────

  def handle_info({:invite_expired, channel}, socket) do
    {pending, expired} = cancel_existing_invite(socket.assigns.pending_invites, channel)

    socket = assign(socket, pending_invites: pending)

    socket =
      if expired do
        nickname = socket.assigns.session.nickname
        try_remove_invite_exception(channel, nickname)
        socket
      else
        socket
      end

    {:halt, socket}
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_msg, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp dispatch_command(socket, session, name, args) do
    CommandDispatch.dispatch_command(socket, session, name, args)
  end

  defp send_plain_message(socket, session, text) do
    CommandDispatch.send_plain_message(socket, session, text)
  end

  defp execute_perform_command(socket, session, command) do
    case Parser.parse(command) do
      {:command, name, args} ->
        dispatch_command(socket, session, name, args)

      {:message, _text} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Perform: invalid command format: #{PerformList.mask_command(command)}")
        )
    end
  end

  defp maybe_restore_active_tab(socket) do
    target_channel = socket.assigns[:reconnect_active_channel]
    target_pm = socket.assigns[:reconnect_active_pm]
    session = socket.assigns.session

    socket = assign(socket, reconnect_active_channel: nil, reconnect_active_pm: nil)

    cond do
      target_pm && target_pm in session.pm_conversations ->
        new_session = Session.set_active_pm(session, target_pm)
        messages = load_pm_messages(new_session.nickname, target_pm)

        socket
        |> assign(session: new_session, show_status_tab: false)
        |> stream(:chat_messages, messages, reset: true)

      target_channel && target_channel in session.channels ->
        new_session = Session.set_active_channel(session, target_channel)

        socket
        |> assign(session: new_session, show_status_tab: false)
        |> load_channel_users(target_channel)
        |> load_channel_messages_with_pagination(target_channel)

      true ->
        socket
    end
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

  defp cancel_existing_invite(pending, channel) do
    case Enum.split_with(pending, &(&1.channel == channel)) do
      {[existing], rest} ->
        Process.cancel_timer(existing.timer_ref)
        {rest, existing}

      {[], _} ->
        {pending, nil}
    end
  end

  defp try_remove_invite_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
