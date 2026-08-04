defmodule RetroHexChatWeb.Components.UI.StartMenuApp do
  @moduledoc """
  The Start menu — the same one on every screen the app has.

  Landing, Connect, Chat, Help and the showcase all render this component and all
  get the identical list of entries. What changes between them is which entries
  are live: a visitor on the landing page can open Start ▸ Tools and read
  "Address Book", "Notify List", "Ignore List" grayed out, because those are real
  parts of the app they have not connected to yet. Hiding them would make the
  menu a different menu on every screen and leave the app's surface invisible
  until you were already inside it.

  `screen` is the only capability input a caller needs; the table below it is the
  single place that decides what each screen can reach, which is what makes the
  symmetry testable rather than a convention four call sites have to remember.

  ## Structure

  The desktop menu cannot scroll — `overflow` would make it a clipping context
  and swallow the flyouts, which escape to the right — so the root list has to
  fit on screen at any height. Ten rows, one level of groups deep:

      Tools ▸ Automation ▸ Settings ▸ P2P ▸ Account ▸ Admin ▸
      Windows ▸ Navigate ▸
      Help ▸
      Disconnect

  One level is also the limit the `WindowManagerHook` supports: opening a group
  closes every other `[data-start-submenu]` in the menu, an ancestor included, so
  a nested group would shut its own parent.

  Pure presentation: primitives and semantic event names only (no `Session`, no
  domain calls), like `MenuBarApp`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.ShowcaseCatalog

  @screens [:chat, :connect, :landing, :help, :showcase]

  attr :id, :string, default: "start-menu"

  attr :screen, :atom,
    required: true,
    values: @screens,
    doc: "which desktop this menu sits on — decides what is reachable"

  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false, doc: "Enables the P2P group while a session exists"

  attr :windows, :list,
    default: [],
    doc: "%{id, label, icon_fn} windows of THIS desktop, listed under Windows"

  attr :on_action, :any, default: "toolbar_action"

  @spec start_menu_app(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu_app(assigns) do
    assigns =
      assigns
      |> assign(:chat?, assigns.screen == :chat)
      |> assign(:p2p?, assigns.screen == :chat and assigns.p2p_active)
      |> assign(:admin?, assigns.screen == :chat and assigns.is_admin)
      |> assign(:help?, assigns.screen == :help)
      |> assign(:nav_pages, nav_pages())

    ~H"""
    <div class="relative">
      <.start_button label={dgettext("ui", "Start")}>
        <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
      </.start_button>
      <.start_menu id={@id}>
        <%!-- ── The app's own windows, by what they are for ────────── --%>
        <.start_menu_submenu
          label={dgettext("ui", "Tools")}
          muted={!@chat?}
          testid="start-menu-tools-submenu"
        >
          <:icon><Icons.icon_group_tools class="h-4 w-4" /></:icon>
          <.window_item
            window="address-book"
            label={dgettext("ui", "Address Book")}
            icon_fn={:icon_btn_address_book}
            disabled={!@chat?}
          />
          <.window_item
            window="notify-list"
            label={dgettext("ui", "Notify List")}
            icon_fn={:icon_tab_notify}
            disabled={!@chat?}
          />
          <.window_item
            window="ignore-list"
            label={dgettext("ui", "Ignore List")}
            icon_fn={:icon_btn_ignore_list}
            disabled={!@chat?}
          />
          <.window_item
            window="highlight"
            label={dgettext("ui", "Highlight Words")}
            icon_fn={:icon_btn_highlight_words}
            disabled={!@chat?}
          />
          <.window_item
            window="user-lookup"
            label={dgettext("ui", "User Lookup")}
            icon_fn={:icon_btn_search}
            disabled={!@chat?}
          />
          <.window_item
            window="url-catcher"
            label={dgettext("ui", "URL Catcher")}
            icon_fn={:icon_btn_url_catcher}
            disabled={!@chat?}
          />
          <%!-- Server openers: /list rows and channel state are loaded by the
                LiveView on open, so these two cannot be client-side. --%>
          <.app_item
            action="toggle_channel_list"
            on_action={@on_action}
            label={dgettext("ui", "Channel List")}
            icon_fn={:icon_btn_channel_list}
            disabled={!@chat?}
          />
          <.app_item
            action="open_channel_central"
            on_action={@on_action}
            label={dgettext("ui", "Channel Central")}
            icon_fn={:icon_btn_channel_central}
            disabled={!@chat?}
          />
        </.start_menu_submenu>

        <.start_menu_submenu
          label={dgettext("ui", "Automation")}
          muted={!@chat?}
          testid="start-menu-automation-submenu"
        >
          <:icon><Icons.icon_dialog_perform class="h-4 w-4" /></:icon>
          <.window_item
            window="perform"
            label={dgettext("ui", "Perform")}
            icon_fn={:icon_btn_perform}
            disabled={!@chat?}
          />
          <.window_item
            window="autojoin"
            label={dgettext("ui", "Auto-Join")}
            icon_fn={:icon_btn_autojoin}
            disabled={!@chat?}
          />
          <.window_item
            window="auto-respond"
            label={dgettext("ui", "Auto Respond")}
            icon_fn={:icon_btn_auto_respond}
            disabled={!@chat?}
          />
          <.window_item
            window="alias"
            label={dgettext("ui", "Alias Editor")}
            icon_fn={:icon_btn_alias_editor}
            disabled={!@chat?}
          />
          <.window_item
            window="custom-menus"
            label={dgettext("ui", "Custom Menus")}
            icon_fn={:icon_btn_custom_menus}
            disabled={!@chat?}
          />
          <.window_item
            window="timers"
            label={dgettext("ui", "Timers")}
            icon_fn={:icon_btn_timers}
            disabled={!@chat?}
          />
        </.start_menu_submenu>

        <.start_menu_submenu
          label={dgettext("ui", "Settings")}
          muted={!@chat?}
          testid="start-menu-settings-submenu"
        >
          <:icon><Icons.icon_btn_settings class="h-4 w-4" /></:icon>
          <.window_item
            window="nick-colors"
            label={dgettext("ui", "Nick Colors")}
            icon_fn={:icon_btn_nick_colors}
            disabled={!@chat?}
          />
          <.window_item
            window="sound-settings"
            label={dgettext("ui", "Sounds")}
            icon_fn={:icon_btn_sounds}
            disabled={!@chat?}
          />
          <.window_item
            window="flood-protection"
            label={dgettext("ui", "Flood Protection")}
            icon_fn={:icon_btn_flood_protection}
            disabled={!@chat?}
          />
        </.start_menu_submenu>

        <%!-- Gated twice over: the whole group needs a chat, and every entry
              needs a live peer session on top of it. --%>
        <.start_menu_submenu
          label={dgettext("ui", "P2P")}
          muted={!@p2p?}
          testid="start-menu-p2p-submenu"
        >
          <:icon><Icons.icon_p2p class="h-4 w-4" /></:icon>
          <.app_item
            action="p2p_start_audio"
            on_action={@on_action}
            label={dgettext("ui", "Start Audio Call")}
            icon_fn={:icon_microphone}
            disabled={!@p2p?}
          />
          <.app_item
            action="p2p_start_video"
            on_action={@on_action}
            label={dgettext("ui", "Start Video Call")}
            icon_fn={:icon_camera}
            disabled={!@p2p?}
          />
          <.app_item
            action="p2p_console_select"
            on_action={@on_action}
            label={dgettext("ui", "Send a File...")}
            icon_fn={:icon_file_send}
            disabled={!@p2p?}
            phx-value-section="files"
            testid="start-menu-item-p2p-files"
          />
          <.app_item
            action="p2p_console_select"
            on_action={@on_action}
            label={dgettext("ui", "Play a Game...")}
            icon_fn={:icon_game_arcade}
            disabled={!@p2p?}
            phx-value-section="games"
            testid="start-menu-item-p2p-games"
          />
          <.app_item
            action="p2p_console_select"
            on_action={@on_action}
            label={dgettext("ui", "P2P Stats")}
            icon_fn={:icon_status_signal}
            disabled={!@p2p?}
            phx-value-section="stats"
            testid="start-menu-item-p2p-stats"
          />
          <.app_item
            action="p2p_end_session"
            on_action={@on_action}
            label={dgettext("ui", "End P2P Session")}
            icon_fn={:icon_btn_disconnect}
            disabled={!@p2p?}
          />
        </.start_menu_submenu>

        <%!-- Account is action-driven, never `data-window-open`: opening these
              has server-side work attached (identity sync, bio seeding). --%>
        <.start_menu_submenu
          label={dgettext("ui", "Account")}
          muted={!@chat?}
          testid="start-menu-account-submenu"
        >
          <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
          <.app_item
            action="open_account_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Account")}
            icon_fn={:icon_status_user}
            disabled={!@chat?}
          />
          <.app_item
            action="open_profile_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Profile")}
            icon_fn={:icon_btn_profile}
            disabled={!@chat?}
          />
          <.app_item
            action="open_away_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Away")}
            icon_fn={:icon_btn_away}
            disabled={!@chat?}
          />
          <.app_item
            action="open_user_modes_dialog"
            on_action={@on_action}
            label={dgettext("ui", "User Modes")}
            icon_fn={:icon_btn_user_modes}
            disabled={!@chat?}
          />
          <.app_item
            action="open_trusted_terminals_dialog"
            on_action={@on_action}
            label={dgettext("ui", "Trusted Terminals")}
            icon_fn={:icon_lock}
            disabled={!@chat?}
          />
        </.start_menu_submenu>

        <.start_menu_submenu
          label={dgettext("ui", "Admin")}
          muted={!@admin?}
          testid="start-menu-admin-submenu"
        >
          <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
          <.app_item
            :for={{action, label, icon_fn} <- admin_entries()}
            action={action}
            on_action={@on_action}
            label={label}
            icon_fn={icon_fn}
            disabled={!@admin?}
          />
        </.start_menu_submenu>

        <.start_menu_separator />

        <%!-- The one group whose contents are meant to differ: these are the
              windows of the desktop you are standing on. Closing a window takes
              its taskbar button with it, the way Win98 does, and this is how it
              comes back. --%>
        <.start_menu_submenu
          label={dgettext("ui", "Windows")}
          muted={@windows == []}
          testid="start-menu-windows-submenu"
        >
          <:icon><Icons.icon_group_view class="h-4 w-4" /></:icon>
          <.window_item
            :for={window <- @windows}
            window={window.id}
            label={window.label}
            icon_fn={window.icon_fn}
          />
          <.start_menu_item
            :if={@windows == []}
            label={dgettext("ui", "No windows")}
            disabled
            data-testid="start-menu-item-no-windows"
          >
            <:icon><Icons.icon_group_view class="h-4 w-4" /></:icon>
          </.start_menu_item>
        </.start_menu_submenu>

        <%!-- Real links, so this group navigates and indexes with JavaScript
              off. `href` rather than `navigate` throughout: these cross
              live_sessions, which a LiveView patch cannot. --%>
        <.start_menu_submenu
          label={dgettext("ui", "Navigate")}
          testid="start-menu-navigate-submenu"
        >
          <:icon><Icons.icon_globe class="h-4 w-4" /></:icon>
          <.link_item
            :for={page <- @nav_pages}
            href={page.path}
            label={page.label}
            icon_fn={page.icon_fn}
            testid={"start-menu-item-page-#{page.id}"}
          />
          <.start_menu_separator />
          <.link_item
            href="/chat/help"
            label={dgettext("landing", "Documentation")}
            icon_fn={:icon_notepad}
            disabled={@help?}
            testid="start-menu-item-documentation"
          />
          <.link_item
            href={ShowcaseCatalog.root()}
            label={dgettext("showcase", "Design System")}
            icon_fn={:icon_palette}
            disabled={@screen == :showcase}
            testid="start-menu-item-design-system"
          />
          <.start_menu_separator />
          <.link_item
            href="/connect"
            label={dgettext("landing", "Open the app")}
            icon_fn={:icon_connect}
            disabled={@screen in [:chat, :connect]}
            class="font-bold"
            testid="start-menu-item-open-the-app"
          />
          <%!-- The help viewer is the one screen that returns to a chat it
                never left: the session is still up behind it, so it goes back
                through the LiveView instead of a fresh page load. --%>
          <.app_item
            :if={@help?}
            action="help_back_to_chat"
            on_action="help_back_to_chat"
            label={dgettext("help", "Back to chat")}
            icon_fn={:icon_chat}
            testid="start-menu-item-back-to-chat"
          />
          <.link_item
            :if={!@help?}
            href="/chat"
            label={dgettext("help", "Back to chat")}
            icon_fn={:icon_chat}
            disabled={@chat?}
            testid="start-menu-item-back-to-chat"
          />
        </.start_menu_submenu>

        <.start_menu_separator />

        <.start_menu_submenu label={dgettext("ui", "Help")} testid="start-menu-help-submenu">
          <:icon><Icons.icon_group_help class="h-4 w-4" /></:icon>
          <.help_topics_item screen={@screen} />
          <.app_item
            action="help_nav_tab"
            on_action="help_nav_tab"
            label={dgettext("help", "Search")}
            icon_fn={:icon_btn_search}
            disabled={!@help?}
            phx-value-tab="search"
            testid="start-menu-item-help-search"
          />
          <.window_item
            window="cheatsheet"
            label={dgettext("ui", "Shortcut Cheatsheet")}
            icon_fn={:icon_dialog_cheatsheet}
            disabled={!@chat?}
          />
          <.start_menu_separator />
          <.about_item screen={@screen} />
        </.start_menu_submenu>

        <.start_menu_separator />

        <%!-- Win98 put Shut Down last, alone, under a rule. This is that row. --%>
        <.app_item
          action="disconnect"
          on_action={@on_action}
          label={dgettext("ui", "Disconnect")}
          icon_fn={:icon_btn_disconnect}
          disabled={!@chat?}
        />
      </.start_menu>
    </div>
    """
  end

  # ── Private helpers ─────────────────────────────────

  # The ten admin windows share one gate and one shape, so they are a table
  # rather than ten near-identical blocks of markup. The labels stay literal
  # `dgettext` calls — a msgid assembled at runtime is invisible to the
  # extractor and would ship untranslated.
  defp admin_entries do
    [
      {"open_admin_users", dgettext("ui", "Users"), :icon_community},
      {"open_admin_channels", dgettext("ui", "Channels"), :icon_channels},
      {"open_admin_server_settings", dgettext("ui", "Server Settings"), :icon_server},
      {"open_admin_audit_log", dgettext("ui", "Audit Log"), :icon_notepad},
      {"open_admin_motd", dgettext("ui", "MOTD"), :icon_notepad},
      {"open_admin_turn", dgettext("ui", "TURN"), :icon_websocket},
      {"open_admin_broadcast", dgettext("ui", "Broadcast"), :icon_megaphone},
      {"open_admin_danger_zone", dgettext("ui", "Danger Zone"), :icon_warning},
      {"open_admin_console", dgettext("ui", "Console"), :icon_dialog_admin_console},
      {"open_bot_dialog", dgettext("ui", "Bot Management"), :icon_btn_bot_management}
    ]
  end

  # The seven public pages, named the way the landing shell names them — these
  # are the landing vocabulary, and its catalogs already carry them translated.
  defp nav_pages do
    [
      %{id: "home", path: "/", label: dgettext("landing", "Home"), icon_fn: :icon_hex_stone},
      %{
        id: "how-it-works",
        path: "/how-it-works",
        label: dgettext("landing", "How It Works"),
        icon_fn: :icon_server
      },
      %{
        id: "features",
        path: "/features",
        label: dgettext("landing", "Features"),
        icon_fn: :icon_chat
      },
      %{
        id: "privacy",
        path: "/privacy",
        label: dgettext("landing", "Privacy"),
        icon_fn: :icon_lock
      },
      %{
        id: "install",
        path: "/install",
        label: dgettext("landing", "Install"),
        icon_fn: :icon_terminal
      },
      %{
        id: "community",
        path: "/community",
        label: dgettext("landing", "Community"),
        icon_fn: :icon_code
      },
      %{id: "faq", path: "/faq", label: dgettext("landing", "FAQ"), icon_fn: :icon_question}
    ]
  end

  # Help Topics is the same entry everywhere and reaches its topics three ways:
  # the chat and connect LiveViews both answer the bare `help_topics` event, the
  # help viewer already owns the window, and the public pages link to the page it
  # lives on.
  attr :screen, :atom, required: true

  defp help_topics_item(%{screen: :help} = assigns) do
    ~H"""
    <.window_item
      window="help"
      label={dgettext("ui", "Help Topics")}
      icon_fn={:icon_btn_help_topics}
      testid="start-menu-item-help_topics"
    />
    """
  end

  defp help_topics_item(%{screen: screen} = assigns) when screen in [:chat, :connect] do
    ~H"""
    <.app_item
      action="help_topics"
      on_action="help_topics"
      label={dgettext("ui", "Help Topics")}
      icon_fn={:icon_btn_help_topics}
      testid="start-menu-item-help_topics"
    />
    """
  end

  defp help_topics_item(assigns) do
    ~H"""
    <.link_item
      href="/chat/help"
      label={dgettext("ui", "Help Topics")}
      icon_fn={:icon_btn_help_topics}
      testid="start-menu-item-help_topics"
    />
    """
  end

  # About is live on every screen. The landing desktop gives it a window of its
  # own; the other four each mount `about_dialog id="about-dialog"`, so the same
  # modal command reaches it from all of them.
  attr :screen, :atom, required: true

  defp about_item(%{screen: :landing} = assigns) do
    ~H"""
    <.window_item
      window="about"
      label={dgettext("ui", "About RetroHexChat")}
      icon_fn={:icon_dialog_about}
      testid="start-menu-item-show_about"
    />
    """
  end

  defp about_item(assigns) do
    ~H"""
    <.start_menu_item
      phx-click={show_modal("about-dialog")}
      label={dgettext("ui", "About RetroHexChat")}
      data-testid="start-menu-item-show_about"
    >
      <:icon><Icons.icon_dialog_about class="h-4 w-4" /></:icon>
    </.start_menu_item>
    """
  end

  # Opens/focuses a desktop window client-side (no server round trip). A disabled
  # row drops the attribute as well as the click: the hook reads the DOM, and a
  # dead entry should not look like a live one to it.
  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :window, :string, required: true, doc: "target window id"
  attr :disabled, :boolean, default: false
  attr :testid, :string, default: nil

  defp window_item(assigns) do
    ~H"""
    <.start_menu_item
      data-window-open={!@disabled && @window}
      label={@label}
      disabled={@disabled}
      data-testid={@testid || "start-menu-item-#{@window}"}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :on_action, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :testid, :string, default: nil
  attr :rest, :global

  defp app_item(assigns) do
    ~H"""
    <.start_menu_item
      phx-click={!@disabled && @on_action}
      phx-value-action={!@disabled && @action}
      label={@label}
      disabled={@disabled}
      data-testid={@testid || "start-menu-item-#{@action}"}
      {@rest}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :href, :string, required: true
  attr :disabled, :boolean, default: false
  attr :testid, :string, required: true
  attr :class, :any, default: nil

  defp link_item(assigns) do
    ~H"""
    <.start_menu_item
      href={@href}
      label={@label}
      disabled={@disabled}
      class={@class}
      data-testid={@testid}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end
end
