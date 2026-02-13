defmodule RetroHexChatWeb.ChatLive.CoreEvents do
  @moduledoc """
  Handle core chat navigation and interaction events.

  Covers: send_input, switch_channel, switch_pm, switch_to_status,
  close_channel_tab, close_pm_tab, close_dialog, load_more,
  scroll_to_bottom, history_navigate, tab_complete.

  Attached as `attach_hook(:core_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream: 4, stream_insert: 4, push_event: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      load_channel_users: 2,
      load_channel_messages_with_pagination: 2,
      push_reconnect_state: 1,
      part_channel: 2,
      reset_activity: 1
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Commands.Parser
  alias RetroHexChatWeb.ChatLive

  # -- send_input --

  def handle_event("send_input", %{"input" => ""}, socket), do: {:halt, socket}

  def handle_event("send_input", %{"input" => input}, socket) do
    session = socket.assigns.session
    history = [input | socket.assigns.command_history] |> Enum.take(50)

    case Parser.parse(input) do
      {:message, text} ->
        new_session = Session.set_last_message_at(session, DateTime.utc_now())

        socket =
          socket
          |> assign(session: new_session)
          |> ChatLive.CommandDispatch.send_plain_message(new_session, text)
          |> reset_activity()

        {:halt, assign(socket, input: "", command_history: history, history_index: -1)}

      {:command, name, args} ->
        socket =
          socket
          |> ChatLive.CommandDispatch.dispatch_command(session, name, args)
          |> reset_activity()

        {:halt, assign(socket, input: "", command_history: history, history_index: -1)}
    end
  end

  # -- switch_channel --

  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    session = Session.set_active_channel(socket.assigns.session, channel)
    unread = MapSet.delete(socket.assigns.unread_channels, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)
    flash = MapSet.delete(socket.assigns.flash_channels, channel)
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> assign(
       session: session,
       unread_channels: unread,
       highlight_channels: highlight,
       flash_channels: flash,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
     |> load_channel_users(channel)
     |> load_channel_messages_with_pagination(channel)
     |> push_reconnect_state()}
  end

  # -- switch_pm --

  def handle_event("switch_pm", %{"nickname" => nickname}, socket) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    messages = load_pm_messages(session.nickname, nickname)
    unread = MapSet.delete(socket.assigns.unread_channels, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:halt,
     socket
     |> assign(
       session: session,
       unread_channels: unread,
       flash_channels: flash,
       current_topic: nil,
       current_modes: nil,
       show_status_tab: false,
       pm_typing_from: nil,
       pm_typing_timer: nil
     )
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
    {:halt, assign(socket, show_about: false, show_whois: false, whois_target: nil)}
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

  def handle_event("tab_complete", %{"partial" => partial}, socket) do
    users = socket.assigns.channel_users
    matches = Enum.filter(users, &String.starts_with?(&1.nickname, partial))

    case matches do
      [match] -> {:halt, assign(socket, input: match.nickname <> ": ")}
      _ -> {:halt, socket}
    end
  end

  # -- Catch-all: pass unhandled events to the next hook --

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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
  end
end
