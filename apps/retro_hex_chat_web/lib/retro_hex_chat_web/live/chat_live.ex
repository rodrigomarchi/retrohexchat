defmodule RetroHexChatWeb.ChatLive do
  @moduledoc """
  Main chat interface with MDI layout: treebar, chat area, nicklist, status bar.
  """
  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, Session}
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.{Formatter, Highlight, HighlightWords, Queries, Search, Service}
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Commands.Registry, as: CmdRegistry
  alias RetroHexChat.Presence.{NotifyList, Tracker}
  alias RetroHexChat.Services.NickServ

  @impl true
  def mount(params, _session, socket) do
    nickname = params["nickname"] || "Guest_#{:rand.uniform(99999)}"

    case NicknameValidator.validate(nickname) do
      :ok ->
        session = Session.new(nickname)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")

          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "presence:global",
            {:user_connected, %{nickname: nickname}}
          )

          socket =
            socket
            |> assign_defaults(session)
            |> join_channel("#lobby", session)
            |> maybe_join_from_params(params)
            |> maybe_start_nickserv_timer(nickname)

          {:ok, socket}
        else
          {:ok, assign_defaults(socket, session)}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp assign_defaults(socket, session) do
    socket
    |> assign(
      channel_users: [],
      command_history: [],
      command_palette_filter: "",
      command_palette_visible: false,
      contacts_selected: nil,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil},
      nick_color_fn: build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      input: "",
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: "RetroHexChat",
      search_current_index: 0,
      search_query: "",
      search_result_count: 0,
      search_results: [],
      search_visible: false,
      session: session,
      show_about: false,
      show_address_book: false,
      show_context_color_picker: false,
      show_contact_add_dialog: false,
      show_contact_edit_dialog: false,
      address_book_tab: "contacts",
      show_nick_color_add_dialog: false,
      show_nick_color_edit_dialog: false,
      show_nicklist: true,
      show_notify_add_dialog: false,
      show_notify_edit_dialog: false,
      show_notify_list: false,
      highlight_channels: MapSet.new(),
      highlight_selected: nil,
      show_highlight_add_dialog: false,
      show_highlight_dialog: false,
      show_highlight_edit_dialog: false,
      show_treebar: true,
      show_whois: false,
      unread_channels: MapSet.new(),
      whois_target: nil
    )
    |> stream(:chat_messages, [])
    |> stream(:status_messages, [])
  end

  # ── Event handlers ──────────────────────────────────────────

  @impl true
  def handle_event("send_input", %{"input" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_input", %{"input" => input}, socket) do
    session = socket.assigns.session
    history = [input | socket.assigns.command_history] |> Enum.take(50)

    case Parser.parse(input) do
      {:message, text} ->
        socket = send_plain_message(socket, session, text)
        {:noreply, assign(socket, input: "", command_history: history, history_index: -1)}

      {:command, name, args} ->
        socket = dispatch_command(socket, session, name, args)
        {:noreply, assign(socket, input: "", command_history: history, history_index: -1)}
    end
  end

  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    session = Session.set_active_channel(socket.assigns.session, channel)
    unread = MapSet.delete(socket.assigns.unread_channels, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)

    {:noreply,
     socket
     |> assign(session: session, unread_channels: unread, highlight_channels: highlight)
     |> load_channel_users(channel)
     |> load_channel_messages_with_pagination(channel)}
  end

  def handle_event("switch_pm", %{"nickname" => nickname}, socket) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    messages = load_pm_messages(session.nickname, nickname)
    unread = MapSet.delete(socket.assigns.unread_channels, "pm:#{nickname}")

    {:noreply,
     socket
     |> assign(session: session, unread_channels: unread)
     |> stream(:chat_messages, messages, reset: true)}
  end

  def handle_event("close_dialog", _params, socket) do
    {:noreply, assign(socket, show_about: false, show_whois: false, whois_target: nil)}
  end

  def handle_event("load_more", _params, socket) do
    %{loading_more: loading_more, has_more: has_more, oldest_message_id: oldest_id} =
      socket.assigns

    if loading_more or not has_more or is_nil(oldest_id) do
      {:noreply, socket}
    else
      {:noreply, do_load_more(socket, oldest_id)}
    end
  end

  def handle_event("scroll_to_bottom", _params, socket) do
    {:noreply, assign(socket, new_messages_indicator: false)}
  end

  def handle_event("toggle_search", _params, socket) do
    visible = !socket.assigns.search_visible

    if visible do
      {:noreply, assign(socket, search_visible: true)}
    else
      {:noreply, clear_search_state(socket)}
    end
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    {:noreply, do_search(socket, query)}
  end

  def handle_event("search_next", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx >= count, do: 1, else: idx + 1
      {:noreply, assign(socket, search_current_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_prev", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx <= 1, do: count, else: idx - 1
      {:noreply, assign(socket, search_current_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_search", _params, socket) do
    {:noreply, clear_search_state(socket)}
  end

  def handle_event("window_keydown", %{"key" => "f", "ctrlKey" => true}, socket) do
    {:noreply, assign(socket, search_visible: true)}
  end

  def handle_event("window_keydown", %{"key" => "b", "altKey" => true}, socket) do
    if socket.assigns.show_address_book do
      {:noreply,
       assign(socket,
         show_address_book: false,
         address_book_tab: "contacts",
         contacts_selected: nil,
         show_contact_add_dialog: false,
         show_contact_edit_dialog: false
       )}
    else
      {:noreply, assign(socket, show_address_book: true)}
    end
  end

  def handle_event("window_keydown", %{"key" => "h", "altKey" => true}, socket) do
    if socket.assigns.show_highlight_dialog do
      {:noreply,
       assign(socket,
         show_highlight_dialog: false,
         show_highlight_add_dialog: false,
         show_highlight_edit_dialog: false,
         highlight_selected: nil
       )}
    else
      {:noreply, assign(socket, show_highlight_dialog: true)}
    end
  end

  def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
    if socket.assigns.search_visible do
      {:noreply, clear_search_state(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("window_keydown", _params, socket) do
    {:noreply, socket}
  end

  # Context menu events (Phase 12)
  def handle_event("nick_right_click", %{"nick" => nick} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:noreply, assign(socket, context_menu: %{visible: true, x: x, y: y, target_nick: nick})}
  end

  def handle_event("close_context_menu", _params, socket) do
    {:noreply, close_context_menu(socket)}
  end

  def handle_event("context_query", %{"nick" => nick}, socket) do
    {:noreply,
     socket
     |> close_context_menu()
     |> open_pm_conversation(nick)}
  end

  def handle_event("context_whois", %{"nick" => nick}, socket) do
    {:noreply,
     socket
     |> close_context_menu()
     |> assign(show_whois: true, whois_target: nick)}
  end

  def handle_event("context_kick", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_kick(channel, nick)}
  end

  def handle_event("context_ban", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_ban(channel, nick)}
  end

  def handle_event("context_op", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+o", [nick])}
  end

  def handle_event("context_voice", %{"nick" => nick}, socket) do
    channel = socket.assigns.session.active_channel

    {:noreply,
     socket
     |> close_context_menu()
     |> context_set_mode(channel, "+v", [nick])}
  end

  # Context menu Address Book actions (Phase 8)
  def handle_event("context_add_contact", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case ContactList.add_entry(session.contacts, session.nickname, nick, nil) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:noreply,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Added #{nick} to contacts", :system)}

      {:error, :duplicate} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> push_status_message("#{nick} is already in your contacts", :error)}

      {:error, :self_add} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> push_status_message("Cannot add yourself to contacts", :error)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> push_status_message("Could not add #{nick} to contacts", :error)}
    end
  end

  def handle_event("context_set_nick_color", _params, socket) do
    {:noreply, assign(socket, show_context_color_picker: true)}
  end

  def handle_event("context_pick_color", %{"color_index" => color_str}, socket) do
    session = socket.assigns.session
    target = socket.assigns.context_menu.target_nick
    color_index = String.to_integer(color_str)

    case NickColors.add_or_update(session.nick_colors, target, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)
        color_name = NickColors.hex_for_index(color_index)

        {:noreply,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)
         |> push_status_message("Set #{target}'s color to #{color_name}", :system)}

      {:error, :list_full} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> push_status_message("Nick color list is full (max 50)", :error)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> push_status_message("Could not set color for #{target}", :error)}
    end
  end

  # Menu bar events (Phase 14)
  def handle_event("quit_chat", _params, socket) do
    cleanup_channels(socket.assigns.session)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("open_search", _params, socket) do
    {:noreply, assign(socket, search_visible: true)}
  end

  def handle_event("settings", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_treebar", _params, socket) do
    {:noreply, assign(socket, show_treebar: !socket.assigns.show_treebar)}
  end

  def handle_event("toggle_nicklist", _params, socket) do
    {:noreply, assign(socket, show_nicklist: !socket.assigns.show_nicklist)}
  end

  def handle_event("toggle_strip_formatting", _params, socket) do
    session = Session.toggle_strip_formatting(socket.assigns.session)
    socket = assign(socket, session: session)

    socket =
      if session.active_channel do
        load_channel_messages_with_pagination(socket, session.active_channel)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("show_about", _params, socket) do
    {:noreply, assign(socket, show_about: true)}
  end

  # Command palette events
  def handle_event("open_command_palette", _params, socket) do
    {:noreply, assign(socket, command_palette_visible: true, command_palette_filter: "")}
  end

  def handle_event("close_command_palette", _params, socket) do
    {:noreply, assign(socket, command_palette_visible: false, command_palette_filter: "")}
  end

  def handle_event("filter_command_palette", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, command_palette_filter: filter)}
  end

  def handle_event("select_command", %{"command" => command}, socket) do
    {:noreply,
     assign(socket,
       input: "/#{command} ",
       command_palette_visible: false,
       command_palette_filter: ""
     )}
  end

  # Keyboard shortcut events
  def handle_event("history_navigate", %{"direction" => direction}, socket) do
    history = socket.assigns.command_history
    index = socket.assigns[:history_index] || -1

    case direction do
      "up" ->
        new_index = min(index + 1, length(history) - 1)

        if new_index >= 0 and new_index < length(history) do
          {:noreply, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:noreply, socket}
        end

      "down" ->
        new_index = max(index - 1, -1)

        if new_index >= 0 do
          {:noreply, assign(socket, input: Enum.at(history, new_index), history_index: new_index)}
        else
          {:noreply, assign(socket, input: "", history_index: -1)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("tab_complete", %{"partial" => partial}, socket) do
    users = socket.assigns.channel_users
    matches = Enum.filter(users, &String.starts_with?(&1.nickname, partial))

    case matches do
      [match] -> {:noreply, assign(socket, input: match.nickname <> ": ")}
      _ -> {:noreply, socket}
    end
  end

  # Toolbar events (Phase 14)
  def handle_event("disconnect", _params, socket) do
    cleanup_channels(socket.assigns.session)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("channel_list", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/channels")}
  end

  # Address Book events
  def handle_event("toggle_address_book", _params, socket) do
    if socket.assigns.show_address_book do
      {:noreply,
       assign(socket,
         show_address_book: false,
         address_book_tab: "contacts",
         contacts_selected: nil,
         show_contact_add_dialog: false,
         show_contact_edit_dialog: false,
         nick_colors_selected: nil,
         show_nick_color_add_dialog: false,
         show_nick_color_edit_dialog: false
       )}
    else
      {:noreply, assign(socket, show_address_book: true)}
    end
  end

  def handle_event("address_book_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, address_book_tab: tab)}
  end

  # Contact CRUD events (Phase 4)
  def handle_event("contact_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, contacts_selected: nick)}
  end

  def handle_event("contact_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: true)}
  end

  def handle_event("contact_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_add_dialog: false)}
  end

  def handle_event("contact_add", %{"nickname" => nickname} = params, socket) do
    session = socket.assigns.session
    note = params["note"]
    note = if note == "", do: nil, else: note

    case ContactList.add_entry(session.contacts, session.nickname, nickname, note) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:noreply,
         socket
         |> assign(session: new_session, show_contact_add_dialog: false)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Added #{nickname} to contacts", :system)}

      {:error, :self_add} ->
        {:noreply, push_status_message(socket, "Cannot add yourself to contacts", :system)}

      {:error, :duplicate} ->
        {:noreply,
         push_status_message(socket, "#{nickname} is already in your contacts", :system)}

      {:error, :list_full} ->
        {:noreply, push_status_message(socket, "Contact list is full (max 100 entries)", :system)}

      {:error, :invalid_nickname} ->
        {:noreply, push_status_message(socket, "Invalid nickname", :system)}
    end
  end

  def handle_event("contact_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_contact_edit_dialog: true)}
  end

  def handle_event("contact_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_contact_edit_dialog: false)}
  end

  def handle_event("contact_edit", %{"note" => note} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.contacts_selected
    note = if note == "", do: nil, else: note

    case ContactList.update_note(session.contacts, nickname, note) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:noreply,
         socket
         |> assign(session: new_session, show_contact_edit_dialog: false)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Updated note for #{nickname}", :system)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "#{nickname} is not in your contacts", :system)}
    end
  end

  def handle_event("contact_remove", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    case ContactList.remove_entry(session.contacts, nick) do
      {:ok, updated_contacts} ->
        new_session = Session.set_contacts(session, updated_contacts)

        {:noreply,
         socket
         |> assign(session: new_session, contacts_selected: nil)
         |> maybe_persist_contacts(new_session)
         |> push_status_message("Removed #{nick} from contacts", :system)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "#{nick} is not in your contacts", :system)}
    end
  end

  # Nick color CRUD events (Phase 6)
  def handle_event("nick_color_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, nick_colors_selected: nick)}
  end

  def handle_event("nick_color_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_nick_color_add_dialog: true)}
  end

  def handle_event("nick_color_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_nick_color_add_dialog: false)}
  end

  def handle_event(
        "nick_color_add",
        %{"nickname" => nickname, "color_index" => color_str},
        socket
      ) do
    session = socket.assigns.session
    nickname = String.trim(nickname)
    color_index = String.to_integer(color_str)

    case NickColors.add_entry(session.nick_colors, nickname, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, show_nick_color_add_dialog: false)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)}

      {:error, :duplicate} ->
        {:noreply, push_status_message(socket, "#{nickname} already has a custom color", :error)}

      {:error, :list_full} ->
        {:noreply, push_status_message(socket, "Nick color list is full (max 50)", :error)}

      {:error, :invalid_nickname} ->
        {:noreply, push_status_message(socket, "Invalid nickname", :error)}

      {:error, :invalid_color} ->
        {:noreply, push_status_message(socket, "Invalid color", :error)}
    end
  end

  def handle_event("nick_color_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_nick_color_edit_dialog: true)}
  end

  def handle_event("nick_color_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_nick_color_edit_dialog: false)}
  end

  def handle_event("nick_color_edit", %{"color_index" => color_str} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.nick_colors_selected
    color_index = String.to_integer(color_str)

    case NickColors.update_color(session.nick_colors, nickname, color_index) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, show_nick_color_edit_dialog: false)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "Nick color entry not found", :error)}

      {:error, :invalid_color} ->
        {:noreply, push_status_message(socket, "Invalid color", :error)}
    end
  end

  def handle_event("nick_color_remove", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    case NickColors.remove_entry(session.nick_colors, nick) do
      {:ok, updated} ->
        new_session = Session.set_nick_colors(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, nick_colors_selected: nil)
         |> rebuild_nick_color_fn(new_session)
         |> maybe_persist_nick_colors(new_session)
         |> push_status_message("Removed custom color for #{nick}", :system)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "#{nick} has no custom color", :system)}
    end
  end

  # Highlight dialog events
  def handle_event("open_highlight_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_dialog: true)}
  end

  def handle_event("close_highlight_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_highlight_dialog: false,
       show_highlight_add_dialog: false,
       show_highlight_edit_dialog: false,
       highlight_selected: nil
     )}
  end

  def handle_event("highlight_select", %{"word" => word}, socket) do
    {:noreply, assign(socket, highlight_selected: word)}
  end

  def handle_event("open_highlight_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_add_dialog: true)}
  end

  def handle_event("close_highlight_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_add_dialog: false)}
  end

  def handle_event("open_highlight_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_edit_dialog: true)}
  end

  def handle_event("close_highlight_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_edit_dialog: false)}
  end

  def handle_event("highlight_color_pick", %{"color" => color}, socket) do
    {:noreply, assign(socket, highlight_selected_color: color)}
  end

  # Highlight word CRUD events
  def handle_event("highlight_add", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.add_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, show_highlight_add_dialog: false)
         |> maybe_persist_highlight_words(new_session)}

      {:error, reason} ->
        {:noreply, push_status_message(socket, "Cannot add highlight: #{reason}", :error)}
    end
  end

  def handle_event("highlight_remove", %{"word" => word}, socket) do
    session = socket.assigns.session

    case HighlightWords.remove_entry(session.highlight_words, word) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, highlight_selected: nil)
         |> maybe_persist_highlight_words(new_session)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "Word not in highlight list", :error)}
    end
  end

  def handle_event("highlight_edit", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.update_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:noreply,
         socket
         |> assign(session: new_session, show_highlight_edit_dialog: false)
         |> maybe_persist_highlight_words(new_session)}

      {:error, reason} ->
        {:noreply, push_status_message(socket, "Cannot update highlight: #{reason}", :error)}
    end
  end

  # Notify list events (US1/US3)
  def handle_event("toggle_notify_list", _params, socket) do
    {:noreply, assign(socket, show_notify_list: !socket.assigns.show_notify_list)}
  end

  def handle_event("notify_add", %{"nickname" => nick} = params, socket) do
    session = socket.assigns.session
    note = params["note"]
    note = if note == "", do: nil, else: note

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_notify_add_dialog: false)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Added #{nick} to notify list", :system)}

      {:error, :self_add} ->
        {:noreply, push_status_message(socket, "Cannot add yourself to the notify list", :system)}

      {:error, :duplicate} ->
        {:noreply, push_status_message(socket, "#{nick} is already in your notify list", :system)}

      {:error, :list_full} ->
        {:noreply, push_status_message(socket, "Notify list is full (max 50 entries)", :system)}
    end
  end

  def handle_event("notify_remove", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        # Cancel any pending debounce timer for this buddy
        socket = cancel_notify_timer(socket, nick)

        {:noreply,
         socket
         |> assign(session: new_session, notify_selected: nil)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Removed #{nick} from notify list", :system)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "#{nick} is not in your notify list", :system)}
    end
  end

  def handle_event("notify_edit", %{"nickname" => nick, "note" => note}, socket) do
    session = socket.assigns.session
    note = if note == "", do: nil, else: note

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_notify_edit_dialog: false)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Updated note for #{nick}", :system)}

      {:error, :not_found} ->
        {:noreply, push_status_message(socket, "#{nick} is not in your notify list", :system)}
    end
  end

  def handle_event("notify_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, notify_selected: nick)}
  end

  def handle_event("notify_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: true)}
  end

  def handle_event("notify_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_add_dialog: false)}
  end

  def handle_event("notify_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_notify_edit_dialog: true)}
  end

  def handle_event("notify_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_notify_edit_dialog: false)}
  end

  def handle_event("notify_dblclick", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    entry =
      Enum.find(session.notify_list.entries, fn e ->
        String.downcase(e.tracked_nickname) == String.downcase(nick)
      end)

    if entry && entry.online do
      {:noreply, open_pm_conversation(socket, nick)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_auto_whois", _params, socket) do
    session = socket.assigns.session
    current = session.notify_list.settings.auto_whois
    updated_list = NotifyList.set_auto_whois(session.notify_list, !current)
    new_session = Session.set_notify_list(session, updated_list)

    socket =
      socket
      |> assign(session: new_session)
      |> maybe_persist_notify_list(new_session)

    {:noreply, socket}
  end

  # ── PubSub handlers ────────────────────────────────────────

  @impl true
  def handle_info(%{event: "new_message", payload: payload}, socket) do
    session = socket.assigns.session
    decorated = maybe_highlight(payload, session)

    socket = maybe_play_highlight_sound(socket, decorated, payload.channel)

    if payload.channel == session.active_channel do
      {:noreply, stream_insert(socket, :chat_messages, decorated)}
    else
      unread = MapSet.put(socket.assigns.unread_channels, payload.channel)

      highlight =
        if Map.get(decorated, :highlighted),
          do: MapSet.put(socket.assigns.highlight_channels, payload.channel),
          else: socket.assigns.highlight_channels

      {:noreply, assign(socket, unread_channels: unread, highlight_channels: highlight)}
    end
  end

  def handle_info(%{event: "new_pm", payload: payload}, socket) do
    session = socket.assigns.session
    other_nick = pm_other_nick(payload, session.nickname)

    if session.active_pm == other_nick do
      {:noreply, stream_insert(socket, :chat_messages, pm_to_stream_item(payload))}
    else
      unread = MapSet.put(socket.assigns.unread_channels, "pm:#{other_nick}")
      {:noreply, assign(socket, unread_channels: unread)}
    end
  end

  def handle_info(
        {:mode_changed, %{nickname: nick, mode_string: mode_string, params: params}},
        socket
      ) do
    msg = "#{nick} sets mode #{mode_string}"
    users = apply_mode_to_users(socket.assigns.channel_users, mode_string, params)

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:mode_changed, %{nickname: nick, mode_string: mode_string}}, socket) do
    msg = "#{nick} sets mode #{mode_string}"
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:user_kicked, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was kicked by #{op}" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == target))

    if target == socket.assigns.session.nickname do
      socket =
        socket
        |> assign(channel_users: users)
        |> part_channel_after_kick(socket.assigns.session.active_channel)
        |> stream_insert(:chat_messages, system_message(msg))

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(channel_users: users)
       |> stream_insert(:chat_messages, system_message(msg))}
    end
  end

  def handle_info({:user_banned, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was banned by #{op}" <> if(reason, do: " (#{reason})", else: "")
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:topic_changed, %{nickname: nick, topic: topic}}, socket) do
    msg = "#{nick} changed the topic to: #{topic}"
    {:noreply, stream_insert(socket, :chat_messages, system_message(msg))}
  end

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = "#{nick} has joined the channel"
    role = Map.get(payload, :role, :regular)
    user = %{nickname: nick, role: role, away: false}
    users = [user | socket.assigns.channel_users]

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason}}, socket) do
    msg = "#{nick} has left" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == nick))

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    # Update nicklist if this is from another user
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    msg = "#{old_nick} is now known as #{new_nick}"

    # Update notify list if old_nick is tracked (T025)
    # NOTE (T047): Renames are only detected when users share a channel. If a tracked
    # buddy renames in a channel the user hasn't joined, the :nick_changed broadcast
    # won't reach here. This mirrors real IRC behavior. A global rename broadcast
    # would be needed to fully solve this; documented as a known limitation.
    socket =
      if NotifyList.tracking?(socket.assigns.session.notify_list, old_nick) do
        session = socket.assigns.session
        updated_list = NotifyList.update_nickname(session.notify_list, old_nick, new_nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          "* Your notify list buddy #{old_nick} is now known as #{new_nick}",
          :notify_rename
        )
      else
        socket
      end

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:force_disconnect, %{reason: reason}}, socket) do
    cleanup_channels(socket.assigns.session)

    {:noreply,
     socket
     |> put_flash(:error, "Disconnected: #{reason}")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:force_rename, %{reason: reason}}, socket) do
    old_nickname = socket.assigns.session.nickname
    guest_nick = "Guest_#{:rand.uniform(99999)}"
    session = Session.update_nickname(socket.assigns.session, guest_nick)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nickname}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{guest_nick}")

    msg = "[NickServ] #{reason}. You are now #{guest_nick}"

    {:noreply,
     socket
     |> assign(session: session)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # Notify list: NickServ identify → load saved list (T017)
  def handle_info({:nickserv_identified, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick == session.nickname do
      new_session =
        session
        |> Session.set_identified(true)
        |> load_persisted_data(nick)

      {:noreply,
       socket
       |> assign(session: new_session)
       |> rebuild_nick_color_fn(new_session)
       |> push_status_message("You are now identified as #{nick}", :system)}
    else
      {:noreply, socket}
    end
  end

  # Notify list: Global presence events (T023)
  def handle_info({:user_connected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    # Ignore our own connect event
    if nick == session.nickname do
      {:noreply, socket}
    else
      if NotifyList.tracking?(session.notify_list, nick) do
        {:noreply, start_notify_debounce(socket, nick, :online)}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_info({:user_disconnected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if NotifyList.tracking?(session.notify_list, nick) do
      {:noreply, start_notify_debounce(socket, nick, :offline)}
    else
      {:noreply, socket}
    end
  end

  # Notify list: Debounce timer fires (T024)
  def handle_info({:notify_debounce, nickname, status}, socket) do
    session = socket.assigns.session
    timers = Map.delete(socket.assigns.notify_debounce_timers, String.downcase(nickname))

    online? = status == :online
    updated_list = NotifyList.set_online(session.notify_list, nickname, online?)
    new_session = Session.set_notify_list(session, updated_list)

    msg =
      if online?,
        do: "* #{nickname} is now online",
        else: "* #{nickname} has gone offline"

    type = if online?, do: :notify_online, else: :notify_offline

    socket =
      socket
      |> assign(session: new_session, notify_debounce_timers: timers)
      |> maybe_persist_notify_list(new_session)
      |> push_status_message(msg, type)

    # Auto-whois on connect
    socket =
      if online? && new_session.notify_list.settings.auto_whois do
        push_whois_info(socket, nickname)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: session.nickname}}
      )

      cleanup_channels(session)
    end

    :ok
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

  # -- Private helpers --

  defp apply_mode_to_users(users, "+o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :operator}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-o", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :regular}, else: user
    end)
  end

  defp apply_mode_to_users(users, "+v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :voiced}, else: user
    end)
  end

  defp apply_mode_to_users(users, "-v", params) do
    Enum.map(users, fn user ->
      if user.nickname in params, do: %{user | role: :regular}, else: user
    end)
  end

  defp apply_mode_to_users(users, _mode, _params), do: users

  defp close_context_menu(socket) do
    assign(socket,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil},
      show_context_color_picker: false
    )
  end

  defp context_ban(socket, nil, _nick), do: socket

  defp context_ban(socket, channel, nick) do
    case Server.ban(channel, socket.assigns.session.nickname, nick, nil) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp context_kick(socket, nil, _nick), do: socket

  defp context_kick(socket, channel, nick) do
    case Server.kick(channel, socket.assigns.session.nickname, nick, nil) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp context_set_mode(socket, nil, _mode, _params), do: socket

  defp context_set_mode(socket, channel, mode, params) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp maybe_start_nickserv_timer(socket, nickname) do
    if NickServ.registered?(nickname) do
      NickServ.start_identify_timer(nickname)

      notice =
        "[NickServ] This nickname is registered. " <>
          "You have 60 seconds to identify via /ns identify <password> or you will be renamed."

      stream_insert(socket, :chat_messages, service_message("NickServ", notice))
    else
      socket
    end
  end

  defp dispatch_command(socket, session, name, args) do
    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      operator_in: channels_where_operator(session)
    }

    result = Dispatcher.dispatch(name, args, context)
    handle_dispatch_result(socket, session, result)
  end

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
    do: handle_ui_action(socket, action, payload)

  defp handle_dispatch_result(socket, _session, {:ok, :system, %{content: text}}),
    do: stream_insert(socket, :chat_messages, service_message(detect_service_author(text), text))

  defp handle_dispatch_result(socket, _session, {:error, msg}),
    do: stream_insert(socket, :chat_messages, error_message(msg))

  defp handle_dispatch_result(socket, _session, _other), do: socket

  defp handle_ui_action(socket, :open_query, %{nickname: target}),
    do: open_pm_conversation(socket, target)

  defp handle_ui_action(socket, :open_channel_list, _),
    do: push_navigate(socket, to: ~p"/channels")

  defp handle_ui_action(socket, :clear_chat, _),
    do: stream(socket, :chat_messages, [], reset: true)

  defp handle_ui_action(socket, :set_away, %{message: message}),
    do: handle_set_away(socket, message)

  defp handle_ui_action(socket, :clear_away, _),
    do: handle_clear_away(socket)

  defp handle_ui_action(socket, :set_topic, %{channel: channel, topic: topic}),
    do: handle_set_topic(socket, channel, topic)

  defp handle_ui_action(socket, :view_topic, %{channel: channel}),
    do: handle_view_topic(socket, channel)

  defp handle_ui_action(socket, :open_whois, %{nickname: target}),
    do: assign(socket, show_whois: true, whois_target: target)

  defp handle_ui_action(socket, :show_help, %{commands: commands}),
    do: show_help_message(socket, commands)

  defp handle_ui_action(socket, :show_command_help, %{help: help}),
    do: show_command_help_message(socket, help)

  defp handle_ui_action(socket, :set_mode, %{
         channel: channel,
         mode_string: mode_string,
         params: params
       }) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode_string, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :kick_user, %{
         channel: channel,
         reason: reason,
         target: target
       }) do
    case Server.kick(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :ban_user, %{
         channel: channel,
         reason: reason,
         target: target
       }) do
    case Server.ban(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :open_notify_list, _payload) do
    assign(socket, show_notify_list: true)
  end

  defp handle_ui_action(socket, :notify_add, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Added #{nick} to notify list", :system)

      {:error, :self_add} ->
        push_status_message(socket, "Cannot add yourself to the notify list", :system)

      {:error, :duplicate} ->
        push_status_message(socket, "#{nick} is already in your notify list", :system)

      {:error, :list_full} ->
        push_status_message(socket, "Notify list is full (max 50 entries)", :system)
    end
  end

  defp handle_ui_action(socket, :notify_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Removed #{nick} from notify list", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
    end
  end

  defp handle_ui_action(socket, :notify_edit, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Updated note for #{nick}", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
    end
  end

  defp handle_ui_action(socket, :notify_list_display, _payload) do
    session = socket.assigns.session
    entries = NotifyList.sorted_entries(session.notify_list)

    if entries == [] do
      push_status_message(socket, "Your notify list is empty", :system)
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        push_status_message(acc, format_notify_entry(entry), :system)
      end)
    end
  end

  defp handle_ui_action(socket, _action, _payload), do: socket

  defp maybe_join_from_params(socket, %{"join" => channel_name})
       when is_binary(channel_name) and channel_name != "" do
    join_channel(socket, channel_name, socket.assigns.session)
  end

  defp maybe_join_from_params(socket, _params), do: socket

  defp join_channel(socket, channel_name, session, password \\ nil) do
    case ensure_channel_exists(channel_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start channel #{channel_name}: #{inspect(reason)}")
    end

    case Server.join(channel_name, session.nickname, password) do
      {:ok, _state} ->
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
        safe_track_user("channel:#{channel_name}", session.nickname)

        new_session =
          session
          |> Session.add_channel(channel_name)
          |> Session.set_active_channel(channel_name)

        socket
        |> assign(session: new_session, input: "")
        |> load_channel_users(channel_name)
        |> load_channel_messages_with_pagination(channel_name)

      {:error, reason} ->
        stream_insert(socket, :chat_messages, error_message(reason))
    end
  end

  defp part_channel(socket, channel_name) do
    session = socket.assigns.session

    try do
      Server.part(channel_name, session.nickname, nil)
    rescue
      e ->
        Logger.warning("Failed to part #{channel_name}: #{inspect(e)}")
        :ok
    end

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    safe_untrack_user("channel:#{channel_name}", session.nickname)
    new_session = Session.remove_channel(session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      socket
      |> load_channel_users(new_session.active_channel)
      |> load_channel_messages_with_pagination(new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false, channel_users: [])
      |> stream(:chat_messages, [], reset: true)
    end
  end

  defp part_channel_after_kick(socket, channel_name) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    safe_untrack_user("channel:#{channel_name}", socket.assigns.session.nickname)
    new_session = Session.remove_channel(socket.assigns.session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      load_channel_messages_with_pagination(socket, new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false)
      |> stream(:chat_messages, [], reset: true)
    end
  end

  defp load_channel_users(socket, channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        users =
          Enum.map(state.members, fn {nick, role} ->
            %{nickname: nick, role: role, away: false}
          end)

        assign(socket, channel_users: users)

      {:error, _} ->
        assign(socket, channel_users: [])
    end
  end

  defp ensure_channel_exists(channel_name) do
    case Registry.lookup(channel_name) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_child(channel_name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp channels_where_operator(session) do
    Enum.filter(session.channels, fn channel_name ->
      case Server.get_state(channel_name) do
        {:ok, state} -> session.nickname in state.operators
        {:error, _} -> false
      end
    end)
  end

  defp viewer_is_op?(session) do
    case session.active_channel do
      nil ->
        false

      channel ->
        case Server.get_state(channel) do
          {:ok, state} -> session.nickname in state.operators
          {:error, _} -> false
        end
    end
  rescue
    e ->
      Logger.warning("Failed to check operator status: #{inspect(e)}")
      false
  end

  defp send_plain_message(socket, session, text) do
    cond do
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

  defp handle_pm_send(socket, target, content) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    case Service.send_private_message(session.nickname, target, content) do
      {:ok, _pm} ->
        new_session = Session.add_pm_conversation(session, target)
        assign(socket, session: new_session)

      {:error, reason} ->
        stream_insert(socket, :chat_messages, error_message(reason))
    end
  end

  defp open_pm_conversation(socket, target) do
    session = socket.assigns.session
    ensure_pm_subscription(session.nickname, target)

    new_session =
      session
      |> Session.add_pm_conversation(target)
      |> Session.set_active_pm(target)

    messages = load_pm_messages(new_session.nickname, target)

    socket
    |> assign(session: new_session, input: "")
    |> stream(:chat_messages, messages, reset: true)
  end

  defp ensure_pm_subscription(nick_a, nick_b) do
    topic = "pm:#{pm_topic(nick_a, nick_b)}"
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
  end

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp pm_other_nick(payload, my_nick) do
    if payload.sender == my_nick, do: payload.recipient, else: payload.sender
  end

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
    older_messages = Queries.list_messages(channel, limit: 50, before_id: oldest_id)
    prepend_older_messages(assign(socket, loading_more: true), older_messages)
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

  defp load_channel_messages_with_pagination(socket, channel_name) do
    raw_messages = Queries.list_messages(channel_name, limit: 50)

    # raw_messages is in desc order; last element is the oldest
    oldest_id =
      case List.last(raw_messages) do
        nil -> nil
        msg -> msg.id
      end

    stream_items =
      raw_messages
      |> Enum.reverse()
      |> Enum.map(&message_to_stream_item/1)

    socket
    |> assign(
      oldest_message_id: oldest_id,
      has_more: length(raw_messages) == 50,
      loading_more: false,
      new_messages_indicator: false
    )
    |> stream(:chat_messages, stream_items, reset: true)
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

  # -- Search helpers --

  defp do_search(socket, "") do
    clear_search_state(socket)
  end

  defp do_search(socket, query) do
    channel = socket.assigns.session.active_channel

    if channel do
      count = Search.count_matches(channel, query)
      results = Search.search_messages(channel, query)

      assign(socket,
        search_query: query,
        search_results: results,
        search_result_count: count,
        search_current_index: min(1, count)
      )
    else
      assign(socket, search_query: query, search_results: [], search_result_count: 0)
    end
  end

  defp clear_search_state(socket) do
    assign(socket,
      search_visible: false,
      search_query: "",
      search_results: [],
      search_result_count: 0,
      search_current_index: 0
    )
  end

  # -- US4 command dispatch helpers --

  defp handle_action_message(socket, session, content) do
    cond do
      session.active_pm ->
        case Service.send_private_message(session.nickname, session.active_pm, content, "action") do
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

  defp handle_nick_change(socket, new_nick) do
    old_nick = socket.assigns.session.nickname
    session = Session.update_nickname(socket.assigns.session, new_nick)

    # Update Server membership for all channels
    Enum.each(session.channels, fn channel ->
      try do
        Server.rename_user(channel, old_nick, new_nick)
      rescue
        e ->
          Logger.warning("Failed to rename #{old_nick}->#{new_nick} in #{channel}: #{inspect(e)}")
      end
    end)

    # Broadcast nick change to all shared channels
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

    # Update Presence: untrack old, track new
    Enum.each(session.channels, fn channel ->
      safe_untrack_user("channel:#{channel}", old_nick)
      safe_track_user("channel:#{channel}", new_nick)
    end)

    # Resubscribe user topic
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nick}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{new_nick}")

    # Update nicklist
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now known as #{new_nick}"))
    |> assign(session: session, channel_users: users)
  end

  defp handle_quit(socket, _reason) do
    cleanup_channels(socket.assigns.session)
    push_navigate(socket, to: ~p"/")
  end

  defp handle_set_away(socket, message) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now away: #{message}"))
    |> assign(session: session)
  end

  defp handle_clear_away(socket) do
    session = socket.assigns.session
    new_session = Session.set_away(session, nil)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, false, nil)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are no longer away"))
    |> assign(session: new_session)
  end

  defp handle_set_topic(socket, channel, topic) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok ->
        socket

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_view_topic(socket, channel) do
    case Server.get_state(channel) do
      {:ok, state} ->
        topic_text = if state.topic == "", do: "No topic set", else: state.topic

        stream_insert(
          socket,
          :chat_messages,
          system_message("Topic for #{channel}: #{topic_text}")
        )

      {:error, _} ->
        socket
    end
  end

  defp show_help_message(socket, commands) do
    text = "Available commands: " <> Enum.join(Enum.map(commands, &"/#{&1}"), ", ")
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp show_command_help_message(socket, help) do
    text = "#{help.syntax} - #{help.description}"
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp safe_track_user(topic, nickname) do
    case Tracker.track_user(topic, nickname) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.track_user(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  defp safe_untrack_user(topic, nickname) do
    Tracker.untrack_user(topic, nickname)
  rescue
    e -> Logger.warning("Tracker.untrack_user(#{topic}, #{nickname}): #{inspect(e)}")
  end

  defp safe_update_away(topic, nickname, away, message) do
    case Tracker.update_away(topic, nickname, away, message) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.update_away(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  # -- Notify list helpers --

  defp push_status_message(socket, content, type) do
    msg = %{
      id: "status-#{System.unique_integer([:positive])}",
      content: content,
      type: type,
      timestamp: DateTime.utc_now()
    }

    stream_insert(socket, :status_messages, msg)
  end

  defp maybe_persist_notify_list(socket, session) do
    if session.identified do
      Task.start(fn -> NotifyList.save(session.nickname, session.notify_list) end)
    end

    socket
  end

  defp maybe_persist_contacts(socket, session) do
    if session.identified do
      Task.start(fn -> ContactList.save(session.nickname, session.contacts) end)
    end

    socket
  end

  defp maybe_persist_nick_colors(socket, session) do
    if session.identified do
      Task.start(fn -> NickColors.save(session.nickname, session.nick_colors) end)
    end

    socket
  end

  defp maybe_persist_highlight_words(socket, session) do
    if session.identified do
      Task.start(fn -> HighlightWords.save(session.nickname, session.highlight_words) end)
    end

    socket
  end

  @spec load_persisted_data(Session.t(), String.t()) :: Session.t()
  defp load_persisted_data(session, nick) do
    session
    |> load_if_found(NotifyList.load(nick), &Session.set_notify_list/2)
    |> load_if_found(ContactList.load(nick), &Session.set_contacts/2)
    |> load_if_found(NickColors.load(nick), &Session.set_nick_colors/2)
    |> load_if_found(HighlightWords.load(nick), &Session.set_highlight_words/2)
  end

  @spec load_if_found(Session.t(), {:ok, term()} | {:error, term()}, (Session.t(), term() ->
                                                                        Session.t())) ::
          Session.t()
  defp load_if_found(session, {:ok, data}, setter), do: setter.(session, data)
  defp load_if_found(session, {:error, _}, _setter), do: session

  @spec build_nick_color_fn(Session.t()) :: (String.t() -> String.t())
  defp build_nick_color_fn(session) do
    fn nickname ->
      NickColors.color_for(session.nick_colors, nickname) || nick_color(nickname)
    end
  end

  defp rebuild_nick_color_fn(socket, session) do
    assign(socket, nick_color_fn: build_nick_color_fn(session))
  end

  defp start_notify_debounce(socket, nickname, status) do
    key = String.downcase(nickname)
    timers = socket.assigns.notify_debounce_timers

    # Cancel existing timer for this nick if any
    timers =
      case Map.get(timers, key) do
        nil ->
          timers

        {old_ref, _old_status} ->
          Process.cancel_timer(old_ref)
          Map.delete(timers, key)
      end

    # Start new timer (10 second debounce)
    ref = Process.send_after(self(), {:notify_debounce, nickname, status}, 10_000)
    new_timers = Map.put(timers, key, {ref, status})
    assign(socket, notify_debounce_timers: new_timers)
  end

  defp cancel_notify_timer(socket, nickname) do
    key = String.downcase(nickname)
    timers = socket.assigns.notify_debounce_timers

    case Map.pop(timers, key) do
      {nil, _} ->
        socket

      {{ref, _status}, new_timers} ->
        Process.cancel_timer(ref)
        assign(socket, notify_debounce_timers: new_timers)
    end
  end

  defp push_whois_info(socket, nickname) do
    {:ok, info} = NotifyList.whois_info(nickname)

    info_lines = ["[Auto-Whois] #{nickname}:"]

    info_lines =
      if info.registered do
        registered = if info.identified, do: "identified", else: "not identified"
        info_lines ++ ["  Registered: yes (#{registered})"]
      else
        info_lines ++ ["  Registered: no"]
      end

    Enum.reduce(info_lines, socket, fn line, acc ->
      push_status_message(acc, line, :system)
    end)
  end

  defp format_notify_entry(entry) do
    status = if entry.online, do: "online", else: "offline"
    note = if entry.note, do: " - #{entry.note}", else: ""
    "  #{entry.tracked_nickname} [#{status}]#{note}"
  end

  defp system_message(content) do
    %{
      id: "system-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :system,
      timestamp: DateTime.utc_now()
    }
  end

  defp error_message(content) do
    %{
      id: "error-#{System.unique_integer([:positive])}",
      author: "System",
      content: content,
      type: :error,
      timestamp: DateTime.utc_now()
    }
  end

  defp detect_service_author("[ChanServ]" <> _), do: "ChanServ"
  defp detect_service_author("[NickServ]" <> _), do: "NickServ"
  defp detect_service_author(_), do: "Service"

  defp service_message(author, content) do
    %{
      id: "service-#{System.unique_integer([:positive])}",
      author: author,
      content: content,
      type: :service,
      timestamp: DateTime.utc_now()
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="app-container"
      phx-click="close_context_menu"
      phx-window-keydown="window_keydown"
      id="app-container"
      phx-hook="SoundHook"
    >
      <RetroHexChatWeb.Components.TitleBar.title_bar />
      <RetroHexChatWeb.Components.MenuBar.menu_bar />
      <RetroHexChatWeb.Components.Toolbar.toolbar connected={true} />

      <div class="mdi-layout">
        <RetroHexChatWeb.Components.Treebar.treebar
          :if={@show_treebar}
          channels={@session.channels}
          active_channel={@session.active_channel}
          unread_channels={MapSet.to_list(@unread_channels)}
          highlight_channels={MapSet.to_list(@highlight_channels)}
          pm_conversations={@session.pm_conversations}
          active_pm={@session.active_pm}
        />

        <div class="chat-area" style="position: relative;">
          <RetroHexChatWeb.Components.SearchBar.search_bar
            visible={@search_visible}
            query={@search_query}
            result_count={@search_result_count}
            current_index={@search_current_index}
          />

          <RetroHexChatWeb.Components.ScrollLoader.scroll_loader loading={@loading_more} />

          <div class="chat-messages" id="chat-messages" phx-update="stream" phx-hook="ScrollHook">
            <div
              :for={{dom_id, msg} <- @streams.chat_messages}
              id={dom_id}
              class={
                "chat-message chat-message--#{msg.type}" <>
                  if(Map.get(msg, :highlighted), do: " chat-message--highlighted", else: "")
              }
              style={
                if(Map.get(msg, :highlighted) && Map.get(msg, :highlight_color),
                  do: "background-color: #{msg.highlight_color}",
                  else: nil
                )
              }
              data-testid={if(Map.get(msg, :highlighted), do: "highlighted-message", else: nil)}
            >
              <span class="chat-timestamp">[{format_time(msg.timestamp)}]</span>
              <%= case msg.type do %>
                <% :action -> %>
                  <span class="chat-action">
                    * {msg.author} {raw(format_content(msg.content, @session.strip_formatting))}
                  </span>
                <% :system -> %>
                  <span class="chat-system">* {msg.content}</span>
                <% :service -> %>
                  <span class="chat-service">{msg.content}</span>
                <% :error -> %>
                  <span class="chat-error">{msg.content}</span>
                <% _ -> %>
                  <span class="chat-nick" style={"color: #{@nick_color_fn.(msg.author)}"}>
                    &lt;{msg.author}&gt;
                  </span>
                  <span class="chat-content">
                    {raw(format_content(msg.content, @session.strip_formatting))}
                  </span>
              <% end %>
            </div>
          </div>

          <RetroHexChatWeb.Components.FormattingToolbar.formatting_toolbar strip_formatting={
            @session.strip_formatting
          } />

          <div class="chat-input-area" style="position: relative;">
            <RetroHexChatWeb.Components.CommandPalette.command_palette
              visible={@command_palette_visible}
              commands={CmdRegistry.list_commands()}
              filter={@command_palette_filter}
            />
            <form phx-submit="send_input" class="chat-input-form">
              <input
                type="text"
                name="input"
                id="chat-input"
                value={@input}
                placeholder="Type a message or /command..."
                autocomplete="off"
                autofocus
                phx-hook="CommandPaletteHook"
              />
              <button type="submit">Send</button>
            </form>
          </div>
        </div>

        <RetroHexChatWeb.Components.Nicklist.nicklist
          :if={@show_nicklist && !@session.active_pm}
          users={@channel_users}
          nick_color_fn={@nick_color_fn}
        />
      </div>

      <RetroHexChatWeb.Components.ContextMenu.context_menu
        visible={@context_menu.visible}
        x={@context_menu.x}
        y={@context_menu.y}
        target_nick={@context_menu.target_nick}
        viewer_is_op={viewer_is_op?(@session)}
        nick_color_fn={@nick_color_fn}
        show_color_picker={@show_context_color_picker}
      />

      <RetroHexChatWeb.Components.Dialog.dialog
        title="About RetroHexChat"
        visible={@show_about}
        on_close="close_dialog"
      >
        <p>RetroHexChat v1.0</p>
        <p>A retro IRC-style chat with Windows 98 aesthetics.</p>
        <p>Built with Elixir, Phoenix LiveView, and 98.css.</p>
      </RetroHexChatWeb.Components.Dialog.dialog>

      <RetroHexChatWeb.Components.NotifyListWindow.notify_list_window
        entries={NotifyList.sorted_entries(@session.notify_list)}
        visible={@show_notify_list}
        selected_entry={@notify_selected}
        show_add_dialog={@show_notify_add_dialog}
        show_edit_dialog={@show_notify_edit_dialog}
        auto_whois={@session.notify_list.settings.auto_whois}
        nick_color_fn={@nick_color_fn}
      />

      <RetroHexChatWeb.Components.AddressBookDialog.address_book_dialog
        visible={@show_address_book}
        active_tab={@address_book_tab}
        contacts={ContactList.sorted_entries(@session.contacts)}
        contacts_selected={@contacts_selected}
        show_contact_add_dialog={@show_contact_add_dialog}
        show_contact_edit_dialog={@show_contact_edit_dialog}
        notify_entries={NotifyList.sorted_entries(@session.notify_list)}
        notify_selected={@notify_selected}
        show_notify_add_dialog={@show_notify_add_dialog}
        show_notify_edit_dialog={@show_notify_edit_dialog}
        auto_whois={@session.notify_list.settings.auto_whois}
        nick_color_entries={NickColors.sorted_entries(@session.nick_colors)}
        nick_colors_selected={@nick_colors_selected}
        show_nick_color_add_dialog={@show_nick_color_add_dialog}
        show_nick_color_edit_dialog={@show_nick_color_edit_dialog}
      />

      <RetroHexChatWeb.Components.HighlightDialog.highlight_dialog
        visible={@show_highlight_dialog}
        highlight_entries={HighlightWords.entries(@session.highlight_words)}
        highlight_selected={@highlight_selected}
        own_nick={@session.nickname}
        show_highlight_add_dialog={@show_highlight_add_dialog}
        show_highlight_edit_dialog={@show_highlight_edit_dialog}
      />

      <div class="status-panel" style="height: 120px; border-top: 1px solid #808080;">
        <RetroHexChatWeb.Components.StatusWindow.status_window>
          <div
            id="status-messages"
            phx-update="stream"
            style="font-size: 12px; font-family: monospace;"
          >
            <div :for={{dom_id, msg} <- @streams.status_messages} id={dom_id}>
              <span style={RetroHexChatWeb.Components.StatusWindow.status_message_style(msg.type)}>
                [{RetroHexChatWeb.Components.StatusWindow.format_time(msg.timestamp)}] {msg.content}
              </span>
            </div>
          </div>
        </RetroHexChatWeb.Components.StatusWindow.status_window>
      </div>

      <RetroHexChatWeb.Components.StatusBar.status_bar
        nickname={@session.nickname}
        channel={@session.active_pm || @session.active_channel}
        user_count={length(@channel_users)}
      />
    </div>
    """
  end

  @nick_colors ~w(#e74c3c #3498db #2ecc71 #e67e22 #9b59b6 #1abc9c #f39c12 #e91e63 #00bcd4 #8bc34a #ff5722 #607d8b)

  @spec maybe_highlight(map(), Session.t()) :: map()
  defp maybe_highlight(%{type: type} = payload, session)
       when type in [:message, :action] do
    words = Session.get_highlight_words(session).entries

    case Highlight.check(payload.content, session.nickname, words, payload.author) do
      {:highlight, color} ->
        Map.merge(payload, %{highlighted: true, highlight_color: color})

      :no_highlight ->
        payload
    end
  end

  defp maybe_highlight(payload, _session), do: payload

  @spec maybe_play_highlight_sound(Phoenix.LiveView.Socket.t(), map(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_play_highlight_sound(socket, %{highlighted: true}, channel) do
    if channel_muted?(channel),
      do: socket,
      else: push_event(socket, "play_sound", %{type: "mention"})
  end

  defp maybe_play_highlight_sound(socket, _payload, _channel), do: socket

  @spec channel_muted?(String.t()) :: boolean()
  defp channel_muted?(_channel), do: false

  @spec parse_optional_color(String.t() | nil) :: non_neg_integer() | nil
  defp parse_optional_color(nil), do: nil
  defp parse_optional_color(""), do: nil

  defp parse_optional_color(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @spec format_content(String.t(), boolean()) :: String.t()
  defp format_content(content, strip_formatting) do
    if strip_formatting do
      content |> Formatter.strip() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    else
      {:safe, html} = Formatter.to_safe_html(content)
      html
    end
  end

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  defp format_time(_), do: "--:--"

  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end
end
