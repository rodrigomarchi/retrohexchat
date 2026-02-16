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
  import Phoenix.LiveView, only: [stream: 4, stream_insert: 3, stream_insert: 4, push_event: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      join_channel: 3,
      error_message: 1,
      load_channel_users: 2,
      load_channel_messages_with_pagination: 2,
      push_reconnect_state: 1,
      part_channel: 2,
      reset_activity: 1
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{Policy, Queries, Service, UnreadTracker, UserPreferences}
  alias RetroHexChat.Commands.{Autocomplete, CommandSyntax, Parser, Registry}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.Endpoint

  # -- send_input --

  def handle_event("send_input", %{"input" => ""}, socket) do
    if socket.assigns.edit_mode_message_id do
      # Empty edit = treat as delete (show confirmation dialog)
      msg_id = socket.assigns.edit_mode_message_id

      socket
      |> exit_edit_mode()
      |> assign(delete_confirm: %{message_id: msg_id})
      |> then(&{:halt, &1})
    else
      {:halt, socket}
    end
  end

  def handle_event("send_input", %{"input" => input}, socket) do
    if socket.assigns.edit_mode_message_id do
      {:halt, submit_edit(socket, input)}
    else
      session = socket.assigns.session
      history = [input | socket.assigns.command_history] |> Enum.take(50)

      case Parser.parse(input) do
        {:message, text} ->
          new_session = Session.set_last_message_at(session, DateTime.utc_now())

          socket =
            socket
            |> assign(session: new_session)
            |> ChatLive.CommandDispatch.send_plain_message(new_session, text)
            |> push_event("tip_trigger", %{tip: "first_message"})
            |> reset_activity()

          {:halt,
           socket
           |> assign(
             input: "",
             command_history: history,
             history_index: -1,
             autocomplete_visible: false,
             autocomplete_results: [],
             autocomplete_filter: "",
             autocomplete_selected: 0,
             syntax_tooltip: nil
           )
           |> push_event("clear_input", %{})}

        {:command, name, args} ->
          socket =
            socket
            |> ChatLive.CommandDispatch.dispatch_command(session, name, args)
            |> reset_activity()

          {:halt,
           socket
           |> assign(
             input: "",
             command_history: history,
             history_index: -1,
             autocomplete_visible: false,
             autocomplete_results: [],
             autocomplete_filter: "",
             autocomplete_selected: 0,
             syntax_tooltip: nil
           )
           |> push_event("clear_input", %{})}
      end
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
        {:halt, push_event(socket, "message_confirmed", %{temp_id: temp_id})}

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
    messages = load_pm_messages(session.nickname, nickname)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> assign(
       session: session,
       unread_counts: unread_counts,
       flash_channels: flash,
       current_topic: nil,
       current_modes: nil,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> clear_search_on_switch()
     |> stream(:chat_messages, messages, reset: true)
     |> push_reconnect_state()}
  end

  # -- switch_to_status --

  def handle_event("switch_to_status", _params, socket) do
    {:halt, assign(socket, show_status_tab: true)}
  end

  # -- close_channel_tab --

  def handle_event("close_channel_tab", %{"channel" => channel}, socket) do
    {:halt, part_channel(socket, channel)}
  end

  # -- close_pm_tab --

  def handle_event("close_pm_tab", %{"nickname" => nickname}, socket) do
    session = Session.remove_pm_conversation(socket.assigns.session, nickname)
    socket = assign(socket, session: session)

    socket =
      if session.active_pm do
        messages = load_pm_messages(session.nickname, session.active_pm)
        stream(socket, :chat_messages, messages, reset: true)
      else
        if session.active_channel do
          socket
          |> load_channel_users(session.active_channel)
          |> load_channel_messages_with_pagination(session.active_channel)
        else
          socket
          |> assign(current_topic: nil, current_modes: nil)
          |> stream(:chat_messages, [], reset: true)
        end
      end

    {:halt, socket}
  end

  # -- close_dialog --

  def handle_event("close_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_about: false,
       show_whois: false,
       whois_target: nil,
       cheatsheet_visible: false
     )}
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

  # -- paste_lines / paste_cancel / paste_send --

  def handle_event("paste_lines", %{"lines" => lines}, socket) do
    filtered = Enum.filter(lines, &(String.trim(&1) != ""))
    count = length(filtered)

    {:halt,
     assign(socket,
       paste_lines: filtered,
       paste_flood_warning: count > 50,
       paste_send_disabled: count > 100
     )}
  end

  def handle_event("paste_cancel", _params, socket) do
    {:halt, assign(socket, paste_lines: nil)}
  end

  def handle_event("paste_send", _params, socket) do
    lines = socket.assigns.paste_lines || []
    Process.send_after(self(), {:paste_next, lines}, 0)
    {:halt, assign(socket, paste_lines: nil)}
  end

  # -- syntax_tooltip_query --

  def handle_event("syntax_tooltip_query", %{"command" => command, "args" => args}, socket) do
    help_level = UserPreferences.get_command_help_level(socket.assigns.session.user_preferences)

    if help_level == :off do
      {:halt, assign(socket, syntax_tooltip: nil)}
    else
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
  end

  # -- syntax_tooltip_dismiss --

  def handle_event("syntax_tooltip_dismiss", _params, socket) do
    {:halt, assign(socket, syntax_tooltip: nil)}
  end

  # -- reply_to_message --

  def handle_event("reply_to_message", %{"message_id" => msg_id_str}, socket) do
    msg_id = String.to_integer(msg_id_str)
    session = socket.assigns.session

    message =
      if session.active_pm do
        Queries.get_private_message(msg_id)
      else
        Queries.get_message(msg_id)
      end

    if message do
      author = Map.get(message, :author_nickname) || Map.get(message, :sender_nickname, "?")
      preview = String.slice(message.content, 0, 100)

      reply_to = %{
        id: message.id,
        author: author,
        preview: preview
      }

      {:halt, assign(socket, reply_to: reply_to)}
    else
      {:halt, socket}
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

    if last_message && Policy.can_edit?(last_message, nickname) == :ok do
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
    msg_id = String.to_integer(msg_id_str)
    {:halt, assign(socket, delete_confirm: %{message_id: msg_id})}
  end

  # -- confirm_delete --

  def handle_event("confirm_delete", _params, socket) do
    case socket.assigns.delete_confirm do
      %{message_id: msg_id} ->
        session = socket.assigns.session

        result =
          if session.active_pm do
            Service.delete_private_message(msg_id, session.nickname)
          else
            Service.delete_message(msg_id, session.nickname)
          end

        socket = assign(socket, delete_confirm: nil)

        case result do
          {:ok, _} ->
            {:halt, socket}

          {:error, reason} ->
            {:halt,
             socket
             |> stream_insert(:chat_messages, error_message(reason))}
        end

      nil ->
        {:halt, socket}
    end
  end

  # -- cancel_delete --

  def handle_event("cancel_delete", _params, socket) do
    {:halt, assign(socket, delete_confirm: nil)}
  end

  # -- confirm_nick_change --

  def handle_event("confirm_nick_change", params, socket) do
    dialog = socket.assigns.nick_change_dialog

    if dialog do
      {:halt, handle_nick_change_confirm(socket, dialog, params)}
    else
      {:halt, socket}
    end
  end

  # -- cancel_nick_change --

  def handle_event("cancel_nick_change", _params, socket) do
    {:halt, assign(socket, nick_change_dialog: nil)}
  end

  # -- update_nick_change_password --

  def handle_event("update_nick_change_password", %{"value" => value}, socket) do
    case socket.assigns.nick_change_dialog do
      %{} = dialog ->
        {:halt, assign(socket, nick_change_dialog: %{dialog | password: value})}

      nil ->
        {:halt, socket}
    end
  end

  # -- Catch-all: pass unhandled events to the next hook --

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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
        stream_insert(socket, :chat_messages, error_message(reason))
    end
  end

  defp load_pm_messages(my_nick, other_nick) do
    Queries.list_private_messages(my_nick, other_nick, limit: 50)
    |> Enum.reverse()
    |> Enum.map(&pm_to_stream_item/1)
  end

  defp pm_to_stream_item(pm) do
    base = %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:timestamp, :inserted_at])
    }

    base
    |> maybe_add_field(pm, :reply_to_id)
    |> maybe_add_field(pm, :reply_to_author)
    |> maybe_add_field(pm, :reply_to_preview)
    |> maybe_add_field(pm, :edited_at)
    |> maybe_add_field(pm, :deleted_at)
  end

  defp pm_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp pm_resolve_type(%{type: type}) when is_atom(type), do: type
  defp pm_resolve_type(%{type: type}) when is_binary(type), do: String.to_existing_atom(type)
  defp pm_resolve_type(_), do: :message

  defp do_load_more(socket, oldest_id) do
    channel = socket.assigns.session.active_channel

    if channel do
      older_messages = Queries.list_messages(channel, limit: 50, before_id: oldest_id)
      prepend_older_messages(assign(socket, loading_more: true), older_messages)
    else
      socket
    end
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
          param -> "Próximo: #{param.name}"
        end
    end
  end

  defp build_sub_option_context(sub_options, trimmed) do
    first_arg = trimmed |> String.split(~r/\s+/) |> hd()

    case Enum.find(sub_options, &String.starts_with?(first_arg, &1.flag)) do
      nil -> nil
      opt -> "Você está definindo: #{opt.flag} (#{opt.label})"
    end
  end

  defp handle_nick_change_confirm(socket, dialog, params) do
    target = dialog.target_nick
    password = params["password"] || ""

    if dialog.registered do
      case NickServ.identify(target, password) do
        {:ok, _} ->
          token = Phoenix.Token.sign(Endpoint, "nickserv_identify", target)

          socket
          |> assign(nick_change_dialog: nil, nick_change_target: target, nick_change_token: token)
          |> push_event("submit_nick_change", %{})

        {:error, _} ->
          assign(socket,
            nick_change_dialog: %{dialog | password_error: "Senha incorreta", password: ""}
          )
      end
    else
      socket
      |> assign(nick_change_dialog: nil, nick_change_target: target, nick_change_token: nil)
      |> push_event("submit_nick_change", %{})
    end
  end

  defp clear_search_on_switch(socket) do
    if socket.assigns.search_visible do
      socket
      |> assign(
        search_visible: false,
        search_last_query: socket.assigns.search_query,
        search_query: "",
        search_results: [],
        search_result_count: 0,
        search_history_count: 0,
        search_current_index: 0,
        search_error: nil
      )
      |> push_event("search_clear_highlights", %{})
    else
      socket
    end
  end
end
