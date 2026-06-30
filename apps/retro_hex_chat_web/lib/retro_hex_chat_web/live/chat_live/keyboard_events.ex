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
    AliasDialog,
    AutoRespondDialog,
    Composer,
    CustomMenusDialog,
    InviteChannelPickerDialog,
    KnockRequestDialog,
    SoundSettingsDialog
  }

  alias RetroHexChatWeb.ChatLive.ChannelListEvents
  alias RetroHexChatWeb.ChatLive.NavigationEvents
  alias RetroHexChatWeb.ChatLive.PerformAutojoinEvents
  alias RetroHexChatWeb.ChatLive.SearchEvents
  alias RetroHexChatWeb.ChatLive.UserLookupEvents

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
    assign(socket, show_address_book: true, address_book_tab: "control")
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

  defp dispatch_action(:toggle_perform_dialog, socket) do
    PerformAutojoinEvents.toggle(socket)
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

  defp topmost_dismissal(socket) do
    if socket.assigns.pending_invites != [] do
      &dismiss_pending_invite/1
    else
      find_active_dismissal(socket, topmost_dismissals())
    end
  end

  defp find_active_dismissal(socket, dismissals) do
    case Enum.find(dismissals, fn {assign, _dismissal} -> Map.get(socket.assigns, assign) end) do
      nil -> nil
      {_assign, dismissal} -> dismissal
    end
  end

  defp topmost_dismissals do
    [
      {:cheatsheet_visible, &close_cheatsheet/1},
      {:show_contact_add_dialog, &close_contact_add_dialog/1},
      {:show_contact_edit_dialog, &close_contact_edit_dialog/1},
      {:show_highlight_add_dialog, &close_highlight_add_dialog/1},
      {:show_highlight_edit_dialog, &close_highlight_edit_dialog/1}
    ]
  end

  defp secondary_dismissals do
    [
      {:show_channel_list, &close_channel_list/1},
      {:show_invite_channel_picker, &close_invite_channel_picker/1},
      {:show_knock_request_dialog, &close_knock_request_dialog/1},
      {:search_visible, &clear_search_state/1},
      {:show_address_book, &close_address_book/1},
      {:show_highlight_dialog, &close_highlight_dialog/1},
      {:show_sound_settings_dialog, &close_sound_settings_dialog/1},
      {:show_flood_protection_dialog, &close_flood_protection_dialog/1},
      {:show_alias_dialog, &close_alias_dialog/1},
      {:show_custom_menus_dialog, &close_custom_menus_dialog/1},
      {:show_url_catcher, &close_url_catcher/1},
      {:show_user_lookup_dialog, &close_user_lookup_dialog/1},
      {:lookup_result, &close_lookup_result/1},
      {:show_autorespond_dialog, &close_autorespond_dialog/1},
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

  defp close_cheatsheet(socket), do: assign(socket, cheatsheet_visible: false)
  defp close_contact_add_dialog(socket), do: assign(socket, show_contact_add_dialog: false)
  defp close_contact_edit_dialog(socket), do: assign(socket, show_contact_edit_dialog: false)
  defp close_highlight_add_dialog(socket), do: assign(socket, show_highlight_add_dialog: false)
  defp close_highlight_edit_dialog(socket), do: assign(socket, show_highlight_edit_dialog: false)

  defp cancel_notice_mode(socket) do
    send_update(Composer, id: Composer.id(), cancel_notice: true)
    assign(socket, notice_active: false)
  end

  defp close_sound_settings_dialog(socket) do
    send_update(SoundSettingsDialog, id: SoundSettingsDialog.id(), action: :close)
    assign(socket, show_sound_settings_dialog: false)
  end

  defp close_flood_protection_dialog(socket),
    do: assign(socket, show_flood_protection_dialog: false)

  defp close_url_catcher(socket), do: assign(socket, show_url_catcher: false)
  defp close_user_lookup_dialog(socket), do: UserLookupEvents.close(socket)
  defp close_lookup_result(socket), do: assign(socket, lookup_result: nil)

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp close_channel_list(socket), do: ChannelListEvents.close(socket)

  defp close_invite_channel_picker(socket) do
    send_update(InviteChannelPickerDialog, id: InviteChannelPickerDialog.id(), action: :close)
    assign(socket, show_invite_channel_picker: false)
  end

  defp close_knock_request_dialog(socket) do
    send_update(KnockRequestDialog, id: KnockRequestDialog.id(), action: :close)
    assign(socket, show_knock_request_dialog: false)
  end

  defp close_address_book(socket) do
    assign(socket,
      show_address_book: false,
      address_book_tab: "contacts",
      contacts_selected: nil,
      show_contact_add_dialog: false,
      show_contact_edit_dialog: false,
      nick_colors_selected: nil,
      show_nick_color_add_dialog: false,
      show_nick_color_edit_dialog: false,
      control_selected: nil,
      show_control_add_dialog: false
    )
  end

  defp close_highlight_dialog(socket) do
    assign(socket,
      show_highlight_dialog: false,
      show_highlight_add_dialog: false,
      show_highlight_edit_dialog: false,
      highlight_selected: nil
    )
  end

  defp close_alias_dialog(socket) do
    send_update(AliasDialog, id: AliasDialog.id(), action: :reset)
    assign(socket, show_alias_dialog: false)
  end

  defp close_custom_menus_dialog(socket) do
    send_update(CustomMenusDialog, id: CustomMenusDialog.id(), action: :reset)
    assign(socket, show_custom_menus_dialog: false)
  end

  defp close_autorespond_dialog(socket) do
    send_update(AutoRespondDialog, id: AutoRespondDialog.id(), action: :reset)
    assign(socket, show_autorespond_dialog: false)
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
