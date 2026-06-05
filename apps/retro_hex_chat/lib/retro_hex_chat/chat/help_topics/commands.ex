defmodule RetroHexChat.Chat.HelpTopics.Commands do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "commands-overview",
        title: dgettext("help", "IRC Commands Reference"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["commands", "reference", "list", "help", "overview", "slash"],
        icon: :icon_terminal,
        description:
          dgettext(
            "help",
            "Complete reference of all available IRC slash commands with syntax and examples."
          )
      },
      %{
        id: "cmd-alias",
        title: "/alias",
        category: dgettext("help", "Automation"),
        keywords: [
          "alias",
          "shortcut",
          "macro",
          "expansion",
          "abbreviation",
          dgettext("help", "timers dialog")
        ],
        icon: :icon_dialog_alias,
        description:
          dgettext("help", "Create custom command aliases that expand into one or more commands.")
      },
      %{
        id: "cmd-autojoin",
        title: "/autojoin",
        category: dgettext("help", "Automation"),
        keywords: [
          "autojoin",
          dgettext("help", "auto join"),
          "auto-join",
          "channel",
          dgettext("help", "on connect")
        ],
        icon: :icon_tab_autojoin,
        description:
          dgettext(
            "help",
            "Manage the list of channels that are automatically joined on connect."
          )
      },
      %{
        id: "cmd-autorespond",
        title: "/autorespond",
        category: dgettext("help", "Automation"),
        keywords: ["autorespond", "auto", "respond", "trigger", "event", "greet", "timers"],
        icon: :icon_dialog_auto_respond,
        description:
          dgettext(
            "help",
            "Configure automatic responses triggered by events like users joining a channel."
          )
      },
      %{
        id: "cmd-away",
        title: "/away",
        category: dgettext("help", "Users & Identity"),
        keywords: ["away", "afk", "absent", "back", "presence", "account"],
        icon: :icon_clock,
        description:
          dgettext(
            "help",
            "Set or clear your away status to let others know you are not available."
          )
      },
      %{
        id: "cmd-ban",
        title: "/ban",
        category: dgettext("help", "Moderation"),
        keywords: ["ban", "block", "prohibit", dgettext("help", "context menu")],
        icon: :icon_ban,
        description:
          dgettext("help", "Ban a user from a channel by nickname or hostmask pattern.")
      },
      %{
        id: "cmd-bio",
        title: "/bio",
        category: dgettext("help", "Users & Identity"),
        keywords: ["bio", "profile", dgettext("help", "about me"), "description", "account"],
        icon: :icon_status_user,
        description:
          dgettext(
            "help",
            "Set or view a personal biography that appears in whois and hover cards."
          )
      },
      %{
        id: "cmd-call",
        title: "/call",
        category: dgettext("help", "P2P & Calls"),
        keywords: ["call", "audio", "voice", dgettext("help", "voice call"), "p2p"],
        icon: :icon_microphone,
        description:
          dgettext("help", "Start a peer-to-peer audio or video call with another user.")
      },
      %{
        id: "cmd-clear",
        title: "/clear",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["clear", "clean", "wipe", "reset", dgettext("help", "clear window")],
        icon: :icon_trash,
        description:
          dgettext("help", "Clear all messages from the current channel or conversation view.")
      },
      %{
        id: "cmd-cs",
        title: "/cs",
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "cs",
          "chanserv",
          "cs register",
          "cs drop",
          "cs info",
          "sop",
          "aop",
          "vop",
          "registration tab",
          dgettext("help", "channel service"),
          dgettext("help", "register channel")
        ],
        icon: :icon_shield,
        description:
          dgettext("help", "Send commands to ChanServ for channel registration and management."),
        see_also: ["chanserv", "chanserv-register", "chanserv-access", "chanserv-ui"]
      },
      %{
        id: "cmd-game",
        title: "/game",
        category: dgettext("help", "P2P & Calls"),
        keywords: ["game", "play", "p2p", "games", "arcade", "retro"],
        icon: :icon_star,
        description:
          dgettext(
            "help",
            "Start a peer-to-peer game session with another user for retro arcade games."
          )
      },
      %{
        id: "cmd-help",
        title: "/help",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["help", "commands", "usage"],
        icon: :icon_question,
        description: dgettext("help", "Display help information for commands and features.")
      },
      %{
        id: "cmd-ignore",
        title: "/ignore",
        category: dgettext("help", "Contacts & Notify"),
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide"],
        icon: :icon_dialog_ignore,
        description:
          dgettext("help", "Add a user to your ignore list to hide their messages and actions.")
      },
      %{
        id: "cmd-invite",
        title: "/invite",
        category: dgettext("help", "Channels"),
        keywords: [
          "invite",
          dgettext("help", "invite user"),
          dgettext("help", "channel invite"),
          dgettext("help", "invite to channel"),
          dgettext("help", "nicklist menu"),
          dgettext("help", "context menu"),
          "invite-only",
          "auto-join"
        ],
        icon: :icon_dialog_invite,
        description:
          dgettext(
            "help",
            "Invite a user to join a channel, especially useful for invite-only channels."
          )
      },
      %{
        id: "cmd-join",
        title: "/join",
        category: dgettext("help", "Channels"),
        keywords: [
          "join",
          "enter",
          "channel",
          "invite",
          "knock",
          dgettext("help", "request access")
        ],
        icon: :icon_btn_join,
        description:
          dgettext(
            "help",
            "Join a chat channel to read and send messages. Creates the channel if it does not exist."
          )
      },
      %{
        id: "cmd-kick",
        title: "/kick",
        category: dgettext("help", "Moderation"),
        keywords: ["kick", "remove", "eject", dgettext("help", "context menu")],
        icon: :icon_dialog_kick,
        description:
          dgettext(
            "help",
            "Remove a user from a channel. Requires operator or higher privileges."
          )
      },
      %{
        id: "cmd-list",
        title: "/list",
        category: dgettext("help", "Channels"),
        keywords: [
          "list",
          "channels",
          dgettext("help", "channel list"),
          "browse",
          "knock",
          dgettext("help", "request access"),
          "invite-only",
          "+i"
        ],
        icon: :icon_dialog_channel_list,
        description:
          dgettext(
            "help",
            "Browse available channels, join open rooms, or request access to invite-only channels."
          )
      },
      %{
        id: "cmd-me",
        title: "/me",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["me", "action", "action toggle", "emote", "roleplay"],
        icon: :icon_chat,
        description: dgettext("help", "Send an action message that describes what you are doing.")
      },
      %{
        id: "cmd-mode",
        title: "/mode",
        category: dgettext("help", "Channels"),
        keywords: [
          "mode",
          dgettext("help", "channel mode"),
          dgettext("help", "set mode"),
          "operator"
        ],
        icon: :icon_tab_modes,
        description: dgettext("help", "View or change channel modes and user privilege modes.")
      },
      %{
        id: "cmd-msg",
        title: "/msg",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["msg", "message", "private", "whisper", "pm"],
        icon: :icon_send,
        description:
          dgettext(
            "help",
            "Send a private message to another user without opening a conversation tab."
          )
      },
      %{
        id: "cmd-nick",
        title: "/nick",
        category: dgettext("help", "Users & Identity"),
        keywords: ["nick", "nickname", "rename", dgettext("help", "change name"), "account"],
        icon: :icon_dialog_nick,
        description: dgettext("help", "Change your current nickname to a new one.")
      },
      %{
        id: "cmd-notice",
        title: "/notice",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["notice", "send notice", "context menu", "notification", "announce"],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Send a notice message to a user or channel. Notices do not open query windows."
          )
      },
      %{
        id: "cmd-notice-routing",
        title: "/notice_routing",
        category: dgettext("help", "Notifications & Sounds"),
        keywords: ["notice", "routing", "active window"],
        icon: :icon_dialog_notifications,
        description:
          dgettext(
            "help",
            "Show the current notice routing policy. Notices are always routed to the active window."
          )
      },
      %{
        id: "cmd-notify",
        title: "/notify",
        category: dgettext("help", "Contacts & Notify"),
        keywords: ["notify", "buddy", "friend", "watch"],
        icon: :icon_tab_notify,
        description:
          dgettext(
            "help",
            "Add or remove users from your notify list to track when they connect or disconnect."
          )
      },
      %{
        id: "cmd-ns",
        title: "/ns",
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "ns",
          "nickserv",
          "register",
          "identify",
          "ghost",
          "drop",
          "account",
          "login"
        ],
        icon: :icon_lock,
        description:
          dgettext(
            "help",
            "Send commands to NickServ for nickname registration and identification."
          )
      },
      %{
        id: "cmd-p2p",
        title: "/p2p",
        category: dgettext("help", "P2P & Calls"),
        keywords: ["p2p", "peer", "session", "direct", "peer-to-peer"],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "Manage peer-to-peer sessions for direct communication, calls, and file transfers."
          )
      },
      %{
        id: "cmd-part",
        title: "/part",
        category: dgettext("help", "Channels"),
        keywords: ["part", "leave", "exit", "channel"],
        icon: :icon_btn_remove,
        description: dgettext("help", "Leave the current channel with an optional part message.")
      },
      %{
        id: "cmd-perform",
        title: "/perform",
        category: dgettext("help", "Automation"),
        keywords: ["perform", "auto", dgettext("help", "on connect"), "execute", "autorun"],
        icon: :icon_dialog_perform,
        description:
          dgettext(
            "help",
            "Manage commands that run automatically when you connect to the server."
          )
      },
      %{
        id: "cmd-popups",
        title: "/popups",
        category: dgettext("help", "Automation"),
        keywords: [
          "popups",
          "popup",
          dgettext("help", "context menu"),
          dgettext("help", "custom menu"),
          "right-click"
        ],
        icon: :icon_dialog_custom_menus,
        description:
          dgettext(
            "help",
            "Open the custom menus editor to add items to right-click context menus."
          )
      },
      %{
        id: "cmd-query",
        title: "/query",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["query", "pm", "private", dgettext("help", "open conversation")],
        icon: :icon_tab_pm,
        description: dgettext("help", "Open a private conversation tab with another user.")
      },
      %{
        id: "cmd-quit",
        title: "/quit",
        category: dgettext("help", "Chat & Messaging"),
        keywords: ["quit", "disconnect", "exit", "logout"],
        icon: :icon_close,
        description: dgettext("help", "Disconnect from the server with an optional quit message.")
      },
      %{
        id: "cmd-sendfile",
        title: "/sendfile",
        category: dgettext("help", "P2P & Calls"),
        keywords: ["sendfile", "send", "file", "transfer", "p2p"],
        icon: :icon_file_send,
        description:
          dgettext("help", "Send a file to another user through a peer-to-peer connection.")
      },
      %{
        id: "cmd-singleplayer",
        title: "/singleplayer",
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: ["singleplayer", dgettext("help", "single player"), "solo", "arcade", "admin"],
        icon: :icon_game_arcade,
        description:
          dgettext(
            "help",
            "Start a solo arcade session. This command is reserved for administrators."
          )
      },
      %{
        id: "cmd-timer",
        title: "/timer",
        category: dgettext("help", "Automation"),
        keywords: [
          "timer",
          "timers",
          "schedule",
          "delay",
          "repeat",
          "interval",
          "cron",
          dgettext("help", "timers dialog"),
          "open_timers_dialog",
          dgettext("help", "tools menu"),
          dgettext("help", "toolbar options")
        ],
        icon: :icon_btn_timers,
        description:
          dgettext("help", "Schedule commands to run after a delay or at regular intervals.")
      },
      %{
        id: "cmd-topic",
        title: "/topic",
        category: dgettext("help", "Channels"),
        keywords: ["topic", dgettext("help", "channel topic"), dgettext("help", "set topic")],
        icon: :icon_btn_set_topic,
        description: dgettext("help", "View or set the topic for the current channel.")
      },
      %{
        id: "cmd-unban",
        title: "/unban",
        category: dgettext("help", "Moderation"),
        keywords: [
          "unban",
          dgettext("help", "remove ban"),
          dgettext("help", "lift ban"),
          "pardon",
          dgettext("help", "channel central")
        ],
        icon: :icon_accept,
        description: dgettext("help", "Remove a ban from a channel to allow the user to rejoin.")
      },
      %{
        id: "cmd-unignore",
        title: "/unignore",
        category: dgettext("help", "Contacts & Notify"),
        keywords: ["unignore", "unblock", "unmute", "unsilence"],
        icon: :icon_accept,
        description:
          dgettext("help", "Remove a user from your ignore list to see their messages again.")
      },
      %{
        id: "cmd-whois",
        title: "/whois",
        category: dgettext("help", "Users & Identity"),
        keywords: [
          "whois",
          "info",
          dgettext("help", "user info"),
          "lookup",
          "profile",
          "idle",
          "bio",
          dgettext("help", "user lookup"),
          dgettext("help", "result card")
        ],
        icon: :icon_status_user,
        description:
          dgettext(
            "help",
            "Look up detailed information about a user including channels, idle time, and bio."
          )
      },
      %{
        id: "cmd-whowas",
        title: "/whowas",
        category: dgettext("help", "Users & Identity"),
        keywords: [
          "whowas",
          "recently",
          "disconnected",
          dgettext("help", "last seen"),
          "offline",
          dgettext("help", "user lookup"),
          dgettext("help", "result card")
        ],
        icon: :icon_clock,
        description:
          dgettext(
            "help",
            "Look up information about a user who recently disconnected from the server."
          )
      },
      # ── Admin & channel management commands ─────────────────
      %{
        id: "cmd-admin",
        title: "/admin",
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "administration", "server", "manage", "ban", "mute", "role"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Server administration commands for managing users, channels, services, and server settings."
          )
      },
      %{
        id: "cmd-admin-server",
        title: dgettext("help", "/admin server"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "server", "settings", "info", "config", "motd"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "View server information and manage server settings (name, description, registration, limits)."
          ),
        see_also: ["feature-admin-console", "cmd-singleplayer"]
      },
      %{
        id: "cmd-admin-user",
        title: dgettext("help", "/admin user"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "user", "ban", "kick", "mute", "rename", "role", "banlist"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Manage server users: list, info, ban/unban, kick, mute/unmute, rename, set role."
          )
      },
      %{
        id: "cmd-admin-channel",
        title: dgettext("help", "/admin channel"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "channel", "create", "delete", "purge", "banlist"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Manage server channels: list, info, create, delete, purge messages, view bans."
          )
      },
      %{
        id: "cmd-admin-ns",
        title: dgettext("help", "/admin ns"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "nickserv", "drop", "resetpass", "password", "registration"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "NickServ administration: drop nick registrations, view info, reset passwords."
          )
      },
      %{
        id: "cmd-admin-cs",
        title: dgettext("help", "/admin cs"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "chanserv", "drop", "transfer", "access", "founder"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "ChanServ administration: drop registrations, transfer founder, manage access lists."
          )
      },
      %{
        id: "cmd-admin-debug",
        title: dgettext("help", "/admin debug"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "debug", "connections", "processes", "memory", "stats"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Server debug tools: view active connections, channel processes, and BEAM memory usage."
          )
      },
      %{
        id: "cmd-admin-log",
        title: dgettext("help", "/admin log"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "audit", "log", "history", "actions"],
        icon: :icon_shield,
        description:
          dgettext("help", "Query the audit log of admin actions with optional filters."),
        see_also: ["feature-admin-console"]
      },
      %{
        id: "cmd-admin-turn",
        title: dgettext("help", "/admin turn"),
        category: dgettext("help", "Admin & Server"),
        keywords: ["admin", "turn", "stun", "webrtc", "allocations", "relay", "p2p"],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "View TURN server stats (active allocations, relay ports in use) and list active allocations."
          ),
        see_also: ["feature-admin-console", "feature-privacy-mode"]
      },
      %{
        id: "cmd-admin-nuke",
        title: dgettext("help", "/admin nuke"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "nuke",
          "wipe",
          "reset",
          "factory",
          "destroy",
          "clean",
          dgettext("help", "delete all")
        ],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Factory reset — destroys ALL data (users, channels, messages, preferences, bots, P2P sessions) "
          ) <>
            dgettext("help", "except admin roles, audit logs, and server bans. ") <>
            dgettext(
              "help",
              "Run without --confirm for a preview; with --confirm to execute. IRREVERSIBLE."
            )
      },
      %{
        id: "cmd-op",
        title: "/op",
        category: dgettext("help", "Moderation"),
        keywords: [
          "op",
          "operator",
          "promote",
          dgettext("help", "channel operator"),
          dgettext("help", "give op"),
          dgettext("help", "context menu")
        ],
        icon: :icon_tab_modes,
        description: dgettext("help", "Give operator status to a user in the current channel.")
      },
      %{
        id: "cmd-deop",
        title: "/deop",
        category: dgettext("help", "Moderation"),
        keywords: [
          "deop",
          dgettext("help", "remove operator"),
          "demote",
          dgettext("help", "remove op"),
          dgettext("help", "context menu")
        ],
        icon: :icon_tab_modes,
        description:
          dgettext("help", "Remove operator status from a user in the current channel.")
      },
      %{
        id: "cmd-voice",
        title: "/voice",
        category: dgettext("help", "Moderation"),
        keywords: [
          "voice",
          dgettext("help", "give voice"),
          "speak",
          "promote",
          dgettext("help", "context menu")
        ],
        icon: :icon_tab_modes,
        description: dgettext("help", "Give voice status to a user in the current channel.")
      },
      %{
        id: "cmd-devoice",
        title: "/devoice",
        category: dgettext("help", "Moderation"),
        keywords: [
          "devoice",
          dgettext("help", "remove voice"),
          "silence",
          dgettext("help", "context menu")
        ],
        icon: :icon_tab_modes,
        description: dgettext("help", "Remove voice status from a user in the current channel.")
      },
      %{
        id: "cmd-slow",
        title: "/slow",
        category: dgettext("help", "Moderation"),
        keywords: ["slow", "throttle", dgettext("help", "rate limit"), "flood"],
        icon: :icon_clock,
        description:
          dgettext("help", "Enable or disable slow mode (join throttle) in the current channel.")
      },
      %{
        id: "cmd-mute",
        title: "/mute",
        category: dgettext("help", "Moderation"),
        keywords: [
          "mute",
          "silence",
          dgettext("help", "channel mute"),
          "quiet",
          dgettext("help", "mute channel"),
          dgettext("help", "duration"),
          dgettext("help", "context menu")
        ],
        icon: :icon_mute,
        description:
          dgettext(
            "help",
            "Mute a user in the current channel, preventing them from sending messages."
          )
      },
      %{
        id: "cmd-unmute",
        title: "/unmute",
        category: dgettext("help", "Moderation"),
        keywords: [
          "unmute",
          "unsilence",
          dgettext("help", "channel unmute"),
          dgettext("help", "unmute channel"),
          dgettext("help", "context menu")
        ],
        icon: :icon_mute,
        description:
          dgettext(
            "help",
            "Remove a channel mute from a user, allowing them to send messages again."
          )
      },
      %{
        id: "cmd-transfer",
        title: "/transfer",
        category: dgettext("help", "Moderation"),
        keywords: ["transfer", "ownership", dgettext("help", "channel owner"), "founder"],
        icon: :icon_tab_modes,
        description: dgettext("help", "Transfer channel ownership to another user.")
      }
    ]
  end
end
