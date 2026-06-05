defmodule RetroHexChatWeb.App.ChatLive do
  @moduledoc """
  Main chat interface using the app UI components.

  This is a full rewrite — no v1 code reuse. The UI is composed entirely from
  the new component library in `components/ui/`. Backend domain contexts and
  PubSub patterns are used directly.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

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
  import RetroHexChatWeb.Components.UI.AccountDialog
  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.Components.UI.AliasDialog
  import RetroHexChatWeb.Components.UI.AutoRespondDialog
  import RetroHexChatWeb.Components.UI.ChannelCentralDialog
  import RetroHexChatWeb.Components.UI.ChannelList
  import RetroHexChatWeb.Components.UI.CheatsheetDialog
  import RetroHexChatWeb.Components.UI.CustomMenusDialog
  import RetroHexChatWeb.Components.UI.DeleteConfirmDialog
  import RetroHexChatWeb.Components.UI.DisconnectConfirmDialog
  import RetroHexChatWeb.Components.UI.FloodProtectionDialog
  import RetroHexChatWeb.Components.UI.HighlightDialog

  import RetroHexChatWeb.Components.UI.InviteDialog
  import RetroHexChatWeb.Components.UI.InviteChannelPickerDialog
  import RetroHexChatWeb.Components.UI.KickDialog
  import RetroHexChatWeb.Components.UI.KnockRequestDialog
  import RetroHexChatWeb.Components.UI.MuteDurationDialog
  import RetroHexChatWeb.Components.UI.NickChangeDialog
  import RetroHexChatWeb.Components.UI.NotifyList

  import RetroHexChatWeb.Components.UI.PasteConfirmDialog
  import RetroHexChatWeb.Components.UI.PerformDialog
  import RetroHexChatWeb.Components.UI.SoundSettingsDialog
  import RetroHexChatWeb.Components.UI.TimersDialog
  import RetroHexChatWeb.Components.UI.UrlCatcher
  import RetroHexChatWeb.Components.UI.UserLookupDialog
  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.BotFormDialog
  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  # ── HTML helpers ─────────────────────────────────────────────
  import Phoenix.HTML, only: [raw: 1]

  # ── Domain aliases ────────────────────────────────────────────
  alias RetroHexChat.Accounts.{ContactList, NickColors, NicknameValidator, ServerRoles, Session}
  alias RetroHexChat.Admin.ServerBans
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

  alias RetroHexChat.Presence.{NotifyList, Tracker, WhowasCache}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.Timezone

  # ── Mount ─────────────────────────────────────────────────────

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(params, http_session, socket) do
    nickname = http_session["chat_nickname"]

    case validate_session_nickname(nickname) do
      :ok ->
        if ServerBans.banned?(nickname) do
          {:ok, push_navigate(socket, to: ~p"/connect?reason=banned")}
        else
          {:ok, mount_chat_session(params, http_session, socket, nickname)}
        end

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/connect")}
    end
  end

  defp mount_chat_session(params, http_session, socket, nickname) do
    session = Session.new(nickname)

    if connected?(socket) do
      mount_connected_chat(params, http_session, socket, session, nickname)
    else
      mount_disconnected_chat(http_session, socket, session)
    end
  end

  defp mount_connected_chat(params, http_session, socket, session, nickname) do
    default_channel = Application.get_env(:retro_hex_chat, :default_channel, "#lobby")
    takeover_expected? = takeover_expected?(default_channel, nickname)
    takeover_ref = make_ref()

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "user:#{nickname}",
      {:force_disconnect,
       %{
         reason: dgettext("chat", "Session ended — logged in from another window"),
         takeover_ack: {self(), takeover_ref}
       }}
    )

    if takeover_expected?, do: wait_for_takeover_cleanup(takeover_ref)

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
    previous_nickname = Map.get(socket.assigns.flash, "nick_changed_from")
    pre_identified = http_session["chat_pre_identified"] == true
    join_channel = params["join"]

    ChatLive.Helpers.safe_track_user("presence:global", nickname)

    socket
    |> attach_all_hooks()
    |> assign_defaults(session)
    |> assign(timezone: timezone, client_info: client_info)
    |> ChatLive.Helpers.join_channel(default_channel, session)
    |> ChatLive.Helpers.maybe_join_channel(join_channel)
    |> maybe_broadcast_nick_changed(previous_nickname, nickname)
    |> ChatLive.Helpers.maybe_start_nickserv_timer(nickname, pre_identified)
    |> ChatLive.Helpers.maybe_trigger_perform()
    |> ChatLive.Helpers.play_event_sound(:connect, session)
    |> maybe_show_motd()
    |> show_welcome_message()
    |> show_chanserv_announcement()
    |> show_nickserv_announcement()
    |> push_initial_preferences()
  end

  defp takeover_expected?(default_channel, nickname) do
    Tracker.online?("presence:global", nickname) or channel_has_member?(default_channel, nickname)
  end

  defp channel_has_member?(channel_name, nickname) do
    target = String.downcase(nickname)

    case Server.get_state(channel_name) do
      {:ok, state} ->
        Enum.any?(state.members, fn {member, _role} ->
          String.downcase(member) == target
        end)

      {:error, _} ->
        false
    end
  catch
    :exit, _reason -> false
  end

  defp wait_for_takeover_cleanup(ref) do
    receive do
      {:force_disconnect_ack, ^ref} -> :ok
    after
      1_000 ->
        Logger.warning("Timed out waiting for previous chat session takeover cleanup")
        :ok
    end
  end

  defp mount_disconnected_chat(http_session, socket, session) do
    socket
    |> assign_defaults(session)
    |> assign(
      timezone: Timezone.validate(http_session["chat_timezone"]),
      client_info: %{}
    )
  end

  # ── Terminate ─────────────────────────────────────────────────

  @impl true
  def terminate(_reason, socket) do
    session = connected?(socket) && socket.assigns[:session]

    if session do
      quit_reason = socket.assigns[:quit_reason] || dgettext("chat", "Leaving")

      Queries.update_last_seen_by_nickname(session.nickname)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "presence:global",
        {:user_disconnected, %{nickname: session.nickname}}
      )

      ChatLive.Helpers.safe_untrack_user("presence:global", session.nickname)
      WhowasCache.record(session.nickname, session.channels, quit_reason)

      unless socket.assigns[:skip_channel_cleanup] do
        ChatLive.Helpers.cleanup_channels(session, quit_reason)
      end
    end

    :ok
  end

  # ── Event dispatchers ─────────────────────────────────────────
  # App components use compound action events (on_action="toolbar_action" with
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

  def handle_event(event, params, socket) do
    dispatch_to_hooks(event, params, socket)
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
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="action"
        >
          * {@msg.author} {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
        </.chat_message>
      <% :system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          * {@msg.content}
        </.chat_message>
      <% :service -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="service"
        >
          {@msg.content}
        </.chat_message>
      <% :error -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="error"
        >
          {@msg.content}
        </.chat_message>
      <% :notice -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="notice"
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          {@msg.content}
        </.chat_message>
      <% :inline_help -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
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
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          <.arcade_session_link href={@msg.content} />
        </.chat_message>
      <% :p2p_invite -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          <.p2p_invite_card
            label={ChatHelpers.extract_p2p_label(@msg.content)}
            link={ChatHelpers.extract_p2p_link(@msg.content)}
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
            ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)
          }>
            <.deleted_placeholder />
          </.chat_message>
        <% else %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
            <.edited_tag
              :if={Map.get(@msg, :edited_at)}
              timestamp={ChatHelpers.format_edit_timestamp(@msg.edited_at, @timezone)}
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
  defp validate_session_nickname(nil), do: {:error, dgettext("chat", "No nickname in session")}
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
    &ChatLive.TimerEvents.handle_event/3,
    &ChatLive.HighlightEvents.handle_event/3,
    &ChatLive.SettingsDialogsEvents.handle_event/3,
    &ChatLive.AccountEvents.handle_event/3,
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
    &ChatLive.UserLookupEvents.handle_event/3,
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
      {:timer_events, &ChatLive.TimerEvents.handle_event/3},
      {:highlight_events, &ChatLive.HighlightEvents.handle_event/3},
      {:settings_dialogs_events, &ChatLive.SettingsDialogsEvents.handle_event/3},
      {:account_events, &ChatLive.AccountEvents.handle_event/3},
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
      {:user_lookup_events, &ChatLive.UserLookupEvents.handle_event/3},
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
      mute_duration_dialog: %{show: false, target_nick: nil},
      context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        target_nick: nil,
        is_target_registered: false
      },
      nick_color_fn: ChatHelpers.build_nick_color_fn(session),
      nick_colors_selected: nil,
      has_more: true,
      history_index: -1,
      hover_card: ChatLive.HoverEvents.default_hover_card(),
      input: "",
      action_mode: false,
      notice_target: nil,
      input_error: nil,
      chat_clear_token: 0,
      cleared_channel_cutoffs: %{},
      link_previews: %{},
      loading_more: false,
      messages: %{},
      new_messages_indicator: false,
      notify_debounce_timers: %{},
      notify_selected: nil,
      oldest_message_id: nil,
      page_title: dgettext("chat", "RetroHexChat"),
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
      show_account_dialog: false,
      account_dialog_tab: "register",
      account_auth_mode: "register",
      account_registered: false,
      account_error: nil,
      account_auth_valid: false,
      account_nick_error: nil,
      account_bio_draft: nil,
      account_bio_warning: nil,
      account_ghost_error: nil,
      account_last_away_message: nil,
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
      show_user_lookup_dialog: false,
      user_lookup_nick: "",
      user_lookup_error: nil,
      lookup_result: nil,
      whois_output_mode: :card,
      unread_counts: %{},
      kick_queue: [],
      url_catcher_entries: [],
      url_catcher_filter_channel: nil,
      url_catcher_search_query: "",
      url_catcher_sort_column: :timestamp,
      url_catcher_sort_direction: :desc,
      whois_target: nil,
      ignore_timers: %{},
      control_selected: nil,
      show_control_add_dialog: false,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_state: nil,
      channel_central_channel: nil,
      channel_central_operator: false,
      channel_central_owner: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      channel_central_notice: nil,
      channel_central_transfer_error: nil,
      channel_central_registration: nil,
      channel_central_access_tab: "sop",
      channel_central_access_selected: nil,
      channel_central_access_nick: "",
      channel_central_cs_error: nil,
      channel_central_cs_confirm_drop: false,
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false,
      show_cc_transfer_dialog: false,
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
      knock_timestamps: %{},
      duplicate_tracker: DuplicateTracker.new(),
      flood_tracker: FloodTracker.new(),
      auto_ignore_state: %{active: %{}, cooldowns: %{}},
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
      conversations_context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        type: :channel,
        channel: nil,
        nick: nil
      },
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
      show_timers_dialog: false,
      timers_dialog_selected: nil,
      timers_dialog_editing: false,
      timers_dialog_draft_name: "",
      timers_dialog_draft_repeat: false,
      timers_dialog_draft_seconds: "",
      timers_dialog_draft_command: "",
      timers_dialog_error: nil,
      show_admin_console: false,
      admin_console_results: [],
      admin_console_tab: "console",
      admin_console_motd: nil,
      admin_console_motd_result: nil,
      admin_console_broadcast_result: nil,
      admin_console_turn_stats: nil,
      admin_console_turn_allocations: nil,
      admin_console_turn_result: nil,
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
      show_invite_channel_picker: false,
      invite_channel_picker_target: nil,
      invite_channel_picker_selected: nil,
      invite_channel_picker_error: nil,
      show_knock_request_dialog: false,
      knock_request_channel: nil,
      knock_request_message: "",
      knock_request_error: nil,
      show_channel_list: false,
      channel_list_channels: [],
      channel_list_filtered: [],
      channel_list_selected: nil,
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

  defp admin_only?(session) do
    ServerRoles.admin?(session.nickname, session.identified)
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

  defp channel_user_op?(users, nick), do: channel_user_role?(users, nick, [:operator])
  defp channel_user_voiced?(users, nick), do: channel_user_role?(users, nick, [:voiced])

  defp channel_user_muted?(users, nick) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :muted, false)
    end
  end

  defp channel_user_role?(users, nick, roles) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :role) in roles
    end
  end

  defp find_channel_user(_users, nil), do: nil

  defp find_channel_user(users, nick) do
    Enum.find(users, &(Map.get(&1, :nickname) == nick))
  end

  defp conversation_context_key(%{type: :pm, nick: nick}) when is_binary(nick), do: "pm:#{nick}"
  defp conversation_context_key(%{type: "pm", nick: nick}) when is_binary(nick), do: "pm:#{nick}"
  defp conversation_context_key(%{channel: channel}) when is_binary(channel), do: channel
  defp conversation_context_key(_context), do: nil

  defp conversation_context_custom_items(_session, %{type: :pm}), do: []
  defp conversation_context_custom_items(_session, %{type: "pm"}), do: []

  defp conversation_context_custom_items(session, _context) do
    CustomMenus.entries_for(session.custom_menus, :channel)
  end

  defp message_classes(msg, edit_mode_message_id) do
    base = "chat-message chat-message--#{Map.get(msg, :type, :normal)}"

    highlighted =
      if Map.get(msg, :highlighted), do: " chat-message--highlighted", else: ""

    highlight_bg = ChatHelpers.highlight_bg_class(msg)

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

  defp channel_central_modes(nil), do: %{}
  defp channel_central_modes(state), do: Map.get(state, :modes_detail, %{})

  defp channel_central_welcome_message(nil), do: ""

  defp channel_central_welcome_message(state) do
    state
    |> Map.get(:welcome_message)
    |> case do
      %{message: message} when is_binary(message) -> message
      _ -> ""
    end
  end

  defp channel_central_throttle_seconds(nil), do: 0

  defp channel_central_throttle_seconds(state) do
    state
    |> Map.get(:modes_detail, %{})
    |> Map.get(:join_throttle)
    |> case do
      {_count, seconds} when is_integer(seconds) -> seconds
      _ -> 0
    end
  end

  defp chat_action_enabled?(session, show_status_tab) do
    !show_status_tab and session.active_pm == nil and session.active_channel != nil
  end

  defp topic_bar_modes(_modes, true, _active_pm), do: []
  defp topic_bar_modes(_modes, _show_status_tab, active_pm) when is_binary(active_pm), do: []
  defp topic_bar_modes(nil, _show_status_tab, _active_pm), do: []
  defp topic_bar_modes("", _show_status_tab, _active_pm), do: []
  defp topic_bar_modes(modes, _show_status_tab, _active_pm), do: [modes]

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
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_created_at(nil, _tz), do: nil

  defp channel_central_created_at(state, timezone) do
    case Map.get(state, :created_at) do
      nil -> nil
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_member_count(nil), do: 0
  defp channel_central_member_count(state), do: Map.get(state, :member_count, 0)

  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  defp online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  defp online_buddy_count(_notify_list), do: 0

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

  defp maybe_broadcast_nick_changed(socket, old_nickname, new_nickname)
       when is_binary(old_nickname) and old_nickname != "" and old_nickname != new_nickname do
    Enum.each(socket.assigns.session.channels, fn channel ->
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel}",
        {:nick_changed, %{old_nick: old_nickname, new_nick: new_nickname, channel: channel}}
      )
    end)

    socket
  end

  defp maybe_broadcast_nick_changed(socket, _old_nickname, _new_nickname), do: socket

  defp show_welcome_message(socket) do
    server_name = Queries.get_setting("server_name") || dgettext("chat", "RetroHexChat")

    lines = [
      dgettext("chat", "Welcome to %{server_name}!", server_name: server_name),
      dgettext("chat", "A real-time chat platform with a retro look and feel."),
      "",
      dgettext("chat", "Useful commands:"),
      dgettext("chat", "  /join #channel   — Join a channel"),
      dgettext("chat", "  /msg nick text   — Send a private message"),
      dgettext("chat", "  /nick new_nick   — Change your nickname"),
      dgettext("chat", "  /help            — View full help"),
      dgettext("chat", "  /help commands   — List all commands"),
      "",
      dgettext("chat", "Tip: Go to Help > Help Topics for the full documentation.") <>
        " " <> dgettext("chat", "Open /chat/help in a new tab.")
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
      dgettext("chat", "[ChanServ] Channel Services Online"),
      dgettext("chat", "ChanServ manages channel registration and access control."),
      dgettext("chat", "Register your channel to protect it when no operators are online."),
      "",
      dgettext("chat", "Quick start:"),
      dgettext("chat", "  /cs register #channel          — Register a channel you operate"),
      dgettext("chat", "  /cs sop #channel add <nick>    — Add a Super Operator"),
      dgettext("chat", "  /cs aop #channel add <nick>    — Add an Auto Operator"),
      dgettext("chat", "  /cs vop #channel add <nick>    — Add an Auto Voice user"),
      dgettext("chat", "  /cs info #channel              — View channel registration info"),
      "",
      dgettext("chat", "Access hierarchy: Owner > SOP > AOP > VOP"),
      "",
      dgettext("chat", "Rules:"),
      dgettext("chat", "  • Channels expire after 7 days of inactivity"),
      dgettext("chat", "  • If a founder's nick expires, the next ranked user is promoted"),
      "",
      dgettext("chat", "Type /help chanserv or /help channel-permissions for full details.")
    ]

    Enum.reduce(lines, socket, fn line, acc ->
      ChatLive.Helpers.push_status_message(acc, line, :service)
    end)
  end

  defp show_nickserv_announcement(socket) do
    lines = [
      "",
      dgettext("chat", "[NickServ] Nickname Services Online"),
      dgettext(
        "chat",
        "NickServ protects your nickname with a password so nobody else can use it."
      ),
      "",
      dgettext("chat", "Quick start:"),
      dgettext("chat", "  /ns register <password>   — Register your current nickname"),
      dgettext("chat", "  /ns identify <password>   — Identify (log in) for this session"),
      dgettext("chat", "  /ns info [nickname]       — Look up registration info"),
      dgettext("chat", "  /ns ghost <nick> <pass>   — Disconnect a ghost session"),
      dgettext("chat", "  /ns drop <password>       — Permanently unregister your nickname"),
      "",
      dgettext("chat", "Rules:"),
      dgettext("chat", "  • Nicks are case sensitive — \"Alice\" and \"alice\" are different"),
      dgettext("chat", "  • Nicks expire after 7 days of inactivity"),
      dgettext("chat", "  • Switching to a registered nick gives you 60s to identify"),
      "",
      dgettext("chat", "Type /help nickserv for full details.")
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
