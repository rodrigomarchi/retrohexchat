defmodule RetroHexChatWeb.ChatLive.CommandDispatch do
  @moduledoc """
  Command dispatch: alias expansion, command execution, and result handling.

  Public functions called by ChatLive.handle_event("send_input") and timer handlers.
  NOT a hook module — these are plain public functions.
  """

  import Phoenix.Component, only: [assign: 2]

  import Phoenix.LiveView,
    only: [push_event: 3, push_navigate: 2, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

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
      clear_reconnect_state: 1,
      maybe_persist_autojoin_list: 2
    ]

  alias RetroHexChat.Accounts.{ServerRoles, Session}
  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Observability

  alias RetroHexChat.Chat.{
    AliasExpander,
    AliasList,
    AutoJoinList,
    Service
  }

  alias RetroHexChat.Channels.Roles
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.{Dispatcher, Parser, Registry}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.NickChangeDialog
  alias RetroHexChatWeb.ChatLive.Helpers.LobbyInvite
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
    {socket, _result} = dispatch_command_with_result(socket, session, name, args, alias_depth)
    socket
  end

  @spec dispatch_command_with_result(
          Phoenix.LiveView.Socket.t(),
          Session.t(),
          String.t(),
          [String.t()],
          non_neg_integer()
        ) :: {Phoenix.LiveView.Socket.t(), term()}
  def dispatch_command_with_result(socket, session, name, args, alias_depth \\ 0) do
    Observability.span(
      [:retro_hex_chat, :commands, :dispatch],
      command_metadata(name, args, alias_depth),
      fn -> do_dispatch_command_with_result(socket, session, name, args, alias_depth) end,
      &classify_dispatched_command/1
    )
  end

  defp do_dispatch_command_with_result(socket, session, name, args, alias_depth) do
    context = build_context(session, socket.assigns.show_status_tab)

    case try_alias_expansion(session, name, args, context, alias_depth) do
      {:expanded, expanded_input} ->
        dispatch_expanded_command(socket, session, expanded_input, alias_depth)

      :not_alias ->
        result = Dispatcher.dispatch(name, args, context)
        {handle_dispatch_result(socket, session, result), result}

      {:error, msg} ->
        result = {:error, msg}
        {error_event(socket, msg), result}
    end
  end

  defp command_metadata(name, args, alias_depth) do
    safe_name = safe_command_name(name)

    %{
      command: if(Registry.known?(safe_name), do: safe_name, else: "unknown"),
      command_known: Registry.known?(safe_name),
      argument_count: length(args),
      alias_depth: alias_depth
    }
  end

  defp classify_dispatched_command({_socket, {:error, _reason}}),
    do: %{result: "error", reason: "command_error"}

  defp classify_dispatched_command({_socket, _result}), do: %{result: "ok"}

  defp safe_command_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.slice(0, 40)
  end

  defp safe_command_name(_name), do: "unknown"

  @spec send_plain_message(
          Phoenix.LiveView.Socket.t(),
          Session.t(),
          String.t(),
          map() | nil,
          String.t(),
          [integer()]
        ) ::
          Phoenix.LiveView.Socket.t()
  def send_plain_message(
        socket,
        session,
        text,
        reply_to \\ nil,
        content_format \\ "irc",
        attachment_ids \\ []
      ) do
    cond do
      socket.assigns.show_status_tab ->
        push_status_message(
          socket,
          dgettext("chat", "Cannot send text to status window. Use /commands."),
          :error
        )

      session.active_pm ->
        send_pm_message(socket, session, text, reply_to, content_format, attachment_ids)

      session.active_channel ->
        send_channel_message(socket, session, text, reply_to, content_format, attachment_ids)

      true ->
        socket
    end
  end

  defp build_context(session, show_status_tab) do
    roles = Roles.held_by(session.channels, session.nickname)

    %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      show_status_tab: show_status_tab,
      channels: session.channels,
      identified: session.identified,
      owner_in: roles.owner,
      operator_in: roles.operator,
      half_operator_in: roles.half_operator,
      is_admin: ServerRoles.admin?(session.nickname, session.identified),
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }
  end

  defp dispatch_expanded_command(socket, session, expanded_input, alias_depth) do
    case Parser.parse(expanded_input) do
      {:command, new_name, new_args} ->
        dispatch_command_with_result(socket, session, new_name, new_args, alias_depth + 1)

      {:message, text} ->
        {send_plain_message(socket, session, text), {:ok, :message_sent}}
    end
  end

  # ── Private: message sending ─────────────────────────────

  defp send_pm_message(socket, session, text, reply_to, content_format, attachment_ids) do
    if GlobalMutes.muted?(session.nickname) do
      error_event(socket, dgettext("chat", "You are muted by an administrator"))
    else
      do_send_pm_message(socket, session, text, reply_to, content_format, attachment_ids)
    end
  end

  defp do_send_pm_message(socket, session, text, reply_to, content_format, attachment_ids) do
    opts =
      [content_format: content_format]
      |> maybe_put_reply_to(reply_to)
      |> Keyword.put(:attachment_ids, attachment_ids)

    target = session.active_pm

    case Service.send_private_message(session.nickname, target, text, "message", opts) do
      {:ok, _pm} ->
        socket

      {:error, reason} ->
        error_event(socket, reason)
    end
  end

  defp send_channel_message(socket, session, text, reply_to, content_format, attachment_ids) do
    if GlobalMutes.muted?(session.nickname) do
      error_event(socket, dgettext("chat", "You are muted by an administrator"))
    else
      do_send_channel_message(socket, session, text, reply_to, content_format, attachment_ids)
    end
  end

  # The optimistic row is keyed by the persisted message id (returned by
  # `send_message`), the same id the PubSub echo carries. The echo therefore
  # updates this exact row in place — it neither appends a duplicate nor moves
  # the row to the tail, so rapid sends (paste) keep their order. `pending`
  # status is stripped client-side by `message_confirmed`; the echo also clears
  # it when it re-renders the row with the decorated payload.
  defp do_send_channel_message(socket, session, text, reply_to, content_format, attachment_ids) do
    opts =
      [content_format: content_format]
      |> maybe_put_reply_to(reply_to)
      |> Keyword.put(:attachment_ids, attachment_ids)

    case Server.send_message(session.active_channel, session.nickname, text, opts) do
      {:ok, id} ->
        pending_msg =
          build_pending_msg(
            id,
            session.nickname,
            text,
            session.active_channel,
            reply_to,
            content_format
          )

        socket
        |> MessageViewport.insert(pending_msg)
        |> push_event("message_confirmed", %{temp_id: id})

      {:error, reason} ->
        temp_id = "pending_#{System.unique_integer([:positive])}"

        failed_msg =
          build_pending_msg(
            temp_id,
            session.nickname,
            text,
            session.active_channel,
            reply_to,
            content_format
          )
          |> Map.put(:status, :failed)

        socket
        |> MessageViewport.insert(failed_msg)
        |> push_event("message_failed", %{temp_id: temp_id, reason: reason})
        |> error_event(reason)
    end
  end

  defp build_pending_msg(temp_id, nickname, text, channel, nil, content_format) do
    %{
      id: temp_id,
      author: nickname,
      content: text,
      content_format: content_format,
      type: :message,
      timestamp: DateTime.utc_now(),
      status: :pending,
      target: channel
    }
  end

  defp build_pending_msg(temp_id, nickname, text, channel, reply_to, content_format) do
    %{
      id: temp_id,
      author: nickname,
      content: text,
      content_format: content_format,
      type: :message,
      timestamp: DateTime.utc_now(),
      status: :pending,
      target: channel,
      reply_to_id: reply_to.id,
      reply_to_author: reply_to.author,
      reply_to_preview: reply_to.preview
    }
  end

  defp maybe_put_reply_to(opts, nil), do: opts
  defp maybe_put_reply_to(opts, reply_to), do: Keyword.put(opts, :reply_to_id, reply_to.id)

  # ── Private: alias expansion ──────────────────────────────

  defp try_alias_expansion(session, name, args, context, alias_depth) do
    if alias_depth >= 5 do
      {:error, dgettext("chat", "Alias recursion limit reached (max 5 levels)")}
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
    if nick_in_use?(new_nick, socket.assigns.session.nickname) do
      error_event(
        socket,
        dgettext("chat", "Nickname %{nickname} is already in use", nickname: new_nick)
      )
    else
      registered = NickServ.registered?(new_nick)

      send_update(NickChangeDialog,
        id: NickChangeDialog.id(),
        action: {:open, %{target_nick: new_nick, registered: registered}}
      )

      socket
    end
  end

  defp handle_dispatch_result(socket, _session, {:ok, :quit, reason}),
    do: handle_quit(socket, reason)

  defp handle_dispatch_result(socket, _session, {:ok, :ui_action, action, payload})
       when action in [:show_help, :show_command_help] do
    socket
    |> push_event("tip_trigger", %{tip: "help_used"})
    |> UiActionHandlers.handle_ui_action(action, payload)
  end

  defp handle_dispatch_result(socket, session, {:ok, :ui_action, :lobby_invite, payload}),
    do: LobbyInvite.handle_lobby_invite(socket, session, payload)

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
          {:ok, _id} -> socket
          {:error, reason} -> error_event(socket, reason)
        end

      true ->
        socket
    end
  end

  # ── Private: quit ─────────────────────────────────────────

  defp handle_quit(socket, reason) do
    session = socket.assigns.session
    quit_reason = reason || dgettext("chat", "Leaving")
    cleanup_channels(session, quit_reason)

    socket
    |> assign(quit_reason: quit_reason)
    |> clear_reconnect_state()
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

  defp detect_service_author("[ChanServ]" <> _), do: "ChanServ"
  defp detect_service_author("[NickServ]" <> _), do: "NickServ"
  defp detect_service_author(_), do: dgettext("chat", "Service")

  defp nick_in_use?(nickname, current_nickname) do
    String.downcase(nickname) != String.downcase(current_nickname) and
      Tracker.online?("presence:global", nickname)
  end

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
            dgettext(
              "chat",
              "Auto-join list is full (20 channels). %{channel} was not added to auto-join.",
              channel: channel_name
            )
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
