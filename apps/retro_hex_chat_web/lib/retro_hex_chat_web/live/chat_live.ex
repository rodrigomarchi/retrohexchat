defmodule RetroHexChatWeb.ChatLive do
  @moduledoc """
  Main chat interface with MDI layout: treebar, chat area, nicklist, status bar.
  """
  use RetroHexChatWeb, :live_view

  require Logger

  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, Session}
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  alias RetroHexChat.Chat.{
    AutoJoinList,
    CapturedURL,
    CtcpSettings,
    DisplayPreferences,
    DuplicateTracker,
    Favorites,
    FloodProtection,
    FloodTracker,
    Formatter,
    HelpTopics,
    Highlight,
    HighlightWords,
    IgnoreList,
    LinkPreview,
    LogExporter,
    LogFilter,
    LogQueries,
    NoticeRouting,
    PerformList,
    Queries,
    Search,
    Service,
    SoundSettings,
    URLDetector
  }

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
            |> maybe_trigger_perform()
            |> play_event_sound(:connect, session)

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
      link_previews: %{},
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
      show_status_tab: false,
      show_notify_add_dialog: false,
      show_notify_edit_dialog: false,
      show_notify_list: false,
      help_active_tab: "contents",
      help_index_filter: "",
      help_search_query: "",
      help_search_results: [],
      help_selected_topic: nil,
      highlight_channels: MapSet.new(),
      highlight_selected: nil,
      show_help_dialog: false,
      show_highlight_add_dialog: false,
      show_highlight_dialog: false,
      show_highlight_edit_dialog: false,
      current_topic: nil,
      current_modes: nil,
      show_treebar: true,
      show_url_catcher: false,
      show_whois: false,
      unread_channels: MapSet.new(),
      url_catcher_entries: [],
      url_catcher_filter_channel: nil,
      url_catcher_search_query: "",
      url_catcher_sort_column: :timestamp,
      url_catcher_sort_direction: :desc,
      whois_target: nil,
      ignore_timers: %{},
      show_ignore_dialog: false,
      ignore_selected: nil,
      show_ignore_add_dialog: false,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_state: nil,
      channel_central_channel: nil,
      channel_central_operator: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false,
      show_perform_dialog: false,
      perform_dialog_tab: "commands",
      perform_selected: nil,
      show_perform_add_dialog: false,
      show_perform_edit_dialog: false,
      autojoin_selected: nil,
      show_autojoin_add_dialog: false,
      show_autojoin_edit_dialog: false,
      show_log_viewer: false,
      log_filter: LogFilter.new(),
      log_source_options: [],
      log_page: nil,
      log_loading: false,
      log_preferences: DisplayPreferences.new(),
      log_exporting: false,
      log_error: nil,
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_active_pm: nil,
      ctcp_pending: %{},
      ctcp_rate_limits: %{},
      show_ctcp_settings_dialog: false,
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
      ctcp_reply_tracker: %{timestamps: []},
      show_flood_protection_dialog: false,
      show_sound_settings_dialog: false,
      sound_settings_draft: nil,
      muted: false,
      favorite_dialog_channel: nil,
      favorite_dialog_data: nil,
      favorite_dialog_is_duplicate: false,
      favorite_dialog_mode: :add,
      flash_channels: MapSet.new(),
      organize_favorites_selected: nil,
      pm_typing_from: nil,
      pm_typing_timer: nil,
      show_favorite_dialog: false,
      show_organize_favorites: false,
      treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil}
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
        new_session = Session.set_last_message_at(session, DateTime.utc_now())
        socket = socket |> assign(session: new_session) |> send_plain_message(new_session, text)
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
    flash = MapSet.delete(socket.assigns.flash_channels, channel)
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:noreply,
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

  def handle_event("switch_pm", %{"nickname" => nickname}, socket) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    messages = load_pm_messages(session.nickname, nickname)
    unread = MapSet.delete(socket.assigns.unread_channels, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")
    if socket.assigns.pm_typing_timer, do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    {:noreply,
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

  def handle_event("switch_to_status", _params, socket) do
    {:noreply, assign(socket, show_status_tab: true)}
  end

  def handle_event("close_channel_tab", %{"channel" => channel}, socket) do
    {:noreply, part_channel(socket, channel)}
  end

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

    {:noreply, socket}
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

  def handle_event("window_keydown", %{"key" => "i", "altKey" => true}, socket) do
    if socket.assigns.show_ignore_dialog do
      {:noreply,
       assign(socket,
         show_ignore_dialog: false,
         ignore_selected: nil,
         show_ignore_add_dialog: false
       )}
    else
      {:noreply, assign(socket, show_ignore_dialog: true)}
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

  def handle_event("window_keydown", %{"key" => "u", "altKey" => true}, socket) do
    {:noreply, assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)}
  end

  def handle_event("window_keydown", %{"key" => "l", "altKey" => true}, socket) do
    if socket.assigns.show_log_viewer do
      {:noreply, close_log_viewer(socket)}
    else
      {:noreply, open_log_viewer(socket)}
    end
  end

  def handle_event("window_keydown", %{"key" => "p", "altKey" => true}, socket) do
    if socket.assigns.show_perform_dialog do
      {:noreply, close_perform_dialog(socket)}
    else
      {:noreply, assign(socket, show_perform_dialog: true)}
    end
  end

  def handle_event("window_keydown", %{"key" => "F1"}, socket) do
    {:noreply, open_help_dialog(socket)}
  end

  def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
    cond do
      socket.assigns.pending_invites != [] ->
        # Dismiss the most recent invite (last in list)
        last = List.last(socket.assigns.pending_invites)
        Process.cancel_timer(last.timer_ref)
        remaining = List.delete_at(socket.assigns.pending_invites, -1)
        try_remove_invite_exception(last.channel, socket.assigns.session.nickname)
        {:noreply, assign(socket, pending_invites: remaining)}

      socket.assigns.show_perform_dialog ->
        {:noreply, close_perform_dialog(socket)}

      socket.assigns.show_log_viewer ->
        {:noreply, close_log_viewer(socket)}

      socket.assigns.show_channel_central ->
        {:noreply, close_channel_central(socket)}

      socket.assigns.search_visible ->
        {:noreply, clear_search_state(socket)}

      true ->
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

  # ── Favorites Events ────────────────────────────────────────

  def handle_event("channel_right_click", %{"channel" => channel} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:noreply,
     assign(socket,
       treebar_context_menu: %{visible: true, x: x, y: y, channel: channel}
     )}
  end

  def handle_event("close_treebar_context_menu", _params, socket) do
    {:noreply, assign(socket, treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil})}
  end

  def handle_event("add_to_favorites", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)

    if Favorites.has_entry?(favorites, channel) do
      existing = Favorites.find_entry(favorites, channel)

      {:noreply,
       assign(socket,
         treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
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
      {:noreply,
       assign(socket,
         treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
         show_favorite_dialog: true,
         favorite_dialog_mode: :add,
         favorite_dialog_channel: channel,
         favorite_dialog_is_duplicate: false,
         favorite_dialog_data: nil
       )}
    end
  end

  def handle_event("save_favorite", params, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)
    channel = params["channel_name"]
    password = if params["password"] != "", do: params["password"]
    auto_join = params["auto_join"] == "true"

    attrs = %{
      channel_name: channel,
      description: params["description"] || "",
      password: password,
      auto_join: auto_join
    }

    updated_favorites =
      if Favorites.has_entry?(favorites, channel) do
        case Favorites.update_entry(favorites, channel, attrs) do
          {:ok, updated} -> updated
          {:error, _} -> favorites
        end
      else
        case Favorites.add_entry(favorites, attrs) do
          {:ok, updated} -> updated
          {:error, _} -> favorites
        end
      end

    new_session = Session.set_favorites(session, updated_favorites)
    maybe_persist_favorites(socket, new_session)

    {:noreply,
     assign(socket,
       session: new_session,
       show_favorite_dialog: false,
       favorite_dialog_channel: nil,
       favorite_dialog_data: nil,
       favorite_dialog_is_duplicate: false
     )}
  end

  def handle_event("close_favorite_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_favorite_dialog: false,
       favorite_dialog_channel: nil,
       favorite_dialog_data: nil,
       favorite_dialog_is_duplicate: false
     )}
  end

  def handle_event("join_favorite", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)

    if channel in session.channels do
      # Already joined — just switch
      new_session = Session.set_active_channel(session, channel)
      {:noreply, assign(socket, session: new_session)}
    else
      # Join using saved password if available
      entry = Favorites.find_entry(favorites, channel)
      password = if entry, do: entry.password

      {:noreply, join_channel(socket, channel, session, password)}
    end
  end

  def handle_event("open_organize_favorites", _params, socket) do
    {:noreply, assign(socket, show_organize_favorites: true, organize_favorites_selected: nil)}
  end

  def handle_event("close_organize_favorites", _params, socket) do
    {:noreply, assign(socket, show_organize_favorites: false, organize_favorites_selected: nil)}
  end

  def handle_event("favorite_select", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, organize_favorites_selected: channel)}
  end

  def handle_event("favorite_move_up", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      updated = Favorites.move_up(favorites, selected)
      new_session = Session.set_favorites(session, updated)
      maybe_persist_favorites(socket, new_session)
      {:noreply, assign(socket, session: new_session)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("favorite_move_down", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      updated = Favorites.move_down(favorites, selected)
      new_session = Session.set_favorites(session, updated)
      maybe_persist_favorites(socket, new_session)
      {:noreply, assign(socket, session: new_session)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("favorite_edit", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      entry = Favorites.find_entry(favorites, selected)

      if entry do
        {:noreply,
         assign(socket,
           show_favorite_dialog: true,
           favorite_dialog_mode: :edit,
           favorite_dialog_channel: entry.channel_name,
           favorite_dialog_is_duplicate: false,
           favorite_dialog_data: %{
             description: entry.description,
             auto_join: entry.auto_join,
             has_password: entry.password != nil and entry.password != ""
           }
         )}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("favorite_remove", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)

      case Favorites.remove_entry(favorites, selected) do
        {:ok, updated} ->
          new_session = Session.set_favorites(session, updated)
          maybe_persist_favorites(socket, new_session)
          {:noreply, assign(socket, session: new_session, organize_favorites_selected: nil)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
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

  def handle_event("context_ignore", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case IgnoreList.add_entry(session.ignore_list, nick, :all, nil) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:noreply,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(:chat_messages, system_message("* #{nick} is now ignored"))}

      {:error, :list_full} ->
        {:noreply,
         socket
         |> close_context_menu()
         |> stream_insert(:chat_messages, error_message("Ignore list is full (max 100 entries)"))}

      {:error, _reason} ->
        {:noreply, close_context_menu(socket)}
    end
  end

  def handle_event("context_unignore", %{"nick" => nick}, socket) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:noreply,
         socket
         |> close_context_menu()
         |> assign(session: new_session)
         |> cancel_ignore_timer(nick)
         |> cancel_auto_ignore_with_cooldown(nick)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(:chat_messages, system_message("* #{nick} is no longer ignored"))}

      {:error, :not_found} ->
        {:noreply, close_context_menu(socket)}
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

    {:noreply,
     socket
     |> push_event("intentional_disconnect", %{})
     |> push_navigate(to: ~p"/")}
  end

  def handle_event("restore_session", params, socket) do
    {:noreply, restore_session(socket, params)}
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

  # Help dialog events
  def handle_event("toggle_help_dialog", _params, socket) do
    if socket.assigns.show_help_dialog do
      {:noreply, close_help_dialog(socket)}
    else
      {:noreply, open_help_dialog(socket)}
    end
  end

  def handle_event("close_help", _params, socket) do
    {:noreply, close_help_dialog(socket)}
  end

  def handle_event("help_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, help_active_tab: tab)}
  end

  def handle_event("help_select_topic", %{"id" => id}, socket) do
    {:noreply, assign(socket, help_selected_topic: HelpTopics.get_topic(id))}
  end

  def handle_event("help_index_filter", %{"value" => filter}, socket) do
    {:noreply, assign(socket, help_index_filter: filter)}
  end

  def handle_event("help_search_input", %{"key" => "Enter", "value" => query}, socket) do
    {:noreply,
     assign(socket, help_search_query: query, help_search_results: HelpTopics.search(query))}
  end

  def handle_event("help_search_input", %{"value" => query}, socket) do
    {:noreply, assign(socket, help_search_query: query)}
  end

  def handle_event("help_search", %{"query" => query}, socket) do
    {:noreply, assign(socket, help_search_results: HelpTopics.search(query))}
  end

  def handle_event("help_content_click", %{"data-help-topic" => topic_id}, socket) do
    {:noreply, assign(socket, help_selected_topic: HelpTopics.get_topic(topic_id))}
  end

  def handle_event("help_content_click", _params, socket) do
    {:noreply, socket}
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

  # Ignore dialog events
  def handle_event("open_ignore_dialog", _params, socket) do
    {:noreply, assign(socket, show_ignore_dialog: true)}
  end

  def handle_event("close_ignore_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_ignore_dialog: false,
       ignore_selected: nil,
       show_ignore_add_dialog: false
     )}
  end

  def handle_event("ignore_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, ignore_selected: nick)}
  end

  def handle_event("ignore_dialog_add", _params, socket) do
    {:noreply, assign(socket, show_ignore_add_dialog: true)}
  end

  def handle_event("close_ignore_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_ignore_add_dialog: false)}
  end

  def handle_event("ignore_dialog_add_confirm", params, socket) do
    nick = params["nickname"]
    type = String.to_existing_atom(params["type"])
    duration_str = params["duration"]

    {duration, expires_at} = parse_dialog_duration(duration_str)

    session = socket.assigns.session

    case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_ignore_add_dialog: false)
         |> cancel_ignore_timer(nick)
         |> maybe_start_ignore_timer(nick, duration)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(:chat_messages, system_message("* #{nick} is now ignored (#{type})"))}

      {:error, reason} ->
        {:noreply,
         stream_insert(socket, :chat_messages, error_message("Failed to add ignore: #{reason}"))}
    end
  end

  def handle_event("ignore_dialog_remove", _params, socket) do
    nick = socket.assigns.ignore_selected

    if nick do
      session = socket.assigns.session

      case IgnoreList.remove_entry(session.ignore_list, nick) do
        {:ok, updated_list} ->
          new_session = Session.set_ignore_list(session, updated_list)

          {:noreply,
           socket
           |> assign(session: new_session, ignore_selected: nil)
           |> cancel_ignore_timer(nick)
           |> cancel_auto_ignore_with_cooldown(nick)
           |> maybe_persist_ignore_list(new_session)
           |> stream_insert(:chat_messages, system_message("* #{nick} is no longer ignored"))}

        {:error, :not_found} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Perform dialog events ─────────────────────────────────

  def handle_event("open_ctcp_settings_dialog", _params, socket) do
    {:noreply, assign(socket, show_ctcp_settings_dialog: true)}
  end

  def handle_event("close_ctcp_settings_dialog", _params, socket) do
    {:noreply, assign(socket, show_ctcp_settings_dialog: false)}
  end

  def handle_event("ctcp_save_settings", params, socket) do
    session = socket.assigns.session
    settings = session.ctcp_settings

    settings =
      settings
      |> CtcpSettings.set_enabled(params["enabled"] == "true")
      |> CtcpSettings.set_version_string(params["version_string"] || "RetroHexChat v1.0")
      |> CtcpSettings.set_finger_text(
        case params["finger_text"] do
          "" -> nil
          nil -> nil
          text -> text
        end
      )

    new_session = Session.set_ctcp_settings(session, settings)

    if new_session.identified do
      Task.start(fn ->
        CtcpSettings.save(new_session.nickname, settings)
      end)
    end

    {:noreply,
     socket
     |> assign(session: new_session, show_ctcp_settings_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* CTCP settings saved")
     )}
  end

  def handle_event("open_flood_protection_dialog", _params, socket) do
    {:noreply, assign(socket, show_flood_protection_dialog: true)}
  end

  def handle_event("close_flood_protection_dialog", _params, socket) do
    {:noreply, assign(socket, show_flood_protection_dialog: false)}
  end

  def handle_event("flood_save_settings", params, socket) do
    session = socket.assigns.session
    settings = session.flood_protection

    settings =
      settings
      |> try_set(&FloodProtection.set_flood_threshold/2, params["flood_threshold"])
      |> try_set(&FloodProtection.set_flood_window_seconds/2, params["flood_window_seconds"])
      |> try_set(
        &FloodProtection.set_auto_ignore_duration_seconds/2,
        params["auto_ignore_duration_seconds"]
      )
      |> try_set(&FloodProtection.set_spam_threshold/2, params["spam_threshold"])
      |> try_set(&FloodProtection.set_spam_window_seconds/2, params["spam_window_seconds"])
      |> try_set(&FloodProtection.set_ctcp_reply_limit/2, params["ctcp_reply_limit"])
      |> try_set(
        &FloodProtection.set_ctcp_reply_window_seconds/2,
        params["ctcp_reply_window_seconds"]
      )

    new_session = Session.set_flood_protection(session, settings)

    if new_session.identified do
      Task.start(fn -> FloodProtection.save(new_session.nickname, settings) end)
    end

    {:noreply,
     socket
     |> assign(session: new_session, show_flood_protection_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* Flood protection settings saved")
     )}
  end

  def handle_event("flood_reset_defaults", _params, socket) do
    session = socket.assigns.session
    defaults = FloodProtection.new()
    new_session = Session.set_flood_protection(session, defaults)

    if new_session.identified do
      Task.start(fn -> FloodProtection.save(new_session.nickname, defaults) end)
    end

    {:noreply,
     socket
     |> assign(session: new_session, show_flood_protection_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* Flood protection settings reset to defaults")
     )}
  end

  # ── Sound Settings Dialog ──────────────────────────────────

  def handle_event("open_sound_settings_dialog", _params, socket) do
    draft = socket.assigns.session.sound_settings

    {:noreply,
     assign(socket,
       show_sound_settings_dialog: true,
       sound_settings_draft: draft
     )}
  end

  def handle_event("close_sound_settings_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_sound_settings_dialog: false,
       sound_settings_draft: nil
     )}
  end

  def handle_event("sound_settings_change", params, socket) do
    draft = socket.assigns.sound_settings_draft

    updated_draft =
      Enum.reduce(SoundSettings.event_types(), draft, fn event, acc ->
        key = "event_#{event}"

        case Map.get(params, key) do
          nil -> acc
          sound_name -> SoundSettings.set_sound(acc, event, sound_name)
        end
      end)

    {:noreply, assign(socket, sound_settings_draft: updated_draft)}
  end

  def handle_event("sound_flash_toggle", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    draft = socket.assigns.sound_settings_draft
    current = SoundSettings.get_flash(draft, event)
    updated_draft = SoundSettings.set_flash(draft, event, not current)

    {:noreply, assign(socket, sound_settings_draft: updated_draft)}
  end

  def handle_event("sound_preview", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    draft = socket.assigns.sound_settings_draft
    sound = SoundSettings.get_sound(draft, event)

    if sound == "none" do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "play_sound", %{type: sound})}
    end
  end

  def handle_event("sound_settings_apply", _params, socket) do
    draft = socket.assigns.sound_settings_draft
    session = socket.assigns.session
    new_session = Session.set_sound_settings(session, draft)

    if new_session.identified do
      Task.start(fn -> SoundSettings.save(new_session.nickname, draft) end)
    end

    {:noreply,
     socket
     |> assign(session: new_session)
     |> stream_insert(
       :chat_messages,
       system_message("* Sound settings applied")
     )}
  end

  def handle_event("sound_settings_ok", _params, socket) do
    draft = socket.assigns.sound_settings_draft
    session = socket.assigns.session
    new_session = Session.set_sound_settings(session, draft)

    if new_session.identified do
      Task.start(fn -> SoundSettings.save(new_session.nickname, draft) end)
    end

    {:noreply,
     socket
     |> assign(
       session: new_session,
       show_sound_settings_dialog: false,
       sound_settings_draft: nil
     )
     |> stream_insert(
       :chat_messages,
       system_message("* Sound settings saved")
     )}
  end

  def handle_event("toggle_mute", _params, socket) do
    new_muted = not socket.assigns.muted

    {:noreply,
     socket
     |> assign(muted: new_muted)
     |> push_event("toggle_mute", %{})}
  end

  def handle_event("mute_state_sync", %{"muted" => muted}, socket) do
    {:noreply, assign(socket, muted: muted)}
  end

  def handle_event("tab_focused", _params, socket) do
    {:noreply, push_event(socket, "title_flash_stop", %{})}
  end

  # ── PM Typing Indicator ──────────────────────────────────

  def handle_event("pm_typing", _params, socket) do
    session = socket.assigns.session

    if session.active_pm do
      topic = "pm:#{pm_topic(session.nickname, session.active_pm)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{event: "typing", payload: %{nickname: session.nickname}}
      )
    end

    {:noreply, socket}
  end

  def handle_event("pm_stop_typing", _params, socket) do
    session = socket.assigns.session

    if session.active_pm do
      topic = "pm:#{pm_topic(session.nickname, session.active_pm)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{event: "stop_typing", payload: %{nickname: session.nickname}}
      )
    end

    {:noreply, socket}
  end

  def handle_event("open_perform_dialog", _params, socket) do
    {:noreply, assign(socket, show_perform_dialog: true)}
  end

  def handle_event("close_perform_dialog", _params, socket) do
    {:noreply, close_perform_dialog(socket)}
  end

  def handle_event("perform_dialog_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, perform_dialog_tab: tab)}
  end

  def handle_event("perform_select", %{"position" => pos}, socket) do
    {:noreply, assign(socket, perform_selected: String.to_integer(pos))}
  end

  def handle_event("perform_dialog_add", _params, socket) do
    {:noreply, assign(socket, show_perform_add_dialog: true)}
  end

  def handle_event("close_perform_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_perform_add_dialog: false)}
  end

  def handle_event("perform_dialog_add_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_perform_add_dialog: false)
         |> maybe_persist_perform_list(new_session)}

      {:error, reason} ->
        {:noreply,
         stream_insert(
           socket,
           :chat_messages,
           error_message("Failed to add perform command: #{reason}")
         )}
    end
  end

  def handle_event("perform_dialog_edit", _params, socket) do
    if socket.assigns.perform_selected do
      {:noreply, assign(socket, show_perform_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_perform_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_perform_edit_dialog: false)}
  end

  def handle_event("perform_dialog_edit_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session
    position = socket.assigns.perform_selected

    if position do
      updated_list = PerformList.update_entry(session.perform_list, position, command)
      new_session = Session.set_perform_list(session, updated_list)

      {:noreply,
       socket
       |> assign(session: new_session, show_perform_edit_dialog: false)
       |> maybe_persist_perform_list(new_session)}
    else
      {:noreply, assign(socket, show_perform_edit_dialog: false)}
    end
  end

  def handle_event("perform_dialog_remove", _params, socket) do
    position = socket.assigns.perform_selected

    if position do
      session = socket.assigns.session

      case PerformList.remove_entry(session.perform_list, position) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:noreply,
           socket
           |> assign(session: new_session, perform_selected: nil)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("perform_dialog_move_up", _params, socket) do
    position = socket.assigns.perform_selected

    if position && position > 0 do
      session = socket.assigns.session

      case PerformList.move_entry(session.perform_list, position, position - 1) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:noreply,
           socket
           |> assign(session: new_session, perform_selected: position - 1)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("perform_dialog_move_down", _params, socket) do
    position = socket.assigns.perform_selected
    session = socket.assigns.session
    max_pos = PerformList.count(session.perform_list) - 1

    if position && position < max_pos do
      case PerformList.move_entry(session.perform_list, position, position + 1) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:noreply,
           socket
           |> assign(session: new_session, perform_selected: position + 1)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("perform_toggle_enabled", _params, socket) do
    session = socket.assigns.session
    current = PerformList.enabled?(session.perform_list)
    updated_list = PerformList.set_enabled(session.perform_list, !current)
    new_session = Session.set_perform_list(session, updated_list)

    {:noreply,
     socket
     |> assign(session: new_session)
     |> maybe_persist_perform_list(new_session)}
  end

  def handle_event("autojoin_select", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, autojoin_selected: channel)}
  end

  def handle_event("autojoin_dialog_add", _params, socket) do
    {:noreply, assign(socket, show_autojoin_add_dialog: true)}
  end

  def handle_event("close_autojoin_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_autojoin_add_dialog: false)}
  end

  def handle_event("autojoin_dialog_add_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = params["key"]
    key = if key == "", do: nil, else: key

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_autojoin_add_dialog: false)
         |> maybe_persist_autojoin_list(new_session)}

      {:error, reason} ->
        {:noreply,
         stream_insert(
           socket,
           :chat_messages,
           error_message("Failed to add auto-join channel: #{reason}")
         )}
    end
  end

  def handle_event("autojoin_dialog_edit", _params, socket) do
    if socket.assigns.autojoin_selected do
      {:noreply, assign(socket, show_autojoin_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_autojoin_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_autojoin_edit_dialog: false)}
  end

  def handle_event("autojoin_dialog_edit_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = params["key"]
    key = if key == "", do: nil, else: key

    case AutoJoinList.update_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(session: new_session, show_autojoin_edit_dialog: false)
         |> maybe_persist_autojoin_list(new_session)}

      {:error, _} ->
        {:noreply, assign(socket, show_autojoin_edit_dialog: false)}
    end
  end

  def handle_event("autojoin_dialog_remove", _params, socket) do
    channel = socket.assigns.autojoin_selected

    if channel do
      session = socket.assigns.session

      case AutoJoinList.remove_entry(session.autojoin_list, channel) do
        {:ok, updated_list} ->
          new_session = Session.set_autojoin_list(session, updated_list)

          {:noreply,
           socket
           |> assign(session: new_session, autojoin_selected: nil)
           |> maybe_persist_autojoin_list(new_session)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Channel Central dialog events ──────────────────────────

  def handle_event("open_channel_central", params, socket) do
    channel = params["cc_channel"] || socket.assigns.session.active_channel

    if channel do
      open_channel_central(socket, channel)
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_channel_central", _params, socket) do
    {:noreply, close_channel_central(socket)}
  end

  def handle_event("channel_central_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, channel_central_tab: tab)}
  end

  def handle_event("cc_ban_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_ban_selected: nick)}
  end

  def handle_event("cc_ban_ex_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_ban_ex_selected: nick)}
  end

  def handle_event("cc_invite_ex_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_invite_ex_selected: nick)}
  end

  def handle_event("cc_open_add_ban", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_dialog: true)}
  end

  def handle_event("cc_close_add_ban", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_dialog: false)}
  end

  def handle_event("cc_open_add_ban_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_ex_dialog: true)}
  end

  def handle_event("cc_close_add_ban_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_ex_dialog: false)}
  end

  def handle_event("cc_open_add_invite_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_invite_ex_dialog: true)}
  end

  def handle_event("cc_close_add_invite_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_invite_ex_dialog: false)}
  end

  def handle_event("cc_set_topic", %{"topic" => topic}, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_topic(channel, nickname, topic) do
      :ok ->
        {:noreply, refresh_channel_central(socket)}

      {:error, msg} ->
        {:noreply, stream_insert(socket, :chat_messages, error_message("Topic error: #{msg}"))}
    end
  end

  def handle_event("cc_apply_modes", params, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname
    current = socket.assigns.channel_central_state.modes_detail

    socket = apply_mode_changes(socket, channel, nickname, current, params)
    {:noreply, refresh_channel_central(socket)}
  end

  def handle_event("cc_add_ban", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.ban(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_ban_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply, stream_insert(socket, :chat_messages, error_message("Ban error: #{msg}"))}
    end
  end

  def handle_event("cc_remove_ban", _params, socket) do
    nick = socket.assigns.channel_central_ban_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      # Unban by setting -b mode (or via Server API if available)
      # For now use the ban list approach: remove from server state
      case remove_ban_via_server(channel, operator, nick) do
        :ok ->
          {:noreply,
           socket
           |> assign(channel_central_ban_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply, stream_insert(socket, :chat_messages, error_message("Unban error: #{msg}"))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cc_add_ban_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_ban_exception(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_ban_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply,
         stream_insert(socket, :chat_messages, error_message("Ban exception error: #{msg}"))}
    end
  end

  def handle_event("cc_remove_ban_exception", _params, socket) do
    nick = socket.assigns.channel_central_ban_ex_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.remove_ban_exception(channel, operator, nick) do
        :ok ->
          {:noreply,
           socket
           |> assign(channel_central_ban_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply,
           stream_insert(socket, :chat_messages, error_message("Remove exception error: #{msg}"))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cc_add_invite_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_invite_exception(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_invite_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply,
         stream_insert(
           socket,
           :chat_messages,
           error_message("Invite exception error: #{msg}")
         )}
    end
  end

  def handle_event("cc_remove_invite_exception", _params, socket) do
    nick = socket.assigns.channel_central_invite_ex_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.remove_invite_exception(channel, operator, nick) do
        :ok ->
          {:noreply,
           socket
           |> assign(channel_central_invite_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply,
           stream_insert(
             socket,
             :chat_messages,
             error_message("Remove exception error: #{msg}")
           )}
      end
    else
      {:noreply, socket}
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

  # ── URL Catcher events ────────────────────────────────────

  def handle_event("toggle_url_catcher", _params, socket) do
    {:noreply, assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)}
  end

  def handle_event("url_catcher_sort", %{"column" => column}, socket) do
    col = String.to_existing_atom(column)

    direction =
      if socket.assigns.url_catcher_sort_column == col,
        do: toggle_direction(socket.assigns.url_catcher_sort_direction),
        else: :asc

    {:noreply,
     assign(socket, url_catcher_sort_column: col, url_catcher_sort_direction: direction)}
  end

  def handle_event("url_catcher_filter", %{"channel" => ""}, socket) do
    {:noreply, assign(socket, url_catcher_filter_channel: nil)}
  end

  def handle_event("url_catcher_filter", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, url_catcher_filter_channel: channel)}
  end

  def handle_event("url_catcher_search", %{"query" => query}, socket) do
    {:noreply, assign(socket, url_catcher_search_query: query)}
  end

  # ── Invite dialog events ──────────────────────────────────

  def handle_event("invite_accept", %{"channel" => channel}, socket) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        {:noreply,
         stream_insert(socket, :chat_messages, error_message("This invitation has expired"))}

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)

        socket =
          socket
          |> assign(pending_invites: remaining)
          |> join_channel(channel, session)

        {:noreply, socket}
    end
  end

  def handle_event("invite_ignore", %{"channel" => channel}, socket) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        {:noreply, assign(socket, pending_invites: pending)}

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)
        {:noreply, assign(socket, pending_invites: remaining)}
    end
  end

  # ── Log Viewer events ─────────────────────────────────────

  def handle_event("open_log_viewer", _params, socket) do
    {:noreply, open_log_viewer(socket)}
  end

  def handle_event("close_log_viewer", _params, socket) do
    {:noreply, close_log_viewer(socket)}
  end

  def handle_event("log_set_source", %{"source" => ""}, socket) do
    filter = %{socket.assigns.log_filter | source: nil, source_type: nil}
    {:noreply, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_source", %{"source" => "pm:" <> nick}, socket) do
    filter = %{socket.assigns.log_filter | source: nick, source_type: :pm, page: 1}
    {:noreply, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_set_source", %{"source" => channel}, socket) do
    filter = %{socket.assigns.log_filter | source: channel, source_type: :channel, page: 1}
    {:noreply, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_set_date_from", %{"date" => ""}, socket) do
    filter = %{socket.assigns.log_filter | date_from: nil}
    {:noreply, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_date_from", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        filter = %{socket.assigns.log_filter | date_from: date}

        case LogFilter.validate(filter) do
          :ok -> {:noreply, assign(socket, log_filter: filter, log_error: nil)}
          {:error, msg} -> {:noreply, assign(socket, log_error: msg)}
        end

      _ ->
        {:noreply, assign(socket, log_error: "Invalid date format")}
    end
  end

  def handle_event("log_set_date_to", %{"date" => ""}, socket) do
    filter = %{socket.assigns.log_filter | date_to: nil}
    {:noreply, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_date_to", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        filter = %{socket.assigns.log_filter | date_to: date}

        case LogFilter.validate(filter) do
          :ok -> {:noreply, assign(socket, log_filter: filter, log_error: nil)}
          {:error, msg} -> {:noreply, assign(socket, log_error: msg)}
        end

      _ ->
        {:noreply, assign(socket, log_error: "Invalid date format")}
    end
  end

  def handle_event("log_search", %{"nickname" => nick, "text" => text}, socket) do
    filter = %{
      socket.assigns.log_filter
      | nickname: normalize_empty(nick),
        text: normalize_empty(text),
        page: 1
    }

    {:noreply, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    filter = %{socket.assigns.log_filter | page: page}
    {:noreply, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_refresh", _params, socket) do
    {:noreply, run_log_search(socket)}
  end

  def handle_event("log_toggle_event", %{"event_type" => event_type}, socket) do
    session = socket.assigns.session
    field = String.to_existing_atom(event_type)
    prefs = DisplayPreferences.toggle_event(session.log_preferences, field)
    new_session = Session.set_log_preferences(session, prefs)
    {:noreply, assign(socket, session: new_session, log_preferences: prefs)}
  end

  def handle_event("log_set_timestamp_format", %{"format" => format}, socket) do
    session = socket.assigns.session
    fmt = String.to_existing_atom(format)
    prefs = DisplayPreferences.set_timestamp_format(session.log_preferences, fmt)
    new_session = Session.set_log_preferences(session, prefs)
    {:noreply, assign(socket, session: new_session, log_preferences: prefs)}
  end

  def handle_event("log_export", %{"format" => format}, socket) do
    page = socket.assigns.log_page

    if page && page.entries != [] do
      filter = socket.assigns.log_filter
      prefs = socket.assigns.log_preferences

      # Fetch ALL matching results (not just current page)
      all_filter = %{filter | page: 1, per_page: 10_000}

      entries = fetch_all_log_entries(socket, all_filter)

      content = LogExporter.export(entries, format, prefs)

      filename = LogExporter.generate_filename(filter, format)

      mime =
        if format == "html",
          do: "text/html",
          else: "text/plain"

      {:noreply,
       socket
       |> assign(log_exporting: false)
       |> push_event("download_file", %{
         content: Base.encode64(content),
         filename: filename,
         mime_type: mime
       })}
    else
      {:noreply, socket}
    end
  end

  # ── PubSub handlers ────────────────────────────────────────

  @impl true
  def handle_info(%{event: "new_message", payload: payload}, socket) do
    session = socket.assigns.session
    msg_type = if payload.type == :action, do: :action, else: :message

    if IgnoreList.ignored?(session.ignore_list, payload.author, msg_type) do
      {:noreply, socket}
    else
      socket = check_channel_duplicate(socket, payload)

      if payload.type != :system and
           DuplicateTracker.duplicate?(
             socket.assigns.duplicate_tracker,
             payload.author,
             {:channel, payload.channel},
             payload.content,
             FloodProtection.get_spam_threshold(session.flood_protection),
             FloodProtection.get_spam_window_seconds(session.flood_protection)
           ) do
        {:noreply, socket}
      else
        socket = check_flood_and_auto_ignore(socket, payload.author, payload.type, session)
        decorated = maybe_highlight(payload, session)

        socket =
          socket
          |> maybe_play_highlight_sound(decorated, session)
          |> capture_urls(payload.content, payload.channel, :channel, payload.author)

        {:noreply, apply_new_message(socket, decorated, payload.channel, session)}
      end
    end
  end

  def handle_info(%{event: "new_pm", payload: payload}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, payload.sender, :pm) do
      {:noreply, socket}
    else
      socket = check_pm_duplicate(socket, payload)

      if DuplicateTracker.duplicate?(
           socket.assigns.duplicate_tracker,
           payload.sender,
           {:pm, payload.sender},
           payload.content,
           FloodProtection.get_spam_threshold(session.flood_protection),
           FloodProtection.get_spam_window_seconds(session.flood_protection)
         ) do
        {:noreply, socket}
      else
        {:noreply, apply_new_pm(socket, payload, session)}
      end
    end
  end

  # ── PM Typing PubSub Handlers ─────────────────────────────

  def handle_info(%{event: "typing", payload: %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick != session.nickname and
         session.active_pm == nick and
         not IgnoreList.ignored?(session.ignore_list, nick, :pm) do
      # Cancel existing timer
      if socket.assigns.pm_typing_timer do
        Process.cancel_timer(socket.assigns.pm_typing_timer)
      end

      timer = Process.send_after(self(), :clear_typing_indicator, 5_000)

      {:noreply, assign(socket, pm_typing_from: nick, pm_typing_timer: timer)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "stop_typing", payload: %{nickname: nick}}, socket) do
    if socket.assigns.pm_typing_from == nick do
      if socket.assigns.pm_typing_timer do
        Process.cancel_timer(socket.assigns.pm_typing_timer)
      end

      {:noreply, assign(socket, pm_typing_from: nil, pm_typing_timer: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:clear_typing_indicator, socket) do
    {:noreply, assign(socket, pm_typing_from: nil, pm_typing_timer: nil)}
  end

  def handle_info({:new_notice, %{sender: sender, content: content}}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, sender, :notice) do
      {:noreply, socket}
    else
      {:noreply, route_notice(socket, session, sender, content)}
    end
  end

  def handle_info(
        %{event: "new_notice", payload: %{author: author, content: content, channel: channel}},
        socket
      ) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, author, :notice) do
      {:noreply, socket}
    else
      if channel == session.active_channel do
        {:noreply, stream_insert(socket, :chat_messages, notice_message(author, content))}
      else
        {:noreply, socket}
      end
    end
  end

  # ── CTCP handle_info ──────────────────────────────────────────

  def handle_info(
        {:ctcp_request, %{type: type, sender: sender, request_id: req_id, sent_at: sent_at}},
        socket
      ) do
    session = socket.assigns.session
    settings = Session.get_ctcp_settings(session)
    type_upper = type |> Atom.to_string() |> String.upcase()

    socket =
      stream_insert(
        socket,
        :chat_messages,
        system_message("* CTCP #{type_upper} request from #{sender}")
      )

    socket = maybe_send_ctcp_reply(socket, session, settings, type, sender, req_id, sent_at)
    {:noreply, socket}
  end

  def handle_info(
        {:ctcp_reply,
         %{type: type, replier: replier, request_id: req_id, value: value, sent_at: sent_at}},
        socket
      ) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, req_id) do
      {nil, _} ->
        # Unknown or already expired request — ignore
        {:noreply, socket}

      {%{timer_ref: timer_ref}, remaining} ->
        Process.cancel_timer(timer_ref)
        type_upper = type |> Atom.to_string() |> String.upcase()

        display_value =
          case type do
            :ping ->
              latency = System.monotonic_time(:millisecond) - sent_at
              "#{latency}ms"

            _ ->
              value
          end

        {:noreply,
         socket
         |> assign(ctcp_pending: remaining)
         |> stream_insert(
           :chat_messages,
           system_message("* CTCP #{type_upper} reply from #{replier}: #{display_value}")
         )}
    end
  end

  def handle_info({:ctcp_timeout, request_id}, socket) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, request_id) do
      {nil, _} ->
        {:noreply, socket}

      {%{target: target}, remaining} ->
        {:noreply,
         socket
         |> assign(ctcp_pending: remaining)
         |> stream_insert(
           :chat_messages,
           system_message("* No CTCP reply from #{target} (timed out)")
         )}
    end
  end

  # Test helpers for CTCP
  def handle_info({:_test_add_ctcp_pending, request_id, data}, socket) do
    pending = Map.put(socket.assigns.ctcp_pending, request_id, data)
    {:noreply, assign(socket, ctcp_pending: pending)}
  end

  def handle_info({:_test_set_ctcp_enabled, enabled}, socket) do
    session = socket.assigns.session
    settings = CtcpSettings.set_enabled(session.ctcp_settings, enabled)
    new_session = Session.set_ctcp_settings(session, settings)
    {:noreply, assign(socket, session: new_session)}
  end

  def handle_info(
        {:mode_changed, %{nickname: nick, mode_string: mode_string, params: params} = payload},
        socket
      ) do
    msg = "#{nick} sets mode #{mode_string}"
    users = apply_mode_to_users(socket.assigns.channel_users, mode_string, params)

    socket =
      socket
      |> assign(channel_users: users)
      |> maybe_update_current_modes(payload)
      |> stream_insert(:chat_messages, system_message(msg))

    {:noreply, socket}
  end

  def handle_info({:mode_changed, %{nickname: nick, mode_string: mode_string} = payload}, socket) do
    msg = "#{nick} sets mode #{mode_string}"
    channel = Map.get(payload, :channel)

    socket =
      socket
      |> maybe_update_current_modes(payload)
      |> maybe_refresh_cc(channel)
      |> stream_insert(:chat_messages, system_message(msg))

    {:noreply, socket}
  end

  def handle_info({:user_kicked, %{operator: op, target: target, reason: reason}}, socket) do
    msg = "#{target} was kicked by #{op}" <> if(reason, do: " (#{reason})", else: "")
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == target))

    if target == socket.assigns.session.nickname do
      socket =
        socket
        |> assign(channel_users: users)
        |> play_event_sound(:kick, socket.assigns.session)
        |> part_channel_after_kick(socket.assigns.session.active_channel)
        |> stream_insert(:chat_messages, system_message(msg))

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(channel_users: users)
       |> play_event_sound(:kick, socket.assigns.session)
       |> stream_insert(:chat_messages, system_message(msg))}
    end
  end

  def handle_info(
        {:user_banned, %{operator: op, target: target, reason: reason} = payload},
        socket
      ) do
    msg = "#{target} was banned by #{op}" <> if(reason, do: " (#{reason})", else: "")
    channel = Map.get(payload, :channel)

    {:noreply,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_unbanned, %{operator: op, target: target} = payload}, socket) do
    msg = "#{target} was unbanned by #{op}"
    channel = Map.get(payload, :channel)

    {:noreply,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # T046: Exception broadcast handlers — refresh CC if open
  def handle_info({:ban_exception_added, %{channel: channel}}, socket) do
    {:noreply, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:ban_exception_removed, %{channel: channel}}, socket) do
    {:noreply, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:invite_exception_added, %{channel: channel}}, socket) do
    {:noreply, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:invite_exception_removed, %{channel: channel}}, socket) do
    {:noreply, maybe_refresh_cc(socket, channel)}
  end

  def handle_info({:topic_changed, %{nickname: nick, topic: topic} = payload}, socket) do
    msg = "#{nick} changed the topic to: #{topic}"
    channel = Map.get(payload, :channel)

    socket =
      if channel && channel == socket.assigns.session.active_channel do
        assign(socket, current_topic: topic)
      else
        socket
      end

    {:noreply,
     socket
     |> maybe_refresh_cc(channel)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = "#{nick} has joined the channel"
    role = Map.get(payload, :role, :regular)
    channel = Map.get(payload, :channel)
    user = %{nickname: nick, role: role, away: false}
    users = [user | socket.assigns.channel_users]

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:join, socket.assigns.session)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason} = payload}, socket) do
    msg = "#{nick} has left" <> if(reason, do: " (#{reason})", else: "")
    channel = Map.get(payload, :channel)
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == nick))

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:part, socket.assigns.session)
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

    # Update ignore list if old_nick is ignored
    socket =
      if IgnoreList.get_entry(socket.assigns.session.ignore_list, old_nick) do
        session = socket.assigns.session
        updated_list = IgnoreList.update_nickname(session.ignore_list, old_nick, new_nick)
        new_session = Session.set_ignore_list(session, updated_list)
        assign(socket, session: new_session)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  def handle_info({:ignore_expired, nickname}, socket) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nickname) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        timers = Map.delete(socket.assigns.ignore_timers, String.downcase(nickname))

        {:noreply,
         socket
         |> assign(session: new_session, ignore_timers: timers)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(
           :chat_messages,
           system_message("* #{nickname} is no longer ignored (timer expired)")
         )}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  def handle_info({:auto_ignore_expired, nickname}, socket) do
    session = socket.assigns.session
    sender_key = String.downcase(nickname)
    auto_state = socket.assigns.auto_ignore_state

    case IgnoreList.remove_entry(session.ignore_list, nickname) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)
        new_active = Map.delete(auto_state.active, sender_key)
        new_auto_state = %{auto_state | active: new_active}

        # Reset flood tracker for sender so they start fresh
        new_tracker = FloodTracker.reset_sender(socket.assigns.flood_tracker, nickname)

        {:noreply,
         socket
         |> assign(
           session: new_session,
           auto_ignore_state: new_auto_state,
           flood_tracker: new_tracker
         )
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(
           :chat_messages,
           system_message("* #{nickname} is no longer auto-ignored")
         )}

      {:error, :not_found} ->
        # Already removed (maybe manually un-ignored)
        new_active = Map.delete(auto_state.active, sender_key)
        new_auto_state = %{auto_state | active: new_active}
        {:noreply, assign(socket, auto_ignore_state: new_auto_state)}
    end
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

    buddy_sound = if online?, do: :buddy_online, else: :buddy_offline

    socket =
      socket
      |> assign(session: new_session, notify_debounce_timers: timers)
      |> maybe_persist_notify_list(new_session)
      |> push_status_message(msg, type)
      |> play_event_sound(buddy_sound, new_session)

    # Auto-whois on connect
    socket =
      if online? && new_session.notify_list.settings.auto_whois do
        push_whois_info(socket, nickname)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:link_preview_result, url, {:ok, title}}, socket) do
    LinkPreview.Cache.put(url, title)

    updated_entries =
      Enum.map(socket.assigns.url_catcher_entries, fn entry ->
        if entry.url == url, do: CapturedURL.set_preview_title(entry, title), else: entry
      end)

    socket =
      socket
      |> assign(
        link_previews: Map.put(socket.assigns.link_previews, url, title),
        url_catcher_entries: updated_entries
      )
      |> push_event("link_preview", %{url: url, title: title})

    {:noreply, socket}
  end

  def handle_info({:link_preview_result, url, {:error, _}}, socket) do
    LinkPreview.Cache.put_error(url)
    {:noreply, socket}
  end

  def handle_info({:execute_perform, index}, socket) do
    session = socket.assigns.session
    entries = PerformList.entries(session.perform_list)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      masked = PerformList.mask_command(entry.command)

      socket =
        socket
        |> stream_insert(:chat_messages, system_message("* Performing: #{masked}"))
        |> execute_perform_command(session, entry.command)

      Process.send_after(self(), {:execute_perform, index + 1}, 100)
      {:noreply, socket}
    else
      send(self(), {:execute_autojoin, 0})
      {:noreply, socket}
    end
  end

  def handle_info({:execute_autojoin, index}, socket) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      channel = entry.channel_name
      key = entry.channel_key

      socket =
        socket
        |> stream_insert(:chat_messages, system_message("* Auto-joining #{channel}..."))
        |> join_channel(channel, session, key)

      Process.send_after(self(), {:execute_autojoin, index + 1}, 100)
      {:noreply, socket}
    else
      send(self(), {:execute_favorites_autojoin, 0})
      {:noreply, socket}
    end
  end

  def handle_info({:execute_favorites_autojoin, index}, socket) do
    session = socket.assigns.session
    entries = Favorites.auto_join_entries(session.favorites)

    if index < length(entries) do
      entry = Enum.at(entries, index)
      channel = entry.channel_name

      socket =
        if channel in session.channels do
          socket
        else
          socket
          |> stream_insert(
            :chat_messages,
            system_message("* Auto-joining favorite #{channel}...")
          )
          |> join_channel(channel, session, entry.password)
        end

      Process.send_after(self(), {:execute_favorites_autojoin, index + 1}, 100)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:execute_rejoin, index, channels}, socket) do
    session = socket.assigns.session

    if index < length(channels) do
      channel = Enum.at(channels, index)

      socket =
        if channel in session.channels do
          socket
        else
          socket
          |> stream_insert(:chat_messages, system_message("* Rejoining #{channel}..."))
          |> join_channel(channel, session, nil)
        end

      Process.send_after(self(), {:execute_rejoin, index + 1, channels}, 100)
      {:noreply, socket}
    else
      {:noreply, maybe_restore_active_tab(socket)}
    end
  end

  # ── Channel Invite System ─────────────────────────────────

  def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
    session = socket.assigns.session

    if Session.get_auto_join_on_invite(session) do
      # Auto-join path
      socket =
        socket
        |> join_channel(channel, session)
        |> stream_insert(
          :chat_messages,
          system_message("* You have been invited to #{channel} by #{inviter} (auto-joined)")
        )

      {:noreply, socket}
    else
      # Dialog path — add to pending_invites with expiration timer
      pending = socket.assigns.pending_invites

      # Cancel existing timer for same channel (FR-020 dedup)
      {pending, _old} = cancel_existing_invite(pending, channel)

      timer_ref = Process.send_after(self(), {:invite_expired, channel}, 300_000)

      invite = %{
        channel: channel,
        inviter: inviter,
        invited_at: DateTime.utc_now(),
        timer_ref: timer_ref
      }

      {:noreply, assign(socket, pending_invites: pending ++ [invite])}
    end
  end

  def handle_info({:invite_expired, channel}, socket) do
    {pending, expired} = cancel_existing_invite(socket.assigns.pending_invites, channel)

    socket = assign(socket, pending_invites: pending)

    # Clean up invite_exception
    socket =
      if expired do
        nickname = socket.assigns.session.nickname
        try_remove_invite_exception(channel, nickname)
        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({_ref, _result}, socket), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
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
      show_context_color_picker: false,
      treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil}
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

  defp handle_ui_action(socket, :ignore_list, _payload) do
    session = socket.assigns.session
    entries = IgnoreList.sorted_entries(session.ignore_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your ignore list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(acc, :chat_messages, system_message(format_ignore_entry(entry)))
      end)
    end
  end

  defp handle_ui_action(socket, :ignore_add, %{nickname: nick, type: type} = payload) do
    session = socket.assigns.session
    duration = Map.get(payload, :duration)
    expires_at = if duration, do: DateTime.add(DateTime.utc_now(), duration, :second)
    existing = IgnoreList.get_entry(session.ignore_list, nick)

    case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        msg =
          if existing do
            "* #{nick} ignore updated to: #{type}"
          else
            "* #{nick} is now ignored (#{type})"
          end

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> maybe_start_ignore_timer(nick, duration)
        |> maybe_persist_ignore_list(new_session)
        |> stream_insert(:chat_messages, system_message(msg))

      {:error, :list_full} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Ignore list is full (max 100 entries)")
        )

      {:error, :invalid_type} ->
        stream_insert(socket, :chat_messages, error_message("Invalid ignore type: #{type}"))
    end
  end

  defp handle_ui_action(socket, :ignore_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> cancel_auto_ignore_with_cooldown(nick)
        |> maybe_persist_ignore_list(new_session)
        |> stream_insert(:chat_messages, system_message("* #{nick} is no longer ignored"))

      {:error, :not_found} ->
        stream_insert(socket, :chat_messages, error_message("#{nick} is not in your ignore list"))
    end
  end

  defp handle_ui_action(socket, :open_perform_dialog, payload) do
    tab = Map.get(payload, :tab, "commands")
    assign(socket, show_perform_dialog: true, perform_dialog_tab: tab)
  end

  defp handle_ui_action(socket, :perform_list_display, _payload) do
    session = socket.assigns.session
    entries = PerformList.entries(session.perform_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your perform list is empty"))
    else
      Enum.with_index(entries)
      |> Enum.reduce(socket, fn {entry, idx}, acc ->
        masked = PerformList.mask_command(entry.command)
        stream_insert(acc, :chat_messages, system_message("  #{idx}: #{masked}"))
      end)
    end
  end

  defp handle_ui_action(socket, :perform_add, %{command: command}) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)
        masked = PerformList.mask_command(String.trim(command))

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(:chat_messages, system_message("* Added to perform list: #{masked}"))

      {:error, :invalid_command} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Invalid command. Commands must start with /")
        )

      {:error, :disallowed_command} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("That command cannot be added to the perform list")
        )

      {:error, :command_too_long} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Command too long (max 500 characters)")
        )

      {:error, :list_full} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Perform list is full (max 50 commands)")
        )
    end
  end

  defp handle_ui_action(socket, :perform_remove, %{position: position}) do
    session = socket.assigns.session

    case PerformList.remove_entry(session.perform_list, position) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Removed command at position #{position}")
        )

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("No command at position #{position}")
        )
    end
  end

  defp handle_ui_action(socket, :perform_move, %{from: from, to: to}) do
    session = socket.assigns.session

    case PerformList.move_entry(session.perform_list, from, to) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Moved command from position #{from} to #{to}")
        )

      {:error, :same_position} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Source and destination are the same")
        )

      {:error, :invalid_position} ->
        stream_insert(socket, :chat_messages, error_message("Invalid position"))
    end
  end

  defp handle_ui_action(socket, :perform_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = PerformList.clear(session.perform_list)
    new_session = Session.set_perform_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_perform_list(new_session)
    |> stream_insert(:chat_messages, system_message("* Perform list cleared"))
  end

  defp handle_ui_action(socket, :autojoin_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your auto-join list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(acc, :chat_messages, system_message(format_autojoin_entry(entry)))
      end)
    end
  end

  defp handle_ui_action(socket, :autojoin_add, %{channel: channel} = payload) do
    session = socket.assigns.session
    key = Map.get(payload, :key)

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Added to auto-join list: #{channel}")
        )

      {:error, reason} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Failed to add auto-join channel: #{reason}")
        )
    end
  end

  defp handle_ui_action(socket, :autojoin_remove, %{channel: channel}) do
    session = socket.assigns.session

    case AutoJoinList.remove_entry(session.autojoin_list, channel) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Removed #{channel} from auto-join list")
        )

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("#{channel} is not in your auto-join list")
        )
    end
  end

  defp handle_ui_action(socket, :autojoin_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = AutoJoinList.clear(session.autojoin_list)
    new_session = Session.set_autojoin_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_autojoin_list(new_session)
    |> stream_insert(:chat_messages, system_message("* Auto-join list cleared"))
  end

  defp handle_ui_action(socket, :send_invite, %{target: target, channel: channel}) do
    nickname = socket.assigns.session.nickname

    with {:ok, state} <- Server.get_state(channel),
         :ok <- validate_operator(nickname, state),
         :ok <- validate_invite_only(channel, state),
         :ok <- validate_target_not_in_channel(target, state),
         :ok <- validate_target_online(target) do
      Server.add_invite_exception(channel, nickname, target)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{target}",
        {:channel_invite, %{channel: channel, inviter: nickname}}
      )

      stream_insert(socket, :chat_messages, system_message("* Inviting #{target} to #{channel}"))
    else
      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
    session = socket.assigns.session
    new_session = Session.toggle_auto_join_on_invite(session)
    status = if new_session.auto_join_on_invite, do: "enabled", else: "disabled"

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* Auto-join on invite: #{status}"))
  end

  defp handle_ui_action(socket, :notice_routing_show, _payload) do
    session = socket.assigns.session
    routing = Session.get_notice_routing(session)

    stream_insert(
      socket,
      :chat_messages,
      system_message("* Notice routing is set to: #{routing}")
    )
  end

  defp handle_ui_action(socket, :notice_routing_set, %{routing: routing}) do
    session = socket.assigns.session
    new_session = Session.set_notice_routing(session, routing)

    if new_session.identified do
      Task.start(fn ->
        NoticeRouting.save(new_session.nickname, %{routing: routing})
      end)
    end

    socket
    |> assign(session: new_session)
    |> stream_insert(
      :chat_messages,
      system_message("* Notice routing set to: #{routing}")
    )
  end

  defp handle_ui_action(socket, _action, _payload), do: socket

  defp format_autojoin_entry(entry) do
    key_part = if entry.channel_key, do: " (key: ****)", else: ""
    "  #{entry.channel_name}#{key_part}"
  end

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
        |> push_reconnect_state()

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

    socket =
      if new_session.active_channel do
        socket
        |> load_channel_users(new_session.active_channel)
        |> load_channel_messages_with_pagination(new_session.active_channel)
      else
        socket
        |> assign(
          oldest_message_id: nil,
          has_more: false,
          channel_users: [],
          current_topic: nil,
          current_modes: nil
        )
        |> stream(:chat_messages, [], reset: true)
      end

    push_reconnect_state(socket)
  end

  defp part_channel_after_kick(socket, channel_name) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "channel:#{channel_name}")
    safe_untrack_user("channel:#{channel_name}", socket.assigns.session.nickname)
    new_session = Session.remove_channel(socket.assigns.session, channel_name)

    socket = assign(socket, session: new_session)

    if new_session.active_channel do
      socket
      |> load_channel_users(new_session.active_channel)
      |> load_channel_messages_with_pagination(new_session.active_channel)
    else
      socket
      |> assign(oldest_message_id: nil, has_more: false, current_topic: nil, current_modes: nil)
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

        assign(socket,
          channel_users: users,
          current_topic: state.topic,
          current_modes: state.modes
        )

      {:error, _} ->
        assign(socket, channel_users: [], current_topic: nil, current_modes: nil)
    end
  end

  defp maybe_update_current_modes(socket, payload) do
    channel = Map.get(payload, :channel)

    if channel && channel == socket.assigns.session.active_channel do
      case Server.get_state(channel) do
        {:ok, state} -> assign(socket, current_modes: state.modes)
        {:error, _} -> socket
      end
    else
      socket
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

  # ── Invite validation helpers ─────────────────────────────

  defp validate_operator(nickname, state) do
    if nickname in state.operators do
      :ok
    else
      {:error, "* You are not a channel operator"}
    end
  end

  defp validate_invite_only(channel, state) do
    if state.modes_detail.invite_only do
      :ok
    else
      {:error, "* #{channel} is not invite-only — anyone can join"}
    end
  end

  defp validate_target_not_in_channel(target, state) do
    member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

    if target in member_nicks do
      {:error, "* #{target} is already in the channel"}
    else
      :ok
    end
  end

  defp validate_target_online(target) do
    # Check if target is in #lobby (all connected users auto-join #lobby)
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

  defp find_invite(pending, channel) do
    Enum.find(pending, &(&1.channel == channel))
  end

  defp cancel_existing_invite(pending, channel) do
    case Enum.split_with(pending, &(&1.channel == channel)) do
      {[existing], rest} ->
        Process.cancel_timer(existing.timer_ref)
        {rest, existing}

      {[], _} ->
        {pending, nil}
    end
  end

  defp try_remove_invite_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, target_nick) do
    IgnoreList.get_entry(session.ignore_list, target_nick) != nil
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

  defp handle_notice_send(socket, session, "#" <> _ = channel, content) do
    if channel in session.channels do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel}",
        %{
          event: "new_notice",
          payload: %{
            author: session.nickname,
            content: content,
            channel: channel,
            timestamp: DateTime.utc_now()
          }
        }
      )

      socket
    else
      stream_insert(
        socket,
        :chat_messages,
        error_message("You must be a member of #{channel} to send notices there")
      )
    end
  end

  defp handle_notice_send(socket, session, target, content) do
    case validate_target_online(target) do
      :ok ->
        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:new_notice,
           %{sender: session.nickname, content: content, timestamp: DateTime.utc_now()}}
        )

        socket

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  # ── CTCP Send ─────────────────────────────────────────────────

  defp handle_ctcp_send(socket, session, target, type) do
    # Self-CTCP: handle locally without PubSub
    if target == session.nickname do
      handle_self_ctcp(socket, session, type)
    else
      # Rate limit check
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

    # Prune timestamps older than window
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

  defp capture_urls(socket, content, source, source_type, author) do
    urls = URLDetector.extract_urls(content)

    if urls == [] do
      socket
    else
      new_entries =
        Enum.map(urls, fn url ->
          CapturedURL.new(%{
            url: url,
            source: source,
            source_type: source_type,
            posted_by: author,
            timestamp: DateTime.utc_now()
          })
        end)

      socket
      |> assign(url_catcher_entries: new_entries ++ socket.assigns.url_catcher_entries)
      |> maybe_fetch_previews(urls)
    end
  end

  defp maybe_fetch_previews(socket, urls) do
    lv_pid = self()
    Enum.each(urls, &fetch_preview_for_url(&1, lv_pid))
    socket
  end

  defp fetch_preview_for_url(url, lv_pid) do
    case LinkPreview.Cache.get(url) do
      {:ok, :error} -> :ok
      {:ok, title} -> send(lv_pid, {:link_preview_result, url, {:ok, title}})
      :miss -> spawn_preview_fetch(url, lv_pid)
    end
  end

  defp spawn_preview_fetch(url, lv_pid) do
    unless LinkPreview.Cache.pending?(url) do
      LinkPreview.Cache.mark_pending(url)

      Task.Supervisor.async_nolink(RetroHexChat.LinkPreviewTasks, fn ->
        result = LinkPreview.HTTP.fetch_title(url)
        send(lv_pid, {:link_preview_result, url, result})
      end)
    end
  end

  defp toggle_direction(:asc), do: :desc
  defp toggle_direction(:desc), do: :asc

  defp filtered_url_catcher_entries(assigns) do
    assigns.url_catcher_entries
    |> CapturedURL.filter_by_source(assigns.url_catcher_filter_channel)
    |> CapturedURL.filter_by_url(assigns.url_catcher_search_query)
    |> CapturedURL.sort_by(assigns.url_catcher_sort_column, assigns.url_catcher_sort_direction)
  end

  defp filtered_help_keywords(assigns) do
    all = HelpTopics.all_keywords()

    case assigns.help_index_filter do
      "" ->
        all

      filter ->
        Enum.filter(all, fn {kw, _id} ->
          String.contains?(String.downcase(kw), String.downcase(filter))
        end)
    end
  end

  defp url_catcher_channels(assigns) do
    assigns.url_catcher_entries
    |> Enum.map(& &1.source)
    |> Enum.uniq()
    |> Enum.sort()
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

    socket
    |> push_event("intentional_disconnect", %{})
    |> push_navigate(to: ~p"/")
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
    text =
      "Available commands: " <>
        Enum.join(Enum.map(commands, &"/#{&1}"), ", ") <>
        "\nType /help <command> for details, or press F1 for the full help system."

    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp show_command_help_message(socket, help) do
    text = "#{help.syntax} - #{help.description}"
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp open_help_dialog(socket) do
    assign(socket,
      show_help_dialog: true,
      help_active_tab: "contents",
      help_selected_topic: nil,
      help_index_filter: "",
      help_search_query: "",
      help_search_results: []
    )
  end

  defp close_help_dialog(socket) do
    assign(socket,
      show_help_dialog: false,
      help_selected_topic: nil,
      help_index_filter: "",
      help_search_query: "",
      help_search_results: []
    )
  end

  # ── Channel Central helpers ─────────────────────────────────

  defp open_channel_central(socket, channel) do
    nickname = socket.assigns.session.nickname

    # Validate membership
    case Server.get_state(channel) do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if nickname in member_nicks do
          operator = nickname in state.operators

          {:noreply,
           assign(socket,
             show_channel_central: true,
             channel_central_tab: "general",
             channel_central_channel: channel,
             channel_central_state: state,
             channel_central_operator: operator,
             channel_central_ban_selected: nil,
             channel_central_ban_ex_selected: nil,
             channel_central_invite_ex_selected: nil,
             channel_central_modes_form: %{},
             show_cc_add_ban_dialog: false,
             show_cc_add_ban_ex_dialog: false,
             show_cc_add_invite_ex_dialog: false
           )}
        else
          {:noreply,
           stream_insert(
             socket,
             :chat_messages,
             error_message("You must be a member of #{channel} to open Channel Central")
           )}
        end

      {:error, _} ->
        {:noreply,
         stream_insert(socket, :chat_messages, error_message("Channel #{channel} not found"))}
    end
  end

  defp close_channel_central(socket) do
    assign(socket,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_channel: nil,
      channel_central_state: nil,
      channel_central_operator: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false
    )
  end

  # ── Log Viewer helpers ────────────────────────────────────

  defp open_log_viewer(socket) do
    session = socket.assigns.session
    source_options = build_log_source_options(session)
    prefs = session.log_preferences

    assign(socket,
      show_log_viewer: true,
      log_source_options: source_options,
      log_preferences: prefs,
      log_filter: LogFilter.new(),
      log_page: nil,
      log_loading: false,
      log_exporting: false,
      log_error: nil
    )
  end

  defp close_perform_dialog(socket) do
    assign(socket,
      show_perform_dialog: false,
      perform_dialog_tab: "commands",
      perform_selected: nil,
      show_perform_add_dialog: false,
      show_perform_edit_dialog: false,
      autojoin_selected: nil,
      show_autojoin_add_dialog: false,
      show_autojoin_edit_dialog: false
    )
  end

  defp push_reconnect_state(socket) do
    session = socket.assigns.session

    push_event(socket, "save_reconnect_state", %{
      nickname: session.nickname,
      channels: session.channels,
      active_channel: session.active_channel,
      active_pm: session.active_pm
    })
  end

  defp restore_session(socket, params) do
    channels = Map.get(params, "channels", [])
    active_channel = Map.get(params, "active_channel")
    active_pm = Map.get(params, "active_pm")

    socket =
      socket
      |> assign(reconnect_active_channel: active_channel, reconnect_active_pm: active_pm)
      |> stream_insert(:chat_messages, system_message("* Restoring session..."))

    if channels != [] do
      Process.send_after(self(), {:execute_rejoin, 0, channels}, 200)
    end

    socket
  end

  defp maybe_restore_active_tab(socket) do
    target_channel = socket.assigns[:reconnect_active_channel]
    target_pm = socket.assigns[:reconnect_active_pm]
    session = socket.assigns.session

    socket = assign(socket, reconnect_active_channel: nil, reconnect_active_pm: nil)

    cond do
      target_pm && target_pm in session.pm_conversations ->
        new_session = Session.set_active_pm(session, target_pm)
        messages = load_pm_messages(new_session.nickname, target_pm)

        socket
        |> assign(session: new_session, show_status_tab: false)
        |> stream(:chat_messages, messages, reset: true)

      target_channel && target_channel in session.channels ->
        new_session = Session.set_active_channel(session, target_channel)

        socket
        |> assign(session: new_session, show_status_tab: false)
        |> load_channel_users(target_channel)
        |> load_channel_messages_with_pagination(target_channel)

      true ->
        socket
    end
  end

  defp close_log_viewer(socket) do
    assign(socket,
      show_log_viewer: false,
      log_filter: LogFilter.new(),
      log_source_options: [],
      log_page: nil,
      log_loading: false,
      log_exporting: false,
      log_error: nil
    )
  end

  defp build_log_source_options(session) do
    if session.identified do
      channels =
        LogQueries.list_user_channels(session.nickname)
        |> Enum.map(fn ch -> %{type: :channel, label: ch, value: ch} end)

      pms =
        LogQueries.list_user_pm_partners(session.nickname)
        |> Enum.map(fn nick -> %{type: :pm, label: nick, value: nick} end)

      channels ++ pms
    else
      channels =
        session.channels
        |> Enum.sort()
        |> Enum.map(fn ch -> %{type: :channel, label: ch, value: ch} end)

      pms =
        session.pm_conversations
        |> Enum.sort()
        |> Enum.map(fn nick -> %{type: :pm, label: nick, value: nick} end)

      channels ++ pms
    end
  end

  defp run_log_search(socket) do
    filter = socket.assigns.log_filter

    if filter.source == nil do
      assign(socket, log_page: nil, log_error: nil)
    else
      case LogFilter.validate(filter) do
        :ok ->
          page = fetch_log_page(socket, filter)
          assign(socket, log_page: page, log_loading: false, log_error: nil)

        {:error, msg} ->
          assign(socket, log_error: msg)
      end
    end
  end

  defp fetch_log_page(socket, filter) do
    case filter.source_type do
      :pm ->
        LogQueries.search_pm_log(socket.assigns.session.nickname, filter)

      _ ->
        LogQueries.search_channel_log(filter)
    end
  end

  defp fetch_all_log_entries(socket, filter) do
    page = fetch_log_page(socket, filter)
    page.entries
  end

  defp normalize_empty(""), do: nil
  defp normalize_empty(s), do: s

  defp refresh_channel_central(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname
          operator = nickname in state.operators
          assign(socket, channel_central_state: state, channel_central_operator: operator)

        {:error, _} ->
          close_channel_central(socket)
      end
    else
      socket
    end
  end

  defp apply_mode_changes(socket, channel, nickname, current, params) do
    mode_ops = build_mode_ops(current, params)

    Enum.reduce(mode_ops, socket, fn {mode_str, mode_params}, acc ->
      case Server.set_mode(channel, nickname, mode_str, mode_params) do
        :ok -> acc
        {:error, msg} -> stream_insert(acc, :chat_messages, error_message("Mode error: #{msg}"))
      end
    end)
  end

  defp build_mode_ops(current, params) do
    ops = []

    ops = toggle_flag_op(ops, current.moderated, params["moderated"] == "true", "m")
    ops = toggle_flag_op(ops, current.invite_only, params["invite_only"] == "true", "i")
    ops = toggle_flag_op(ops, current.topic_lock, params["topic_lock"] == "true", "t")
    ops = build_key_op(ops, current.key, params["has_key"] == "true", params["key_value"])
    ops = build_limit_op(ops, current.limit, params["has_limit"] == "true", params["limit_value"])

    ops
  end

  defp toggle_flag_op(ops, was_on, is_on, flag) do
    cond do
      !was_on and is_on -> [{"+#{flag}", []} | ops]
      was_on and !is_on -> [{"-#{flag}", []} | ops]
      true -> ops
    end
  end

  defp build_key_op(ops, nil, true, key_value) when is_binary(key_value) and key_value != "",
    do: [{"+k", [key_value]} | ops]

  defp build_key_op(ops, old_key, false, _) when old_key != nil,
    do: [{"-k", []} | ops]

  defp build_key_op(ops, old_key, true, key_value)
       when old_key != nil and is_binary(key_value) and key_value != "" and key_value != old_key,
       do: [{"-k", []}, {"+k", [key_value]} | ops]

  defp build_key_op(ops, _, _, _), do: ops

  defp build_limit_op(ops, nil, true, val) when is_binary(val) and val != "",
    do: [{"+l", [val]} | ops]

  defp build_limit_op(ops, old, false, _) when old != nil,
    do: [{"-l", []} | ops]

  defp build_limit_op(ops, old, true, val) when old != nil and is_binary(val) and val != "" do
    if val != to_string(old), do: [{"-l", []}, {"+l", [val]} | ops], else: ops
  end

  defp build_limit_op(ops, _, _, _), do: ops

  defp remove_ban_via_server(channel, operator, nick) do
    Server.unban(channel, operator, nick)
  end

  # T045: Refresh Channel Central dialog if open for the given channel
  defp maybe_refresh_cc(socket, channel) do
    if socket.assigns.show_channel_central and socket.assigns.channel_central_channel == channel do
      refresh_channel_central(socket)
    else
      socket
    end
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

  defp maybe_persist_favorites(_socket, session) do
    if session.identified do
      Task.start(fn -> Favorites.save(session.nickname, session.favorites) end)
    end
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

  defp maybe_persist_ignore_list(socket, session) do
    if session.identified do
      Task.start(fn -> IgnoreList.save(session.nickname, session.ignore_list) end)
    end

    socket
  end

  defp maybe_persist_perform_list(socket, session) do
    if session.identified do
      Task.start(fn -> PerformList.save(session.nickname, session.perform_list) end)
    end

    socket
  end

  defp maybe_persist_autojoin_list(socket, session) do
    if session.identified do
      Task.start(fn -> AutoJoinList.save(session.nickname, session.autojoin_list) end)
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
    |> load_if_found(IgnoreList.load(nick), &Session.set_ignore_list/2)
    |> load_if_found(PerformList.load(nick), &Session.set_perform_list/2)
    |> load_if_found(AutoJoinList.load(nick), &Session.set_autojoin_list/2)
    |> load_if_found(NoticeRouting.load(nick), fn session, %{routing: routing} ->
      Session.set_notice_routing(session, routing)
    end)
    |> load_if_found(CtcpSettings.load(nick), &Session.set_ctcp_settings/2)
    |> load_if_found(Favorites.load(nick), &Session.set_favorites/2)
    |> load_if_found(FloodProtection.load(nick), &Session.set_flood_protection/2)
    |> load_if_found(SoundSettings.load(nick), &Session.set_sound_settings/2)
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

  defp format_ignore_entry(entry) do
    alias RetroHexChat.Chat.IgnoreEntry
    expires = if IgnoreEntry.permanent?(entry), do: "permanent", else: "timed"
    "  #{entry.nickname} [#{entry.ignore_type}] (#{expires})"
  end

  defp maybe_start_ignore_timer(socket, _nick, nil), do: socket

  defp maybe_start_ignore_timer(socket, nick, duration_seconds) do
    ref = Process.send_after(self(), {:ignore_expired, nick}, duration_seconds * 1000)
    timers = Map.put(socket.assigns.ignore_timers, String.downcase(nick), ref)
    assign(socket, ignore_timers: timers)
  end

  defp parse_dialog_duration(nil), do: {nil, nil}
  defp parse_dialog_duration(""), do: {nil, nil}

  defp parse_dialog_duration(str) do
    case Regex.run(~r/^(\d+)([mhd])$/, String.trim(str)) do
      [_, num_str, unit] ->
        num = String.to_integer(num_str)
        multiplier = %{"m" => 60, "h" => 3600, "d" => 86_400}
        seconds = num * multiplier[unit]
        {seconds, DateTime.add(DateTime.utc_now(), seconds, :second)}

      _ ->
        {nil, nil}
    end
  end

  defp cancel_ignore_timer(socket, nick) do
    key = String.downcase(nick)

    case Map.get(socket.assigns.ignore_timers, key) do
      nil ->
        socket

      ref ->
        Process.cancel_timer(ref)
        assign(socket, ignore_timers: Map.delete(socket.assigns.ignore_timers, key))
    end
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

  defp notice_message(author, content) do
    %{
      id: "notice-#{System.unique_integer([:positive])}",
      author: author,
      content: content,
      type: :notice,
      timestamp: DateTime.utc_now()
    }
  end

  defp route_notice(socket, session, sender, content) do
    notice = notice_message(sender, content)

    case Session.get_notice_routing(session) do
      :active ->
        stream_insert(socket, :chat_messages, notice)

      :status ->
        if socket.assigns.show_status_tab do
          push_status_message(socket, "-#{sender}- #{content}", :notice)
        else
          stream_insert(socket, :chat_messages, notice)
        end

      :sender ->
        if sender in session.pm_conversations do
          stream_insert(socket, :chat_messages, notice)
        else
          stream_insert(socket, :chat_messages, notice)
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="reconnect-hook" phx-hook="ReconnectHook" style="display: none;"></div>
    <div id="title-flash" phx-hook="TitleFlashHook" style="display: none;"></div>
    <div
      class="app-container"
      phx-click="close_context_menu"
      phx-window-keydown="window_keydown"
      id="app-container"
      phx-hook="SoundHook"
    >
      <RetroHexChatWeb.Components.TitleBar.title_bar />
      <RetroHexChatWeb.Components.MenuBar.menu_bar
        favorites={Favorites.entries(@session.favorites)}
        joined_channels={@session.channels}
      />
      <RetroHexChatWeb.Components.Toolbar.toolbar connected={true} />

      <div class="mdi-layout">
        <RetroHexChatWeb.Components.Treebar.treebar
          :if={@show_treebar}
          channels={@session.channels}
          active_channel={@session.active_channel}
          unread_channels={MapSet.to_list(@unread_channels)}
          highlight_channels={MapSet.to_list(@highlight_channels)}
          flash_channels={MapSet.to_list(@flash_channels)}
          pm_conversations={@session.pm_conversations}
          active_pm={@session.active_pm}
        />

        <div class="chat-area" style="position: relative;">
          <RetroHexChatWeb.Components.TabBar.tab_bar
            channels={@session.channels}
            pm_conversations={@session.pm_conversations}
            active_channel={@session.active_channel}
            active_pm={@session.active_pm}
            show_status_tab={@show_status_tab}
            unread_channels={MapSet.to_list(@unread_channels)}
            highlight_channels={MapSet.to_list(@highlight_channels)}
          />

          <RetroHexChatWeb.Components.TopicBar.topic_bar
            channel={@session.active_channel}
            pm_target={@session.active_pm}
            topic={@current_topic}
            modes={@current_modes}
            show_status_tab={@show_status_tab}
          />

          <RetroHexChatWeb.Components.SearchBar.search_bar
            visible={@search_visible}
            query={@search_query}
            result_count={@search_result_count}
            current_index={@search_current_index}
          />

          <RetroHexChatWeb.Components.ScrollLoader.scroll_loader loading={@loading_more} />

          <div
            class="chat-messages"
            id="chat-messages"
            phx-update="stream"
            phx-hook="ScrollHook"
            style={if @show_status_tab, do: "display: none;", else: nil}
          >
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
                <% :notice -> %>
                  <span class="chat-notice">
                    <span class="chat-notice-nick">-{msg.author}-</span> {msg.content}
                  </span>
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

          <div
            class="chat-messages status-messages-view"
            id="status-messages"
            phx-update="stream"
            style={if @show_status_tab, do: nil, else: "display: none;"}
            data-testid="status-messages"
          >
            <div :for={{dom_id, msg} <- @streams.status_messages} id={dom_id}>
              <span class="chat-timestamp">[{format_status_time(msg.timestamp)}]</span>
              <span class={"chat-status chat-status--#{msg.type}"}>{msg.content}</span>
            </div>
          </div>

          <div style={if @show_status_tab, do: "display: none;", else: nil}>
            <RetroHexChatWeb.Components.FormattingToolbar.formatting_toolbar strip_formatting={
              @session.strip_formatting
            } />
          </div>

          <div
            :if={@pm_typing_from && @session.active_pm}
            class="typing-indicator"
            data-testid="typing-indicator"
          >
            {@pm_typing_from} is typing...
          </div>

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
          :if={@show_nicklist && !@session.active_pm && !@show_status_tab}
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
        is_ignored={context_target_ignored?(@session, @context_menu.target_nick)}
      />

      <RetroHexChatWeb.Components.TreebarContextMenu.treebar_context_menu
        visible={@treebar_context_menu.visible}
        x={@treebar_context_menu.x}
        y={@treebar_context_menu.y}
        channel={@treebar_context_menu.channel}
      />

      <RetroHexChatWeb.Components.FavoriteDialog.favorite_dialog
        visible={@show_favorite_dialog}
        mode={@favorite_dialog_mode}
        channel={@favorite_dialog_channel}
        data={@favorite_dialog_data}
        is_duplicate={@favorite_dialog_is_duplicate}
      />

      <RetroHexChatWeb.Components.OrganizeFavoritesDialog.organize_favorites_dialog
        visible={@show_organize_favorites}
        favorites={Favorites.entries(@session.favorites)}
        selected={@organize_favorites_selected}
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

      <RetroHexChatWeb.Components.IgnoreListDialog.ignore_list_dialog
        visible={@show_ignore_dialog}
        ignore_entries={IgnoreList.sorted_entries(@session.ignore_list)}
        ignore_selected={@ignore_selected}
        show_ignore_add_dialog={@show_ignore_add_dialog}
      />

      <RetroHexChatWeb.Components.CtcpSettingsDialog.ctcp_settings_dialog
        visible={@show_ctcp_settings_dialog}
        ctcp_settings={@session.ctcp_settings}
      />

      <RetroHexChatWeb.Components.FloodProtectionDialog.flood_protection_dialog
        visible={@show_flood_protection_dialog}
        flood_protection={@session.flood_protection}
      />

      <RetroHexChatWeb.Components.SoundSettingsDialog.sound_settings_dialog
        visible={@show_sound_settings_dialog}
        sound_settings_draft={@sound_settings_draft}
      />

      <RetroHexChatWeb.Components.PerformDialog.perform_dialog
        visible={@show_perform_dialog}
        active_tab={@perform_dialog_tab}
        perform_entries={PerformList.entries(@session.perform_list)}
        perform_selected={@perform_selected}
        perform_enabled={PerformList.enabled?(@session.perform_list)}
        autojoin_entries={AutoJoinList.entries(@session.autojoin_list)}
        autojoin_selected={@autojoin_selected}
        show_perform_add_dialog={@show_perform_add_dialog}
        show_perform_edit_dialog={@show_perform_edit_dialog}
        show_autojoin_add_dialog={@show_autojoin_add_dialog}
        show_autojoin_edit_dialog={@show_autojoin_edit_dialog}
      />

      <RetroHexChatWeb.Components.ChannelCentralDialog.channel_central_dialog
        visible={@show_channel_central}
        active_tab={@channel_central_tab}
        channel_state={@channel_central_state}
        operator={@channel_central_operator}
        ban_selected={@channel_central_ban_selected}
        ban_ex_selected={@channel_central_ban_ex_selected}
        invite_ex_selected={@channel_central_invite_ex_selected}
        modes_form={@channel_central_modes_form}
        show_add_ban_dialog={@show_cc_add_ban_dialog}
        show_add_ban_ex_dialog={@show_cc_add_ban_ex_dialog}
        show_add_invite_ex_dialog={@show_cc_add_invite_ex_dialog}
      />

      <RetroHexChatWeb.Components.HighlightDialog.highlight_dialog
        visible={@show_highlight_dialog}
        highlight_entries={HighlightWords.entries(@session.highlight_words)}
        highlight_selected={@highlight_selected}
        own_nick={@session.nickname}
        show_highlight_add_dialog={@show_highlight_add_dialog}
        show_highlight_edit_dialog={@show_highlight_edit_dialog}
      />

      <RetroHexChatWeb.Components.URLCatcherWindow.url_catcher_window
        visible={@show_url_catcher}
        entries={filtered_url_catcher_entries(assigns)}
        sort_column={@url_catcher_sort_column}
        sort_direction={@url_catcher_sort_direction}
        filter_channel={@url_catcher_filter_channel}
        search_query={@url_catcher_search_query}
        channels={url_catcher_channels(assigns)}
        entry_count={length(@url_catcher_entries)}
      />

      <RetroHexChatWeb.Components.HelpDialog.help_dialog
        visible={@show_help_dialog}
        active_tab={@help_active_tab}
        selected_topic={@help_selected_topic}
        topics_by_category={RetroHexChat.Chat.HelpTopics.topics_by_category()}
        index_keywords={filtered_help_keywords(assigns)}
        index_filter={@help_index_filter}
        search_query={@help_search_query}
        search_results={@help_search_results}
      />

      <RetroHexChatWeb.Components.LogViewerDialog.log_viewer_dialog
        visible={@show_log_viewer}
        filter={@log_filter}
        page={@log_page}
        preferences={@log_preferences}
        source_options={@log_source_options}
        loading={@log_loading}
        exporting={@log_exporting}
        error={@log_error}
        nick_color_fn={@nick_color_fn}
      />

      <RetroHexChatWeb.Components.InviteDialog.invite_dialog pending_invites={@pending_invites} />

      <RetroHexChatWeb.Components.StatusBar.status_bar
        nickname={@session.nickname}
        channel={@session.active_pm || @session.active_channel}
        user_count={length(@channel_users)}
        muted={@muted}
      />
    </div>
    """
  end

  @nick_colors ~w(#e74c3c #3498db #2ecc71 #e67e22 #9b59b6 #1abc9c #f39c12 #e91e63 #00bcd4 #8bc34a #ff5722 #607d8b)

  defp apply_new_message(socket, decorated, channel, session) do
    if channel == session.active_channel do
      stream_insert(socket, :chat_messages, decorated)
    else
      unread = MapSet.put(socket.assigns.unread_channels, channel)
      highlight = maybe_add_highlight_channel(socket, decorated, channel)
      is_highlighted = Map.get(decorated, :highlighted, false)
      flash_type = if is_highlighted, do: :highlight, else: :message

      socket =
        if not is_highlighted do
          play_event_sound(socket, :message, session)
        else
          socket
        end

      socket
      |> maybe_flash_channel(channel, flash_type, session)
      |> assign(unread_channels: unread, highlight_channels: highlight)
    end
  end

  defp maybe_add_highlight_channel(socket, decorated, channel) do
    if Map.get(decorated, :highlighted),
      do: MapSet.put(socket.assigns.highlight_channels, channel),
      else: socket.assigns.highlight_channels
  end

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

  @spec apply_new_pm(Phoenix.LiveView.Socket.t(), map(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  defp apply_new_pm(socket, payload, session) do
    socket = check_flood_and_auto_ignore(socket, payload.sender, :message, session)
    other_nick = pm_other_nick(payload, session.nickname)
    socket = capture_urls(socket, payload.content, other_nick, :pm, payload.sender)

    # Clear typing indicator if the sender was typing
    socket =
      if socket.assigns.pm_typing_from == payload.sender do
        if socket.assigns.pm_typing_timer,
          do: Process.cancel_timer(socket.assigns.pm_typing_timer)

        assign(socket, pm_typing_from: nil, pm_typing_timer: nil)
      else
        socket
      end

    if session.active_pm == other_nick do
      stream_insert(socket, :chat_messages, pm_to_stream_item(payload))
    else
      unread = MapSet.put(socket.assigns.unread_channels, "pm:#{other_nick}")

      socket
      |> play_event_sound(:pm, session)
      |> maybe_flash_channel("pm:#{other_nick}", :pm, session)
      |> assign(unread_channels: unread)
    end
  end

  @spec check_channel_duplicate(Phoenix.LiveView.Socket.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp check_channel_duplicate(socket, %{type: :system}), do: socket

  defp check_channel_duplicate(socket, payload) do
    tracker =
      DuplicateTracker.record_message(
        socket.assigns.duplicate_tracker,
        payload.author,
        {:channel, payload.channel},
        payload.content
      )

    assign(socket, duplicate_tracker: tracker)
  end

  @spec check_pm_duplicate(Phoenix.LiveView.Socket.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp check_pm_duplicate(socket, payload) do
    tracker =
      DuplicateTracker.record_message(
        socket.assigns.duplicate_tracker,
        payload.sender,
        {:pm, payload.sender},
        payload.content
      )

    assign(socket, duplicate_tracker: tracker)
  end

  @spec check_flood_and_auto_ignore(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          atom(),
          Session.t()
        ) :: Phoenix.LiveView.Socket.t()
  defp check_flood_and_auto_ignore(socket, _sender, :system, _session), do: socket

  defp check_flood_and_auto_ignore(socket, sender, _msg_type, session) do
    # Don't track the user's own messages
    if String.downcase(sender) == String.downcase(session.nickname) do
      socket
    else
      flood_settings = session.flood_protection
      tracker = FloodTracker.record_message(socket.assigns.flood_tracker, sender)
      socket = assign(socket, flood_tracker: tracker)

      if FloodTracker.flooded?(
           tracker,
           sender,
           FloodProtection.get_flood_threshold(flood_settings),
           FloodProtection.get_flood_window_seconds(flood_settings)
         ) do
        maybe_trigger_auto_ignore(socket, sender, session)
      else
        socket
      end
    end
  end

  @spec maybe_trigger_auto_ignore(Phoenix.LiveView.Socket.t(), String.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_trigger_auto_ignore(socket, sender, session) do
    sender_key = String.downcase(sender)
    auto_state = socket.assigns.auto_ignore_state

    # Don't trigger if already auto-ignored
    already_active = Map.has_key?(auto_state.active, sender_key)
    # Don't trigger if in cooldown
    in_cooldown = cooldown_active?(auto_state, sender_key)
    # Don't trigger if already permanently ignored
    already_ignored = IgnoreList.ignored?(session.ignore_list, sender, :all)

    if already_active or in_cooldown or already_ignored do
      socket
    else
      duration = FloodProtection.get_auto_ignore_duration_seconds(session.flood_protection)
      expires_at = DateTime.add(DateTime.utc_now(), duration, :second)

      case IgnoreList.add_entry(session.ignore_list, sender, :all, expires_at) do
        {:ok, updated_list} ->
          new_session = Session.set_ignore_list(session, updated_list)

          # Schedule auto-ignore expiry timer
          timer_ref =
            Process.send_after(self(), {:auto_ignore_expired, sender}, duration * 1000)

          # Update auto-ignore state
          new_active = Map.put(auto_state.active, sender_key, timer_ref)
          new_auto_state = %{auto_state | active: new_active}

          duration_str = format_duration(duration)

          socket
          |> assign(
            session: new_session,
            auto_ignore_state: new_auto_state
          )
          |> maybe_persist_ignore_list(new_session)
          |> stream_insert(
            :chat_messages,
            system_message("* #{sender} has been auto-ignored for flooding (#{duration_str})")
          )

        {:error, _} ->
          socket
      end
    end
  end

  @spec cooldown_active?(map(), String.t()) :: boolean()
  defp cooldown_active?(auto_state, sender_key) do
    case Map.get(auto_state.cooldowns, sender_key) do
      nil ->
        false

      cooldown_until ->
        System.monotonic_time(:millisecond) < cooldown_until
    end
  end

  @spec format_duration(integer()) :: String.t()
  defp format_duration(seconds) when seconds >= 3600 do
    hours = div(seconds, 3600)
    "#{hours} hour#{if hours > 1, do: "s", else: ""}"
  end

  defp format_duration(seconds) when seconds >= 60 do
    minutes = div(seconds, 60)
    "#{minutes} minute#{if minutes > 1, do: "s", else: ""}"
  end

  defp format_duration(seconds), do: "#{seconds} seconds"

  @spec try_set(map(), (map(), integer() -> map() | {:error, atom()}), String.t() | nil) ::
          map()
  defp try_set(settings, _setter, nil), do: settings

  defp try_set(settings, setter, value_str) do
    case Integer.parse(value_str) do
      {value, _} ->
        case setter.(settings, value) do
          {:error, _} -> settings
          updated -> updated
        end

      :error ->
        settings
    end
  end

  @spec maybe_send_ctcp_reply(
          Phoenix.LiveView.Socket.t(),
          Session.t(),
          map(),
          atom(),
          String.t(),
          String.t(),
          integer()
        ) :: Phoenix.LiveView.Socket.t()
  defp maybe_send_ctcp_reply(
         socket,
         _session,
         %{enabled: false},
         _type,
         _sender,
         _req_id,
         _sent_at
       ),
       do: socket

  defp maybe_send_ctcp_reply(socket, session, _settings, type, sender, req_id, sent_at) do
    flood_settings = session.flood_protection
    reply_limit = FloodProtection.get_ctcp_reply_limit(flood_settings)
    reply_window = FloodProtection.get_ctcp_reply_window_seconds(flood_settings)

    if ctcp_reply_allowed?(socket.assigns.ctcp_reply_tracker, reply_limit, reply_window) do
      socket = record_ctcp_reply(socket)
      value = generate_ctcp_reply_value(session, type)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{sender}",
        {:ctcp_reply,
         %{
           type: type,
           replier: session.nickname,
           request_id: req_id,
           value: value,
           sent_at: sent_at
         }}
      )

      socket
    else
      socket
    end
  end

  @spec ctcp_reply_allowed?(map(), integer(), integer()) :: boolean()
  defp ctcp_reply_allowed?(tracker, limit, window_seconds) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_seconds * 1000

    recent =
      Enum.count(tracker.timestamps, fn ts -> ts > cutoff end)

    recent < limit
  end

  @spec record_ctcp_reply(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp record_ctcp_reply(socket) do
    tracker = socket.assigns.ctcp_reply_tracker
    now = System.monotonic_time(:millisecond)
    new_tracker = %{tracker | timestamps: [now | tracker.timestamps]}
    assign(socket, ctcp_reply_tracker: new_tracker)
  end

  @cooldown_duration_ms 60_000

  @spec cancel_auto_ignore_with_cooldown(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp cancel_auto_ignore_with_cooldown(socket, nick) do
    sender_key = String.downcase(nick)
    auto_state = socket.assigns.auto_ignore_state

    case Map.get(auto_state.active, sender_key) do
      nil ->
        socket

      timer_ref ->
        Process.cancel_timer(timer_ref)

        # Remove from active, add cooldown
        new_active = Map.delete(auto_state.active, sender_key)
        cooldown_until = System.monotonic_time(:millisecond) + @cooldown_duration_ms
        new_cooldowns = Map.put(auto_state.cooldowns, sender_key, cooldown_until)

        new_auto_state = %{active: new_active, cooldowns: new_cooldowns}

        # Reset flood tracker for sender
        new_tracker = FloodTracker.reset_sender(socket.assigns.flood_tracker, nick)

        assign(socket,
          auto_ignore_state: new_auto_state,
          flood_tracker: new_tracker
        )
    end
  end

  @spec play_event_sound(Phoenix.LiveView.Socket.t(), atom(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  defp play_event_sound(socket, event_type, session) do
    sound = SoundSettings.get_sound(session.sound_settings, event_type)

    if sound == "none" do
      socket
    else
      push_event(socket, "play_sound", %{type: sound})
    end
  end

  @spec maybe_play_highlight_sound(Phoenix.LiveView.Socket.t(), map(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_play_highlight_sound(socket, %{highlighted: true}, session) do
    play_event_sound(socket, :highlight, session)
  end

  defp maybe_play_highlight_sound(socket, _payload, _session), do: socket

  @spec maybe_flash_channel(Phoenix.LiveView.Socket.t(), String.t(), atom(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_flash_channel(socket, channel_key, event_type, session) do
    if SoundSettings.get_flash(session.sound_settings, event_type) do
      flash = MapSet.put(socket.assigns.flash_channels, channel_key)

      socket
      |> assign(flash_channels: flash)
      |> push_event("title_flash_start", %{message: "* New activity"})
    else
      socket
    end
  end

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
      content |> Formatter.strip() |> URLDetector.linkify()
    else
      {:safe, html} = Formatter.to_safe_html(content)
      URLDetector.linkify_html(html)
    end
  end

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  defp format_time(_), do: "--:--"

  defp format_status_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  defp format_status_time(_), do: "--:--"

  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end

  # -- Perform helpers --

  defp maybe_trigger_perform(socket) do
    session = socket.assigns.session

    if PerformList.enabled?(session.perform_list) and
         PerformList.count(session.perform_list) > 0 do
      send(self(), {:execute_perform, 0})
    end

    socket
  end

  defp execute_perform_command(socket, session, command) do
    case Parser.parse(command) do
      {:command, name, args} ->
        dispatch_command(socket, session, name, args)

      {:message, _text} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Perform: invalid command format: #{PerformList.mask_command(command)}")
        )
    end
  end
end
