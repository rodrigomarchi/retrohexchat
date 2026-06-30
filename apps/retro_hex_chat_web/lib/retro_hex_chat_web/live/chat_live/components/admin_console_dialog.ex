defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog do
  @moduledoc """
  Stateful island for the Admin Console mini-app.

  Owns the heavy display/result state of the console (`results`, every tab's
  `*_text`/`*_result` output, `turn_stats`/`turn_allocations`, `motd`,
  `server_settings_*`, the danger-zone preview/confirm, and `show`/`active_tab`) —
  ~26 assigns lifted out of the parent `assign_defaults`.

  **Ownership split (shared read-model, playbook §1d).** The privileged work
  (every `admin_console_*` command) stays in `AdminConsoleEvents` as STRING
  adapters: the `server_administration_feature_test` fires those events by name
  and they need the parent session + permissions, so they cannot be `@myself`.
  Each adapter reflects its result here via `send_update` (the events module's
  `put_console/2`). The seven filter/draft strings that sibling adapters read back
  to preserve a filter across an action (`users_search`, `users_online_only`,
  `channels_search`/`info_channel`/`create_name`, `audit_log_last`/`user`) remain
  the parent's read-model and arrive here as passthrough assigns.

  Permissions arrive as the three booleans `is_admin`/`admin_only`/`root_admin`
  (snapshot from `ChatContext`); the per-control `*_can_*` flags are derived in
  `render/1`, so the parent template no longer computes them inline.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  @id "admin-console-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @owned_defaults %{
    show: false,
    active_tab: "console",
    results: [],
    motd_content: nil,
    motd_result: nil,
    broadcast_result: nil,
    turn_stats: nil,
    turn_allocations: nil,
    turn_result: nil,
    audit_log_text: nil,
    audit_log_result: nil,
    server_settings_info: nil,
    server_settings_text: nil,
    server_settings_values: %{},
    server_settings_result: nil,
    users_text: nil,
    users_banlist_text: nil,
    users_result: nil,
    users_info_nick: "",
    channels_text: nil,
    channels_banlist_text: nil,
    channels_result: nil,
    danger_zone_preview: nil,
    danger_zone_result: nil,
    danger_zone_confirm: "",
    danger_zone_server_name: "RetroHexChat"
  }

  # Passthrough read-model + permission snapshot defaults (the parent always
  # supplies these in the template; defaults guard the very first render).
  @passthrough_defaults %{
    is_admin: false,
    admin_only: false,
    root_admin: false,
    users_search: "",
    users_online_only: false,
    channels_search: "",
    channels_info_channel: "",
    channels_create_name: "",
    audit_log_last: "20",
    audit_log_user: ""
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@owned_defaults)
     |> assign(@passthrough_defaults)}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_console_dialog
        id={@id}
        show={@show}
        active_tab={@active_tab}
        results={@results}
        motd_content={@motd_content}
        motd_result={@motd_result}
        motd_editable={@admin_only}
        broadcast_result={@broadcast_result}
        broadcast_can_wallops={@is_admin}
        broadcast_can_announce={@admin_only}
        turn_stats={@turn_stats}
        turn_allocations={@turn_allocations}
        turn_result={@turn_result}
        turn_can_refresh={@admin_only}
        audit_log_text={@audit_log_text}
        audit_log_last={@audit_log_last}
        audit_log_user={@audit_log_user}
        audit_log_result={@audit_log_result}
        audit_log_can_refresh={@admin_only}
        server_settings_info={@server_settings_info}
        server_settings_text={@server_settings_text}
        server_settings_values={@server_settings_values}
        server_settings_result={@server_settings_result}
        server_settings_can_edit={@admin_only}
        users_text={@users_text}
        users_banlist_text={@users_banlist_text}
        users_result={@users_result}
        users_search={@users_search}
        users_online_only={@users_online_only}
        users_info_nick={@users_info_nick}
        users_can_refresh={@admin_only}
        users_can_set_admin_role={@root_admin}
        channels_text={@channels_text}
        channels_banlist_text={@channels_banlist_text}
        channels_result={@channels_result}
        channels_search={@channels_search}
        channels_info_channel={@channels_info_channel}
        channels_create_name={@channels_create_name}
        channels_can_refresh={@admin_only}
        danger_zone_preview={@danger_zone_preview}
        danger_zone_result={@danger_zone_result}
        danger_zone_confirm={@danger_zone_confirm}
        danger_zone_server_name={@danger_zone_server_name}
        danger_zone_can_execute={@admin_only}
        on_tab="admin_console_tab"
        on_motd_set="admin_console_set_motd"
        on_motd_clear="admin_console_clear_motd"
        on_motd_refresh="admin_console_refresh_motd"
        on_broadcast_send="admin_console_send_broadcast"
        on_turn_refresh="admin_console_refresh_turn"
        on_audit_log_refresh="admin_console_refresh_audit_log"
        on_server_settings_save="admin_console_save_server_settings"
        on_server_settings_refresh="admin_console_refresh_server_settings"
        on_singleplayer="admin_console_start_singleplayer"
        on_users_refresh="admin_console_refresh_users"
        on_users_info="admin_console_user_info"
        on_users_ban="admin_console_user_ban"
        on_users_unban="admin_console_user_unban"
        on_users_kick="admin_console_user_kick"
        on_users_mute="admin_console_user_mute"
        on_users_unmute="admin_console_user_unmute"
        on_users_rename="admin_console_user_rename"
        on_users_role="admin_console_user_role"
        on_users_ns_info="admin_console_user_ns_info"
        on_users_ns_drop="admin_console_user_ns_drop"
        on_users_ns_resetpass="admin_console_user_ns_resetpass"
        on_channels_refresh="admin_console_refresh_channels"
        on_channels_info="admin_console_channel_info"
        on_channels_create="admin_console_channel_create"
        on_channels_delete="admin_console_channel_delete"
        on_channels_purge="admin_console_channel_purge"
        on_channels_cs_info="admin_console_channel_cs_info"
        on_channels_cs_drop="admin_console_channel_cs_drop"
        on_channels_cs_transfer="admin_console_channel_cs_transfer"
        on_channels_cs_access_list="admin_console_channel_cs_access_list"
        on_channels_cs_access_add="admin_console_channel_cs_access_add"
        on_channels_cs_access_del="admin_console_channel_cs_access_del"
        on_danger_zone_preview="admin_console_preview_nuke"
        on_danger_zone_change="admin_console_change_nuke_confirm"
        on_danger_zone_execute="admin_console_execute_nuke"
        on_close="close_admin_console"
      />
    </div>
    """
  end
end
