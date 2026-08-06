defmodule RetroHexChatWeb.Components.UI.AdminUsersDialog do
  @moduledoc """
  Admin Users window — server-wide user administration.

  Three concerns share the window because they all answer "what do I do about
  this person": moderation (ban/unban/kick/mute/unmute), the account itself
  (rename, role) and the NickServ registration behind it (info, reset password,
  drop).

  Every form takes its own nick rather than a shared selection: an admin acting
  on a list of names types each one, and a stale shared selection on destructive
  actions is worse than retyping.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.RetroTable
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :banlist_text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Table{} for the user list"
  attr :banlist_table, :any, default: nil, doc: "%Table{} for the ban list"
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :online_only, :boolean, default: false
  attr :info_nick, :string, default: ""
  attr :can_refresh, :boolean, default: false
  attr :can_set_admin_role, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_load_more, :string, default: nil
  attr :on_info, :any, default: nil
  attr :on_ban, :any, default: nil
  attr :on_unban, :any, default: nil
  attr :on_kick, :any, default: nil
  attr :on_mute, :any, default: nil
  attr :on_unmute, :any, default: nil
  attr :on_rename, :any, default: nil
  attr :on_role, :any, default: nil
  attr :on_ns_info, :any, default: nil
  attr :on_ns_drop, :any, default: nil
  attr :on_ns_resetpass, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc """
  Framed variant with dialog chrome — used by the showcase page.

  The chat mounts `admin_users_panel/1` inside a desktop window instead, which
  supplies its own title bar and close control.
  """
  @spec admin_users_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_users_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-3xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Users")} on_close={@on_cancel}>
        <:icon><Icons.icon_community class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_users_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :banlist_text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Table{} for the user list"
  attr :banlist_table, :any, default: nil, doc: "%Table{} for the ban list"
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :online_only, :boolean, default: false
  attr :info_nick, :string, default: ""
  attr :can_refresh, :boolean, default: false
  attr :can_set_admin_role, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_load_more, :string, default: nil
  attr :on_info, :any, default: nil
  attr :on_ban, :any, default: nil
  attr :on_unban, :any, default: nil
  attr :on_kick, :any, default: nil
  attr :on_mute, :any, default: nil
  attr :on_unmute, :any, default: nil
  attr :on_rename, :any, default: nil
  attr :on_role, :any, default: nil
  attr :on_ns_info, :any, default: nil
  attr :on_ns_drop, :any, default: nil
  attr :on_ns_resetpass, :any, default: nil

  @spec admin_users_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_users_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-users-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <form id="admin-users-search-form" phx-submit={@on_refresh} phx-target={@target}>
            <div class="flex flex-wrap items-end gap-retro-6">
              <div class="flex-1 min-w-[160px]">
                <label for="admin-users-search" class="block text-xs font-bold mb-retro-2">
                  {dgettext("dialogs", "Search")}
                </label>
                <input
                  id="admin-users-search"
                  name="search"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  value={@search}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
              </div>
              <label class="inline-flex items-center gap-retro-4 text-sm min-h-[28px]">
                <input
                  type="checkbox"
                  name="online_only"
                  value="true"
                  checked={@online_only}
                  disabled={not @can_refresh}
                />
                <span>{dgettext("dialogs", "Online only")}</span>
              </label>
              <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh")}
              </.button>
            </div>
          </form>

          <div
            id="admin-users-output"
            class="shadow-retro-sunken bg-white min-h-[140px] max-h-[210px] overflow-y-auto retro-scrollbar"
          >
            <.retro_table
              id="admin-users-table"
              table={@table}
              text={@text}
              testid="admin-users-table"
              target={@target}
              on_load_more={@on_load_more}
              empty_title={dgettext("dialogs", "No users found")}
            />
          </div>

          <form id="admin-users-info-form" phx-submit={@on_info} phx-target={@target}>
            <div class="flex flex-wrap items-end gap-retro-6">
              <div class="flex-1 min-w-[160px]">
                <label for="admin-users-info-nick" class="block text-xs font-bold mb-retro-2">
                  {dgettext("dialogs", "Nick")}
                </label>
                <input
                  id="admin-users-info-nick"
                  name="nick"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  value={@info_nick}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
              </div>
              <.button type="submit" size="sm" disabled={not @can_refresh}>
                <:icon><Icons.icon_btn_info class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Info")}
              </.button>
            </div>
          </form>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Moderation")}</div>
            <div class="grid gap-retro-6 md:grid-cols-2">
              <.nick_action_form
                target={@target}
                id="admin-users-ban-form"
                event={@on_ban}
                title={dgettext("dialogs", "Ban user")}
                button_label={dgettext("dialogs", "Confirm ban")}
                icon_fn={:icon_ban}
                show_reason
                show_duration
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-unban-form"
                event={@on_unban}
                title={dgettext("dialogs", "Unban user")}
                button_label={dgettext("dialogs", "Confirm unban")}
                icon_fn={:icon_checkmark}
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-kick-form"
                event={@on_kick}
                title={dgettext("dialogs", "Kick user")}
                button_label={dgettext("dialogs", "Confirm kick")}
                icon_fn={:icon_dialog_kick}
                show_reason
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-mute-form"
                event={@on_mute}
                title={dgettext("dialogs", "Mute user")}
                button_label={dgettext("dialogs", "Confirm mute")}
                icon_fn={:icon_mute}
                show_duration
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-unmute-form"
                event={@on_unmute}
                title={dgettext("dialogs", "Unmute user")}
                button_label={dgettext("dialogs", "Confirm unmute")}
                icon_fn={:icon_checkmark}
                disabled={not @can_refresh}
              />
            </div>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Account & Roles")}</div>
            <div class="grid gap-retro-6 md:grid-cols-2">
              <form
                id="admin-users-rename-form"
                phx-submit={@on_rename}
                phx-target={@target}
                class="shadow-retro-sunken bg-white p-retro-6 space-y-retro-4"
              >
                <div class="text-xs font-bold">{dgettext("dialogs", "Rename user")}</div>
                <input
                  name="old_nick"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  placeholder={dgettext("dialogs", "Current nick")}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
                <input
                  name="new_nick"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  placeholder={dgettext("dialogs", "New nick")}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
                <div class="flex justify-end">
                  <.button type="submit" size="sm" disabled={not @can_refresh}>
                    <:icon><Icons.icon_tab_nicklist class="w-[14px] h-[14px]" /></:icon>
                    {dgettext("dialogs", "Rename")}
                  </.button>
                </div>
              </form>

              <form
                id="admin-users-role-form"
                phx-submit={@on_role}
                phx-target={@target}
                class="shadow-retro-sunken bg-white p-retro-6 space-y-retro-4"
              >
                <div class="text-xs font-bold">{dgettext("dialogs", "Set role")}</div>
                <input
                  name="nick"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  placeholder={dgettext("dialogs", "Nick")}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
                <select
                  name="role"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  disabled={not @can_refresh}
                >
                  <option value="server_operator">{dgettext("dialogs", "server_operator")}</option>
                  <option value="user">{dgettext("dialogs", "user")}</option>
                  <option value="admin" disabled={not @can_set_admin_role}>
                    {dgettext("dialogs", "admin")}
                  </option>
                </select>
                <div class="flex justify-end">
                  <.button type="submit" size="sm" disabled={not @can_refresh}>
                    <:icon><Icons.icon_shield class="w-[14px] h-[14px]" /></:icon>
                    {dgettext("dialogs", "Set role")}
                  </.button>
                </div>
              </form>
            </div>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "NickServ admin")}</div>
            <div class="grid gap-retro-6 md:grid-cols-3">
              <.nick_action_form
                target={@target}
                id="admin-users-ns-info-form"
                event={@on_ns_info}
                title={dgettext("dialogs", "NickServ info")}
                button_label={dgettext("dialogs", "NickServ info")}
                icon_fn={:icon_btn_info}
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-ns-resetpass-form"
                event={@on_ns_resetpass}
                title={dgettext("dialogs", "Reset password")}
                button_label={dgettext("dialogs", "Reset password")}
                icon_fn={:icon_btn_save}
                include_password
                disabled={not @can_refresh}
              />
              <.nick_action_form
                target={@target}
                id="admin-users-ns-drop-form"
                event={@on_ns_drop}
                title={dgettext("dialogs", "Drop registration")}
                button_label={dgettext("dialogs", "Drop registration")}
                icon_fn={:icon_trash}
                disabled={not @can_refresh}
              />
            </div>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Ban list")}</div>
            <div
              id="admin-users-banlist"
              class="shadow-retro-sunken bg-white min-h-[84px] max-h-[150px] overflow-y-auto retro-scrollbar"
            >
              <.retro_table
                id="admin-users-banlist-table"
                table={@banlist_table}
                text={@banlist_text}
                testid="admin-users-banlist-table"
                empty_title={dgettext("dialogs", "No active server bans")}
              />
            </div>
          </div>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end

  # One nick plus optional extras — the shape every moderation and NickServ
  # action in this window takes. `show_*`/`include_password` add the fields a
  # given action needs, so eleven forms stay one component.
  attr :id, :string, required: true
  attr :event, :any, default: nil
  attr :title, :string, required: true
  attr :button_label, :string, required: true
  attr :icon_fn, :atom, required: true
  attr :show_reason, :boolean, default: false
  attr :show_duration, :boolean, default: false
  attr :include_password, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :target, :any, default: nil

  defp nick_action_form(assigns) do
    ~H"""
    <form
      id={@id}
      phx-submit={@event}
      phx-target={@target}
      class="shadow-retro-sunken bg-white p-retro-6 space-y-retro-4"
    >
      <div class="text-xs font-bold">{@title}</div>
      <input
        name="nick"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Nick")}
        autocomplete="off"
        disabled={@disabled}
      />
      <input
        :if={@show_reason}
        name="reason"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Reason")}
        autocomplete="off"
        disabled={@disabled}
      />
      <input
        :if={@show_duration}
        name="duration"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Duration")}
        autocomplete="off"
        disabled={@disabled}
      />
      <input
        :if={@include_password}
        name="new_password"
        type="password"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "New password")}
        autocomplete="new-password"
        disabled={@disabled}
      />
      <div class="flex justify-end">
        <.button type="submit" size="sm" disabled={@disabled}>
          <:icon>{apply(Icons, @icon_fn, [%{class: "w-[14px] h-[14px]"}])}</:icon>
          {@button_label}
        </.button>
      </div>
    </form>
    """
  end
end
