defmodule RetroHexChatWeb.Components.UI.MenuBarApp do
  @moduledoc """
  macOS-style textual menu bar for the App interface.

  Renders a compact, single-line menu bar with File, Edit, View, Tools, and Help
  dropdown menus. When `connected=false`, only Help is enabled — the other
  menus are grayed out and non-interactive.

  Uses the same action strings as the previous ToolbarApp, so no backend
  changes are needed.

  ## Usage

      <.menu_bar_app
        id="menubar"
        phx-hook="MenuBarHook"
        connected={true}
        is_admin={false}
        on_action="toolbar_action"
      />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  # ── Public ──────────────────────────────────────────

  @doc "Renders the application menu bar."
  attr :id, :string, default: "menubar"
  attr :connected, :boolean, default: false
  attr :is_admin, :boolean, default: false
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec menu_bar_app(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_bar_app(assigns) do
    ~H"""
    <nav
      id={@id}
      class={classes(["flex items-center shrink-0 select-none", @class])}
      role="menubar"
      data-testid="menu-bar"
      {@rest}
    >
      <%!-- File menu --%>
      <div class="relative inline-flex">
        <.menu_trigger label={dgettext("ui", "File")} disabled={!@connected} />
        <.menu_dropdown :if={@connected}>
          <.context_menu_label>{dgettext("ui", "Account")}</.context_menu_label>
          <.menu_item
            icon_fn={:icon_lock}
            label={dgettext("ui", "Register Nickname...")}
            action="open_account_register"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_status_user}
            label={dgettext("ui", "Identify...")}
            action="open_account_identify"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_dialog_nick}
            label={dgettext("ui", "Change Nickname...")}
            action="open_account_profile"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_status_user}
            label={dgettext("ui", "Edit Profile...")}
            action="open_account_profile"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_dnd}
            label={dgettext("ui", "Set Away...")}
            action="open_account_presence"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_tab_status}
            label={dgettext("ui", "Account Info")}
            action="account_info"
            on_action={@on_action}
          />
          <.context_menu_separator />
          <.menu_item
            icon_fn={:icon_btn_disconnect}
            label={dgettext("ui", "Disconnect")}
            action="disconnect"
            on_action={@on_action}
          />
          <.menu_item
            :if={@is_admin}
            icon_fn={:icon_dialog_admin_console}
            label={dgettext("ui", "Admin Console")}
            action="open_admin_console"
            on_action={@on_action}
          />
        </.menu_dropdown>
      </div>

      <%!-- Edit menu --%>
      <div class="relative inline-flex">
        <.menu_trigger label={dgettext("ui", "Edit")} disabled={!@connected} />
        <.menu_dropdown :if={@connected}>
          <.menu_item
            icon_fn={:icon_btn_remove}
            label={dgettext("ui", "Clear Window")}
            action="clear_window"
            on_action={@on_action}
          />
          <.context_menu_separator />
          <.menu_item
            icon_fn={:icon_copy}
            label={dgettext("ui", "Copy")}
            action="copy_selection"
            data-menubar-copy-selection="true"
            data-copy-disabled="true"
            aria-disabled="true"
          />
          <.context_menu_separator />
          <.menu_item
            icon_fn={:icon_btn_find}
            label={dgettext("ui", "Find")}
            action="toggle_search"
            on_action={@on_action}
            shortcut={dgettext("ui", "Ctrl+Shift+F")}
          />
        </.menu_dropdown>
      </div>

      <%!-- View menu --%>
      <div class="relative inline-flex">
        <.menu_trigger label={dgettext("ui", "View")} disabled={!@connected} />
        <.menu_dropdown :if={@connected}>
          <.menu_item
            icon_fn={:icon_btn_channel_list}
            label={dgettext("ui", "Channel List")}
            action="toggle_channel_list"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_toggle_conversations}
            label={dgettext("ui", "Toggle Conversations")}
            action="toggle_conversations"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_toggle_nicklist}
            label={dgettext("ui", "Toggle Nicklist")}
            action="toggle_nicklist"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_tab_notify}
            label={dgettext("ui", "Notify List")}
            action="toggle_notify_list"
            on_action={@on_action}
          />
        </.menu_dropdown>
      </div>

      <%!-- Tools menu --%>
      <div class="relative inline-flex">
        <.menu_trigger label={dgettext("ui", "Tools")} disabled={!@connected} />
        <.menu_dropdown :if={@connected}>
          <.menu_item
            icon_fn={:icon_btn_address_book}
            label={dgettext("ui", "Address Book")}
            action="toggle_address_book"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_highlight_words}
            label={dgettext("ui", "Highlight Words")}
            action="open_highlight_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_url_catcher}
            label={dgettext("ui", "URL Catcher")}
            action="toggle_url_catcher"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_channel_central}
            label={dgettext("ui", "Channel Central")}
            action="open_channel_central"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_search}
            label={dgettext("ui", "User Lookup")}
            action="open_user_lookup"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_perform}
            label={dgettext("ui", "Perform")}
            action="open_perform_dialog"
            on_action={@on_action}
          />
          <.context_menu_separator />
          <.menu_item
            icon_fn={:icon_btn_sounds}
            label={dgettext("ui", "Sounds")}
            action="open_sound_settings_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_flood_protection}
            label={dgettext("ui", "Flood Protection")}
            action="open_flood_protection_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_alias_editor}
            label={dgettext("ui", "Alias Editor")}
            action="open_alias_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_custom_menus}
            label={dgettext("ui", "Custom Menus")}
            action="open_custom_menus_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_auto_respond}
            label={dgettext("ui", "Auto Respond")}
            action="open_autorespond_dialog"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_btn_timers}
            label={dgettext("ui", "Timers")}
            action="open_timers_dialog"
            on_action={@on_action}
          />
          <.menu_item
            :if={@is_admin}
            icon_fn={:icon_btn_bot_management}
            label={dgettext("ui", "Bot Management")}
            action="open_bot_dialog"
            on_action={@on_action}
          />
        </.menu_dropdown>
      </div>

      <%!-- Help menu (always enabled) --%>
      <div class="relative inline-flex">
        <.menu_trigger label={dgettext("ui", "Help")} disabled={false} />
        <.menu_dropdown>
          <.menu_item
            icon_fn={:icon_btn_help_topics}
            label={dgettext("ui", "Help Topics")}
            action="help_topics"
            on_action={@on_action}
          />
          <.menu_item
            icon_fn={:icon_dialog_cheatsheet}
            label={dgettext("ui", "Shortcut Cheatsheet")}
            action="toggle_cheatsheet"
            on_action={@on_action}
          />
          <.context_menu_separator />
          <.context_menu_item on_click={show_modal("about-dialog")} action="show_about">
            <:icon>{apply(Icons, :icon_dialog_about, [%{class: "w-[14px] h-[14px]"}])}</:icon>
            {dgettext("ui", "About RetroHexChat")}
          </.context_menu_item>
        </.menu_dropdown>
      </div>
    </nav>
    """
  end

  # ── Private helpers ─────────────────────────────────

  attr :label, :string, required: true
  attr :disabled, :boolean, default: false

  defp menu_trigger(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "px-2 py-px text-sm border border-transparent whitespace-nowrap",
        if(@disabled,
          do: "text-muted-foreground cursor-default",
          else: "bg-transparent cursor-pointer hover:bg-accent"
        )
      ]}
      data-menubar-trigger
      data-disabled={if(@disabled, do: "true", else: "false")}
      aria-haspopup="true"
    >
      {@label}
    </button>
    """
  end

  slot :inner_block, required: true

  defp menu_dropdown(assigns) do
    ~H"""
    <div
      class="u-hidden absolute top-full left-0 min-w-[180px] p-[3px] bg-surface shadow-retro-window z-dropdown"
      data-menubar-dropdown
    >
      <ul class="list-none m-0 p-retro-2">
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :on_action, :any, default: nil
  attr :shortcut, :string, default: nil
  attr :rest, :global

  defp menu_item(assigns) do
    ~H"""
    <.context_menu_item on_click={@on_action} action={@action} {@rest}>
      <:icon>{apply(Icons, @icon_fn, [%{class: "w-[14px] h-[14px]"}])}</:icon>
      <:shortcut :if={@shortcut}>{@shortcut}</:shortcut>
      {@label}
    </.context_menu_item>
    """
  end
end
