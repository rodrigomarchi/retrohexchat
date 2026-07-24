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
  alias RetroHexChat.Commands.Parser
  alias RetroHexChat.Observability
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive

  alias RetroHexChatWeb.ChatLive.Components.{
    Composer,
    DeleteConfirmDialog,
    MessageViewport,
    NickChangeDialog,
    PasteConfirmDialog
  }

  alias RetroHexChatWeb.ChatLive.Helpers.Messages, as: MessageHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.PM
  alias RetroHexChatWeb.Endpoint

  # The composer input form (input_changed / send_input / toggle_action_mode /
  # cancel_notice_mode) is owned by the Composer LiveComponent (phx-target).
  # On submit it bubbles a semantic command back here via the public
  # dispatch_composer_input/3, submit_composer_edit/2, empty_composer_edit/1
  # below, which run the privileged Parser/CommandDispatch/Service work.

  # -- retry_message --

  def handle_event(
        "retry_message",
        %{"temp_id" => temp_id, "content" => content, "target" => target},
        socket
      ) do
    session = socket.assigns.session

    case Server.send_message(target, session.nickname, content) do
      {:ok, _id} ->
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
       notice_active: false,
       unread_counts: unread_counts,
       highlight_channels: highlight,
       flash_channels: flash,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> reset_composer_modes()
     |> clear_search_on_switch()
     |> close_mobile_navigation_panels()
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
    PM.ensure_pm_subscription(socket.assigns.session.nickname, nickname)

    session =
      socket.assigns.session
      |> Session.add_pm_conversation(nickname)
      |> Session.set_active_pm(nickname)

    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> PM.open_pm_tab(nickname)
     |> assign(
       session: session,
       notice_active: false,
       unread_counts: unread_counts,
       flash_channels: flash,
       current_topic: nil,
       current_modes: nil,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> reset_composer_modes()
     |> clear_search_on_switch()
     |> close_mobile_navigation_panels()
     |> PM.load_pm_messages_with_pagination(nickname)
     |> push_reconnect_state()}
  end

  # -- switch_to_status --

  def handle_event("switch_to_status", _params, socket) do
    {:halt,
     socket
     |> assign(show_status_tab: true, status_unread: false, notice_active: false)
     |> reset_composer_modes()
     |> clear_search_on_switch()
     |> close_mobile_navigation_panels()}
  end

  # -- close_channel_tab --

  def handle_event("close_channel_tab", %{"channel" => channel}, socket) do
    {:halt, part_channel(socket, channel)}
  end

  # -- close_pm_tab --

  def handle_event("close_pm_tab", %{"nickname" => nickname}, socket) do
    old_session = socket.assigns.session
    topic = "pm:#{PM.pm_topic(old_session.nickname, nickname)}"
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, topic)

    remaining_pm_tabs = List.delete(socket.assigns[:open_pm_tabs] || [], nickname)

    {session, show_status_tab} =
      session_after_pm_tab_close(
        old_session,
        nickname,
        remaining_pm_tabs,
        socket.assigns.show_status_tab
      )

    socket =
      socket
      |> assign(
        session: session,
        open_pm_tabs: remaining_pm_tabs,
        show_status_tab: show_status_tab
      )

    socket =
      cond do
        session.active_pm ->
          PM.load_pm_messages_with_pagination(socket, session.active_pm)

        session.active_channel ->
          socket
          |> load_channel_users(session.active_channel)
          |> load_channel_messages_with_pagination(session.active_channel)

        show_status_tab ->
          socket
          |> assign(current_topic: nil, current_modes: nil)
          |> MessageViewport.reset([])
      end

    {:halt, push_reconnect_state(socket)}
  end

  # -- close_dialog --

  def handle_event("close_dialog", _params, socket) do
    {:halt,
     Phoenix.LiveView.push_event(socket, "window_command", %{action: "close", id: "cheatsheet"})}
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
    {:halt, socket}
  end

  # history_navigate/tab_complete/syntax_tooltip_* are relayed to the Composer by
  # the shared `RetroHexChatWeb.App.ComposerEvents` hook.

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

  # -- reply_to_message --

  def handle_event("reply_to_message", %{"message_id" => msg_id_str}, socket) do
    with {:ok, msg_id} <- parse_message_id(msg_id_str),
         %{} = message <- get_reply_parent(socket.assigns.session, msg_id) do
      {:halt, put_composer(socket, set_reply_to: build_reply_to(message))}
    else
      _ -> {:halt, socket}
    end
  end

  # -- edit_message --

  def handle_event("edit_message", %{"message_id" => msg_id_str}, socket) do
    session = socket.assigns.session
    nickname = session.nickname

    with {:ok, msg_id} <- parse_message_id(msg_id_str),
         %{} = message <- get_reply_parent(session, msg_id),
         true <- editable_message?(message, session, nickname) do
      {:halt, enter_edit_mode(socket, message)}
    else
      _ -> {:halt, socket}
    end
  end

  # -- cancel_reply --

  def handle_event("cancel_reply", _params, socket) do
    {:halt, put_composer(socket, cancel_reply: true)}
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
      {:halt, enter_edit_mode(socket, last_message)}
    else
      {:halt, socket}
    end
  end

  # -- cancel_edit --

  def handle_event("cancel_edit", _params, socket) do
    {:halt, exit_edit_mode(socket, :restore)}
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

  defp session_after_pm_tab_close(session, closed_pm, remaining_pm_tabs, current_status_tab?) do
    if session.active_pm == closed_pm do
      cond do
        next_pm = List.first(remaining_pm_tabs) ->
          {Session.set_active_pm(session, next_pm), false}

        next_channel = List.first(session.channels) ->
          {Session.set_active_channel(session, next_channel), false}

        true ->
          {%{session | active_pm: nil, active_channel: nil}, true}
      end
    else
      {session, current_status_tab?}
    end
  end

  # Bubbled from the Composer LiveComponent on submit: the component has already
  # applied the action/notice prefix, updated its own history and reset itself;
  # here we run the privileged Parser/CommandDispatch work. `reply_to` is carried
  # in the message because it is now composer-owned.
  @spec dispatch_composer_input(Phoenix.LiveView.Socket.t(), String.t(), map() | nil) ::
          Phoenix.LiveView.Socket.t()
  def dispatch_composer_input(socket, text, reply_to) do
    session = socket.assigns.session
    parsed = Parser.parse(text)

    Observability.span(
      [:retro_hex_chat, :chat, :composer, :dispatch],
      composer_metadata(parsed, text, reply_to),
      fn ->
        socket
        |> dispatch_parsed_input(session, parsed, reply_to)
        |> reset_activity()
      end
    )
  end

  defp dispatch_parsed_input(socket, session, {:message, text}, reply_to) do
    new_session = Session.set_last_message_at(session, DateTime.utc_now())

    socket
    |> assign(session: new_session)
    |> ChatLive.CommandDispatch.send_plain_message(new_session, text, reply_to)
    |> push_event("tip_trigger", %{tip: "first_message"})
  end

  defp dispatch_parsed_input(socket, session, {:command, name, args}, _reply_to) do
    ChatLive.CommandDispatch.dispatch_command(socket, session, name, args)
  end

  @spec submit_composer_edit(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def submit_composer_edit(socket, new_content) do
    msg_id = socket.assigns.edit_mode_message_id
    session = socket.assigns.session

    result =
      if session.active_pm do
        Service.edit_private_message(msg_id, session.nickname, new_content)
      else
        Service.edit_message(msg_id, session.nickname, new_content)
      end

    case result do
      {:ok, _} -> exit_edit_mode(socket, :clear)
      {:error, reason} -> socket |> exit_edit_mode(:restore) |> error_event(reason)
    end
  end

  @spec empty_composer_edit(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def empty_composer_edit(socket) do
    msg_id = socket.assigns.edit_mode_message_id

    socket
    |> exit_edit_mode(:restore)
    |> open_delete_confirm(msg_id)
  end

  defp put_composer(socket, attrs) do
    send_update(Composer, [id: Composer.id()] ++ attrs)
    socket
  end

  defp reset_composer_modes(socket), do: put_composer(socket, reset_modes: true)

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

  defp composer_metadata(parsed, text, reply_to) do
    %{
      input_kind: parsed_kind(parsed),
      message_size_bytes: byte_size(text),
      has_reply: not is_nil(reply_to)
    }
  end

  defp parsed_kind({:message, _text}), do: "message"
  defp parsed_kind({:command, name, _args}), do: "command:#{safe_command_name(name)}"

  defp safe_command_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.slice(0, 40)
  end

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

  defp enter_edit_mode(socket, message) do
    msg_id = message.id
    socket = put_composer(socket, enter_edit: message.content)

    socket
    |> assign(edit_mode_message_id: msg_id)
    |> push_event("enter_edit_mode", %{message_id: msg_id, content: message.content})
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

  # Clears the parent-owned edit_mode_message_id and drives the Composer to
  # restore (cancel/error) or clear (successful save) its own input mirror. The
  # `set_input`/`exit_edit_mode` client pushes are global hook handlers, so the
  # component emits `set_input` from its own owned value.
  defp exit_edit_mode(socket, mode) do
    msg_id = socket.assigns.edit_mode_message_id

    socket
    |> assign(edit_mode_message_id: nil)
    |> tap(fn _ -> send_update(Composer, id: Composer.id(), exit_edit: mode) end)
    |> push_event("exit_edit_mode", %{message_id: msg_id})
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
    new_oldest = List.last(older_messages)

    stream_items =
      older_messages
      |> MessageHelpers.visible_channel_messages(socket.assigns.session.ignore_list)
      |> Enum.reverse()
      |> Enum.map(&message_to_stream_item/1)

    socket
    |> assign(
      loading_more: false,
      oldest_message_id: new_oldest.id,
      has_more: length(older_messages) == 50,
      loaded_message_count: (socket.assigns[:loaded_message_count] || 50) + length(older_messages)
    )
    |> push_event("prepend_start", %{})
    |> MessageViewport.prepend(stream_items)
  end

  defp message_to_stream_item(msg) do
    %{
      id: msg.id,
      author: msg.author_nickname,
      content: msg.content,
      type: MessageHelpers.stream_type(msg.type),
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

  defp close_mobile_navigation_panels(%{assigns: %{mobile_viewport: true}} = socket) do
    assign(socket, show_conversations: false, show_nicklist: false)
  end

  defp close_mobile_navigation_panels(socket), do: socket
end
