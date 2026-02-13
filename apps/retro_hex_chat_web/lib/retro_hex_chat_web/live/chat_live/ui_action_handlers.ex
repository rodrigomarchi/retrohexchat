defmodule RetroHexChatWeb.ChatLive.UiActionHandlers do
  @moduledoc """
  Handle all ui_action dispatch results from command execution.

  Delegates to focused sub-modules under `UiActions.*`:
  - `Core` — query, channel list, clear, away, topic, whois, help, mode, kick, ban
  - `Notify` — notify list CRUD
  - `Ignore` — ignore list CRUD
  - `Perform` — perform list CRUD
  - `Aliases` — alias CRUD
  - `Scripting` — custom menus, autorespond, timers
  - `Autojoin` — auto-join list CRUD
  - `Invite` — send invite, toggle auto-join on invite
  - `Settings` — notice routing, bio, whowas

  NOT a hook module — public function called by CommandDispatch.
  """

  alias RetroHexChatWeb.ChatLive.UiActions

  @core_actions ~w(
    open_query open_channel_list clear_chat set_away clear_away
    set_topic view_topic show_whois_info show_help show_command_help
    set_mode kick_user ban_user
  )a

  @notify_actions ~w(
    open_notify_list notify_add notify_remove notify_edit notify_list_display
  )a

  @ignore_actions ~w(ignore_list ignore_add ignore_remove)a

  @perform_actions ~w(
    open_perform_dialog perform_list_display perform_add perform_remove
    perform_move perform_clear
  )a

  @alias_actions ~w(
    open_alias_dialog alias_added alias_removed alias_list_display
  )a

  @scripting_actions ~w(
    open_custom_menus_dialog open_autorespond_dialog
    autorespond_added autorespond_removed autorespond_list_display
    timer_create timer_stop timer_list
  )a

  @autojoin_actions ~w(
    autojoin_list_display autojoin_add autojoin_remove autojoin_clear
  )a

  @invite_actions ~w(send_invite toggle_auto_join_on_invite)a

  @settings_actions ~w(
    notice_routing_show notice_routing_set show_whowas_info
    set_bio view_bio clear_bio
  )a

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, action, payload) when action in @core_actions,
    do: UiActions.Core.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @notify_actions,
    do: UiActions.Notify.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @ignore_actions,
    do: UiActions.Ignore.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @perform_actions,
    do: UiActions.Perform.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @alias_actions,
    do: UiActions.Aliases.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @scripting_actions,
    do: UiActions.Scripting.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @autojoin_actions,
    do: UiActions.Autojoin.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @invite_actions,
    do: UiActions.Invite.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, action, payload) when action in @settings_actions,
    do: UiActions.Settings.handle_ui_action(socket, action, payload)

  def handle_ui_action(socket, _action, _payload), do: socket
end
