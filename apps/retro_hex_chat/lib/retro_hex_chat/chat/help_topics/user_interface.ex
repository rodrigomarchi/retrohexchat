defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: dgettext("help", "User Interface Overview"),
        category: dgettext("help", "User Interface"),
        keywords: ["ui", "interface", "layout", "window", "mdi", "edit menu"],
        icon: :icon_laptop,
        description:
          dgettext(
            "help",
            "Overview of the RetroHexChat interface layout including panels, toolbar, and navigation."
          )
      },
      %{
        id: "ui-connect-window",
        title: dgettext("help", "Connect Window"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "connect",
          "sign in",
          "login",
          "landing",
          "home page",
          "nickname",
          "trusted terminal",
          "auto-login"
        ],
        icon: :icon_connect,
        description:
          dgettext(
            "help",
            "Sign in from the Connect window, which appears both on its own screen and on every public page. It carries the whole flow: pick a nickname, register a new one or enter a password for a registered one, and choose whether to remember the terminal. A remembered terminal signs you in with a single click, and one set to auto-login takes you straight to the chat."
          )
      },
      %{
        id: "ui-desktop",
        title: dgettext("help", "Desktop & Windows"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "desktop",
          "window",
          "taskbar",
          "start menu",
          "minimize",
          "maximize",
          "restore",
          "tray",
          "clock",
          "title",
          "title bar",
          "browser tab",
          "cascade",
          "tile",
          "help viewer",
          "search topics",
          "logon",
          "connect screen",
          "phone",
          "mobile"
        ],
        icon: :icon_win_maximize,
        description:
          dgettext(
            "help",
            "The chat runs on a Windows-style desktop: the chat itself is one pinned window " <>
              "(maximized by default) that you can restore, drag and resize, over a taskbar " <>
              "with a Start menu and a tray clock. Window layout persists across visits. " <>
              "The window, its taskbar button and the browser tab are all named after the " <>
              "conversation you are in. "
          ) <>
            dgettext(
              "help",
              "The chat, the solo arcade and this Help viewer share the same window " <>
                "manager. The Help viewer is laid out like the classic Windows Help: a toolbar " <>
                "(Back / Forward / Home), a navigator with Contents, Index and Search tabs, and " <>
                "a \"See Also\" list of related topics under each article."
            ) <>
            " " <>
            dgettext(
              "help",
              "The Connect screen is a logon-style desktop too: the connect dialog is a pinned " <>
                "window centered over the taskbar, with Help available from its Start menu."
            ) <>
            " " <>
            dgettext(
              "help",
              "On a phone the desktop stacks: one window fills the screen at a time and the " <>
                "taskbar switches between them — the same strip of window buttons as on a " <>
                "desktop, squeezed to fit and scrolled when crowded. The conversations and user " <>
                "list keep no column of their own there: the first two buttons of the " <>
                "conversation toolbar slide each one open over the chat, so every message and " <>
                "the message box run the full width of the screen. The Start menu opens one " <>
                "level at a time: tapping a group replaces the list with its entries, and the " <>
                "group's own row at the top takes you back."
            ) <>
            " " <>
            dgettext(
              "help",
              "The menu bar becomes a rail of icons across the top of the screen — one per " <>
                "menu, in the same order as on the desktop. Tapping one opens the menu already " <>
                "on that section; tapping another switches to it, and tapping the one already " <>
                "open closes the menu."
            ),
        see_also: ["ui-start-menu", "ui-overview", "keyboard-shortcuts"]
      },
      %{
        id: "ui-start-menu",
        title: dgettext("help", "The Start Menu"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "start menu",
          "start button",
          "grayed out",
          "disabled",
          "groups",
          "tools",
          "automation",
          "settings",
          "view",
          "language",
          "games",
          "arcade",
          "copy",
          "navigate",
          "windows",
          "admin",
          "disconnect"
        ],
        icon: :icon_hex_stone,
        description:
          dgettext(
            "help",
            "The Start button opens the same menu on every screen RetroHexChat has — the " <>
              "landing pages, the Connect screen, the chat, this Help viewer and the design " <>
              "system. What changes between them is which entries are live."
          ) <>
            " " <>
            dgettext(
              "help",
              "Entries you cannot use right now are grayed out rather than hidden. Opening " <>
                "Start ▸ Tools from the landing page shows Address Book, Notify List and the " <>
                "rest in gray: they are real parts of the app, waiting for you to connect. " <>
                "The menu is the same map wherever you are standing on it."
            ) <>
            " " <>
            dgettext(
              "help",
              "The entries are grouped one level deep, and the menu carries everything the " <>
                "app can do: anything a menu bar offers is offered here too. View acts on " <>
                "the window in front of you; Tools holds the address book, lists, channel " <>
                "windows and the display settings; Automation holds Perform, Auto-Join, " <>
                "aliases, custom menus and timers; P2P comes alive with a peer session; " <>
                "Games holds Retro Games and the Arcade; Account and Admin hold their own; " <>
                "Windows reopens a window of the screen you are on; Navigate reaches the " <>
                "public pages, the documentation and the app; Language switches locale; " <>
                "Help holds the topics, the cheatsheet and About. Disconnect sits alone at " <>
                "the bottom."
            ) <>
            " " <>
            dgettext(
              "help",
              "On a desktop a group flies out beside the menu and hovering another group " <>
                "switches to it. On a phone the menu drills down instead: tapping a group " <>
                "replaces the list with its entries and the group's own row at the top takes " <>
                "you back."
            ),
        see_also: ["ui-desktop", "ui-overview", "keyboard-shortcuts"]
      },
      %{
        id: "ui-conversations",
        title: dgettext("help", "Conversations"),
        category: dgettext("help", "User Interface"),
        keywords: ["conversations", "sidebar", "navigation", "left pane", "channels", "popular"],
        icon: :icon_tab_conversations,
        description:
          dgettext(
            "help",
            "Navigate channels and private conversations using the left-side conversations panel."
          ),
        see_also: ["ui-lists", "ui-tab-bar"]
      },
      %{
        id: "ui-tab-bar",
        title: dgettext("help", "Tab Bar"),
        category: dgettext("help", "User Interface"),
        keywords: ["tab", dgettext("help", "tab bar"), "switch", dgettext("help", "close tab")],
        icon: :icon_tab_channel,
        description:
          dgettext(
            "help",
            "Switch between channels and conversations using the tab bar at the bottom of the chat area."
          )
      },
      %{
        id: "ui-nicklist",
        title: dgettext("help", "User List"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "nicklist",
          dgettext("help", "user list"),
          dgettext("help", "nick list"),
          "users",
          dgettext("help", "conversations users")
        ],
        icon: :icon_tab_nicklist,
        description:
          dgettext(
            "help",
            "View and interact with users in the current channel through the right-side user list."
          ),
        see_also: ["ui-lists"]
      },
      %{
        id: "ui-topic-bar",
        title: dgettext("help", "Topic Bar"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "topic bar"),
          dgettext("help", "channel info"),
          dgettext("help", "modes display")
        ],
        icon: :icon_btn_set_topic,
        description:
          dgettext(
            "help",
            "View the channel topic and active modes in the bar below the tab bar."
          )
      },
      %{
        id: "ui-context-menu",
        title: dgettext("help", "Context Menu"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "context menu"),
          dgettext("help", "right click"),
          "right-click",
          "popup",
          "op",
          "deop",
          "voice",
          "devoice",
          dgettext("help", "channel mute"),
          dgettext("help", "unmute channel"),
          dgettext("help", "moderation")
        ],
        icon: :icon_dialog_custom_menus,
        description:
          dgettext(
            "help",
            "Access user actions and channel operations through right-click context menus."
          )
      },
      %{
        id: "ui-status-tab",
        title: dgettext("help", "Status Tab"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "status",
          dgettext("help", "status tab"),
          dgettext("help", "status window"),
          dgettext("help", "system messages"),
          "observability"
        ],
        icon: :icon_tab_status,
        description:
          dgettext(
            "help",
            "View server messages, connection events, and system notifications in the Status tab."
          )
      },
      %{
        id: "ui-lists",
        title: dgettext("help", "Long Lists & Loading More"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "load more"),
          dgettext("help", "infinite scroll"),
          dgettext("help", "scroll back"),
          dgettext("help", "end of list"),
          dgettext("help", "older messages"),
          "pagination",
          "scrollback"
        ],
        icon: :icon_btn_channel_list,
        description:
          dgettext(
            "help",
            "How long lists load a page at a time as you scroll, how to load the next page " <>
              "from the keyboard, and how to tell the end of a list from a list still loading."
          ),
        see_also: [
          "ui-desktop",
          "ui-nicklist",
          "ui-conversations",
          "ui-listings",
          "keyboard-shortcuts"
        ]
      },
      %{
        id: "ui-message-of-the-day",
        title: dgettext("help", "Message of the Day"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "motd",
          "message of the day",
          "show_motd",
          "Help menu",
          dgettext("help", "server message"),
          dgettext("help", "status tab")
        ],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "Open the current server Message of the Day from Help > Message of the Day."
          ),
        see_also: ["cmd-motd", "cmd-setmotd", "cmd-clearmotd", "feature-special-messages"]
      },
      %{
        id: "ui-toolbar",
        title: dgettext("help", "Toolbar"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "toolbar",
          "buttons",
          "icons",
          "tools",
          "menu",
          "edit",
          "notify",
          "bots",
          "timers",
          dgettext("help", "toolbar options")
        ],
        icon: :icon_group_tools,
        description:
          dgettext(
            "help",
            "Access common features through the menu bar and toolbar options."
          )
      },
      %{
        id: "ui-edit-menu",
        title: dgettext("help", "Edit Menu"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "edit",
          dgettext("help", "edit menu"),
          "clear",
          dgettext("help", "clear window"),
          "copy",
          "clipboard",
          "find",
          "search"
        ],
        icon: :icon_btn_edit,
        description:
          dgettext(
            "help",
            "Clear the current chat window, copy selected chat text, and open Find from the Edit menu."
          )
      },
      %{
        id: "ui-account-dialog",
        title: dgettext("help", "Account Windows"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "account",
          "identity",
          "profile",
          "presence",
          "away",
          "bio",
          "nickserv",
          "login",
          "identify",
          "drop",
          "unregister",
          "ghost",
          "nickname validation",
          "user modes",
          "wallops",
          dgettext("help", "status bar")
        ],
        icon: :icon_status_user,
        description:
          dgettext(
            "help",
            "Manage nickname registration, profile bio, away status, and user modes from the four Account windows."
          )
      },
      %{
        id: "ui-timers-dialog",
        title: dgettext("help", "Timers Dialog"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "timers",
          dgettext("help", "timers dialog"),
          "open_timers_dialog",
          dgettext("help", "Tools menu"),
          dgettext("help", "toolbar options"),
          "/timer",
          dgettext("help", "session-only")
        ],
        icon: :icon_btn_timers,
        description:
          dgettext(
            "help",
            "Add, edit, and stop session-only scheduled commands from Tools > Timers."
          )
      },
      %{
        id: "ui-bot-management",
        title: dgettext("help", "Bot Management Window"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "bot management",
          "open_bot_dialog",
          "bots",
          "bot dialog",
          "bot roster",
          "/bot",
          "automation",
          dgettext("help", "Tools menu")
        ],
        icon: :icon_btn_bot_management,
        description:
          dgettext(
            "help",
            "Manage server bots from Tools > Bot Management, including status, capabilities, channels, custom commands, and events."
          )
      },
      %{
        id: "ui-system-windows",
        title: dgettext("help", "System Windows"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "system",
          "runtime",
          "processes",
          "memory",
          "metrics",
          "oban",
          "jobs",
          "queues",
          "rss health",
          "ets",
          "ports",
          "sockets",
          "allocators",
          "os data",
          "database stats",
          "app info",
          "live log",
          "monitor",
          "diagnostics",
          "beam",
          "vm"
        ],
        icon: :icon_server,
        description:
          dgettext(
            "help",
            "Thirteen admin-only windows that read the running server: its memory, processes, connections, database, Oban jobs and live metrics."
          ),
        see_also: ["ui-listings", "ui-lists", "keyboard-shortcuts"]
      },
      %{
        id: "ui-listings",
        title: dgettext("help", "Listings & Tables"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "table",
          "listing",
          "column",
          "resize",
          "sort",
          "hide column",
          "select row",
          "copy rows",
          dgettext("help", "table"),
          dgettext("help", "column"),
          dgettext("help", "resize"),
          dgettext("help", "sort")
        ],
        icon: :icon_table_grid,
        description:
          dgettext(
            "help",
            "Every window that shows rows shares one table: resize its columns, choose which ones show, order by any of them, and copy what you select."
          )
      },
      %{
        id: "empty-states",
        title: dgettext("help", "Empty States"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "empty",
          dgettext("help", "empty state"),
          "placeholder",
          dgettext("help", "no messages"),
          dgettext("help", "no users"),
          dgettext("help", "no channels"),
          dgettext("help", "no urls")
        ],
        icon: :icon_folder,
        description:
          dgettext(
            "help",
            "Helpful placeholders shown when lists are empty, guiding you on what to do next."
          )
      }
    ]
  end
end
