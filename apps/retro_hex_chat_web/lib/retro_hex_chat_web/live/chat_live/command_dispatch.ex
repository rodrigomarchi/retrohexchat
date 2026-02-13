defmodule RetroHexChatWeb.ChatLive.CommandDispatch do
  @moduledoc """
  Command dispatch: alias expansion, command execution, and result handling.

  Public functions called by ChatLive.handle_event("send_input") and timer handlers.
  NOT a hook module — these are plain public functions.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      error_message: 1,
      service_message: 2,
      push_status_message: 3,
      join_channel: 3,
      join_channel: 4,
      part_channel: 2,
      handle_pm_send: 3,
      handle_notice_send: 4,
      safe_track_user: 2,
      safe_untrack_user: 2
    ]

  alias RetroHexChat.Accounts.Session

  alias RetroHexChat.Chat.{
    AliasExpander,
    AliasList,
    CtcpSettings,
    Service
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.UiActionHandlers

  require Logger

  @spec dispatch_command(
          Phoenix.LiveView.Socket.t(),
          Session.t(),
          String.t(),
          [String.t()],
          non_neg_integer()
        ) :: Phoenix.LiveView.Socket.t()
  def dispatch_command(socket, session, name, args, alias_depth \\ 0) do
    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      operator_in: channels_where_operator(session),
      half_operator_in: channels_where_half_operator(session)
    }

    case try_alias_expansion(session, name, args, context, alias_depth) do
      {:expanded, expanded_input} ->
        case Parser.parse(expanded_input) do
          {:command, new_name, new_args} ->
            dispatch_command(socket, session, new_name, new_args, alias_depth + 1)

          {:message, text} ->
            send_plain_message(socket, session, text)
        end

      :not_alias ->
        result = Dispatcher.dispatch(name, args, context)
        handle_dispatch_result(socket, session, result)

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  @spec send_plain_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def send_plain_message(socket, session, text) do
    cond do
      socket.assigns.show_status_tab ->
        push_status_message(socket, "Cannot send text to status window. Use /commands.", :error)

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

  # ── Private: alias expansion ──────────────────────────────

  defp try_alias_expansion(session, name, args, context, alias_depth) do
    if alias_depth >= 5 do
      {:error, "Alias recursion limit reached (max 5 levels)"}
    else
      case AliasList.find_entry(session.aliases, name) do
        nil ->
          :not_alias

        entry ->
          expand_context = %{nick: context.nickname, chan: context.active_channel}
          expanded = AliasExpander.expand(entry.expansion, args, expand_context)
          {:expanded, expanded}
      end
    end
  end

  # ── Private: dispatch result handling ─────────────────────

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
    do: UiActionHandlers.handle_ui_action(socket, action, payload)

  defp handle_dispatch_result(
         socket,
         session,
         {:ok, :notice, %{target: target, content: content}}
       ) do
    handle_notice_send(socket, session, target, content)
  end

  defp handle_dispatch_result(
         socket,
         session,
         {:ok, :ctcp, %{target: target, type: type}}
       ) do
    handle_ctcp_send(socket, session, target, type)
  end

  defp handle_dispatch_result(socket, _session, {:ok, :system, %{content: text}}),
    do: stream_insert(socket, :chat_messages, service_message(detect_service_author(text), text))

  defp handle_dispatch_result(socket, _session, {:error, msg}),
    do: stream_insert(socket, :chat_messages, error_message(msg))

  defp handle_dispatch_result(socket, _session, _other), do: socket

  # ── Private: action message ───────────────────────────────

  defp handle_action_message(socket, session, content) do
    cond do
      session.active_pm ->
        case Service.send_private_message(
               session.nickname,
               session.active_pm,
               content,
               "action"
             ) do
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

  # ── Private: nick change ──────────────────────────────────

  defp handle_nick_change(socket, new_nick) do
    old_nick = socket.assigns.session.nickname
    session = Session.update_nickname(socket.assigns.session, new_nick)

    Enum.each(session.channels, fn channel ->
      try do
        Server.rename_user(channel, old_nick, new_nick)
      rescue
        e ->
          Logger.warning("Failed to rename #{old_nick}->#{new_nick} in #{channel}: #{inspect(e)}")
      end
    end)

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

    Enum.each(session.channels, fn channel ->
      safe_untrack_user("channel:#{channel}", old_nick)
      safe_track_user("channel:#{channel}", new_nick)
    end)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nick}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{new_nick}")

    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now known as #{new_nick}"))
    |> assign(session: session, channel_users: users)
  end

  # ── Private: quit ─────────────────────────────────────────

  defp handle_quit(socket, _reason) do
    cleanup_channels(socket.assigns.session)

    socket
    |> Phoenix.LiveView.push_event("intentional_disconnect", %{})
    |> push_navigate(to: ~p"/")
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

  # ── Private: CTCP send ────────────────────────────────────

  defp handle_ctcp_send(socket, session, target, type) do
    if target == session.nickname do
      handle_self_ctcp(socket, session, type)
    else
      case check_ctcp_rate_limit(socket, target) do
        {:ok, updated_socket} ->
          handle_remote_ctcp(updated_socket, session, target, type)

        {:error, socket_with_error} ->
          socket_with_error
      end
    end
  end

  defp handle_self_ctcp(socket, session, type) do
    value = generate_ctcp_reply_value(session, type)

    case type do
      :ping ->
        stream_insert(
          socket,
          :chat_messages,
          system_message("* CTCP PING reply from #{session.nickname}: 0ms")
        )

      _ ->
        type_upper = type |> Atom.to_string() |> String.upcase()

        stream_insert(
          socket,
          :chat_messages,
          system_message("* CTCP #{type_upper} reply from #{session.nickname}: #{value}")
        )
    end
  end

  defp handle_remote_ctcp(socket, session, target, type) do
    case validate_target_online(target) do
      :ok ->
        request_id = "ctcp_#{System.unique_integer([:positive])}"
        sent_at = System.monotonic_time(:millisecond)
        timer_ref = Process.send_after(self(), {:ctcp_timeout, request_id}, 10_000)

        pending =
          Map.put(socket.assigns.ctcp_pending, request_id, %{
            target: target,
            type: type,
            sent_at: sent_at,
            timer_ref: timer_ref
          })

        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:ctcp_request,
           %{
             type: type,
             sender: session.nickname,
             request_id: request_id,
             sent_at: sent_at
           }}
        )

        assign(socket, ctcp_pending: pending)

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp check_ctcp_rate_limit(socket, target) do
    key = String.downcase(target)
    now = System.monotonic_time(:millisecond)
    window = 30_000
    max_requests = 3

    rate_limits = socket.assigns.ctcp_rate_limits
    timestamps = Map.get(rate_limits, key, [])

    active = Enum.filter(timestamps, fn ts -> now - ts < window end)

    if length(active) < max_requests do
      updated = Map.put(rate_limits, key, [now | active])
      {:ok, assign(socket, ctcp_rate_limits: updated)}
    else
      {:error,
       stream_insert(
         socket,
         :chat_messages,
         system_message(
           "* CTCP rate limit reached for #{target}. Please wait before sending another request."
         )
       )}
    end
  end

  defp generate_ctcp_reply_value(session, type) do
    settings = Session.get_ctcp_settings(session)

    case type do
      :ping ->
        ""

      :version ->
        CtcpSettings.get_version_string(settings)

      :time ->
        Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC")

      :finger ->
        case CtcpSettings.get_finger_text(settings) do
          nil ->
            idle_seconds = DateTime.diff(DateTime.utc_now(), session.last_message_at, :second)
            "#{session.nickname} - idle #{format_idle_time(idle_seconds)}"

          custom ->
            custom
        end
    end
  end

  defp format_idle_time(seconds) when seconds < 60, do: "#{seconds} seconds"

  defp format_idle_time(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    if minutes == 1, do: "1 minute", else: "#{minutes} minutes"
  end

  defp format_idle_time(seconds) when seconds < 86_400 do
    hours = div(seconds, 3600)
    if hours == 1, do: "1 hour", else: "#{hours} hours"
  end

  defp format_idle_time(seconds) do
    days = div(seconds, 86_400)
    if days == 1, do: "1 day", else: "#{days} days"
  end

  # ── Private: helpers ──────────────────────────────────────

  defp channels_where_operator(session) do
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

  defp channels_where_half_operator(session) do
    Enum.filter(session.channels, fn channel_name ->
      case Server.get_state(channel_name) do
        {:ok, state} -> session.nickname in Map.get(state, :half_operators, [])
        {:error, _} -> false
      end
    end)
  end

  defp detect_service_author("[ChanServ]" <> _), do: "ChanServ"
  defp detect_service_author("[NickServ]" <> _), do: "NickServ"
  defp detect_service_author(_), do: "Service"

  # handle_set_away, handle_clear_away, handle_set_topic, handle_view_topic,
  # show_help_message, show_command_help_message, validate_operator,
  # validate_invite_only, validate_target_not_in_channel
  # → UiActionHandlers (local copies)

  defp validate_target_online(target) do
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
end
