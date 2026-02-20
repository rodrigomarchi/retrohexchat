defmodule RetroHexChatWeb.ChatLive.KeyboardEvents do
  @moduledoc """
  Handle keyboard shortcut events (window_keydown).

  Uses KeyBindings.find_action/2 with hardcoded default bindings.

  Escape is always hardcoded to dismiss the topmost dialog/overlay.

  Attached as `attach_hook(:keyboard_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{KeyBindings, LogFilter}
  alias RetroHexChatWeb.ChatLive.NavigationEvents

  # Escape — always hardcoded to dismiss topmost dialog/overlay
  def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
    {:halt, dismiss_topmost(socket)}
  end

  # Dynamic key binding lookup for all other shortcuts
  def handle_event("window_keydown", params, socket) do
    bindings = KeyBindings.defaults()

    case KeyBindings.find_action(bindings, params) do
      nil -> {:halt, socket}
      action -> {:halt, dispatch_action(action, socket)}
    end
  end

  # Shortcut action from ShortcutDispatcherHook (global JS dispatcher)
  def handle_event("shortcut_action", %{"action" => action_string}, socket) do
    action = safe_to_action(action_string)

    if action do
      {:halt, dispatch_action(action, socket)}
    else
      {:halt, socket}
    end
  end

  # Catch-all — pass through all non-keyboard events
  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Action dispatchers
  # ---------------------------------------------------------------------------

  defp dispatch_action(:toggle_search, socket) do
    assign(socket, search_visible: true)
  end

  defp dispatch_action(:toggle_address_book, socket) do
    if socket.assigns.show_address_book do
      assign(socket,
        show_address_book: false,
        address_book_tab: "contacts",
        contacts_selected: nil,
        show_contact_add_dialog: false,
        show_contact_edit_dialog: false
      )
    else
      assign(socket, show_address_book: true)
    end
  end

  defp dispatch_action(:toggle_ignore_dialog, socket) do
    if socket.assigns.show_ignore_dialog do
      assign(socket,
        show_ignore_dialog: false,
        ignore_selected: nil,
        show_ignore_add_dialog: false
      )
    else
      assign(socket, show_ignore_dialog: true)
    end
  end

  defp dispatch_action(:toggle_highlight_dialog, socket) do
    if socket.assigns.show_highlight_dialog do
      assign(socket,
        show_highlight_dialog: false,
        show_highlight_add_dialog: false,
        show_highlight_edit_dialog: false,
        highlight_selected: nil
      )
    else
      assign(socket, show_highlight_dialog: true)
    end
  end

  defp dispatch_action(:toggle_url_catcher, socket) do
    assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)
  end

  defp dispatch_action(:toggle_log_viewer, socket) do
    if socket.assigns.show_log_viewer do
      close_log_viewer(socket)
    else
      open_log_viewer(socket)
    end
  end

  defp dispatch_action(:toggle_perform_dialog, socket) do
    if socket.assigns.show_perform_dialog do
      close_perform_dialog(socket)
    else
      assign(socket, show_perform_dialog: true)
    end
  end

  defp dispatch_action(:toggle_options_dialog, socket) do
    if socket.assigns.show_options_dialog do
      assign(socket, show_options_dialog: false, options_draft: nil)
    else
      draft = socket.assigns.session.user_preferences
      assign(socket, show_options_dialog: true, options_draft: draft)
    end
  end

  defp dispatch_action(:toggle_cheatsheet, socket) do
    assign(socket, cheatsheet_visible: !socket.assigns.cheatsheet_visible)
  end

  defp dispatch_action(:open_help, socket) do
    push_event(socket, "open_url", %{url: "/chat/help"})
  end

  defp dispatch_action(:window_next, socket) do
    {:halt, socket} = NavigationEvents.handle_event("window_next", %{}, socket)
    socket
  end

  defp dispatch_action(:window_prev, socket) do
    {:halt, socket} = NavigationEvents.handle_event("window_prev", %{}, socket)
    socket
  end

  defp dispatch_action(action, socket) when action in ~w(
    window_1 window_2 window_3 window_4 window_5
    window_6 window_7 window_8 window_9
  )a do
    index = action |> Atom.to_string() |> String.split("_") |> List.last() |> String.to_integer()
    {:halt, socket} = NavigationEvents.handle_event("window_select", %{"index" => index}, socket)
    socket
  end

  defp dispatch_action(_unknown, socket), do: socket

  # ---------------------------------------------------------------------------
  # Escape handler — dismiss topmost dialog/overlay
  # ---------------------------------------------------------------------------

  defp dismiss_topmost(socket) do
    cond do
      socket.assigns.pending_invites != [] ->
        dismiss_pending_invite(socket)

      socket.assigns.cheatsheet_visible ->
        assign(socket, cheatsheet_visible: false)

      socket.assigns.show_options_dialog ->
        assign(socket, show_options_dialog: false, options_draft: nil)

      socket.assigns.show_perform_dialog ->
        close_perform_dialog(socket)

      socket.assigns.show_log_viewer ->
        close_log_viewer(socket)

      true ->
        dismiss_secondary(socket)
    end
  end

  defp dismiss_secondary(socket) do
    cond do
      socket.assigns.show_channel_list ->
        close_channel_list(socket)

      socket.assigns.show_channel_central ->
        close_channel_central(socket)

      socket.assigns.search_visible ->
        clear_search_state(socket)

      true ->
        socket
    end
  end

  defp dismiss_pending_invite(socket) do
    last = List.last(socket.assigns.pending_invites)
    Process.cancel_timer(last.timer_ref)
    remaining = List.delete_at(socket.assigns.pending_invites, -1)
    try_remove_invite_exception(last.channel, socket.assigns.session.nickname)
    assign(socket, pending_invites: remaining)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp open_log_viewer(socket) do
    session = socket.assigns.session
    source_options = build_log_source_options(session)

    assign(socket,
      show_log_viewer: true,
      log_source_options: source_options,
      log_filter: %LogFilter{},
      log_page: nil,
      log_loading: false,
      log_error: nil,
      log_timestamp_format: "relative"
    )
  end

  defp close_log_viewer(socket) do
    assign(socket,
      show_log_viewer: false,
      log_filter: %LogFilter{},
      log_page: nil,
      log_loading: false,
      log_error: nil,
      log_source_options: []
    )
  end

  defp build_log_source_options(session) do
    channels =
      session.channels
      |> Enum.sort()
      |> Enum.map(fn ch -> %{value: ch, label: ch, type: "channel"} end)

    pms =
      if session.pm_conversations do
        session.pm_conversations
        |> Enum.sort()
        |> Enum.map(fn nick -> %{value: nick, label: nick, type: "pm"} end)
      else
        []
      end

    channels ++ pms
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

  defp close_channel_list(socket) do
    assign(socket,
      show_channel_list: false,
      channel_list_channels: [],
      channel_list_filtered: [],
      channel_list_search: "",
      channel_list_loading: false,
      channel_list_count: 0
    )
  end

  defp clear_search_state(socket) do
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
  end

  defp safe_to_action(action_string) do
    String.to_existing_atom(action_string)
  rescue
    ArgumentError -> nil
  end

  defp try_remove_invite_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
