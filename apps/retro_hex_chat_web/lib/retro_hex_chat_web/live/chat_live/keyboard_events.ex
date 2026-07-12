defmodule RetroHexChatWeb.ChatLive.KeyboardEvents do
  @moduledoc """
  Handle keyboard shortcut events (window_keydown).

  Uses KeyBindings.find_action/2 with hardcoded default bindings.

  Escape is always hardcoded to dismiss the topmost dialog/overlay.

  Attached as `attach_hook(:keyboard_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.KeyBindings

  alias RetroHexChatWeb.ChatLive.Components.{
    Composer,
    InviteChannelPickerDialog,
    KnockRequestDialog
  }

  alias RetroHexChatWeb.ChatLive.AddressBookEvents
  alias RetroHexChatWeb.ChatLive.GroupCallEvents
  alias RetroHexChatWeb.ChatLive.NavigationEvents
  alias RetroHexChatWeb.ChatLive.PerformAutojoinEvents
  alias RetroHexChatWeb.ChatLive.SearchEvents
  alias RetroHexChatWeb.ChatLive.Windows

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
    SearchEvents.open(socket)
  end

  defp dispatch_action(:toggle_address_book, socket) do
    AddressBookEvents.toggle(socket)
  end

  defp dispatch_action(:toggle_ignore_dialog, socket) do
    AddressBookEvents.open(socket, "control")
  end

  defp dispatch_action(:toggle_highlight_dialog, socket) do
    Windows.open(socket, "highlight")
  end

  defp dispatch_action(:toggle_url_catcher, socket) do
    Windows.open(socket, "url-catcher")
  end

  defp dispatch_action(:toggle_perform_dialog, socket) do
    PerformAutojoinEvents.open(socket)
  end

  defp dispatch_action(:toggle_cheatsheet, socket) do
    Windows.open(socket, "cheatsheet")
  end

  defp dispatch_action(action, socket)
       when action in [
              :group_call_toggle_audio,
              :group_call_toggle_video,
              :group_call_leave,
              :group_call_layout_next,
              :group_call_focus_next
            ] do
    event = action |> Atom.to_string()
    {:halt, socket} = GroupCallEvents.handle_event(event, %{}, socket)
    socket
  end

  defp dispatch_action(:open_help, socket) do
    push_event(socket, "open_url", %{url: "/chat/help"})
  end

  # `window_next`/`window_prev` are mIRC "window" semantics = the chat's
  # CHANNEL/PM TABS, not desktop windows. They cycle the active conversation tab
  # inside the pinned chat window; desktop-window focus is the WM's job.
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
    case topmost_dismissal(socket) do
      nil -> dismiss_secondary(socket)
      dismissal -> dismissal.(socket)
    end
  end

  defp dismiss_secondary(socket) do
    case find_active_dismissal(socket, secondary_dismissals()) do
      nil -> socket
      dismissal -> dismissal.(socket)
    end
  end

  # Desktop windows and WM menus own Escape client-side (a consumed press is
  # stopPropagation'd), so the server ladder only ever sees Escape for the
  # non-window overlays below: a pending invite prompt first, then the modal
  # survivors (locked decision #2) and the search/notice chat modes.
  defp topmost_dismissal(socket) do
    if socket.assigns.pending_invites != [] do
      &dismiss_pending_invite/1
    else
      nil
    end
  end

  defp find_active_dismissal(socket, dismissals) do
    case Enum.find(dismissals, fn {assign, _dismissal} -> Map.get(socket.assigns, assign) end) do
      nil -> nil
      {_assign, dismissal} -> dismissal
    end
  end

  defp secondary_dismissals do
    [
      {:show_invite_channel_picker, &close_invite_channel_picker/1},
      {:show_knock_request_dialog, &close_knock_request_dialog/1},
      {:search_visible, &clear_search_state/1},
      {:notice_active, &cancel_notice_mode/1}
    ]
  end

  defp dismiss_pending_invite(socket) do
    last = List.last(socket.assigns.pending_invites)
    Process.cancel_timer(last.timer_ref)
    remaining = List.delete_at(socket.assigns.pending_invites, -1)
    try_remove_invite_exception(last.channel, socket.assigns.session.nickname)
    assign(socket, pending_invites: remaining)
  end

  defp cancel_notice_mode(socket) do
    send_update(Composer, id: Composer.id(), cancel_notice: true)
    assign(socket, notice_active: false)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp close_invite_channel_picker(socket) do
    send_update(InviteChannelPickerDialog, id: InviteChannelPickerDialog.id(), action: :close)
    assign(socket, show_invite_channel_picker: false)
  end

  defp close_knock_request_dialog(socket) do
    send_update(KnockRequestDialog, id: KnockRequestDialog.id(), action: :close)
    assign(socket, show_knock_request_dialog: false)
  end

  defp clear_search_state(socket) do
    SearchEvents.close(socket)
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
