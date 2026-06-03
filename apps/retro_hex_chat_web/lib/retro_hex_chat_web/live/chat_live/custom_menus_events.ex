defmodule RetroHexChatWeb.ChatLive.CustomMenusEvents do
  @moduledoc """
  Handle custom menu dialog events (open/close, tab, select, add, edit, save,
  delete, cancel_edit).

  Attached as an `attach_hook(:custom_menus_events, :handle_event, ...)` in
  ChatLive.mount/3. Returns `{:halt, socket}` when the event is handled,
  `{:cont, socket}` otherwise.

  Also handles `custom_menu_execute` which expands alias variables and
  dispatches the command via CommandDispatch.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_custom_menus: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AliasExpander, CustomMenus}
  alias RetroHexChat.Commands.Parser
  alias RetroHexChatWeb.ChatLive

  # ── Execute custom menu command ────────────────────────────

  def handle_event("custom_menu_execute", %{"command" => command, "target" => target}, socket) do
    session = socket.assigns.session
    expand_context = %{nick: session.nickname, chan: session.active_channel}
    expanded = AliasExpander.expand(command, [target], expand_context)

    socket =
      case Parser.parse(expanded) do
        {:command, cmd_name, cmd_args} ->
          ChatLive.CommandDispatch.dispatch_command(socket, session, cmd_name, cmd_args)

        {:message, text} ->
          ChatLive.CommandDispatch.send_plain_message(socket, session, text)
      end

    {:halt,
     socket
     |> assign(
       context_menu: %{visible: false, x: 0, y: 0, target_nick: nil, is_target_registered: false}
     )
     |> assign(
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
     |> assign(
       conversations_context_menu: %{
         visible: false,
         x: 0,
         y: 0,
         type: nil,
         channel: nil,
         nick: nil
       }
     )}
  end

  # ── Dialog events ──────────────────────────────────────────

  def handle_event("open_custom_menus_dialog", _params, socket) do
    {:halt, assign(socket, show_custom_menus_dialog: true)}
  end

  def handle_event("close_custom_menus_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_custom_menus_dialog: false,
       custom_menus_dialog_selected: nil,
       custom_menus_dialog_editing: false,
       custom_menus_dialog_draft_label: "",
       custom_menus_dialog_draft_command: "",
       custom_menus_dialog_error: nil
     )}
  end

  def handle_event("custom_menus_tab", %{"tab" => tab}, socket) do
    {:halt,
     assign(socket,
       custom_menus_dialog_tab: String.to_existing_atom(tab),
       custom_menus_dialog_selected: nil,
       custom_menus_dialog_editing: false
     )}
  end

  def handle_event("custom_menu_select", %{"label" => label}, socket) do
    {:halt,
     assign(socket, custom_menus_dialog_selected: label, custom_menus_dialog_editing: false)}
  end

  def handle_event("custom_menu_dialog_add", _params, socket) do
    {:halt,
     assign(socket,
       custom_menus_dialog_editing: true,
       custom_menus_dialog_selected: nil,
       custom_menus_dialog_draft_label: "",
       custom_menus_dialog_draft_command: "",
       custom_menus_dialog_error: nil
     )}
  end

  def handle_event("custom_menu_dialog_edit", _params, socket) do
    selected = socket.assigns.custom_menus_dialog_selected
    tab = socket.assigns.custom_menus_dialog_tab

    if selected do
      session = socket.assigns.session

      entry =
        CustomMenus.entries_for(session.custom_menus, tab)
        |> Enum.find(&(&1.label == selected))

      if entry do
        {:halt,
         assign(socket,
           custom_menus_dialog_editing: true,
           custom_menus_dialog_draft_label: entry.label,
           custom_menus_dialog_draft_command: entry.command,
           custom_menus_dialog_error: nil
         )}
      else
        {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("custom_menu_dialog_save", %{"label" => label, "command" => command}, socket) do
    session = socket.assigns.session
    tab = socket.assigns.custom_menus_dialog_tab
    selected = socket.assigns.custom_menus_dialog_selected

    result =
      if selected do
        CustomMenus.update_entry(session.custom_menus, tab, selected, label, command)
      else
        CustomMenus.add_entry(session.custom_menus, tab, label, command)
      end

    case result do
      {:ok, updated} ->
        new_session = Session.set_custom_menus(session, updated)

        {:halt,
         socket
         |> assign(
           session: new_session,
           custom_menus_dialog_editing: false,
           custom_menus_dialog_selected: label,
           custom_menus_dialog_error: nil
         )
         |> maybe_persist_custom_menus(new_session)}

      {:error, reason} ->
        {:halt, assign(socket, custom_menus_dialog_error: custom_menu_error_msg(reason))}
    end
  end

  def handle_event("custom_menu_dialog_delete", _params, socket) do
    selected = socket.assigns.custom_menus_dialog_selected
    tab = socket.assigns.custom_menus_dialog_tab

    if selected do
      session = socket.assigns.session

      case CustomMenus.remove_entry(session.custom_menus, tab, selected) do
        {:ok, updated} ->
          new_session = Session.set_custom_menus(session, updated)

          {:halt,
           socket
           |> assign(
             session: new_session,
             custom_menus_dialog_selected: nil,
             custom_menus_dialog_editing: false,
             custom_menus_dialog_error: nil
           )
           |> maybe_persist_custom_menus(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("custom_menu_dialog_cancel_edit", _params, socket) do
    {:halt,
     assign(socket,
       custom_menus_dialog_editing: false,
       custom_menus_dialog_draft_label: "",
       custom_menus_dialog_draft_command: "",
       custom_menus_dialog_error: nil
     )}
  end

  # ── Catch-all: pass unhandled events to next hook ──────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp custom_menu_error_msg(:duplicate_label),
    do: dgettext("chat", "An item with that label already exists")

  defp custom_menu_error_msg(:invalid_label),
    do: dgettext("chat", "Invalid label (1-50 characters)")

  defp custom_menu_error_msg(:invalid_command), do: dgettext("chat", "Command is required")

  defp custom_menu_error_msg(:command_too_long),
    do: dgettext("chat", "Command too long (max 500 characters)")

  defp custom_menu_error_msg(:command_chaining),
    do: dgettext("chat", "Command must not contain chaining")

  defp custom_menu_error_msg(:menu_full),
    do: dgettext("chat", "Menu is full (max 10 items per type)")

  defp custom_menu_error_msg(:not_found), do: dgettext("chat", "Item not found")
end
