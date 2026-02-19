defmodule RetroHexChatWeb.ChatLive.ContextMenuEvents do
  @moduledoc """
  Handle context menu events for nicklist and chat area.

  Covers nicklist: nick_right_click, nicklist_dblclick, close_context_menu,
  context_query, context_whois, context_kick, context_ban, context_op,
  context_voice, context_add_contact, context_set_nick_color, context_ignore,
  context_unignore, context_pick_color, context_p2p, context_call,
  context_video_call, context_sendfile.

  Covers chat area: chat_context_menu, close_chat_context_menu, ctx_chat_pm,
  ctx_chat_whois, ctx_chat_copy_nick, ctx_chat_ignore, ctx_chat_add_contact,
  ctx_chat_set_color, ctx_chat_kick, ctx_chat_ban, ctx_chat_voice, ctx_chat_op,
  ctx_chat_open_url, ctx_chat_copy_url, ctx_chat_save_url, ctx_chat_join,
  ctx_chat_fav, ctx_chat_copy_channel, ctx_chat_channel_info,
  ctx_chat_copy_message, ctx_chat_copy_selection, ctx_chat_ignore_sender,
  ctx_chat_p2p, ctx_chat_call, ctx_chat_video_call, ctx_chat_sendfile.

  Attached as `attach_hook(:context_menu_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      show_whois_text: 2,
      open_pm_conversation: 2,
      maybe_persist_contacts: 2,
      push_status_message: 3,
      maybe_persist_ignore_list: 2,
      system_event: 2,
      error_event: 2,
      cancel_ignore_timer: 2,
      rebuild_nick_color_fn: 2,
      maybe_persist_nick_colors: 2
    ]

  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{CapturedURL, Favorites, IgnoreList}
  alias RetroHexChat.Commands.Handlers.P2p
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelper
  alias RetroHexChatWeb.ChatLive.Helpers.P2pInvite

  def handle_event("nick_right_click", %{"nick" => nick} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:halt,
     assign(socket,
       context_menu: %{
         visible: true,
         x: x,
         y: y,
         target_nick: nick,
         is_target_registered: NickServ.registered?(nick)
       }
     )}
  end

  def handle_event("nicklist_dblclick", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_context_menu()
     |> open_pm_conversation(nick)}
  end

  def handle_event("close_context_menu", _params, socket) do
    {:halt, close_context_menu(socket)}
  end

  def handle_event("context_query", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_context_menu()
     |> open_pm_conversation(nick)}
  end

  def handle_event("context_whois", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_context_menu()
     |> show_whois_text(nick)}
  end

  def handle_event("context_kick", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_context_menu()
     |> context_kick(channel, nick)}
  end

  def handle_event("context_ban", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_context_menu()
     |> context_ban(channel, nick)}
  end

  def handle_event("context_op", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+o", [nick])}
  end

  def handle_event("context_voice", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+v", [nick])}
  end

  def handle_event("context_add_contact", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case ContactList.add_entry(session.contacts, session.nickname, nick, nil) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:halt,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Added #{nick} to contacts", :system)}

      {:error, :duplicate} ->
        {:halt,
         socket
         |> close_context_menu()
         |> push_status_message("#{nick} is already in your contacts", :error)}

      {:error, :self_add} ->
        {:halt,
         socket
         |> close_context_menu()
         |> push_status_message("Cannot add yourself to contacts", :error)}

      {:error, _reason} ->
        {:halt,
         socket
         |> close_context_menu()
         |> push_status_message("Could not add #{nick} to contacts", :error)}
    end
  end

  def handle_event("context_set_nick_color", _params, socket) do
    {:halt, assign(socket, show_context_color_picker: true)}
  end

  def handle_event("context_ignore", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case IgnoreList.add_entry(session.ignore_list, nick, :all, nil) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:halt,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_ignore_list(new_session)
         |> system_event("* #{nick} is now ignored")}

      {:error, :list_full} ->
        {:halt,
         socket
         |> close_context_menu()
         |> error_event("Ignore list is full (max 100 entries)")}

      {:error, _reason} ->
        {:halt, close_context_menu(socket)}
    end
  end

  def handle_event("context_unignore", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:halt,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> cancel_ignore_timer(nick)
         |> cancel_auto_ignore_with_cooldown(nick)
         |> maybe_persist_ignore_list(new_session)
         |> system_event("* #{nick} is no longer ignored")}

      {:error, :not_found} ->
        {:halt, close_context_menu(socket)}
    end
  end

  def handle_event("context_pick_color", %{"color_index" => color_str}, socket) do
    session = socket.assigns.session
    target = socket.assigns.context_menu.target_nick
    color_index = String.to_integer(color_str)

    case NickColors.add_or_update(session.nick_colors, target, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)
        color_name = NickColors.hex_for_index(color_index)

        {:halt,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)
         |> push_status_message("Set #{target}'s color to #{color_name}", :system)}

      {:error, :list_full} ->
        {:halt,
         socket
         |> close_context_menu()
         |> push_status_message("Nick color list is full (max 50)", :error)}

      {:error, _reason} ->
        {:halt,
         socket
         |> close_context_menu()
         |> push_status_message("Could not set color for #{target}", :error)}
    end
  end

  # ---------------------------------------------------------------------------
  # Nicklist P2P Context Menu Events
  # ---------------------------------------------------------------------------

  def handle_event("context_p2p", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "generic", :nicklist)}

  def handle_event("context_call", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "audio_call", :nicklist)}

  def handle_event("context_video_call", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "video_call", :nicklist)}

  def handle_event("context_sendfile", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "file_transfer", :nicklist)}

  # ---------------------------------------------------------------------------
  # Chat Area Context Menu Events
  # ---------------------------------------------------------------------------

  def handle_event("chat_context_menu", params, socket) do
    {:halt, open_chat_context_menu(socket, params)}
  end

  def handle_event("close_chat_context_menu", _params, socket) do
    {:halt, close_chat_context_menu(socket)}
  end

  def handle_event("ctx_chat_pm", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> open_pm_conversation(nick)}
  end

  def handle_event("ctx_chat_whois", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> show_whois_text(nick)}
  end

  def handle_event("ctx_chat_copy_nick", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("clipboard_copy", %{text: nick})}
  end

  def handle_event("ctx_chat_ignore", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    if IgnoreList.get_entry(session.ignore_list, nick) != nil do
      # Already ignored — toggle off (unignore)
      {:halt,
       socket
       |> close_chat_context_menu()
       |> ctx_chat_unignore(nick)}
    else
      case IgnoreList.add_entry(session.ignore_list, nick, :all, nil) do
        {:ok, updated_list} ->
          new_session = Session.set_ignore_list(session, updated_list)

          {:halt,
           socket
           |> close_chat_context_menu()
           |> assign(session: new_session)
           |> maybe_persist_ignore_list(new_session)
           |> system_event("* #{nick} is now ignored")}

        {:error, _reason} ->
          {:halt, close_chat_context_menu(socket)}
      end
    end
  end

  def handle_event("ctx_chat_add_contact", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case ContactList.add_entry(session.contacts, session.nickname, nick, nil) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:halt,
         socket
         |> close_chat_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Added #{nick} to contacts", :system)}

      {:error, _reason} ->
        {:halt,
         socket
         |> close_chat_context_menu()
         |> push_status_message("Could not add #{nick} to contacts", :error)}
    end
  end

  def handle_event("ctx_chat_set_color", %{"nick" => nick}, socket) do
    # Reuse the nicklist color picker by opening it with the target nick
    {:halt,
     socket
     |> close_chat_context_menu()
     |> assign(
       context_menu: %{
         visible: true,
         x: socket.assigns.chat_context_menu.x,
         y: socket.assigns.chat_context_menu.y,
         target_nick: nick,
         is_target_registered: false
       },
       show_context_color_picker: true
     )}
  end

  def handle_event("ctx_chat_kick", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_chat_context_menu()
     |> context_kick(channel, nick)}
  end

  def handle_event("ctx_chat_ban", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_chat_context_menu()
     |> context_ban(channel, nick)}
  end

  def handle_event("ctx_chat_voice", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_chat_context_menu()
     |> context_set_mode(channel, "+v", [nick])}
  end

  def handle_event("ctx_chat_op", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:halt,
     socket
     |> close_chat_context_menu()
     |> context_set_mode(channel, "+o", [nick])}
  end

  def handle_event("ctx_chat_open_url", %{"url" => url}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("open_url", %{url: url})}
  end

  def handle_event("ctx_chat_copy_url", %{"url" => url}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("clipboard_copy", %{text: url})}
  end

  def handle_event("ctx_chat_save_url", %{"url" => url} = params, socket) do
    author = params["author"] || "Unknown"
    channel = socket.assigns.session.active_channel || "unknown"

    entry =
      CapturedURL.new(%{
        url: url,
        source: channel,
        source_type: :channel,
        posted_by: author,
        timestamp: DateTime.utc_now()
      })

    entries = [entry | socket.assigns.url_catcher_entries]

    {:halt,
     socket
     |> close_chat_context_menu()
     |> assign(url_catcher_entries: entries)
     |> push_status_message("URL saved to URL Catcher", :system)}
  end

  def handle_event("ctx_chat_join", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> ChannelHelper.join_channel(channel, socket.assigns.session)}
  end

  def handle_event("ctx_chat_fav", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)

    if Favorites.has_entry?(favorites, channel) do
      existing = Favorites.find_entry(favorites, channel)

      {:halt,
       socket
       |> close_chat_context_menu()
       |> assign(
         show_favorite_dialog: true,
         favorite_dialog_mode: :edit,
         favorite_dialog_channel: channel,
         favorite_dialog_is_duplicate: true,
         favorite_dialog_data: %{
           description: existing.description,
           auto_join: existing.auto_join,
           has_password: existing.password != nil and existing.password != ""
         }
       )}
    else
      {:halt,
       socket
       |> close_chat_context_menu()
       |> assign(
         show_favorite_dialog: true,
         favorite_dialog_mode: :add,
         favorite_dialog_channel: channel,
         favorite_dialog_is_duplicate: false,
         favorite_dialog_data: nil
       )}
    end
  end

  def handle_event("ctx_chat_copy_channel", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("clipboard_copy", %{text: channel})}
  end

  def handle_event("ctx_chat_channel_info", %{"channel" => _channel}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> assign(show_channel_central: true)}
  end

  def handle_event("ctx_chat_copy_message", %{"text" => text}, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("clipboard_copy", %{text: text})}
  end

  def handle_event("ctx_chat_copy_selection", _params, socket) do
    {:halt,
     socket
     |> close_chat_context_menu()
     |> push_event("clipboard_copy_selection", %{})}
  end

  def handle_event("ctx_chat_ignore_sender", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case IgnoreList.add_entry(session.ignore_list, nick, :all, nil) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:halt,
         socket
         |> close_chat_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_ignore_list(new_session)
         |> system_event("* #{nick} is now ignored")}

      {:error, _reason} ->
        {:halt, close_chat_context_menu(socket)}
    end
  end

  # ---------------------------------------------------------------------------
  # Chat Area P2P Context Menu Events
  # ---------------------------------------------------------------------------

  def handle_event("ctx_chat_p2p", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "generic", :chat)}

  def handle_event("ctx_chat_call", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "audio_call", :chat)}

  def handle_event("ctx_chat_video_call", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "video_call", :chat)}

  def handle_event("ctx_chat_sendfile", %{"nick" => nick}, socket),
    do: {:halt, handle_p2p_action(socket, nick, "file_transfer", :chat)}

  # Catch-all: not our event, pass it along
  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private helpers (local copies)
  # ---------------------------------------------------------------------------

  defp open_chat_context_menu(socket, params) do
    type = String.to_existing_atom(params["type"])
    urls = params["message_urls"] || []

    target_message = %{
      author: params["author"],
      text: params["message_text"],
      is_system: params["is_system"] == true,
      urls: urls,
      message_id: params["message_id"],
      is_own: params["author"] == socket.assigns.session.nickname
    }

    target_nick = params["nick"]

    is_target_registered =
      if type == :nick and is_binary(target_nick),
        do: NickServ.registered?(target_nick),
        else: false

    assign(socket,
      chat_context_menu: %{
        visible: true,
        type: type,
        x: params["x"] || 0,
        y: params["y"] || 0,
        target_nick: target_nick,
        target_url: params["url"],
        target_channel: params["channel"],
        target_message: target_message,
        has_selection: params["has_selection"] == true,
        is_target_registered: is_target_registered
      }
    )
  end

  defp close_chat_context_menu(socket) do
    assign(socket,
      chat_context_menu: %{
        visible: false,
        type: nil,
        x: 0,
        y: 0,
        target_nick: nil,
        target_url: nil,
        target_channel: nil,
        target_message: nil,
        has_selection: false,
        is_target_registered: false
      }
    )
  end

  defp ctx_chat_unignore(socket, nick) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> maybe_persist_ignore_list(new_session)
        |> system_event("* #{nick} is no longer ignored")

      {:error, :not_found} ->
        socket
    end
  end

  defp close_context_menu(socket) do
    assign(socket,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil, is_target_registered: false},
      show_context_color_picker: false,
      show_favorites_dropdown: false
    )
  end

  defp context_kick(socket, nil, _nick), do: socket

  defp context_kick(socket, channel, nick) do
    operator = socket.assigns.session.nickname
    Server.kick(channel, operator, nick, "Kicked")
    socket
  end

  defp context_ban(socket, nil, _nick), do: socket

  defp context_ban(socket, channel, nick) do
    operator = socket.assigns.session.nickname
    Server.ban(channel, operator, "#{nick}!*@*")
    socket
  end

  defp context_set_mode(socket, nil, _mode, _params), do: socket

  defp context_set_mode(socket, channel, mode, params) do
    Server.set_mode(channel, socket.assigns.session.nickname, mode, params)
    socket
  end

  defp handle_p2p_action(socket, nick, session_type, source) do
    session = socket.assigns.session

    socket =
      case source do
        :nicklist -> close_context_menu(socket)
        :chat -> close_chat_context_menu(socket)
      end

    context = %{
      nickname: session.nickname,
      identified: session.identified,
      active_channel: session.active_channel,
      channels: session.channels,
      operator_in: session.operator_in || [],
      half_operator_in: session.half_operator_in || [],
      is_admin: session.is_admin || false,
      is_server_operator: session.is_server_operator || false
    }

    case P2p.do_execute(nick, session_type, context) do
      {:ok, :ui_action, :p2p_invite, payload} ->
        socket
        |> P2pInvite.handle_p2p_invite(session, payload)
        |> push_navigate(to: ~p"/p2p/#{payload.token}")

      {:error, message} ->
        socket
        |> error_event(message)
    end
  end

  defp cancel_auto_ignore_with_cooldown(socket, nick) do
    auto_state = socket.assigns.auto_ignore_state
    key = String.downcase(nick)

    case Map.get(auto_state.active, key) do
      nil ->
        socket

      _ref ->
        new_active = Map.delete(auto_state.active, key)
        new_cooldowns = Map.delete(auto_state.cooldowns, key)
        new_auto_state = %{active: new_active, cooldowns: new_cooldowns}
        assign(socket, auto_ignore_state: new_auto_state)
    end
  end
end
