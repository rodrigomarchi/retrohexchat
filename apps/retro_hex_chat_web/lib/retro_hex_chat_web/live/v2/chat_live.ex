defmodule RetroHexChatWeb.V2.ChatLive do
  @moduledoc """
  v2 main chat interface using new UI components.

  This is a full rewrite — no v1 code reuse. The UI is composed entirely from
  the new component library in `components/ui/`. Backend domain contexts and
  PubSub patterns are used directly.
  """
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  # ── Shell components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp

  # ── Chat components ──────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.Conversations
  import RetroHexChatWeb.Components.UI.IrcTabs
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.ChatInput
  import RetroHexChatWeb.Components.UI.Nicklist
  import RetroHexChatWeb.Components.UI.SearchBar
  import RetroHexChatWeb.Components.UI.FormattingToolbar
  import RetroHexChatWeb.Components.UI.EmojiPicker
  import RetroHexChatWeb.Components.UI.Autocomplete
  import RetroHexChatWeb.Components.UI.ReplyBar
  import RetroHexChatWeb.Components.UI.ConnectionStatus
  import RetroHexChatWeb.Components.UI.HoverCard
  import RetroHexChatWeb.Components.UI.ScrollLoader
  import RetroHexChatWeb.Components.UI.SyntaxTooltip
  import RetroHexChatWeb.Components.UI.ChatContextMenu
  import RetroHexChatWeb.Components.UI.ConversationsContextMenu
  import RetroHexChatWeb.Components.UI.LoadingSpinner
  import RetroHexChatWeb.Components.UI.HistorySearch
  import RetroHexChatWeb.Components.UI.TypingIndicator
  import RetroHexChatWeb.Components.UI.MessageReplyBlock
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.P2PInviteCard
  import RetroHexChatWeb.Components.UI.ArcadeSessionLink
  import RetroHexChatWeb.Components.UI.MessageIndicators
  import RetroHexChatWeb.Components.UI.NicklistContextMenu

  # ── Dialog components ────────────────────────────────────────
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.Components.UI.AliasDialog
  import RetroHexChatWeb.Components.UI.AutoRespondDialog
  import RetroHexChatWeb.Components.UI.ChannelCentralDialog
  import RetroHexChatWeb.Components.UI.ChannelList
  import RetroHexChatWeb.Components.UI.CheatsheetDialog
  import RetroHexChatWeb.Components.UI.CtcpSettingsDialog
  import RetroHexChatWeb.Components.UI.CustomMenusDialog
  import RetroHexChatWeb.Components.UI.DeleteConfirmDialog
  import RetroHexChatWeb.Components.UI.DisconnectConfirmDialog
  import RetroHexChatWeb.Components.UI.FloodProtectionDialog
  import RetroHexChatWeb.Components.UI.HighlightDialog
  import RetroHexChatWeb.Components.UI.IgnoreListDialog
  import RetroHexChatWeb.Components.UI.InviteDialog
  import RetroHexChatWeb.Components.UI.KickDialog
  import RetroHexChatWeb.Components.UI.NickChangeDialog
  import RetroHexChatWeb.Components.UI.NotifyList

  import RetroHexChatWeb.Components.UI.PasteConfirmDialog
  import RetroHexChatWeb.Components.UI.PerformDialog
  import RetroHexChatWeb.Components.UI.SoundSettingsDialog
  import RetroHexChatWeb.Components.UI.UrlCatcher
  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.BotFormDialog
  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  # ── HTML helpers ─────────────────────────────────────────────
  import Phoenix.HTML, only: [raw: 1]

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, ServerRoles, Session}
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.{Motd, Queries}

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    CapturedURL,
    CustomMenus,
    DuplicateTracker,
    EmojiData,
    FloodTracker,
    HighlightWords,
    IgnoreList,
    KeyBindings,
    PerformList,
    UnreadTracker
  }

  alias RetroHexChat.Presence.{NotifyList, WhowasCache}
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.Timezone
  alias RetroHexChatWeb.V2.V2Helpers

  # ── Mount ─────────────────────────────────────────────────────

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(params, http_session, socket) do
    nickname = http_session["chat_nickname"]

    case validate_session_nickname(nickname) do
      :ok ->
        session = Session.new(nickname)
        pre_identified = http_session["chat_pre_identified"] == true
        join_channel = params["join"]

        if connected?(socket) do
          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "user:#{nickname}",
            {:force_disconnect, %{reason: "Session ended — logged in from another window"}}
          )

          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "presence:global",
            {:user_connected, %{nickname: nickname}}
          )

          timezone = resolve_timezone(http_session, socket)
          client_info = parse_client_info(get_connect_params(socket))

          ChatLive.Helpers.safe_track_user("presence:global", nickname)

          socket =
            socket
            |> assign(v2: true)
            |> attach_all_hooks()
            |> assign_defaults(session)
            |> assign(timezone: timezone, client_info: client_info)
            |> ChatLive.Helpers.join_channel(
              Application.get_env(:retro_hex_chat, :default_channel, "#lobby"),
              session
            )
            |> ChatLive.Helpers.maybe_join_channel(join_channel)
            |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, pre_identified)
            |> ChatLive.Helpers.maybe_trigger_perform()
            |> ChatLive.Helpers.play_event_sound(:connect, session)
            |> maybe_show_motd()
            |> show_welcome_message()
            |> show_chanserv_announcement()
            |> show_nickserv_announcement()
            |> push_initial_preferences()

          {:ok, socket}
        else
          {:ok,
           socket
           |> assign(v2: true)
           |> assign_defaults(session)
           |> assign(
             timezone: Timezone.validate(http_session["chat_timezone"]),
             client_info: %{}
           )}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/connect")}
    end
  end

  # ── Terminate ─────────────────────────────────────────────────

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      quit_reason = socket.assigns[:quit_reason] || "Leaving"

      Queries.update_last_seen_by_nickname(session.nickname)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: session.nickname}}
      )

      ChatLive.Helpers.safe_untrack_user("presence:global", session.nickname)
      WhowasCache.record(session.nickname, session.channels, quit_reason)

      ChatLive.Helpers.cleanup_channels(session, quit_reason)
    end

    :ok
  end

  # ── Event dispatchers ─────────────────────────────────────────
  # v2 components use compound action events (on_action="toolbar_action" with
  # phx-value-action), but the shared v1 event handlers expect individual events.
  # These dispatchers translate between the two patterns.
  #
  # IMPORTANT: Dispatchers call dispatch_to_hooks/3 (NOT handle_event/3) because
  # handle_event/3 only matches clauses defined in THIS module. The actual event
  # handlers live in attached hook modules (CoreEvents, MenuToolbarEvents, etc.)
  # which are only invoked for events coming from the client. dispatch_to_hooks/3
  # simulates the hook pipeline for internally-dispatched events.

  @impl true

  # Toolbar actions — components emit v1 event names directly
  def handle_event("toolbar_action", %{"action" => action}, socket) do
    dispatch_to_hooks(action, %{}, socket)
  end

  # Tab bar actions → type-specific v1 events
  def handle_event("switch_tab", %{"type" => type, "label" => label}, socket) do
    case type do
      "status" -> dispatch_to_hooks("switch_to_status", %{}, socket)
      "channel" -> dispatch_to_hooks("switch_channel", %{"channel" => label}, socket)
      "pm" -> dispatch_to_hooks("switch_pm", %{"nickname" => label}, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("close_tab", %{"type" => type, "label" => label}, socket) do
    case type do
      "status" -> dispatch_to_hooks("switch_to_status", %{}, socket)
      "channel" -> dispatch_to_hooks("close_channel_tab", %{"channel" => label}, socket)
      "pm" -> dispatch_to_hooks("close_pm_tab", %{"nickname" => label}, socket)
      _ -> {:noreply, socket}
    end
  end

  # Context menus — components emit v1 event names directly
  def handle_event("chat_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  def handle_event("conversations_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  def handle_event("nicklist_context_action", %{"action" => action} = params, socket) do
    dispatch_to_hooks(action, Map.delete(params, "action"), socket)
  end

  # ── Catch-all handle_info ─────────────────────────────────────

  @impl true
  def handle_info({_ref, _result}, socket), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_, socket), do: {:noreply, socket}

  # ── Render ────────────────────────────────────────────────────
  # Template is in chat_live.html.heex (auto-detected by Phoenix)

  # ── Private helper: render individual message ─────────────────

  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :edit_mode_message_id, :any, required: true

  defp render_message(assigns) do
    ~H"""
    <%= case Map.get(@msg, :type, :normal) do %>
      <% :action -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="action"
        >
          * {@msg.author} {raw(V2Helpers.format_content(@msg.content, @strip_formatting))}
        </.chat_message>
      <% :system -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          * {@msg.content}
        </.chat_message>
      <% :service -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="service"
        >
          {@msg.content}
        </.chat_message>
      <% :error -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="error"
        >
          {@msg.content}
        </.chat_message>
      <% :notice -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="notice"
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          {@msg.content}
        </.chat_message>
      <% :inline_help -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          <.inline_help_card
            topic_id={@msg.topic_id}
            topic_title={@msg.topic_title}
            help_url={~p"/chat/help/#{@msg.topic_id}"}
          />
        </.chat_message>
      <% :arcade_link -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          <.arcade_session_link href={@msg.content} />
        </.chat_message>
      <% :p2p_invite -> %>
        <.chat_message
          timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          <.p2p_invite_card
            label={V2Helpers.extract_p2p_label(@msg.content)}
            link={V2Helpers.extract_p2p_link(@msg.content)}
          />
        </.chat_message>
      <% _ -> %>
        <.message_reply_block
          :if={Map.get(@msg, :reply_to_id)}
          parent_id={@msg.reply_to_id}
          author={Map.get(@msg, :reply_to_author, "?")}
          preview={Map.get(@msg, :reply_to_preview)}
          nick_color={@nick_color_fn.(Map.get(@msg, :reply_to_author, ""))}
          on_click="scroll_to_reply_parent"
        />
        <%= if Map.get(@msg, :deleted_at) do %>
          <.chat_message timestamp={
            V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)
          }>
            <.deleted_placeholder />
          </.chat_message>
        <% else %>
          <.chat_message
            timestamp={V2Helpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            {raw(V2Helpers.format_content(@msg.content, @strip_formatting))}
            <.edited_tag
              :if={Map.get(@msg, :edited_at)}
              timestamp={V2Helpers.format_edit_timestamp(@msg.edited_at, @timezone)}
            />
            <.retry_button
              :if={Map.get(@msg, :status) == :failed}
              temp_id={@msg.id}
              content={@msg.content}
              target={Map.get(@msg, :target, "")}
              on_retry="retry_message"
            />
          </.chat_message>
        <% end %>
    <% end %>
    """
  end

  # ── Private helpers ───────────────────────────────────────────

  @spec validate_session_nickname(String.t() | nil) :: :ok | {:error, String.t()}
  defp validate_session_nickname(nil), do: {:error, "No nickname in session"}
  defp validate_session_nickname(nickname), do: NicknameValidator.validate(nickname)

  @spec resolve_timezone(map(), Phoenix.LiveView.Socket.t()) :: String.t()
  defp resolve_timezone(http_session, socket) do
    session_tz = http_session["chat_timezone"]
    connect_params = get_connect_params(socket)
    params_tz = Map.get(connect_params || %{}, "timezone")

    tz =
      cond do
        session_tz && session_tz != "" && session_tz != "Etc/UTC" -> session_tz
        params_tz && params_tz != "" -> params_tz
        true -> "Etc/UTC"
      end

    Timezone.validate(tz)
  end

  @allowed_client_keys %{
    "browser" => :browser,
    "os" => :os,
    "language" => :language,
    "screen" => :screen,
    "color_depth" => :color_depth,
    "touch" => :touch,
    "cores" => :cores,
    "timezone" => :timezone
  }
  @max_string_length 100

  @spec parse_client_info(map() | nil) :: map()
  defp parse_client_info(nil), do: %{}

  defp parse_client_info(params) do
    case params["client_info"] do
      json when is_binary(json) -> decode_client_json(json)
      _ -> %{}
    end
  end

  defp decode_client_json(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) ->
        Map.new(@allowed_client_keys, fn {str_key, atom_key} ->
          {atom_key, sanitize_client_value(data[str_key])}
        end)

      _ ->
        %{}
    end
  end

  defp sanitize_client_value(val) when is_binary(val),
    do: String.slice(val, 0, @max_string_length)

  defp sanitize_client_value(val) when is_integer(val), do: val
  defp sanitize_client_value(val) when is_boolean(val), do: val
  defp sanitize_client_value(_), do: nil

  # ── Hook dispatch ─────────────────────────────────────────────
  # Ordered list of event hook functions. Used by both attach_all_hooks/1
  # (to register LiveView hooks) and dispatch_to_hooks/3 (to simulate the
  # hook pipeline for internally-dispatched events).

  @event_hook_fns [
    &ChatLive.EmojiEvents.handle_event/3,
    &ChatLive.UrlCatcherEvents.handle_event/3,
    &ChatLive.InviteEvents.handle_event/3,
    &ChatLive.PmTypingEvents.handle_event/3,
    &ChatLive.AliasEvents.handle_event/3,
    &ChatLive.CustomMenusEvents.handle_event/3,
    &ChatLive.AutorespondEvents.handle_event/3,
    &ChatLive.HighlightEvents.handle_event/3,
    &ChatLive.IgnoreEvents.handle_event/3,
    &ChatLive.SettingsDialogsEvents.handle_event/3,
    &ChatLive.NotifyEvents.handle_event/3,
    &ChatLive.AddressBookEvents.handle_event/3,
    &ChatLive.ConversationsEvents.handle_event/3,
    &ChatLive.ConversationsContextMenuEvents.handle_event/3,
    &ChatLive.ChannelCentralEvents.handle_event/3,
    &ChatLive.NavigationEvents.handle_event/3,
    &ChatLive.SearchEvents.handle_event/3,
    &ChatLive.PerformAutojoinEvents.handle_event/3,
    &ChatLive.ChannelListEvents.handle_event/3,
    &ChatLive.MenuToolbarEvents.handle_event/3,
    &ChatLive.HoverEvents.handle_event/3,
    &ChatLive.ContextMenuEvents.handle_event/3,
    &ChatLive.TipEvents.handle_event/3,
    &ChatLive.AdminConsoleEvents.handle_event/3,
    &ChatLive.BotEvents.handle_event/3,
    &ChatLive.KickEvents.handle_event/3,
    &ChatLive.KeyboardEvents.handle_event/3,
    &ChatLive.ConnectionEvents.handle_event/3,
    &ChatLive.CoreEvents.handle_event/3
  ]

  @spec dispatch_to_hooks(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp dispatch_to_hooks(event, params, socket) do
    result =
      Enum.reduce_while(@event_hook_fns, socket, fn hook_fn, acc ->
        case hook_fn.(event, params, acc) do
          {:halt, updated_socket} -> {:halt, {:halted, updated_socket}}
          {:cont, updated_socket} -> {:cont, updated_socket}
        end
      end)

    case result do
      {:halted, socket} -> {:noreply, socket}
      socket -> {:noreply, socket}
    end
  end

  # ── Hooks ─────────────────────────────────────────────────────

  defp attach_all_hooks(socket) do
    event_hooks = [
      {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
      {:url_catcher_events, &ChatLive.UrlCatcherEvents.handle_event/3},
      {:invite_events, &ChatLive.InviteEvents.handle_event/3},
      {:pm_typing_events, &ChatLive.PmTypingEvents.handle_event/3},
      {:alias_events, &ChatLive.AliasEvents.handle_event/3},
      {:custom_menus_events, &ChatLive.CustomMenusEvents.handle_event/3},
      {:autorespond_events, &ChatLive.AutorespondEvents.handle_event/3},
      {:highlight_events, &ChatLive.HighlightEvents.handle_event/3},
      {:ignore_events, &ChatLive.IgnoreEvents.handle_event/3},
      {:settings_dialogs_events, &ChatLive.SettingsDialogsEvents.handle_event/3},
      {:notify_events, &ChatLive.NotifyEvents.handle_event/3},
      {:address_book_events, &ChatLive.AddressBookEvents.handle_event/3},
      {:conversations_events, &ChatLive.ConversationsEvents.handle_event/3},
      {:conversations_context_menu_events,
       &ChatLive.ConversationsContextMenuEvents.handle_event/3},
      {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
      {:navigation_events, &ChatLive.NavigationEvents.handle_event/3},
      {:search_events, &ChatLive.SearchEvents.handle_event/3},
      {:perform_autojoin_events, &ChatLive.PerformAutojoinEvents.handle_event/3},
      {:channel_list_events, &ChatLive.ChannelListEvents.handle_event/3},
      {:menu_toolbar_events, &ChatLive.MenuToolbarEvents.handle_event/3},
      {:hover_events, &ChatLive.HoverEvents.handle_event/3},
      {:context_menu_events, &ChatLive.ContextMenuEvents.handle_event/3},
      {:tip_events, &ChatLive.TipEvents.handle_event/3},
      {:admin_console_events, &ChatLive.AdminConsoleEvents.handle_event/3},
      {:bot_events, &ChatLive.BotEvents.handle_event/3},
      {:kick_events, &ChatLive.KickEvents.handle_event/3},
      {:keyboard_events, &ChatLive.KeyboardEvents.handle_event/3},
      {:connection_events, &ChatLive.ConnectionEvents.handle_event/3},
      {:core_events, &ChatLive.CoreEvents.handle_event/3}
    ]

    info_hooks = [
      {:timer_handlers, &ChatLive.TimerHandlers.handle_info/2},
      {:pubsub_handlers, &ChatLive.PubsubHandlers.handle_info/2}
    ]

    socket =
      Enum.reduce(event_hooks, socket, fn {name, fun}, acc ->
        attach_hook(acc, name, :handle_event, fun)
      end)

    Enum.reduce(info_hooks, socket, fn {name, fun}, acc ->
      attach_hook(acc, name, :handle_info, fun)
    end)
  end

  # ── Assign defaults ───────────────────────────────────────────

  defp assign_defaults(socket, session) do
    socket
    |> assign(
      channel_users: [],
      command_history: [],
      autocomplete_command: nil,
      autocomplete_filter: "",
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0,
      autocomplete_visible: false,
      recent_commands: [],
      contacts_selected: nil,
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
      },
      context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        target_nick: nil,
        is_target_registered: false
      },
      nick_color_fn: V2Helpers.build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      hover_card: ChatLive.HoverEvents.default_hover_card(),
      input: "",
      link_previews: %{},
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: "RetroHexChat",
      search_case_sensitive: false,
      search_current_index: 0,
      search_error: nil,
      search_history: false,
      search_history_count: 0,
      search_last_query: "",
      search_my_mentions: false,
      search_query: "",
      search_regex: false,
      search_result_count: 0,
      search_results: [],
      search_visible: false,
      session: session,
      tips_suppressed: false,
      cheatsheet_visible: false,
      show_about: false,
      show_address_book: false,
      show_context_color_picker: false,
      show_contact_add_dialog: false,
      show_contact_edit_dialog: false,
      address_book_tab: "contacts",
      show_nick_color_add_dialog: false,
      show_nick_color_edit_dialog: false,
      show_status_tab: false,
      status_unread: false,
      show_notify_add_dialog: false,
      show_notify_edit_dialog: false,
      show_notify_list: false,
      highlight_channels: MapSet.new(),
      highlight_selected: nil,
      highlight_selected_color: nil,
      selected_note: "",
      selected_contact_note: "",
      selected_notify_note: "",
      show_highlight_add_dialog: false,
      show_highlight_dialog: false,
      show_highlight_edit_dialog: false,
      current_topic: nil,
      current_modes: nil,
      show_conversations: true,
      channel_user_counts: %{},
      popular_channels: [],
      popular_channels_loaded: false,
      conversations_sections: %{channels: true, pms: true, popular: false},
      show_url_catcher: false,
      show_whois: false,
      unread_counts: %{},
      kick_queue: [],
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
      control_selected: nil,
      show_control_add_dialog: false,
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
      pending_invites: [],
      reconnect_active_channel: nil,
      reconnect_active_pm: nil,
      ctcp_pending: %{},
      ctcp_rate_limits: %{},
      knock_timestamps: %{},
      show_ctcp_settings_dialog: false,
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
      ctcp_reply_tracker: %{timestamps: []},
      show_flood_protection_dialog: false,
      show_sound_settings_dialog: false,
      sound_settings_draft: nil,
      show_nicklist: true,
      nick_palette_editing_index: nil,
      muted: false,
      muted_channels: MapSet.new(),
      flash_channels: MapSet.new(),
      pm_typing_from: nil,
      pm_typing_timer: nil,
      conversations_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
      last_activity_at: DateTime.utc_now(),
      show_alias_dialog: false,
      alias_dialog_selected: nil,
      alias_dialog_editing: false,
      alias_dialog_draft_name: "",
      alias_dialog_draft_expansion: "",
      alias_dialog_warning: nil,
      alias_dialog_error: nil,
      user_timers: %{},
      autorespond_cooldowns: %{},
      show_custom_menus_dialog: false,
      custom_menus_dialog_tab: :nicklist,
      custom_menus_dialog_selected: nil,
      custom_menus_dialog_editing: false,
      custom_menus_dialog_draft_label: "",
      custom_menus_dialog_draft_command: "",
      custom_menus_dialog_error: nil,
      show_autorespond_dialog: false,
      autorespond_dialog_selected: nil,
      autorespond_dialog_editing: false,
      autorespond_dialog_draft_trigger: "on_join",
      autorespond_dialog_draft_channel: "",
      autorespond_dialog_draft_command: "",
      autorespond_dialog_error: nil,
      show_admin_console: false,
      admin_console_results: [],
      show_bot_dialog: false,
      bot_dialog_bots: [],
      bot_dialog_selected: nil,
      bot_dialog_channels: [],
      bot_dialog_commands: [],
      bot_dialog_tab: :general,
      bot_dialog_events: [],
      bot_dialog_stats: nil,
      bot_dialog_editing_field: nil,
      show_new_bot_dialog: false,
      show_add_command_dialog: false,
      away_replied_to: MapSet.new(),
      paste_lines: nil,
      paste_flood_warning: false,
      paste_send_disabled: false,
      quit_reason: nil,
      show_emoji_picker: false,
      emoji_search: "",
      emoji_category: "Smileys & Emotion",
      emoji_emojis: EmojiData.by_category("Smileys & Emotion"),
      syntax_tooltip: nil,
      command_help_level: :beginner,
      timestamp_format: :dd_mm_hh_mm,
      lag_ms: nil,
      lag_status: :normal,
      loading_channel: nil,
      reply_to: nil,
      edit_mode_message_id: nil,
      edit_original_input: nil,
      show_disconnect_confirm: false,
      delete_confirm: nil,
      nick_change_dialog: nil,
      nick_change_target: nil,
      nick_change_token: nil,
      show_channel_list: false,
      channel_list_channels: [],
      channel_list_filtered: [],
      channel_list_search: "",
      channel_list_loading: false,
      channel_list_count: 0
    )
    |> stream(:chat_messages, [])
    |> stream(:status_messages, [])
  end

  # ── View helpers ──────────────────────────────────────────────

  defp admin?(session) do
    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end

  defp viewer_is_op?(session) do
    case session.active_channel do
      nil ->
        false

      channel ->
        case Server.get_state(channel) do
          {:ok, state} ->
            session.nickname in state.operators or
              session.nickname in Map.get(state, :owners, [])

          {:error, _} ->
            false
        end
    end
  rescue
    e ->
      Logger.warning("Failed to check operator status: #{inspect(e)}")
      false
  end

  defp chat_context_target_ignored?(_session, %{target_nick: nil}), do: false

  defp chat_context_target_ignored?(session, %{target_nick: nick}) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  defp message_classes(msg, edit_mode_message_id) do
    base = "chat-message chat-message--#{Map.get(msg, :type, :normal)}"

    highlighted =
      if Map.get(msg, :highlighted), do: " chat-message--highlighted", else: ""

    highlight_bg = V2Helpers.highlight_bg_class(msg)

    pending =
      if Map.get(msg, :status) == :pending, do: " chat-message--pending", else: ""

    failed =
      if Map.get(msg, :status) == :failed, do: " chat-message--failed", else: ""

    deleted =
      if Map.get(msg, :deleted_at), do: " chat-message--deleted", else: ""

    editing =
      if Map.get(msg, :id) == edit_mode_message_id, do: " chat-message--editing", else: ""

    base <> highlighted <> highlight_bg <> pending <> failed <> deleted <> editing
  end

  defp filtered_url_catcher_entries(assigns) do
    assigns.url_catcher_entries
    |> CapturedURL.filter_by_source(assigns.url_catcher_filter_channel)
    |> CapturedURL.filter_by_url(assigns.url_catcher_search_query)
    |> CapturedURL.sort_by(assigns.url_catcher_sort_column, assigns.url_catcher_sort_direction)
  end

  defp url_catcher_channels(assigns) do
    assigns.url_catcher_entries
    |> Enum.map(& &1.source)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp channel_central_bans(nil), do: []

  defp channel_central_bans(state) do
    state |> Map.get(:bans, []) |> Enum.map(&to_list_entry/1)
  end

  defp channel_central_ban_exceptions(nil), do: []

  defp channel_central_ban_exceptions(state) do
    state |> Map.get(:ban_exceptions, []) |> Enum.map(&to_list_entry/1)
  end

  defp channel_central_invite_exceptions(nil), do: []

  defp channel_central_invite_exceptions(state) do
    state |> Map.get(:invite_exceptions, []) |> Enum.map(&to_list_entry/1)
  end

  @spec to_list_entry(map() | String.t()) :: map()
  defp to_list_entry(%{mask: _} = map), do: map
  defp to_list_entry(nick) when is_binary(nick), do: %{mask: nick, set_by: "—", set_at: "—"}

  defp channel_central_topic(nil), do: ""
  defp channel_central_topic(state), do: Map.get(state, :topic, "")

  defp channel_central_topic_set_by(nil), do: nil
  defp channel_central_topic_set_by(state), do: Map.get(state, :topic_set_by)

  defp channel_central_topic_set_at(nil, _tz), do: nil

  defp channel_central_topic_set_at(state, timezone) do
    case Map.get(state, :topic_set_at) do
      nil -> nil
      dt -> V2Helpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_created_at(nil, _tz), do: nil

  defp channel_central_created_at(state, timezone) do
    case Map.get(state, :created_at) do
      nil -> nil
      dt -> V2Helpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_member_count(nil), do: 0
  defp channel_central_member_count(state), do: Map.get(state, :member_count, 0)

  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, nick) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  # ── Startup messages ──────────────────────────────────────────

  defp maybe_show_motd(socket) do
    case Motd.get() do
      nil -> socket
      content -> ChatLive.Helpers.push_status_message(socket, content, :motd)
    end
  end

  defp show_welcome_message(socket) do
    server_name = Queries.get_setting("server_name") || "RetroHexChat"

    lines = [
      "Welcome to #{server_name}!",
      "A real-time chat platform with a retro look and feel.",
      "",
      "Useful commands:",
      "  /join #channel   — Join a channel",
      "  /msg nick text   — Send a private message",
      "  /nick new_nick   — Change your nickname",
      "  /help            — View full help",
      "  /help commands   — List all commands",
      "",
      "Tip: Go to Help > Help Topics for the full documentation, or open /chat/help in a new tab."
    ]

    socket =
      Enum.reduce(lines, socket, fn line, acc ->
        ChatLive.Helpers.push_status_message(acc, line, :system)
      end)

    case Queries.get_setting("welcome_message") do
      nil -> socket
      msg -> ChatLive.Helpers.push_status_message(socket, msg, :system)
    end
  end

  defp show_chanserv_announcement(socket) do
    lines = [
      "",
      "[ChanServ] Channel Services Online",
      "ChanServ manages channel registration and access control.",
      "Register your channel to protect it when no operators are online.",
      "",
      "Quick start:",
      "  /cs register #channel          — Register a channel you operate",
      "  /cs sop #channel add <nick>    — Add a Super Operator",
      "  /cs aop #channel add <nick>    — Add an Auto Operator",
      "  /cs vop #channel add <nick>    — Add an Auto Voice user",
      "  /cs info #channel              — View channel registration info",
      "",
      "Access hierarchy: Owner > SOP > AOP > VOP",
      "",
      "Rules:",
      "  • Channels expire after 7 days of inactivity",
      "  • If a founder's nick expires, the next ranked user is promoted",
      "",
      "Type /help chanserv or /help channel-permissions for full details."
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      ChatLive.Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp show_nickserv_announcement(socket) do
    lines = [
      "",
      "[NickServ] Nickname Services Online",
      "NickServ protects your nickname with a password so nobody else can use it.",
      "",
      "Quick start:",
      "  /ns register <password>   — Register your current nickname",
      "  /ns identify <password>   — Identify (log in) for this session",
      "  /ns info [nickname]       — Look up registration info",
      "  /ns ghost <nick>          — Disconnect a ghost session",
      "  /ns drop <password>       — Permanently unregister your nickname",
      "",
      "Rules:",
      "  • Nicks are case sensitive — \"Alice\" and \"alice\" are different",
      "  • Nicks expire after 7 days of inactivity",
      "  • Switching to a registered nick gives you 60s to identify",
      "",
      "Type /help nickserv for full details."
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      ChatLive.Helpers.push_status_message(acc, line, :service)
    end)
  end

  @spec cheatsheet_bindings() :: [map()]
  defp cheatsheet_bindings do
    KeyBindings.defaults()
    |> KeyBindings.categories()
    |> Enum.map(fn {category, entries} ->
      %{
        category: KeyBindings.category_label(category),
        items:
          Enum.map(entries, fn entry ->
            %{
              action: entry.label,
              keys: format_binding(entry.binding),
              description: entry.description
            }
          end)
      }
    end)
  end

  @spec format_binding(map() | nil) :: String.t()
  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)

  defp push_initial_preferences(socket) do
    socket
    |> push_event("update_bindings", %{
      bindings: KeyBindings.to_persistable(KeyBindings.defaults())
    })
  end
end
