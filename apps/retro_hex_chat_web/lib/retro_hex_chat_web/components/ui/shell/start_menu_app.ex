defmodule RetroHexChatWeb.Components.UI.StartMenuApp do
  @moduledoc """
  Design-system Start button + Start menu for the chat desktop taskbar.

  The taskbar-side mirror of the menu bar, grouped Tools / View / Admin / Help.
  Items fire the same semantic action events as the menu bar (`on_action` +
  `phx-value-action`, translated by the host LiveView); About opens the
  client-side about modal. The Admin group renders only for admins.

  Pure presentation: takes only primitives and semantic event names (no
  `Session`, no domain calls), like `MenuBarApp`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  alias RetroHexChatWeb.Icons

  attr :id, :string, default: "chat-start-menu"
  attr :label, :string, default: nil, doc: "Start button label (defaults to \"Start\")"
  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false, doc: "Shows the P2P group while a session exists"
  attr :on_action, :any, default: "toolbar_action"
  attr :about_modal, :string, default: "about-dialog", doc: "Modal id opened by the About item"

  @spec start_menu_app(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu_app(assigns) do
    ~H"""
    <div class="relative">
      <.start_button label={@label || dgettext("ui", "Start")}>
        <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
      </.start_button>
      <.start_menu id={@id}>
        <%!-- Tools --%>
        <.window_item
          window="address-book"
          label={dgettext("ui", "Address Book")}
          icon_fn={:icon_btn_address_book}
        />
        <.window_item
          window="notify-list"
          label={dgettext("ui", "Notify List")}
          icon_fn={:icon_tab_notify}
        />
        <.window_item
          window="nick-colors"
          label={dgettext("ui", "Nick Colors")}
          icon_fn={:icon_btn_nick_colors}
        />
        <.window_item
          window="ignore-list"
          label={dgettext("ui", "Ignore List")}
          icon_fn={:icon_btn_ignore_list}
        />
        <.window_item
          window="highlight"
          label={dgettext("ui", "Highlight Words")}
          icon_fn={:icon_btn_highlight_words}
        />
        <.app_item
          action="open_channel_central"
          on_action={@on_action}
          label={dgettext("ui", "Channel Central")}
          icon_fn={:icon_btn_channel_central}
        />
        <.window_item window="perform" label={dgettext("ui", "Perform")} icon_fn={:icon_btn_perform} />
        <.window_item
          window="autojoin"
          label={dgettext("ui", "Auto-Join")}
          icon_fn={:icon_btn_autojoin}
        />
        <.window_item
          window="sound-settings"
          label={dgettext("ui", "Sounds")}
          icon_fn={:icon_btn_sounds}
        />
        <.window_item
          window="flood-protection"
          label={dgettext("ui", "Flood Protection")}
          icon_fn={:icon_btn_flood_protection}
        />
        <.window_item
          window="alias"
          label={dgettext("ui", "Alias Editor")}
          icon_fn={:icon_btn_alias_editor}
        />
        <.window_item
          window="custom-menus"
          label={dgettext("ui", "Custom Menus")}
          icon_fn={:icon_btn_custom_menus}
        />
        <.window_item
          window="auto-respond"
          label={dgettext("ui", "Auto Respond")}
          icon_fn={:icon_btn_auto_respond}
        />
        <.window_item window="timers" label={dgettext("ui", "Timers")} icon_fn={:icon_btn_timers} />
        <.start_menu_separator />
        <%!-- View --%>
        <%!-- Server opener: /list rows are loaded by the LiveView on open. --%>
        <.app_item
          action="toggle_channel_list"
          on_action={@on_action}
          label={dgettext("ui", "Channel List")}
          icon_fn={:icon_btn_channel_list}
        />
        <.window_item
          window="url-catcher"
          label={dgettext("ui", "URL Catcher")}
          icon_fn={:icon_btn_url_catcher}
        />
        <.window_item
          window="user-lookup"
          label={dgettext("ui", "User Lookup")}
          icon_fn={:icon_btn_search}
        />
        <.window_item
          window="cheatsheet"
          label={dgettext("ui", "Shortcut Cheatsheet")}
          icon_fn={:icon_dialog_cheatsheet}
        />
        <%!-- P2P (session-gated, mirrors the P2P menu-bar menu) --%>
        <.start_menu_separator :if={@p2p_active} />
        <.app_item
          :if={@p2p_active}
          action="p2p_start_audio"
          on_action={@on_action}
          label={dgettext("ui", "Start Audio Call")}
          icon_fn={:icon_microphone}
        />
        <.app_item
          :if={@p2p_active}
          action="p2p_start_video"
          on_action={@on_action}
          label={dgettext("ui", "Start Video Call")}
          icon_fn={:icon_camera}
        />
        <.app_item
          :if={@p2p_active}
          action="p2p_console_select"
          on_action={@on_action}
          label={dgettext("ui", "Send a File...")}
          icon_fn={:icon_file_send}
          phx-value-section="files"
          testid="start-menu-item-p2p-files"
        />
        <.app_item
          :if={@p2p_active}
          action="p2p_console_select"
          on_action={@on_action}
          label={dgettext("ui", "Play a Game...")}
          icon_fn={:icon_game_arcade}
          phx-value-section="games"
          testid="start-menu-item-p2p-games"
        />
        <.app_item
          :if={@p2p_active}
          action="p2p_console_select"
          on_action={@on_action}
          label={dgettext("ui", "P2P Stats")}
          icon_fn={:icon_status_signal}
          phx-value-section="stats"
          testid="start-menu-item-p2p-stats"
        />
        <.app_item
          :if={@p2p_active}
          action="p2p_end_session"
          on_action={@on_action}
          label={dgettext("ui", "End P2P Session")}
          icon_fn={:icon_btn_disconnect}
        />
        <%!-- Account --%>
        <.start_menu_separator />
        <.start_menu_submenu
          label={dgettext("ui", "Account")}
          testid="start-menu-account-submenu"
        >
          <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
          <.app_item
            action="open_account_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Account")}
            icon_fn={:icon_status_user}
          />
          <.app_item
            action="open_profile_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Profile")}
            icon_fn={:icon_btn_profile}
          />
          <.app_item
            action="open_away_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Away")}
            icon_fn={:icon_btn_away}
          />
          <.app_item
            action="open_user_modes_dialog"
            on_action={@on_action}
            label={dgettext("ui", "User Modes")}
            icon_fn={:icon_btn_user_modes}
          />
        </.start_menu_submenu>

        <%!-- Admin (permission-gated) --%>
        <.start_menu_separator :if={@is_admin} />
        <.start_menu_submenu
          :if={@is_admin}
          label={dgettext("ui", "Admin")}
          testid="start-menu-admin-submenu"
        >
          <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
          <.app_item
            action="open_admin_users"
            on_action={@on_action}
            label={dgettext("ui", "Users")}
            icon_fn={:icon_community}
          />
          <.app_item
            action="open_admin_channels"
            on_action={@on_action}
            label={dgettext("ui", "Channels")}
            icon_fn={:icon_channels}
          />
          <.app_item
            action="open_admin_server_settings"
            on_action={@on_action}
            label={dgettext("ui", "Server Settings")}
            icon_fn={:icon_server}
          />
          <.app_item
            action="open_admin_audit_log"
            on_action={@on_action}
            label={dgettext("ui", "Audit Log")}
            icon_fn={:icon_notepad}
          />
          <.app_item
            action="open_admin_motd"
            on_action={@on_action}
            label={dgettext("ui", "MOTD")}
            icon_fn={:icon_notepad}
          />
          <.app_item
            action="open_admin_turn"
            on_action={@on_action}
            label={dgettext("ui", "TURN")}
            icon_fn={:icon_websocket}
          />
          <.app_item
            action="open_admin_broadcast"
            on_action={@on_action}
            label={dgettext("ui", "Broadcast")}
            icon_fn={:icon_megaphone}
          />
          <.app_item
            action="open_admin_danger_zone"
            on_action={@on_action}
            label={dgettext("ui", "Danger Zone")}
            icon_fn={:icon_warning}
          />
          <.app_item
            action="open_admin_console"
            on_action={@on_action}
            label={dgettext("ui", "Console")}
            icon_fn={:icon_dialog_admin_console}
          />
        </.start_menu_submenu>
        <.app_item
          :if={@is_admin}
          action="open_bot_dialog"
          on_action={@on_action}
          label={dgettext("ui", "Bot Management")}
          icon_fn={:icon_btn_bot_management}
        />
        <.start_menu_separator />
        <%!-- Help --%>
        <.app_item
          action="help_topics"
          on_action={@on_action}
          label={dgettext("ui", "Help Topics")}
          icon_fn={:icon_btn_help_topics}
        />
        <.start_menu_item
          phx-click={show_modal(@about_modal)}
          label={dgettext("ui", "About RetroHexChat")}
          data-testid="start-menu-item-show_about"
        >
          <:icon><Icons.icon_dialog_about class="h-4 w-4" /></:icon>
        </.start_menu_item>
      </.start_menu>
    </div>
    """
  end

  # ── Private helpers ─────────────────────────────────

  # Opens/focuses a desktop window client-side (no server round trip) — used by
  # entries whose dialog has migrated to a window.
  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :window, :string, required: true, doc: "target window id"

  defp window_item(assigns) do
    ~H"""
    <.start_menu_item
      data-window-open={@window}
      label={@label}
      data-testid={"start-menu-item-#{@window}"}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :on_action, :any, default: nil
  attr :testid, :string, default: nil
  attr :rest, :global

  defp app_item(assigns) do
    ~H"""
    <.start_menu_item
      phx-click={@on_action}
      phx-value-action={@action}
      label={@label}
      data-testid={@testid || "start-menu-item-#{@action}"}
      {@rest}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end
end
