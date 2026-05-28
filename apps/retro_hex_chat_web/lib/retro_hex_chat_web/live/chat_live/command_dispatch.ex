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
      part_channel: 3,
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
    Service
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.GameInvite
  alias RetroHexChatWeb.ChatLive.Helpers.P2pInvite
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers
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

  defp handle_dispatch_result(socket, _session, {:ok, :part, channel_name, msg}) do
    socket
    |> part_channel(channel_name, msg)
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
    url = PathHelpers.activity_path(socket, "/solo/#{payload.token}")

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
    |> push_navigate(to: PathHelpers.connect_path(socket))
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
