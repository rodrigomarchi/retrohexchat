defmodule RetroHexChatWeb.Components.UI.MenuBarApp do
  @moduledoc """
  App menu bar for the chat interface.

  Desktop renders the classic Win98-style textual menu strip. Stacked/mobile
  shells render the same menus as a rail of icon-only buttons spanning the
  header, each opening the shared vertical menu already on its own section, so
  narrow screens do not need horizontal scrolling and the header is not a strip
  of dead space beside a lone hamburger.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChat.Arcade
  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.LanguageMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  # ── Public ──────────────────────────────────────────

  @doc "Renders the application menu bar."
  attr :id, :string, default: "menubar"
  attr :connected, :boolean, default: false
  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false, doc: "Enables the P2P menu while a session exists"

  attr :p2p_turn_available, :boolean,
    default: false,
    doc: "Shows the privacy-mode item (needs a configured TURN relay)"

  attr :arcade_available, :boolean,
    default: false,
    doc: "Enables the Games/Arcade item (needs a registered + identified nick)"

  attr :language_return_to, :string, default: "/connect"
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec menu_bar_app(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_bar_app(assigns) do
    ~H"""
    <.menu_bar id={@id} class={classes(["app-menu-bar", @class])} {@rest}>
      <.mobile_main_menu
        menu_id={@id}
        connected={@connected}
        is_admin={@is_admin}
        p2p_active={@p2p_active}
        p2p_turn_available={@p2p_turn_available}
        arcade_available={@arcade_available}
        language_return_to={@language_return_to}
        on_action={@on_action}
      />

      <.mobile_menu_rail sections={mobile_sections(@connected)} />

      <.menu
        class="app-menu-bar__desktop-menu"
        label={dgettext("ui", "File")}
        disabled={!@connected}
        offline_disabled
      >
        <:icon><Icons.icon_folder class="h-4 w-4" /></:icon>
        <.file_menu_items is_admin={@is_admin} on_action={@on_action} />
      </.menu>

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "Edit")} disabled={!@connected}>
        <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
        <.edit_menu_items on_action={@on_action} />
      </.menu>

      <.menu
        class="app-menu-bar__desktop-menu"
        label={dgettext("ui", "View")}
        disabled={!@connected}
        offline_disabled
      >
        <:icon><Icons.icon_channels class="h-4 w-4" /></:icon>
        <.view_menu_items on_action={@on_action} />
      </.menu>

      <.menu
        class="app-menu-bar__desktop-menu"
        label={dgettext("ui", "Tools")}
        disabled={!@connected}
        offline_disabled
      >
        <:icon><Icons.icon_dialog_options class="h-4 w-4" /></:icon>
        <.tools_menu_items is_admin={@is_admin} on_action={@on_action} />
      </.menu>

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "P2P")} disabled={!@connected}>
        <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
        <.p2p_menu_items
          p2p_active={@p2p_active}
          p2p_turn_available={@p2p_turn_available}
          on_action={@on_action}
        />
      </.menu>

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "Games")} disabled={!@connected}>
        <:icon><Icons.icon_game_arcade class="h-4 w-4" /></:icon>
        <.games_menu_items arcade_available={@arcade_available} on_action={@on_action} />
      </.menu>

      <.language_menu
        mode={:app}
        return_to={@language_return_to}
        class="app-menu-bar__desktop-menu"
      />

      <.menu
        class="app-menu-bar__desktop-menu"
        label={dgettext("ui", "Help")}
        disabled={false}
        testid="app-menu-help-trigger"
      >
        <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
        <.help_menu_items connected={@connected} on_action={@on_action} />
      </.menu>
    </.menu_bar>
    """
  end

  # ── Mobile composition ───────────────────────────────

  attr :menu_id, :string, required: true
  attr :connected, :boolean, default: false
  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false
  attr :p2p_turn_available, :boolean, default: false
  attr :arcade_available, :boolean, default: false
  attr :language_return_to, :string, default: "/connect"
  attr :on_action, :any, default: nil

  defp mobile_main_menu(assigns) do
    assigns =
      assigns
      |> assign(:active_section, default_mobile_section(assigns.connected))
      |> assign(:sections, mobile_sections(assigns.connected))

    ~H"""
    <.mobile_menu_drawer
      menu_id={@menu_id}
      sections={@sections}
      active_section={@active_section}
    >
      <:section :if={@connected} id="file">
        <.file_menu_items is_admin={@is_admin} on_action={@on_action} />
      </:section>
      <:section :if={@connected} id="edit">
        <.edit_menu_items on_action={@on_action} />
      </:section>
      <:section :if={@connected} id="view">
        <.view_menu_items on_action={@on_action} />
      </:section>
      <:section :if={@connected} id="tools">
        <.tools_menu_items is_admin={@is_admin} on_action={@on_action} />
      </:section>
      <:section :if={@connected} id="p2p">
        <.p2p_menu_items
          p2p_active={@p2p_active}
          p2p_turn_available={@p2p_turn_available}
          on_action={@on_action}
        />
      </:section>
      <:section :if={@connected} id="games">
        <.games_menu_items arcade_available={@arcade_available} on_action={@on_action} />
      </:section>
      <:section id="language">
        <.language_menu_items mode={:app} return_to={@language_return_to} />
      </:section>
      <:section id="help">
        <.help_menu_items connected={@connected} on_action={@on_action} />
      </:section>
    </.mobile_menu_drawer>
    """
  end

  # The one list behind both mobile faces of the menu bar: the rail's buttons
  # and the dropdown's category column. Menus that act on a live connection are
  # dropped while there is none — the connect screen offers only Language and
  # Help.
  defp mobile_sections(connected) do
    [
      %{id: "file", label: dgettext("ui", "File"), icon_fn: :icon_folder, needs_connection: true},
      %{id: "edit", label: dgettext("ui", "Edit"), icon_fn: :icon_copy, needs_connection: true},
      %{
        id: "view",
        label: dgettext("ui", "View"),
        icon_fn: :icon_channels,
        needs_connection: true
      },
      %{
        id: "tools",
        label: dgettext("ui", "Tools"),
        icon_fn: :icon_dialog_options,
        needs_connection: true
      },
      %{
        id: "p2p",
        label: dgettext("ui", "P2P"),
        icon_fn: :icon_protocol_p2p_compact,
        needs_connection: true
      },
      %{
        id: "games",
        label: dgettext("ui", "Games"),
        icon_fn: :icon_game_arcade,
        needs_connection: true
      },
      %{
        id: "language",
        label: dgettext("ui", "Language"),
        icon_fn: :icon_globe,
        needs_connection: false
      },
      %{
        id: "help",
        label: dgettext("ui", "Help"),
        icon_fn: :icon_btn_help_topics,
        needs_connection: false
      }
    ]
    |> Enum.filter(&(connected or not &1.needs_connection))
  end

  defp default_mobile_section(true), do: "file"
  defp default_mobile_section(false), do: "language"

  # ── Shared menu item groups ───────────────────────────

  attr :is_admin, :boolean, default: false
  attr :on_action, :any, default: nil

  defp file_menu_items(assigns) do
    ~H"""
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
      action="open_profile_dialog"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_btn_profile}
      label={dgettext("ui", "Edit Profile...")}
      action="open_profile_dialog"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_btn_away}
      label={dgettext("ui", "Set Away...")}
      action="open_away_dialog"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_btn_user_modes}
      label={dgettext("ui", "User Modes...")}
      action="open_user_modes_dialog"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_tab_status}
      label={dgettext("ui", "Account Info")}
      action="account_info"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_lock}
      label={dgettext("ui", "Trusted Terminals...")}
      action="open_trusted_terminals_dialog"
      on_action={@on_action}
    />
    <.context_menu_separator />
    <.menu_item
      icon_fn={:icon_btn_disconnect}
      label={dgettext("ui", "Disconnect")}
      action="disconnect"
      on_action={@on_action}
    />
    <.context_menu_separator :if={@is_admin} />
    <.submenu
      :if={@is_admin}
      label={dgettext("ui", "Admin")}
      testid="app-menu-admin-submenu"
    >
      <:icon><Icons.icon_shield class="h-[14px] w-[14px]" /></:icon>
      <.admin_menu_items on_action={@on_action} />
    </.submenu>
    <.submenu
      :if={@is_admin}
      label={dgettext("ui", "System")}
      testid="app-menu-system-submenu"
    >
      <:icon><Icons.icon_server class="h-[14px] w-[14px]" /></:icon>
      <.system_menu_items on_action={@on_action} />
    </.submenu>
    """
  end

  attr :on_action, :any, default: nil

  defp edit_menu_items(assigns) do
    ~H"""
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
    """
  end

  attr :on_action, :any, default: nil

  defp view_menu_items(assigns) do
    ~H"""
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
    """
  end

  attr :is_admin, :boolean, default: false
  attr :on_action, :any, default: nil

  defp tools_menu_items(assigns) do
    ~H"""
    <.menu_item
      icon_fn={:icon_btn_address_book}
      label={dgettext("ui", "Address Book")}
      action="toggle_address_book"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_btn_nick_colors}
      label={dgettext("ui", "Nick Colors")}
      action="open_nick_colors_dialog"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_btn_ignore_list}
      label={dgettext("ui", "Ignore List")}
      action="open_ignore_list_dialog"
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
    <.menu_item
      icon_fn={:icon_btn_autojoin}
      label={dgettext("ui", "Auto-Join")}
      action="open_autojoin_dialog"
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
    """
  end

  attr :p2p_active, :boolean, default: false
  attr :p2p_turn_available, :boolean, default: false
  attr :on_action, :any, default: nil

  defp p2p_menu_items(assigns) do
    ~H"""
    <.menu_item
      :if={!@p2p_active}
      icon_fn={:icon_protocol_p2p_compact}
      label={dgettext("ui", "Start a P2P Session...")}
      action="p2p_how_to_start"
      on_action={@on_action}
    />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_microphone}
      label={dgettext("ui", "Start Audio Call")}
      action="p2p_start_audio"
      on_action={@on_action}
    />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_camera}
      label={dgettext("ui", "Start Video Call")}
      action="p2p_start_video"
      on_action={@on_action}
    />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_file_send}
      label={dgettext("ui", "Send a File...")}
      action="p2p_console_select"
      on_action={@on_action}
      phx-value-section="files"
    />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_game_arcade}
      label={dgettext("ui", "Play a Game...")}
      action="p2p_console_select"
      on_action={@on_action}
      phx-value-section="games"
    />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_status_signal}
      label={dgettext("ui", "Statistics")}
      action="p2p_console_select"
      on_action={@on_action}
      phx-value-section="stats"
    />
    <.menu_item
      :if={@p2p_active && @p2p_turn_available}
      icon_fn={:icon_lock}
      label={dgettext("ui", "Toggle Privacy Mode")}
      action="p2p_toggle_privacy"
      on_action={@on_action}
    />
    <.context_menu_separator :if={@p2p_active} />
    <.menu_item
      :if={@p2p_active}
      icon_fn={:icon_btn_disconnect}
      label={dgettext("ui", "End Session")}
      action="p2p_end_session"
      on_action={@on_action}
    />
    """
  end

  attr :arcade_available, :boolean, default: false
  attr :on_action, :any, default: nil

  defp games_menu_items(assigns) do
    assigns =
      assign(assigns, :games, if(assigns.arcade_available, do: Arcade.list_games(), else: []))

    ~H"""
    <.menu_item
      icon_fn={:icon_game_arcade}
      label={dgettext("ui", "Arcade...")}
      action="open_arcade"
      on_action={@on_action}
      disabled={!@arcade_available}
    />
    <.context_menu_label :if={!@arcade_available}>
      {dgettext("ui", "Register & identify to play")}
    </.context_menu_label>
    <.context_menu_separator :if={@games != []} />
    <.context_menu_item
      :for={game <- @games}
      on_click={@on_action}
      action="open_arcade"
      phx-value-game-id={game.id}
      testid={"menu-game-#{game.id}"}
    >
      <:icon><Icons.game_icon game_id={game.id} class="w-[14px] h-[14px]" /></:icon>
      {game.name}
    </.context_menu_item>
    """
  end

  attr :on_action, :any, default: nil

  # Server administration. Rendered only for admins and server operators.
  # Each entry opens its own focused window; entries land here as the Admin
  # Console's tabs are split out.
  defp admin_menu_items(assigns) do
    ~H"""
    <.menu_item
      icon_fn={:icon_community}
      label={dgettext("ui", "Users")}
      action="open_admin_users"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_channels}
      label={dgettext("ui", "Channels")}
      action="open_admin_channels"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_server}
      label={dgettext("ui", "Server Settings")}
      action="open_admin_server_settings"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_notepad}
      label={dgettext("ui", "Audit Log")}
      action="open_admin_audit_log"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_notepad}
      label={dgettext("ui", "MOTD")}
      action="open_admin_motd"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_websocket}
      label={dgettext("ui", "TURN")}
      action="open_admin_turn"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_megaphone}
      label={dgettext("ui", "Broadcast")}
      action="open_admin_broadcast"
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_warning}
      label={dgettext("ui", "Danger Zone")}
      action="open_admin_danger_zone"
      on_action={@on_action}
    />
    <.context_menu_separator />
    <.menu_item
      icon_fn={:icon_dialog_admin_console}
      label={dgettext("ui", "Console")}
      action="open_admin_console"
      on_action={@on_action}
    />
    """
  end

  attr :on_action, :any, default: nil

  # Runtime inspection. Sits beside the admin items and behind the same gate,
  # but stays a separate list: every window here only reads the node, while
  # everything under Admin acts on the server.
  defp system_menu_items(assigns) do
    ~H"""
    <.menu_item
      :for={{action, label, icon_fn} <- system_entries()}
      icon_fn={icon_fn}
      label={label}
      action={action}
      on_action={@on_action}
    />
    """
  end

  # Derived from `WindowRegistry` for the same reason the Start menu is: the
  # title and icon a window is opened by must be the ones it opens with.
  defp system_entries do
    for window <- WindowRegistry.windows(),
        window.opener,
        window.family == :system,
        do: {window.opener, window.title, window.icon}
  end

  # The Help menu is the one menu every shell shows, connected or not, so its
  # items carry the disabled state instead of disappearing: the menu reads the
  # same everywhere and only says what is unavailable here. MOTD and the
  # cheatsheet need a live session; Help Topics is plain navigation, so it is a
  # real link and works even on the shells that wire no `on_action` at all.
  attr :connected, :boolean, default: false
  attr :on_action, :any, default: nil

  defp help_menu_items(assigns) do
    ~H"""
    <.context_menu_item action="help_topics">
      <:icon>{apply(Icons, :icon_btn_help_topics, [%{class: "w-[14px] h-[14px]"}])}</:icon>
      <a href="/chat/help" class="block flex-1">{dgettext("ui", "Help Topics")}</a>
    </.context_menu_item>
    <.menu_item
      icon_fn={:icon_notepad}
      label={dgettext("ui", "Message of the Day")}
      action="show_motd"
      disabled={!@connected}
      on_action={@on_action}
    />
    <.menu_item
      icon_fn={:icon_dialog_cheatsheet}
      label={dgettext("ui", "Shortcut Cheatsheet")}
      action="toggle_cheatsheet"
      disabled={!@connected}
      on_action={@on_action}
    />
    <.context_menu_separator />
    <.context_menu_item on_click={show_modal("about-dialog")} action="show_about">
      <:icon>{apply(Icons, :icon_dialog_about, [%{class: "w-[14px] h-[14px]"}])}</:icon>
      {dgettext("ui", "About RetroHexChat")}
    </.context_menu_item>
    """
  end

  # ── Leaf item ────────────────────────────────────────

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :on_action, :any, default: nil
  attr :shortcut, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  defp menu_item(assigns) do
    ~H"""
    <.context_menu_item on_click={@on_action} action={@action} disabled={@disabled} {@rest}>
      <:icon>{apply(Icons, @icon_fn, [%{class: "w-[14px] h-[14px]"}])}</:icon>
      <:shortcut :if={@shortcut}>{@shortcut}</:shortcut>
      {@label}
    </.context_menu_item>
    """
  end
end
