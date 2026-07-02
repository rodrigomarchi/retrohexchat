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
  import Phoenix.LiveView, only: [send_update: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_custom_menus: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AliasExpander, CustomMenus}
  alias RetroHexChat.Commands.Parser
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.Components.ConversationsContextMenu
  alias RetroHexChatWeb.ChatLive.Components.CustomMenusDialog
  alias RetroHexChatWeb.ChatLive.Components.UserContextMenus
  alias RetroHexChatWeb.ChatLive.Windows

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

    # The custom-menu item can be clicked from either the user (nick/chat) context
    # menu or the conversations context menu, so close whichever is open. Both menus
    # are their own islands now (`UserContextMenus`/`ConversationsContextMenu`), so
    # the dismissal is a `send_update` to each component, not a parent assign.
    send_update(UserContextMenus,
      id: UserContextMenus.id(),
      context_menu: UserContextMenus.nick_closed(),
      chat_context_menu: UserContextMenus.chat_closed()
    )

    send_update(ConversationsContextMenu,
      id: ConversationsContextMenu.id(),
      visible: false,
      x: 0,
      y: 0,
      type: :channel,
      channel: nil,
      nick: nil
    )

    {:halt, socket}
  end

  # ── Dialog events ──────────────────────────────────────────

  def handle_event("open_custom_menus_dialog", _params, socket) do
    {:halt, Windows.open(socket, "custom-menus")}
  end

  def handle_event(
        "custom_menu_dialog_save",
        %{"label" => label, "command" => command} = params,
        socket
      ) do
    session = socket.assigns.session
    tab = String.to_existing_atom(params["tab"])
    selected = params["selected"]

    result =
      if selected do
        CustomMenus.update_entry(session.custom_menus, tab, selected, label, command)
      else
        CustomMenus.add_entry(session.custom_menus, tab, label, command)
      end

    case result do
      {:ok, updated} ->
        new_session = Session.set_custom_menus(session, updated)
        send_update(CustomMenusDialog, id: CustomMenusDialog.id(), action: {:saved, label})

        {:halt,
         socket
         |> assign(session: new_session)
         |> maybe_persist_custom_menus(new_session)}

      {:error, reason} ->
        send_update(CustomMenusDialog,
          id: CustomMenusDialog.id(),
          action: {:error, custom_menu_error_msg(reason)}
        )

        {:halt, socket}
    end
  end

  def handle_event("custom_menu_dialog_delete", params, socket) do
    selected = params["selected"]
    tab = String.to_existing_atom(params["tab"])

    if selected do
      session = socket.assigns.session

      case CustomMenus.remove_entry(session.custom_menus, tab, selected) do
        {:ok, updated} ->
          new_session = Session.set_custom_menus(session, updated)
          send_update(CustomMenusDialog, id: CustomMenusDialog.id(), action: :deleted)

          {:halt,
           socket
           |> assign(session: new_session)
           |> maybe_persist_custom_menus(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
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
