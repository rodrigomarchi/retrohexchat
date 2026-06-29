defmodule RetroHexChatWeb.ChatLive.CoreEvents do
  @moduledoc """
  Handle core chat navigation and interaction events.

  Covers: send_input, switch_channel, switch_pm, switch_to_status,
  close_channel_tab, close_pm_tab, close_dialog, load_more,
  scroll_to_bottom, history_navigate, tab_complete, channel_dblclick,
  paste_lines, paste_cancel, paste_send.

  Attached as `attach_hook(:core_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      join_channel: 3,
      error_event: 2,
      load_channel_users: 2,
      load_channel_messages_with_pagination: 2,
      push_reconnect_state: 1,
      part_channel: 2,
      reset_activity: 1
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{Policy, Queries, Service, UnreadTracker}
  alias RetroHexChat.Commands.{Autocomplete, CommandSyntax, Parser, Registry}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive

  alias RetroHexChatWeb.ChatLive.Components.{
    DeleteConfirmDialog,
    MessageViewport,
    NickChangeDialog,
    PasteConfirmDialog
  }

  alias RetroHexChatWeb.ChatLive.Helpers.Messages, as: MessageHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.PM
  alias RetroHexChatWeb.Endpoint

  # -- send_input --

  def handle_event("input_changed", %{"input" => input}, socket) do
    {:halt, assign(socket, input: input, input_error: nil)}
  end

  def handle_event("toggle_action_mode", _params, socket) do
    if action_mode_available?(socket) do
      {:halt,
       assign(socket,
         action_mode: !socket.assigns.action_mode,
         notice_target: nil,
         input_error: nil
       )}
    else
      {:halt, socket}
    end
  end

  def handle_event("cancel_notice_mode", _params, socket) do
    {:halt, cancel_notice_mode(socket)}
  end

  def handle_event("send_input", %{"input" => ""}, socket) do
    handle_empty_input(socket)
  end

  def handle_event("send_input", %{"input" => input}, socket) do
    if socket.assigns.edit_mode_message_id do
      {:halt, submit_edit(socket, input)}
    else
      {:halt, dispatch_chat_input(socket, input)}
    end
  end

  # -- retry_message --

  def handle_event(
        "retry_message",
        %{"temp_id" => temp_id, "content" => content, "target" => target},
        socket
      ) do
    session = socket.assigns.session

    case Server.send_message(target, session.nickname, content) do
      :ok ->
        {:halt,
         socket
         |> MessageViewport.delete(temp_id)
         |> push_event("message_confirmed", %{temp_id: temp_id})}

      {:error, reason} ->
        {:halt, push_event(socket, "message_failed", %{temp_id: temp_id, reason: reason})}
    end
  end

  # -- switch_channel --

  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    session = Session.set_active_channel(socket.assigns.session, channel)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)
    flash = MapSet.delete(socket.assigns.flash_channels, channel)
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> assign(
       session: session,
       action_mode: false,
       notice_target: nil,
       input_error: nil,
       unread_counts: unread_counts,
       highlight_channels: highlight,
       flash_channels: flash,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> clear_search_on_switch()
     |> load_channel_users(channel)
     |> load_channel_messages_with_pagination(channel)
     |> push_reconnect_state()}
  end

  # -- channel_dblclick --

  def handle_event("channel_dblclick", %{"channel" => channel}, socket) do
    session = socket.assigns.session

    if channel in session.channels do
      # Already joined — switch to it
      new_session = Session.set_active_channel(session, channel)

      {:halt,
       socket
       |> assign(session: new_session, show_status_tab: false)
       |> load_channel_users(channel)
       |> load_channel_messages_with_pagination(channel)
       |> push_reconnect_state()}
    else
      # Not joined — join it
      {:halt, join_channel(socket, channel, session)}
    end
  end

  # -- switch_pm --

  def handle_event("switch_pm", %{"nickname" => nickname}, socket) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> assign(
       session: session,
       action_mode: false,
       notice_target: nil,
       input_error: nil,
       unread_counts: unread_counts,
       flash_channels: flash,
       current_topic: nil,
       current_modes: nil,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> clear_search_on_switch()
     |> PM.load_pm_messages_with_pagination(nickname)
     |> push_reconnect_state()}
  end

  # -- switch_to_status --

  def handle_event("switch_to_status", _params, socket) do
    {:halt,
     socket
     |> assign(
       show_status_tab: true,
       status_unread: false,
       action_mode: false,
       notice_target: nil,
       input_error: nil
     )
     |> clear_search_on_switch()}
  end

  # -- close_channel_tab --

  def handle_event("close_channel_tab", %{"channel" => channel}, socket) do
    {:halt, part_channel(socket, channel)}
  end

  # -- close_pm_tab --

  def handle_event("close_pm_tab", %{"nickname" => nickname}, socket) do
    old_session = socket.assigns.session
    topic = "pm:#{PM.pm_topic(old_session.nickname, nickname)}"
    pm_key = "pm:#{nickname}"
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, topic)

    session = Session.remove_pm_conversation(old_session, nickname)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, pm_key)
    flash = MapSet.delete(socket.assigns.flash_channels, pm_key)

    socket = assign(socket, session: session, unread_counts: unread_counts, flash_channels: flash)

    socket =
      if session.active_pm do
        PM.load_pm_messages_with_pagination(socket, session.active_pm)
      else
        if session.active_channel do
          socket
          |> load_channel_users(session.active_channel)
          |> load_channel_messages_with_pagination(session.active_channel)
        else
          socket
          |> assign(current_topic: nil, current_modes: nil)
          |> MessageViewport.reset([])
        end
      end

    {:halt, socket}
  end

  # -- close_dialog --

  def handle_event("close_dialog", _params, socket) do
    {:halt, assign(socket, cheatsheet_visible: false)}
  end

  # -- load_more --

  def handle_event("load_more", _params, socket) do
    %{loading_more: loading_more, has_more: has_more, oldest_message_id: oldest_id} =
      socket.assigns

    if loading_more or not has_more or is_nil(oldest_id) do
      {:halt, socket}
    else
      {:halt, do_load_more(socket, oldest_id)}
    end
  end

  # -- scroll_to_bottom --

  def handle_event("scroll_to_bottom", _params, socket) do
    {:halt, assign(socket, new_messages_indicator: false)}
  end

  # -- history_navigate --

  def handle_event("history_navigate", %{"direction" => direction}, socket) do
    history = socket.assigns.command_history
    index = socket.assigns[:history_index] || -1

    case direction do
      "up" ->
        new_index = min(index + 1, length(history) - 1)

        if new_index >= 0 and new_index < length(history) do
          {:halt, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:halt, socket}
        end

      "down" ->
        new_index = max(index - 1, -1)

        if new_index >= 0 do
          {:halt, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:halt, assign(socket, input: "", history_index: -1)}
        end

      _ ->
        {:halt, socket}
    end
  end

  # -- tab_complete --

  def handle_event("tab_complete", %{"partial" => partial, "is_start" => is_start}, socket) do
    users = socket.assigns.channel_users
    own_nick = socket.assigns.session.nickname

    matches =
      Autocomplete.tab_complete_matches(partial, users, own_nick)

    case matches do
      [] ->
        {:halt, socket}

      _ ->
        {:halt, push_event(socket, "tab_matches", %{matches: matches, is_start: is_start})}
    end
  end

  def handle_event("tab_complete", %{"partial" => partial}, socket) do
    handle_event("tab_complete", %{"partial" => partial, "is_start" => true}, socket)
  end

  # The clipboard JS hook pushes the pasted lines to the parent; we filter out
  # blank lines and forward the rest to the `PasteConfirmDialog` LiveComponent,
  # which owns the queue and the Send/Cancel buttons.
  def handle_event("paste_lines", %{"lines" => lines}, socket) do
    filtered = Enum.filter(lines, &(String.trim(&1) != ""))
    count = length(filtered)

    send_update(PasteConfirmDialog,
      id: PasteConfirmDialog.id(),
      action: {:set, filtered, count > 50, count > 100}
    )

    {:halt, socket}
  end

  # -- syntax_tooltip_query --

  def handle_event("syntax_tooltip_query", %{"command" => command, "args" => args}, socket) do
    case Registry.get_syntax(command) do
      nil ->
        {:halt, assign(socket, syntax_tooltip: nil)}

      %CommandSyntax{} = syntax ->
        current_index = CommandSyntax.compute_current_param_index(syntax.parameters, args)
        payload = CommandSyntax.to_client_payload(syntax)

        tooltip_data =
          Map.merge(payload, %{
            current_param_index: current_index,
            context_message: build_context_message(syntax, args, current_index)
          })

        {:halt, assign(socket, syntax_tooltip: tooltip_data)}
    end
  end

  # -- syntax_tooltip_dismiss --

  def handle_event("syntax_tooltip_dismiss", _params, socket) do
    {:halt, assign(socket, syntax_tooltip: nil)}
  end

  # -- reply_to_message --

  def handle_event("reply_to_message", %{"message_id" => msg_id_str}, socket) do
    with {:ok, msg_id} <- parse_message_id(msg_id_str),
         %{} = message <- get_reply_parent(socket.assigns.session, msg_id) do
      {:halt, assign(socket, reply_to: build_reply_to(message))}
    else
      _ -> {:halt, socket}
    end
  end

  # -- cancel_reply --

  def handle_event("cancel_reply", _params, socket) do
    {:halt, assign(socket, reply_to: nil)}
  end

  # -- scroll_to_reply_parent --

  def handle_event("scroll_to_reply_parent", %{"parent_id" => parent_id}, socket) do
    {:halt, push_event(socket, "scroll_to_message", %{message_id: parent_id})}
  end

  def handle_event("scroll_to_message_missing", _params, socket) do
    {:halt,
     MessageHelpers.system_event(
       socket,
       dgettext(
         "chat",
         "Reply parent message is not currently loaded. Scroll up to load older history, then try again."
       )
     )}
  end

  # -- edit_last_message --

  def handle_event("edit_last_message", _params, socket) do
    session = socket.assigns.session
    nickname = session.nickname

    last_message =
      if session.active_pm do
        Queries.last_own_pm(nickname, session.active_pm)
      else
        session.active_channel && Queries.last_own_message(nickname, session.active_channel)
      end

    if last_message && editable_message?(last_message, session, nickname) do
      msg_id = last_message.id

      {:halt,
       socket
       |> assign(
         edit_mode_message_id: msg_id,
         edit_original_input: socket.assigns.input,
         input: last_message.content
       )
       |> push_event("enter_edit_mode", %{message_id: msg_id, content: last_message.content})}
    else
      {:halt, socket}
    end
  end

  # -- cancel_edit --

  def handle_event("cancel_edit", _params, socket) do
    {:halt, exit_edit_mode(socket)}
  end

  # -- ctx_chat_delete --

  def handle_event("ctx_chat_delete", %{"message_id" => msg_id_str}, socket) do
    case parse_message_id(msg_id_str) do
      {:ok, msg_id} ->
        {:halt, open_delete_confirm(socket, msg_id)}

      :error ->
        case parse_pending_message_id(msg_id_str) do
          {:ok, temp_id} -> {:halt, MessageViewport.delete(socket, temp_id)}
          :error -> {:halt, socket}
        end
    end
  end

  # -- confirm_delete --

  def handle_event("confirm_delete", %{"message_id" => msg_id}, socket) do
    session = socket.assigns.session

    result =
      if session.active_pm do
        Service.delete_private_message(msg_id, session.nickname)
      else
        Service.delete_message(msg_id, session.nickname)
      end

    socket = close_delete_confirm(socket)

    case result do
      {:ok, _} -> {:halt, socket}
      {:error, reason} -> {:halt, error_event(socket, reason)}
    end
  end

  def handle_event("confirm_delete", _params, socket), do: {:halt, socket}

  # -- cancel_delete --

  def handle_event("cancel_delete", _params, socket) do
    {:halt, close_delete_confirm(socket)}
  end

  # -- confirm_nick_change --
  #
  # The nick-change dialog is a stateful LiveComponent (NickChangeDialog); it owns
  # its draft and handles password keyup + cancel locally. Confirm bubbles here
  # carrying `target`/`registered` (via JS.push) and `password` (phx-value),
  # because the NickServ identify + token redirect must run on this LiveView.
  def handle_event("confirm_nick_change", params, socket) do
    {:halt, handle_nick_change_confirm(socket, params)}
  end

  # -- Catch-all: pass unhandled events to the next hook --

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp handle_empty_input(socket) do
    cond do
      socket.assigns.edit_mode_message_id ->
        msg_id = socket.assigns.edit_mode_message_id

        socket
        |> exit_edit_mode()
        |> open_delete_confirm(msg_id)
        |> then(&{:halt, &1})

      notice_mode?(socket) ->
        {:halt, assign(socket, input_error: dgettext("chat", "Notice message cannot be empty"))}

      socket.assigns.action_mode ->
        {:halt, assign(socket, input_error: dgettext("chat", "Action message cannot be empty"))}

      true ->
        {:halt, socket}
    end
  end

  defp dispatch_chat_input(socket, input) do
    session = socket.assigns.session
    submitted_input = input_for_mode(socket, input)
    history = [submitted_input | socket.assigns.command_history] |> Enum.take(50)

    socket
    |> dispatch_parsed_input(session, Parser.parse(submitted_input))
    |> reset_activity()
    |> clear_sent_input(history)
  end

  defp dispatch_parsed_input(socket, session, {:message, text}) do
    new_session = Session.set_last_message_at(session, DateTime.utc_now())

    socket
    |> assign(session: new_session)
    |> ChatLive.CommandDispatch.send_plain_message(new_session, text)
    |> push_event("tip_trigger", %{tip: "first_message"})
  end

  defp dispatch_parsed_input(socket, session, {:command, name, args}) do
    ChatLive.CommandDispatch.dispatch_command(socket, session, name, args)
  end

  defp clear_sent_input(socket, history) do
    socket
    |> assign(
      input: "",
      action_mode: false,
      notice_target: nil,
      input_error: nil,
      command_history: history,
      history_index: -1,
      autocomplete_visible: false,
      autocomplete_results: [],
      autocomplete_filter: "",
      autocomplete_selected: 0,
      syntax_tooltip: nil
    )
    |> push_event("clear_input", %{})
  end

  defp cancel_notice_mode(socket) do
    socket
    |> assign(notice_target: nil, input: "", input_error: nil)
    |> push_event("clear_input", %{})
  end

  defp input_for_mode(socket, input) do
    cond do
      notice_mode?(socket) -> "/notice #{socket.assigns.notice_target} #{input}"
      socket.assigns.action_mode -> "/me #{input}"
      true -> input
    end
  end

  defp notice_mode?(socket) do
    is_binary(socket.assigns.notice_target) and socket.assigns.notice_target != ""
  end

  defp action_mode_available?(socket) do
    session = socket.assigns.session
    !socket.assigns.show_status_tab and session.active_pm == nil and session.active_channel != nil
  end

  defp parse_message_id(id) when is_integer(id), do: {:ok, id}

  defp parse_message_id("chat_messages-" <> id), do: parse_message_id(id)

  defp parse_message_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_message_id(_id), do: :error

  defp parse_pending_message_id("chat_messages-" <> id), do: parse_pending_message_id(id)
  defp parse_pending_message_id("pending_" <> _ = id), do: {:ok, id}
  defp parse_pending_message_id(_id), do: :error

  defp get_reply_parent(session, msg_id) do
    if session.active_pm do
      Queries.get_private_message(msg_id)
    else
      Queries.get_message(msg_id)
    end
  end

  defp build_reply_to(message) do
    author = Map.get(message, :author_nickname) || Map.get(message, :sender_nickname, "?")

    %{
      id: message.id,
      author: author,
      preview: String.slice(message.content, 0, 100)
    }
  end

  defp editable_message?(message, %{active_pm: active_pm}, nickname) when not is_nil(active_pm) do
    message
    |> Map.put(:author_nickname, message.sender_nickname)
    |> Policy.can_edit?(nickname)
    |> Kernel.==(:ok)
  end

  defp editable_message?(message, _session, nickname) do
    Policy.can_edit?(message, nickname) == :ok
  end

  defp exit_edit_mode(socket) do
    msg_id = socket.assigns.edit_mode_message_id
    original = socket.assigns.edit_original_input || ""

    socket
    |> assign(
      edit_mode_message_id: nil,
      edit_original_input: nil,
      input: original
    )
    |> push_event("exit_edit_mode", %{message_id: msg_id})
    |> push_event("set_input", %{value: original})
  end

  defp submit_edit(socket, new_content) do
    msg_id = socket.assigns.edit_mode_message_id
    session = socket.assigns.session

    result =
      if session.active_pm do
        Service.edit_private_message(msg_id, session.nickname, new_content)
      else
        Service.edit_message(msg_id, session.nickname, new_content)
      end

    socket = exit_edit_mode(socket)

    case result do
      {:ok, _} ->
        assign(socket, input: "")
        |> push_event("set_input", %{value: ""})

      {:error, reason} ->
        error_event(socket, reason)
    end
  end

  defp do_load_more(socket, oldest_id) do
    session = socket.assigns.session

    cond do
      session.active_pm ->
        older_messages =
          Queries.list_private_messages(session.nickname, session.active_pm,
            limit: 50,
            before_id: oldest_id
          )

        PM.prepend_older_pm_messages(assign(socket, loading_more: true), older_messages)

      session.active_channel ->
        channel = session.active_channel
        older_messages = Queries.list_messages(channel, limit: 50, before_id: oldest_id)
        prepend_older_messages(assign(socket, loading_more: true), older_messages)

      true ->
        socket
    end
  end

  defp prepend_older_messages(socket, []) do
    assign(socket, loading_more: false, has_more: false)
  end

  defp prepend_older_messages(socket, older_messages) do
    channel = socket.assigns.session.active_channel
    loaded_count = (socket.assigns[:loaded_message_count] || 50) + length(older_messages)

    raw_messages = Queries.list_messages(channel, limit: loaded_count)
    new_oldest = List.last(raw_messages)

    stream_items =
      raw_messages
      |> MessageHelpers.visible_channel_messages(socket.assigns.session.ignore_list)
      |> Enum.reverse()
      |> Enum.map(&message_to_stream_item/1)

    socket
    |> assign(
      loading_more: false,
      oldest_message_id: new_oldest.id,
      has_more: length(older_messages) == 50,
      loaded_message_count: length(raw_messages)
    )
    |> push_event("prepend_start", %{})
    |> MessageViewport.reset(stream_items)
  end

  defp message_to_stream_item(msg) do
    %{
      id: msg.id,
      author: msg.author_nickname,
      content: msg.content,
      type: String.to_existing_atom(msg.type),
      timestamp: msg.inserted_at
    }
    |> maybe_add_field(msg, :reply_to_id)
    |> maybe_add_field(msg, :reply_to_author)
    |> maybe_add_field(msg, :reply_to_preview)
    |> maybe_add_field(msg, :edited_at)
    |> maybe_add_field(msg, :deleted_at)
  end

  defp maybe_add_field(map, source, key) do
    case Map.get(source, key) do
      nil -> map
      value -> Map.put(map, key, value)
    end
  end

  defp build_context_message(%CommandSyntax{} = syntax, args, current_index) do
    trimmed = String.trim(args)

    cond do
      trimmed == "" or current_index == nil ->
        nil

      syntax.sub_options not in [nil, []] ->
        build_sub_option_context(syntax.sub_options, trimmed)

      true ->
        case Enum.at(syntax.parameters, current_index) do
          nil -> nil
          param -> dgettext("chat", "Next: %{parameter}", parameter: param.name)
        end
    end
  end

  defp build_sub_option_context(sub_options, trimmed) do
    first_arg = trimmed |> String.split(~r/\s+/) |> hd()

    case Enum.find(sub_options, &String.starts_with?(first_arg, &1.flag)) do
      nil ->
        nil

      opt ->
        dgettext("chat", "You are setting: %{flag} (%{label})", flag: opt.flag, label: opt.label)
    end
  end

  defp handle_nick_change_confirm(socket, params) do
    target = params["target"] || ""
    registered = params["registered"] in [true, "true"]
    password = params["password"] || ""

    cond do
      nick_in_use?(target, socket.assigns.session.nickname) ->
        close_nick_change_dialog()

        error_event(
          socket,
          dgettext("chat", "Nickname %{nickname} is already in use", nickname: target)
        )

      registered ->
        case NickServ.identify(target, password) do
          {:ok, _} ->
            nick_change_redirect(socket, target,
              token: Phoenix.Token.sign(Endpoint, "nickserv_identify", target)
            )

          {:error, _} ->
            send_update(NickChangeDialog,
              id: NickChangeDialog.id(),
              action: {:password_error, dgettext("chat", "Incorrect password")}
            )

            socket
        end

      true ->
        nick_change_redirect(socket, target, token: nil)
    end
  end

  defp nick_change_redirect(socket, target, token: token) do
    close_nick_change_dialog()

    socket
    |> assign(
      nick_change_target: target,
      nick_change_token: token,
      quit_reason: dgettext("chat", "Changing nickname")
    )
    |> push_event("submit_nick_change", %{
      nickname: target,
      previous_nickname: socket.assigns.session.nickname
    })
  end

  defp close_nick_change_dialog do
    send_update(NickChangeDialog, id: NickChangeDialog.id(), action: :close)
  end

  defp nick_in_use?(nickname, current_nickname) do
    String.downcase(nickname) != String.downcase(current_nickname) and
      Tracker.online?("presence:global", nickname)
  end

  defp open_delete_confirm(socket, message_id) do
    send_update(DeleteConfirmDialog, id: DeleteConfirmDialog.id(), action: {:open, message_id})
    socket
  end

  defp close_delete_confirm(socket) do
    send_update(DeleteConfirmDialog, id: DeleteConfirmDialog.id(), action: :close)
    socket
  end

  defp clear_search_on_switch(socket) do
    if socket.assigns.search_visible do
      ChatLive.SearchEvents.close(socket)
    else
      socket
    end
  end
end
