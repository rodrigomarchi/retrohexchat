defmodule RetroHexChatWeb.Components.UI.StartMenuApp do
  @moduledoc """
  The Start menu — the same one on every screen the app has.

  Landing, Connect, Chat, Help and the showcase all render this component and get
  the same user-facing list of entries. What changes between them is which
  entries are live: a visitor on the landing page can open Start ▸ Tools and read
  "Address Book", "Notify List", "Ignore List" grayed out, because those are real
  parts of the app they have not connected to yet. The exception is privileged
  server operation: Admin and System are visible only inside the chat for admins.

  `screen` is the only capability input a caller needs; the table below it is the
  single place that decides what each screen can reach, which is what makes the
  symmetry testable rather than a convention four call sites have to remember.

  ## Structure

  The desktop menu cannot scroll — `overflow` would make it a clipping context
  and swallow the flyouts, which escape to the right — so the root list has to
  fit on screen at any height. Root rows stay one level of groups deep:

      View ▸ Tools ▸ Automation ▸ P2P ▸ Games ▸ Account ▸ [Admin ▸ System ▸]
      Windows ▸ Navigate ▸ Language ▸
      Help ▸
      Disconnect

  One level is also the limit the `WindowManagerHook` supports: opening a group
  closes every other `[data-start-submenu]` in the menu, an ancestor included, so
  a nested group would shut its own parent. That limit is why Language is a root
  group rather than a row inside Settings, and why Settings itself was folded
  back into Tools: three windows never earned a row of their own once one had to
  be given up.

  This menu is a superset of every non-privileged menu bar the app renders — the
  chat's `MenuBarApp`, the help viewer's `HelpMenuBar` and the landing shell's
  own strip. An item that exists in any of them exists here, on every screen,
  gray where it has nothing to act on. Admin/System are scoped to chat admins
  instead of being advertised on public or non-admin desktops.

  Pure presentation: primitives and semantic event names only (no `Session`, no
  domain calls), like `MenuBarApp`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Components.UI.LanguageMenu
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.ShowcaseCatalog

  @screens [:chat, :connect, :landing, :help, :showcase]

  # The screens that switch locale through the app's redirect endpoint rather
  # than through a localized public URL.
  @app_screens [:chat, :connect]

  attr :id, :string, default: "start-menu"

  attr :screen, :atom,
    required: true,
    values: @screens,
    doc: "which desktop this menu sits on — decides what is reachable"

  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false, doc: "Enables the P2P group while a session exists"

  attr :p2p_turn_available, :boolean,
    default: false,
    doc: "Enables privacy mode (needs a configured TURN relay)"

  attr :arcade_available, :boolean,
    default: false,
    doc: "Enables the Arcade entry (needs a registered + identified nick)"

  attr :windows, :list,
    default: [],
    doc: "%{id, label, icon_fn} windows of THIS desktop, listed under Windows"

  attr :current_path, :string,
    default: nil,
    doc: "path the public locale links rewrite — public screens only"

  attr :language_return_to, :string,
    default: nil,
    doc: "where the app's locale redirect lands; defaults to this screen's own path"

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
      |> assign(:locales, locales(assigns))

    # Offering a session to someone who already has one is the one P2P entry
    # that reads the gate the other way round.
    assigns = assign(assigns, :p2p_idle?, assigns.chat? and not assigns.p2p_active)

    ~H"""
    <div class="relative">
      <.start_button label={dgettext("ui", "Start")}>
        <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
      </.start_button>
      <.start_menu id={@id}>
        <%!-- ── What the window in front of you is showing ─────────── --%>
        <%!-- The chat's Edit and View menus plus the help viewer's own View,
              which are the same question asked of two different documents. The
              group is live on both screens, so it is muted only where neither
              half has anything to act on. --%>
        <.start_menu_submenu
          label={dgettext("ui", "View")}
          muted={!@chat? and !@help?}
          testid="start-menu-view-submenu"
        >
          <:icon><Icons.icon_channels class="h-4 w-4" /></:icon>
          <.app_item
            action="toggle_conversations"
            on_action={@on_action}
            label={dgettext("ui", "Toggle Conversations")}
            icon_fn={:icon_btn_toggle_conversations}
            disabled={!@chat?}
          />
          <.app_item
            action="toggle_nicklist"
            on_action={@on_action}
            label={dgettext("ui", "Toggle Nicklist")}
            icon_fn={:icon_btn_toggle_nicklist}
            disabled={!@chat?}
          />
          <.app_item
            action="toggle_strip_formatting"
            on_action={@on_action}
            label={dgettext("chat", "Strip Formatting")}
            icon_fn={:icon_fmt_color}
            disabled={!@chat?}
          />
          <.start_menu_separator />
          <.app_item
            action="clear_window"
            on_action={@on_action}
            label={dgettext("ui", "Clear Window")}
            icon_fn={:icon_btn_remove}
            disabled={!@chat?}
          />
          <.copy_item disabled={!@chat?} />
          <.app_item
            action="toggle_search"
            on_action={@on_action}
            label={dgettext("ui", "Find")}
            icon_fn={:icon_btn_find}
            disabled={!@chat?}
          />
          <.start_menu_separator />
          <%!-- The help viewer's three tabs. They travel together: split across
                two groups they would read as three unrelated entries rather
                than as one control with three positions. --%>
          <.app_item
            action="help_nav_tab"
            on_action="help_nav_tab"
            label={dgettext("help", "Contents")}
            icon_fn={:icon_notepad}
            disabled={!@help?}
            phx-value-tab="contents"
            testid="start-menu-item-help-contents"
          />
          <.app_item
            action="help_nav_tab"
            on_action="help_nav_tab"
            label={dgettext("help", "Index")}
            icon_fn={:icon_btn_channel_list}
            disabled={!@help?}
            phx-value-tab="index"
            testid="start-menu-item-help-index"
          />
          <.app_item
            action="help_nav_tab"
            on_action="help_nav_tab"
            label={dgettext("help", "Search")}
            icon_fn={:icon_btn_search}
            disabled={!@help?}
            phx-value-tab="search"
            testid="start-menu-item-help-search"
          />
        </.start_menu_submenu>

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
          <%!-- Settings used to be a group of its own. Three windows do not earn
                a root row when a root row is what the menu is short of. --%>
          <.start_menu_separator />
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

        <%!-- Gated twice over: the whole group needs a chat, and every entry
              needs a live peer session on top of it. The exception is the entry
              that explains how to get one, which is live precisely while there
              is none. --%>
        <.start_menu_submenu
          label={dgettext("ui", "P2P")}
          muted={!@p2p? and !@p2p_idle?}
          testid="start-menu-p2p-submenu"
        >
          <:icon><Icons.icon_p2p class="h-4 w-4" /></:icon>
          <.app_item
            action="p2p_how_to_start"
            on_action={@on_action}
            label={dgettext("ui", "Start a P2P Session...")}
            icon_fn={:icon_protocol_p2p_compact}
            disabled={!@p2p_idle?}
          />
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
          <%!-- Routing a call through the relay hides both peers' addresses,
                so it needs a relay to be configured before it can be offered. --%>
          <.app_item
            action="p2p_toggle_privacy"
            on_action={@on_action}
            label={dgettext("ui", "Toggle Privacy Mode")}
            icon_fn={:icon_lock}
            disabled={!@p2p? or !@p2p_turn_available}
          />
          <.start_menu_separator />
          <.app_item
            action="p2p_end_session"
            on_action={@on_action}
            label={dgettext("ui", "End P2P Session")}
            icon_fn={:icon_btn_disconnect}
            disabled={!@p2p?}
          />
        </.start_menu_submenu>

        <.start_menu_submenu
          label={dgettext("ui", "Games")}
          muted={!@chat?}
          testid="start-menu-games-submenu"
        >
          <:icon><Icons.icon_game_arcade class="h-4 w-4" /></:icon>
          <%!-- Client-side: the Retro Games window carries its own LiveView,
                which loads the catalogue in its own mount. Nothing to fetch
                here, so nothing to ask the server for. --%>
          <.window_item
            window="retro-games"
            label={dgettext("ui", "Retro Games")}
            icon_fn={:icon_game_pong}
            disabled={!@chat?}
            testid="start-menu-item-retro-games"
          />
          <%!-- The arcade keeps scores against a nick, so it needs one that is
                registered and identified — a chat alone is not enough. --%>
          <.app_item
            action="open_arcade"
            on_action={@on_action}
            label={dgettext("ui", "Arcade...")}
            icon_fn={:icon_game_arcade}
            disabled={!@chat? or !@arcade_available}
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
          <%!-- Claiming a nick and proving it is the pair that comes before
                everything else under here, so it leads. --%>
          <.app_item
            action="open_account_register"
            on_action={@on_action}
            label={dgettext("ui", "Register Nickname...")}
            icon_fn={:icon_lock}
            disabled={!@chat?}
          />
          <.app_item
            action="open_account_identify"
            on_action={@on_action}
            label={dgettext("ui", "Identify...")}
            icon_fn={:icon_status_user}
            disabled={!@chat?}
          />
          <.start_menu_separator />
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
          <.start_menu_separator />
          <%!-- Prints what the server knows about you into the status window,
                rather than opening one of its own. --%>
          <.app_item
            action="account_info"
            on_action={@on_action}
            label={dgettext("ui", "Account Info")}
            icon_fn={:icon_tab_status}
            disabled={!@chat?}
          />
        </.start_menu_submenu>

        <.start_menu_submenu
          :if={@admin?}
          label={dgettext("ui", "Admin")}
          testid="start-menu-admin-submenu"
        >
          <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
          <.app_item
            :for={{action, label, icon_fn} <- admin_entries()}
            action={action}
            on_action={@on_action}
            label={label}
            icon_fn={icon_fn}
          />
        </.start_menu_submenu>

        <%!-- Kept apart from Admin: these windows only read the node, while
              everything under Admin acts on the server. --%>
        <.start_menu_submenu
          :if={@admin?}
          label={dgettext("ui", "System")}
          testid="start-menu-system-submenu"
        >
          <:icon><Icons.icon_server class="h-4 w-4" /></:icon>
          <.app_item
            :for={{action, label, icon_fn} <- system_entries()}
            action={action}
            on_action={@on_action}
            label={label}
            icon_fn={icon_fn}
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
          <:icon><Icons.icon_btn_next class="h-4 w-4" /></:icon>
          <%!-- The help viewer's history, read by `HelpNavHook` client-side.
                Nothing else on the app keeps a history of its own — the browser
                owns it everywhere the desktop is not a document reader. --%>
          <.help_nav_item
            direction="back"
            label={dgettext("help", "Back")}
            icon_fn={:icon_btn_prev}
            disabled={!@help?}
          />
          <.help_nav_item
            direction="forward"
            label={dgettext("help", "Forward")}
            icon_fn={:icon_btn_next}
            disabled={!@help?}
          />
          <.start_menu_separator />
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
          <%!-- The public pages carry the sign-in window themselves, so this
                leads to one rather than to /connect: nobody has to visit a
                screen whose only job is to hold the form they already have.
                It stays for help and the showcase, the two public screens
                without that window, and goes inert wherever it is redundant. --%>
          <.link_item
            href="/"
            label={dgettext("landing", "Open the app")}
            icon_fn={:icon_connect}
            disabled={@screen in [:chat, :connect, :landing]}
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

        <%!-- Every locale as a real link, exactly as the menu bars render it —
              `LanguageMenu` computes the hrefs for both, so a switch cannot mean
              one thing in the bar and another here. A root group because the
              window manager allows no group inside a group. --%>
        <.start_menu_submenu
          label={dgettext("ui", "Language")}
          testid="start-menu-language-submenu"
        >
          <:icon><Icons.icon_globe class="h-4 w-4" /></:icon>
          <.start_menu_item
            :for={locale <- @locales}
            href={locale.href}
            label={locale.label}
            hreflang={locale.bcp47}
            data-locale={locale.code}
            data-testid={"start-menu-item-language-#{locale.code}"}
          >
            <:icon><Icons.flag_icon locale={locale.code} class="h-4 w-4" /></:icon>
          </.start_menu_item>
        </.start_menu_submenu>

        <.start_menu_separator />

        <.start_menu_submenu label={dgettext("ui", "Help")} testid="start-menu-help-submenu">
          <:icon><Icons.icon_group_help class="h-4 w-4" /></:icon>
          <.help_topics_item screen={@screen} />
          <.window_item
            window="cheatsheet"
            label={dgettext("ui", "Shortcut Cheatsheet")}
            icon_fn={:icon_dialog_cheatsheet}
            disabled={!@chat?}
          />
          <.app_item
            action="show_motd"
            on_action={@on_action}
            label={dgettext("ui", "Message of the Day")}
            icon_fn={:icon_notepad}
            disabled={!@chat?}
          />
          <%!-- The landing shell's Help menu is where these two lived. They are
                the only entries in the menu that leave the app entirely, so
                they stay together and behind the separator. --%>
          <.start_menu_separator />
          <.link_item
            href="https://github.com/rodrigomarchi/retro_hex_chat"
            label="GitHub"
            icon_fn={:icon_code}
            target="_blank"
            rel="noopener"
            testid="start-menu-item-github"
          />
          <.link_item
            href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
            label={dgettext("landing", "License (MIT)")}
            icon_fn={:icon_legal}
            target="_blank"
            rel="noopener"
            testid="start-menu-item-license"
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

  # Public screens rewrite the path they are on; the app's two redirect through
  # `/locale/:code` and come back where they started.
  defp locales(%{screen: screen} = assigns) when screen in @app_screens do
    LanguageMenu.locale_links(:app, nil, assigns.language_return_to || default_return_to(screen))
  end

  defp locales(assigns) do
    LanguageMenu.locale_links(:public, assigns.current_path, nil)
  end

  defp default_return_to(:chat), do: "/chat"
  defp default_return_to(:connect), do: "/connect"

  # Both privileged groups are derived from `WindowRegistry`, so a window
  # cannot be openable from a menu that no longer knows its title, nor carry a
  # different icon here than it does on its own title bar.
  defp admin_entries, do: menu_entries(&(&1.family == :admin or &1.id == "bot-management-dialog"))

  defp system_entries, do: menu_entries(&(&1.family == :system))

  defp menu_entries(filter) do
    for window <- WindowRegistry.windows(),
        window.opener,
        filter.(window),
        do: {window.opener, window.title, window.icon}
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
  attr :rest, :global

  defp link_item(assigns) do
    ~H"""
    <.start_menu_item
      href={@href}
      label={@label}
      disabled={@disabled}
      class={@class}
      data-testid={@testid}
      {@rest}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end

  # Steps the help viewer's own history. `HelpNavHook` reads the attribute off
  # the DOM, so a dead row drops it rather than looking live to the hook.
  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :direction, :string, required: true, values: ["back", "forward"]
  attr :disabled, :boolean, default: false

  defp help_nav_item(assigns) do
    ~H"""
    <.start_menu_item
      data-help-nav={!@disabled && @direction}
      label={@label}
      disabled={@disabled}
      data-testid={"start-menu-item-help-#{@direction}"}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.start_menu_item>
    """
  end

  # Copies the current chat-log selection. The only row in the menu whose live
  # state is not a property of the screen but of the document: it is enabled
  # while something is selected, and `copy_selection.js` — shared with the menu
  # bar — flips `data-copy-disabled` on it as the selection changes. The gate
  # here is the coarse one, and says only whether a chat log exists at all.
  attr :disabled, :boolean, default: false

  defp copy_item(assigns) do
    ~H"""
    <.start_menu_item
      label={dgettext("ui", "Copy")}
      disabled={@disabled}
      data-menubar-copy-selection="true"
      data-copy-disabled="true"
      aria-disabled="true"
      data-testid="start-menu-item-copy_selection"
    >
      <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
    </.start_menu_item>
    """
  end
end
