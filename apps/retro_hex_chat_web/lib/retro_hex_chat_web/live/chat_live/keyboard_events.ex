defmodule RetroHexChatWeb.ChatLive.KeyboardEvents do
  @moduledoc """
  Handle keyboard shortcut events (window_keydown).

  Covers: Ctrl+F (search), Alt+B (address book), Alt+I (ignore),
  Alt+H (highlight), Alt+U (URL catcher), Alt+L (log viewer),
  Alt+P (perform), F1 (help), Escape (dismiss).

  Attached as `attach_hook(:keyboard_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.LogFilter

  # Ctrl+F — toggle search
  def handle_event("window_keydown", %{"key" => "f", "ctrlKey" => true}, socket) do
    {:halt, assign(socket, search_visible: true)}
  end

  # Alt+B — toggle address book
  def handle_event("window_keydown", %{"key" => "b", "altKey" => true}, socket) do
    if socket.assigns.show_address_book do
      {:halt,
       assign(socket,
         show_address_book: false,
         address_book_tab: "contacts",
         contacts_selected: nil,
         show_contact_add_dialog: false,
         show_contact_edit_dialog: false
       )}
    else
      {:halt, assign(socket, show_address_book: true)}
    end
  end

  # Alt+I — toggle ignore dialog
  def handle_event("window_keydown", %{"key" => "i", "altKey" => true}, socket) do
    if socket.assigns.show_ignore_dialog do
      {:halt,
       assign(socket,
         show_ignore_dialog: false,
         ignore_selected: nil,
         show_ignore_add_dialog: false
       )}
    else
      {:halt, assign(socket, show_ignore_dialog: true)}
    end
  end

  # Alt+H — toggle highlight dialog
  def handle_event("window_keydown", %{"key" => "h", "altKey" => true}, socket) do
    if socket.assigns.show_highlight_dialog do
      {:halt,
       assign(socket,
         show_highlight_dialog: false,
         show_highlight_add_dialog: false,
         show_highlight_edit_dialog: false,
         highlight_selected: nil
       )}
    else
      {:halt, assign(socket, show_highlight_dialog: true)}
    end
  end

  # Alt+U — toggle URL catcher
  def handle_event("window_keydown", %{"key" => "u", "altKey" => true}, socket) do
    {:halt, assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)}
  end

  # Alt+L — toggle log viewer
  def handle_event("window_keydown", %{"key" => "l", "altKey" => true}, socket) do
    if socket.assigns.show_log_viewer do
      {:halt, close_log_viewer(socket)}
    else
      {:halt, open_log_viewer(socket)}
    end
  end

  # Alt+P — toggle perform dialog
  def handle_event("window_keydown", %{"key" => "p", "altKey" => true}, socket) do
    if socket.assigns.show_perform_dialog do
      {:halt, close_perform_dialog(socket)}
    else
      {:halt, assign(socket, show_perform_dialog: true)}
    end
  end

  # F1 — open help dialog
  def handle_event("window_keydown", %{"key" => "F1"}, socket) do
    {:halt,
     assign(socket,
       show_help_dialog: true,
       help_active_tab: "contents",
       help_selected_topic: nil,
       help_index_filter: "",
       help_search_query: "",
       help_search_results: []
     )}
  end

  # Escape — dismiss topmost dialog/overlay
  def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
    cond do
      socket.assigns.pending_invites != [] ->
        # Dismiss the most recent invite (last in list)
        last = List.last(socket.assigns.pending_invites)
        Process.cancel_timer(last.timer_ref)
        remaining = List.delete_at(socket.assigns.pending_invites, -1)
        try_remove_invite_exception(last.channel, socket.assigns.session.nickname)
        {:halt, assign(socket, pending_invites: remaining)}

      socket.assigns.show_perform_dialog ->
        {:halt, close_perform_dialog(socket)}

      socket.assigns.show_log_viewer ->
        {:halt, close_log_viewer(socket)}

      socket.assigns.show_channel_central ->
        {:halt, close_channel_central(socket)}

      socket.assigns.search_visible ->
        {:halt, clear_search_state(socket)}

      true ->
        {:halt, socket}
    end
  end

  # Catch-all for unhandled window_keydown
  def handle_event("window_keydown", _params, socket) do
    {:halt, socket}
  end

  # Catch-all — pass through all non-keyboard events
  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private helpers (local copies)
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

  defp clear_search_state(socket) do
    assign(socket,
      search_visible: false,
      search_query: "",
      search_result_count: 0,
      search_current_index: 0
    )
  end

  defp try_remove_invite_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
