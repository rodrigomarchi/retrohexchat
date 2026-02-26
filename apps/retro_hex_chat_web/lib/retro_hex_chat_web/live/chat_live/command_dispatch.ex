defmodule RetroHexChatWeb.ChatLive.CommandDispatch do
  @moduledoc """
  Command dispatch: alias expansion, command execution, and result handling.

  Public functions called by ChatLive.handle_event("send_input") and timer handlers.
  NOT a hook module — these are plain public functions.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      push_status_message: 3,
      system_event: 2,
      error_event: 2,
      service_event: 3,
      join_channel: 3,
      join_channel: 4,
      part_channel: 2,
      handle_pm_send: 3,
      handle_notice_send: 4,
      safe_untrack_user: 2,
      maybe_persist_autojoin_list: 2
    ]

  alias RetroHexChat.Accounts.{ServerRoles, Session}
  alias RetroHexChat.Admin.GlobalMutes

  alias RetroHexChat.Chat.{
    AliasExpander,
    AliasList,
    AutoJoinList,
    CtcpSettings,
    Service
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.GameInvite
  alias RetroHexChatWeb.ChatLive.Helpers.P2pInvite
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
      half_operator_in: channels_where_half_operator(session),
      is_admin: ServerRoles.admin?(session.nickname, session.identified),
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
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
        error_event(socket, msg)
    end
  end

  @spec send_plain_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def send_plain_message(socket, session, text) do
    cond do
      socket.assigns.show_status_tab ->
        push_status_message(socket, "Cannot send text to status window. Use /commands.", :error)

      session.active_pm ->
        send_pm_message(socket, session, text)

      session.active_channel ->
        send_channel_message(socket, session, text)

      true ->
        socket
    end
  end

  # ── Private: message sending ─────────────────────────────

  defp send_pm_message(socket, session, text) do
    if GlobalMutes.muted?(session.nickname) do
      error_event(socket, "You are muted by an administrator")
    else
      do_send_pm_message(socket, session, text)
    end
  end

  defp do_send_pm_message(socket, session, text) do
    reply_to = socket.assigns[:reply_to]
    opts = if reply_to, do: [reply_to_id: reply_to.id], else: []
    target = session.active_pm

    case Service.send_private_message(session.nickname, target, text, "message", opts) do
      {:ok, _pm} ->
        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:incoming_pm_notify, %{sender: session.nickname}}
        )

        assign(socket, reply_to: nil)

      {:error, reason} ->
        error_event(socket, reason)
    end
  end

  defp send_channel_message(socket, session, text) do
    if GlobalMutes.muted?(session.nickname) do
      error_event(socket, "You are muted by an administrator")
    else
      do_send_channel_message(socket, session, text)
    end
  end

  defp do_send_channel_message(socket, session, text) do
    reply_to = socket.assigns[:reply_to]
    temp_id = "pending_#{System.unique_integer([:positive])}"

    pending_msg =
      build_pending_msg(temp_id, session.nickname, text, session.active_channel, reply_to)

    socket = stream_insert(socket, :chat_messages, pending_msg)
    opts = if reply_to, do: [reply_to_id: reply_to.id], else: []

    case Server.send_message(session.active_channel, session.nickname, text, opts) do
      :ok ->
        socket
        |> assign(pending_channel_msg_id: temp_id)
        |> push_event("message_confirmed", %{temp_id: temp_id})
        |> assign(reply_to: nil)

      {:error, reason} ->
        socket
        |> assign(pending_channel_msg_id: nil)
        |> push_event("message_failed", %{temp_id: temp_id, reason: reason})
        |> error_event(reason)
    end
  end

  defp build_pending_msg(temp_id, nickname, text, channel, nil) do
    %{
      id: temp_id,
      author: nickname,
      content: text,
      type: :message,
      timestamp: DateTime.utc_now(),
      status: :pending,
      target: channel
    }
  end

  defp build_pending_msg(temp_id, nickname, text, channel, reply_to) do
    %{
      id: temp_id,
      author: nickname,
      content: text,
      type: :message,
      timestamp: DateTime.utc_now(),
      status: :pending,
      target: channel,
      reply_to_id: reply_to.id,
      reply_to_author: reply_to.author,
      reply_to_preview: reply_to.preview
    }
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

  defp handle_dispatch_result(socket, session, {:ok, :join, channel_name, password}) do
    socket
    |> join_channel(channel_name, session, password)
    |> maybe_auto_add_to_autojoin(channel_name, password)
  end

  defp handle_dispatch_result(socket, session, {:ok, :join, channel_name}) do
    socket
    |> join_channel(channel_name, session)
    |> maybe_auto_add_to_autojoin(channel_name, nil)
  end

  defp handle_dispatch_result(socket, _session, {:ok, :part, channel_name, _msg}) do
    socket
    |> part_channel(channel_name)
    |> maybe_auto_remove_from_autojoin(channel_name)
  end

  defp handle_dispatch_result(
         socket,
         _session,
         {:ok, :message, %{target: target, content: content}}
       ),
       do: handle_pm_send(socket, target, content)

  defp handle_dispatch_result(socket, session, {:ok, :action, %{content: content}}),
    do: handle_action_message(socket, session, content)

  defp handle_dispatch_result(socket, _session, {:ok, :nick_change, new_nick}) do
    registered = NickServ.registered?(new_nick)

    assign(socket,
      nick_change_dialog: %{
        target_nick: new_nick,
        registered: registered,
        password: "",
        password_error: nil
      }
    )
  end

  defp handle_dispatch_result(socket, _session, {:ok, :quit, reason}),
    do: handle_quit(socket, reason)

  defp handle_dispatch_result(socket, _session, {:ok, :ui_action, action, payload})
       when action in [:show_help, :show_command_help] do
    socket
    |> push_event("tip_trigger", %{tip: "help_used"})
    |> UiActionHandlers.handle_ui_action(action, payload)
  end

  defp handle_dispatch_result(socket, session, {:ok, :ui_action, :p2p_invite, payload}),
    do: P2pInvite.handle_p2p_invite(socket, session, payload)

  defp handle_dispatch_result(socket, session, {:ok, :ui_action, :game_invite, payload}),
    do: GameInvite.handle_game_invite(socket, session, payload)

  defp handle_dispatch_result(socket, _session, {:ok, :ui_action, :arcade_session, payload}) do
    url = "/solo/#{payload.token}"

    msg = %{
      id: "system-#{System.unique_integer([:positive])}",
      author: "System",
      content: url,
      type: :arcade_link,
      timestamp: DateTime.utc_now()
    }

    socket
    |> stream_insert(:chat_messages, msg)
    |> push_status_message("Arcade session ready! Open: #{url}", :system)
  end

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
    do: service_event(socket, detect_service_author(text), text)

  defp handle_dispatch_result(socket, _session, {:error, msg}),
    do: error_event(socket, msg)

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
          {:error, reason} -> error_event(socket, reason)
        end

      session.active_channel ->
        case Server.send_message(session.active_channel, session.nickname, content, :action) do
          :ok -> socket
          {:error, reason} -> error_event(socket, reason)
        end

      true ->
        socket
    end
  end

  # ── Private: quit ─────────────────────────────────────────

  defp handle_quit(socket, reason) do
    session = socket.assigns.session
    quit_reason = reason || "Leaving"
    cleanup_channels(session, quit_reason)

    socket
    |> assign(quit_reason: quit_reason)
    |> Phoenix.LiveView.push_event("intentional_disconnect", %{})
    |> push_navigate(to: ~p"/connect")
  end

  defp cleanup_channels(session, reason) do
    NickServ.cancel_identify_timer(session.nickname)

    truncated = String.slice(reason, 0, 200)

    Enum.each(session.channels, fn channel ->
      try do
        safe_untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, truncated)
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
    timezone = socket.assigns[:timezone] || "Etc/UTC"
    value = generate_ctcp_reply_value(session, type, timezone)

    case type do
      :ping ->
        system_event(socket, "* CTCP PING reply from #{session.nickname}: 0ms")

      _ ->
        type_upper = type |> Atom.to_string() |> String.upcase()
        system_event(socket, "* CTCP #{type_upper} reply from #{session.nickname}: #{value}")
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
        error_event(socket, msg)
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
       system_event(
         socket,
         "* CTCP rate limit reached for #{target}. Please wait before sending another request."
       )}
    end
  end

  defp generate_ctcp_reply_value(session, type, timezone) do
    settings = Session.get_ctcp_settings(session)

    case type do
      :ping ->
        ""

      :version ->
        CtcpSettings.get_version_string(settings)

      :time ->
        now = DateTime.utc_now()
        tz_label = RetroHexChatWeb.Timezone.format_utc_offset(timezone)

        now
        |> RetroHexChatWeb.Timezone.shift(timezone)
        |> Calendar.strftime("%Y-%m-%d %H:%M:%S #{tz_label}")

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

  # ── Private: auto-join management ──────────────────────────

  defp maybe_auto_add_to_autojoin(socket, channel_name, key) do
    session = socket.assigns.session

    if session.identified and channel_name != "#lobby" do
      case AutoJoinList.add_entry(session.autojoin_list, channel_name, key) do
        {:ok, new_list} ->
          new_session = Session.set_autojoin_list(session, new_list)

          socket
          |> assign(session: new_session)
          |> maybe_persist_autojoin_list(new_session)

        {:error, :list_full} ->
          system_event(
            socket,
            "Auto-join list is full (20 channels). #{channel_name} was not added to auto-join."
          )

        {:error, :duplicate} ->
          socket
      end
    else
      socket
    end
  end

  defp maybe_auto_remove_from_autojoin(socket, channel_name) do
    session = socket.assigns.session

    if session.identified do
      case AutoJoinList.remove_entry(session.autojoin_list, channel_name) do
        {:ok, new_list} ->
          new_session = Session.set_autojoin_list(session, new_list)

          socket
          |> assign(session: new_session)
          |> maybe_persist_autojoin_list(new_session)

        {:error, :not_found} ->
          socket
      end
    else
      socket
    end
  end
end
