defmodule RetroHexChatWeb.ChatLive.TimerHandlers do
  @moduledoc """
  Handle timer and scheduled message callbacks via handle_info.

  Covers: clear_typing_indicator, user_timer_fired, ignore_expired, auto_ignore_expired,
  execute_perform, execute_autojoin, execute_rejoin,
  invite_expired, paste_next.

  Attached as `attach_hook(:timer_handlers, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
      error_event: 2,
      push_status_message: 3,
      maybe_persist_ignore_list: 2,
      join_channel_in_background: 4,
      load_channel_users: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Accounts.Session

  alias RetroHexChat.Chat.{
    AliasExpander,
    AutoJoinList,
    FloodTracker,
    IgnoreList,
    PerformList
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.Parser
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Helpers.PM

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

      %{type: type, interval: interval, command: command} = timer ->
        session = socket.assigns.session
        firing_window = active_window(socket, session)
        timer_window = Map.get(timer, :window, firing_window)

        socket =
          case activate_timer_window(socket, timer_window) do
            {:ok, target_socket} ->
              execute_timer_command(target_socket, command)

            {:error, target_socket} ->
              error_event(
                target_socket,
                gettext("* Timer '%{name}' target window is no longer available", name: name)
              )
          end

        socket = update_timer_after_fire(socket, name, type, interval, command, timer_window)
        socket = restore_active_window(socket, firing_window)

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
         |> system_event(
           gettext("* %{nickname} is no longer ignored (timer expired)", nickname: nickname)
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
         |> system_event(gettext("* %{nickname} is no longer auto-ignored", nickname: nickname))}

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

      # Preserve the current active window — perform should not steal focus
      prev_active = active_window(socket, session)

      socket =
        socket
        |> system_event(gettext("* Performing: %{command}", command: masked))
        |> execute_perform_command(session, entry.command)

      Process.send_after(self(), {:execute_perform, index + 1}, 100)
      {:halt, restore_active_window(socket, prev_active)}
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
        if channel in session.channels do
          socket
        else
          socket
          |> system_event(gettext("* Auto-joining %{channel}...", channel: channel))
          |> join_channel_in_background(channel, session, key)
        end

      Process.send_after(self(), {:execute_autojoin, index + 1}, 100)
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
          |> system_event(gettext("* Rejoining %{channel}...", channel: channel))
          |> join_channel_in_background(channel, session, nil)
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

        push_status_message(
          socket,
          gettext("* Channel invite to %{channel} expired", channel: channel),
          :system
        )
      else
        socket
      end

    {:halt, socket}
  end

  # ── Paste pacing ─────────────────────────────────────────

  def handle_info({:paste_next, []}, socket), do: {:halt, socket}

  def handle_info({:paste_next, [line | rest]}, socket) do
    session = socket.assigns.session
    socket = send_plain_message(socket, session, line)
    if rest != [], do: Process.send_after(self(), {:paste_next, rest}, 300)
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

  defp execute_timer_command(socket, command) do
    session = socket.assigns.session
    expand_context = %{nick: session.nickname, chan: session.active_channel}
    expanded = AliasExpander.expand(command, [], expand_context)

    case Parser.parse(expanded) do
      {:command, cmd_name, cmd_args} ->
        dispatch_command(socket, session, cmd_name, cmd_args)

      {:message, text} ->
        send_plain_message(socket, session, text)
    end
  end

  defp update_timer_after_fire(socket, name, :repeat, interval, command, timer_window) do
    timers = socket.assigns.user_timers

    if Map.has_key?(timers, name) do
      ref = Process.send_after(self(), {:user_timer_fired, name}, interval * 1000)

      new_timers =
        Map.put(timers, name, %{
          type: :repeat,
          interval: interval,
          command: command,
          window: timer_window,
          ref: ref
        })

      assign(socket, user_timers: new_timers)
    else
      socket
    end
  end

  defp update_timer_after_fire(socket, name, :once, _interval, _command, _timer_window) do
    assign(socket, user_timers: Map.delete(socket.assigns.user_timers, name))
  end

  defp execute_perform_command(socket, session, command) do
    case Parser.parse(command) do
      {:command, name, args} ->
        dispatch_command(socket, session, name, args)

      {:message, _text} ->
        error_event(
          socket,
          gettext("Perform: invalid command format: %{command}",
            command: PerformList.mask_command(command)
          )
        )
    end
  end

  defp active_window(socket, session) do
    cond do
      socket.assigns.show_status_tab -> :status
      session.active_pm -> {:pm, session.active_pm}
      session.active_channel -> {:channel, session.active_channel}
      true -> nil
    end
  end

  defp activate_timer_window(socket, :status) do
    session = socket.assigns.session

    {:ok,
     assign(socket,
       session: %{session | active_channel: nil, active_pm: nil},
       show_status_tab: true
     )}
  end

  defp activate_timer_window(socket, {:channel, channel}) do
    session = socket.assigns.session

    if channel in session.channels do
      {:ok,
       assign(socket,
         session: Session.set_active_channel(session, channel),
         show_status_tab: false
       )}
    else
      {:error, socket}
    end
  end

  defp activate_timer_window(socket, {:pm, target_pm}) do
    session = socket.assigns.session

    if target_pm in session.pm_conversations do
      {:ok,
       assign(socket, session: Session.set_active_pm(session, target_pm), show_status_tab: false)}
    else
      {:error, socket}
    end
  end

  defp activate_timer_window(socket, nil), do: {:ok, socket}

  defp restore_active_window(socket, nil), do: socket

  defp restore_active_window(socket, :status) do
    assign(socket, show_status_tab: true, status_unread: false)
  end

  defp restore_active_window(socket, {:channel, target_channel}) when is_binary(target_channel) do
    session = socket.assigns.session

    if target_channel in session.channels do
      new_session = Session.set_active_channel(session, target_channel)

      socket
      |> assign(session: new_session, show_status_tab: false)
      |> load_channel_users(target_channel)
      |> load_channel_messages_with_pagination(target_channel)
    else
      socket
    end
  end

  defp restore_active_window(socket, {:pm, target_pm}) when is_binary(target_pm) do
    session = socket.assigns.session

    if target_pm in session.pm_conversations do
      new_session = Session.set_active_pm(session, target_pm)

      socket
      |> assign(session: new_session, show_status_tab: false)
      |> PM.load_pm_messages_with_pagination(target_pm)
    else
      socket
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

        socket
        |> assign(session: new_session, show_status_tab: false)
        |> PM.load_pm_messages_with_pagination(target_pm)

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
