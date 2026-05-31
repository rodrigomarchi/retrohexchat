defmodule RetroHexChat.Chat.HelpTopics.Commands do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "commands-overview",
        title: gettext("IRC Commands Reference"),
        category: gettext("Chat & Messaging"),
        keywords: ["commands", "reference", "list", "help", "overview", "slash"],
        icon: :icon_terminal,
        description:
          gettext(
            "Complete reference of all available IRC slash commands with syntax and examples."
          )
      },
      %{
        id: "cmd-alias",
        title: "/alias",
        category: gettext("Automation"),
        keywords: ["alias", "shortcut", "macro", "expansion", "abbreviation"],
        icon: :icon_dialog_alias,
        description:
          gettext("Create custom command aliases that expand into one or more commands.")
      },
      %{
        id: "cmd-autojoin",
        title: "/autojoin",
        category: gettext("Automation"),
        keywords: [
          "autojoin",
          gettext("auto join"),
          "auto-join",
          "channel",
          gettext("on connect")
        ],
        icon: :icon_tab_autojoin,
        description:
          gettext("Manage the list of channels that are automatically joined on connect.")
      },
      %{
        id: "cmd-autorespond",
        title: "/autorespond",
        category: gettext("Automation"),
        keywords: ["autorespond", "auto", "respond", "trigger", "event", "greet"],
        icon: :icon_dialog_auto_respond,
        description:
          gettext(
            "Configure automatic responses triggered by events like users joining a channel."
          )
      },
      %{
        id: "cmd-away",
        title: "/away",
        category: gettext("Users & Identity"),
        keywords: ["away", "afk", "absent", "back"],
        icon: :icon_clock,
        description:
          gettext("Set or clear your away status to let others know you are not available.")
      },
      %{
        id: "cmd-ban",
        title: "/ban",
        category: gettext("Moderation"),
        keywords: ["ban", "block", "prohibit"],
        icon: :icon_ban,
        description: gettext("Ban a user from a channel by nickname or hostmask pattern.")
      },
      %{
        id: "cmd-bio",
        title: "/bio",
        category: gettext("Users & Identity"),
        keywords: ["bio", "profile", gettext("about me"), "description"],
        icon: :icon_status_user,
        description:
          gettext("Set or view a personal biography that appears in whois and hover cards.")
      },
      %{
        id: "cmd-call",
        title: "/call",
        category: gettext("P2P & Calls"),
        keywords: ["call", "audio", "voice", gettext("voice call"), "p2p"],
        icon: :icon_microphone,
        description: gettext("Start a peer-to-peer audio or video call with another user.")
      },
      %{
        id: "cmd-clear",
        title: "/clear",
        category: gettext("Chat & Messaging"),
        keywords: ["clear", "clean", "wipe", "reset"],
        icon: :icon_trash,
        description: gettext("Clear all messages from the current channel or conversation view.")
      },
      %{
        id: "cmd-cs",
        title: "/cs",
        category: gettext("Services & Protocols"),
        keywords: ["cs", "chanserv", gettext("channel service"), gettext("register channel")],
        icon: :icon_shield,
        description: gettext("Send commands to ChanServ for channel registration and management.")
      },
      %{
        id: "cmd-game",
        title: "/game",
        category: gettext("P2P & Calls"),
        keywords: ["game", "play", "p2p", "games", "arcade", "retro"],
        icon: :icon_star,
        description:
          gettext("Start a peer-to-peer game session with another user for retro arcade games.")
      },
      %{
        id: "cmd-help",
        title: "/help",
        category: gettext("Chat & Messaging"),
        keywords: ["help", "commands", "usage"],
        icon: :icon_question,
        description: gettext("Display help information for commands and features.")
      },
      %{
        id: "cmd-ignore",
        title: "/ignore",
        category: gettext("Contacts & Notify"),
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide"],
        icon: :icon_dialog_ignore,
        description: gettext("Add a user to your ignore list to hide their messages and actions.")
      },
      %{
        id: "cmd-invite",
        title: "/invite",
        category: gettext("Channels"),
        keywords: [
          "invite",
          gettext("invite user"),
          gettext("channel invite"),
          "invite-only",
          "auto-join"
        ],
        icon: :icon_dialog_invite,
        description:
          gettext("Invite a user to join a channel, especially useful for invite-only channels.")
      },
      %{
        id: "cmd-join",
        title: "/join",
        category: gettext("Channels"),
        keywords: ["join", "enter", "channel"],
        icon: :icon_btn_join,
        description:
          gettext(
            "Join a chat channel to read and send messages. Creates the channel if it does not exist."
          )
      },
      %{
        id: "cmd-kick",
        title: "/kick",
        category: gettext("Moderation"),
        keywords: ["kick", "remove", "eject"],
        icon: :icon_dialog_kick,
        description:
          gettext("Remove a user from a channel. Requires operator or higher privileges.")
      },
      %{
        id: "cmd-list",
        title: "/list",
        category: gettext("Channels"),
        keywords: ["list", "channels", gettext("channel list"), "browse"],
        icon: :icon_dialog_channel_list,
        description: gettext("Browse all available channels with their topics and user counts.")
      },
      %{
        id: "cmd-me",
        title: "/me",
        category: gettext("Chat & Messaging"),
        keywords: ["me", "action", "emote", "roleplay"],
        icon: :icon_chat,
        description: gettext("Send an action message that describes what you are doing.")
      },
      %{
        id: "cmd-mode",
        title: "/mode",
        category: gettext("Channels"),
        keywords: ["mode", gettext("channel mode"), gettext("set mode"), "operator"],
        icon: :icon_tab_modes,
        description: gettext("View or change channel modes and user privilege modes.")
      },
      %{
        id: "cmd-msg",
        title: "/msg",
        category: gettext("Chat & Messaging"),
        keywords: ["msg", "message", "private", "whisper", "pm"],
        icon: :icon_send,
        description:
          gettext("Send a private message to another user without opening a conversation tab.")
      },
      %{
        id: "cmd-nick",
        title: "/nick",
        category: gettext("Users & Identity"),
        keywords: ["nick", "nickname", "rename", gettext("change name")],
        icon: :icon_dialog_nick,
        description: gettext("Change your current nickname to a new one.")
      },
      %{
        id: "cmd-notice",
        title: "/notice",
        category: gettext("Chat & Messaging"),
        keywords: ["notice", "notification", "announce"],
        icon: :icon_megaphone,
        description:
          gettext(
            "Send a notice message to a user or channel. Notices do not open query windows."
          )
      },
      %{
        id: "cmd-notice-routing",
        title: "/notice_routing",
        category: gettext("Notifications & Sounds"),
        keywords: ["notice", "routing", "preference", "setting"],
        icon: :icon_dialog_notifications,
        description:
          gettext(
            "Configure where incoming notices are displayed — active window, status, or source channel."
          )
      },
      %{
        id: "cmd-notify",
        title: "/notify",
        category: gettext("Contacts & Notify"),
        keywords: ["notify", "buddy", "friend", "watch"],
        icon: :icon_tab_notify,
        description:
          gettext(
            "Add or remove users from your notify list to track when they connect or disconnect."
          )
      },
      %{
        id: "cmd-ns",
        title: "/ns",
        category: gettext("Services & Protocols"),
        keywords: ["ns", "nickserv", "register", "identify"],
        icon: :icon_lock,
        description:
          gettext("Send commands to NickServ for nickname registration and identification.")
      },
      %{
        id: "cmd-p2p",
        title: "/p2p",
        category: gettext("P2P & Calls"),
        keywords: ["p2p", "peer", "session", "direct", "peer-to-peer"],
        icon: :icon_p2p,
        description:
          gettext(
            "Manage peer-to-peer sessions for direct communication, calls, and file transfers."
          )
      },
      %{
        id: "cmd-part",
        title: "/part",
        category: gettext("Channels"),
        keywords: ["part", "leave", "exit", "channel"],
        icon: :icon_btn_remove,
        description: gettext("Leave the current channel with an optional part message.")
      },
      %{
        id: "cmd-perform",
        title: "/perform",
        category: gettext("Automation"),
        keywords: ["perform", "auto", gettext("on connect"), "execute", "autorun"],
        icon: :icon_dialog_perform,
        description:
          gettext("Manage commands that run automatically when you connect to the server.")
      },
      %{
        id: "cmd-popups",
        title: "/popups",
        category: gettext("Automation"),
        keywords: [
          "popups",
          "popup",
          gettext("context menu"),
          gettext("custom menu"),
          "right-click"
        ],
        icon: :icon_dialog_custom_menus,
        description:
          gettext("Open the custom menus editor to add items to right-click context menus.")
      },
      %{
        id: "cmd-query",
        title: "/query",
        category: gettext("Chat & Messaging"),
        keywords: ["query", "pm", "private", gettext("open conversation")],
        icon: :icon_tab_pm,
        description: gettext("Open a private conversation tab with another user.")
      },
      %{
        id: "cmd-quit",
        title: "/quit",
        category: gettext("Chat & Messaging"),
        keywords: ["quit", "disconnect", "exit", "logout"],
        icon: :icon_close,
        description: gettext("Disconnect from the server with an optional quit message.")
      },
      %{
        id: "cmd-sendfile",
        title: "/sendfile",
        category: gettext("P2P & Calls"),
        keywords: ["sendfile", "send", "file", "transfer", "p2p"],
        icon: :icon_file_send,
        description: gettext("Send a file to another user through a peer-to-peer connection.")
      },
      %{
        id: "cmd-singleplayer",
        title: "/singleplayer",
        category: gettext("Solo Arcade: FPS"),
        keywords: ["singleplayer", gettext("single player"), "solo", "arcade", "admin"],
        icon: :icon_game_arcade,
        description:
          gettext("Start a solo arcade session. This command is reserved for administrators.")
      },
      %{
        id: "cmd-timer",
        title: "/timer",
        category: gettext("Automation"),
        keywords: ["timer", "schedule", "delay", "repeat", "interval", "cron"],
        icon: :icon_clock,
        description: gettext("Schedule commands to run after a delay or at regular intervals.")
      },
      %{
        id: "cmd-topic",
        title: "/topic",
        category: gettext("Channels"),
        keywords: ["topic", gettext("channel topic"), gettext("set topic")],
        icon: :icon_btn_set_topic,
        description: gettext("View or set the topic for the current channel.")
      },
      %{
        id: "cmd-unban",
        title: "/unban",
        category: gettext("Moderation"),
        keywords: ["unban", gettext("remove ban"), gettext("lift ban"), "pardon"],
        icon: :icon_accept,
        description: gettext("Remove a ban from a channel to allow the user to rejoin.")
      },
      %{
        id: "cmd-unignore",
        title: "/unignore",
        category: gettext("Contacts & Notify"),
        keywords: ["unignore", "unblock", "unmute", "unsilence"],
        icon: :icon_accept,
        description: gettext("Remove a user from your ignore list to see their messages again.")
      },
      %{
        id: "cmd-whois",
        title: "/whois",
        category: gettext("Users & Identity"),
        keywords: ["whois", "info", gettext("user info"), "lookup", "profile", "idle", "bio"],
        icon: :icon_status_user,
        description:
          gettext(
            "Look up detailed information about a user including channels, idle time, and bio."
          )
      },
      %{
        id: "cmd-whowas",
        title: "/whowas",
        category: gettext("Users & Identity"),
        keywords: ["whowas", "recently", "disconnected", gettext("last seen"), "offline"],
        icon: :icon_clock,
        description:
          gettext("Look up information about a user who recently disconnected from the server.")
      },
      # ── Admin & channel management commands ─────────────────
      %{
        id: "cmd-admin",
        title: "/admin",
        category: gettext("Admin & Server"),
        keywords: ["admin", "administration", "server", "manage", "ban", "mute", "role"],
        icon: :icon_shield,
        description:
          gettext(
            "Server administration commands for managing users, channels, services, and server settings."
          )
      },
      %{
        id: "cmd-admin-server",
        title: gettext("/admin server"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "server", "settings", "info", "config", "motd"],
        icon: :icon_shield,
        description:
          gettext(
            "View server information and manage server settings (name, description, registration, limits)."
          )
      },
      %{
        id: "cmd-admin-user",
        title: gettext("/admin user"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "user", "ban", "kick", "mute", "rename", "role", "banlist"],
        icon: :icon_shield,
        description:
          gettext(
            "Manage server users: list, info, ban/unban, kick, mute/unmute, rename, set role."
          )
      },
      %{
        id: "cmd-admin-channel",
        title: gettext("/admin channel"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "channel", "create", "delete", "purge", "banlist"],
        icon: :icon_shield,
        description:
          gettext(
            "Manage server channels: list, info, create, delete, purge messages, view bans."
          )
      },
      %{
        id: "cmd-admin-ns",
        title: gettext("/admin ns"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "nickserv", "drop", "resetpass", "password", "registration"],
        icon: :icon_shield,
        description:
          gettext("NickServ administration: drop nick registrations, view info, reset passwords.")
      },
      %{
        id: "cmd-admin-cs",
        title: gettext("/admin cs"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "chanserv", "drop", "transfer", "access", "founder"],
        icon: :icon_shield,
        description:
          gettext(
            "ChanServ administration: drop registrations, transfer founder, manage access lists."
          )
      },
      %{
        id: "cmd-admin-debug",
        title: gettext("/admin debug"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "debug", "connections", "processes", "memory", "stats"],
        icon: :icon_shield,
        description:
          gettext(
            "Server debug tools: view active connections, channel processes, and BEAM memory usage."
          )
      },
      %{
        id: "cmd-admin-log",
        title: gettext("/admin log"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "audit", "log", "history", "actions"],
        icon: :icon_shield,
        description: gettext("Query the audit log of admin actions with optional filters.")
      },
      %{
        id: "cmd-admin-turn",
        title: gettext("/admin turn"),
        category: gettext("Admin & Server"),
        keywords: ["admin", "turn", "stun", "webrtc", "allocations", "relay", "p2p"],
        icon: :icon_shield,
        description:
          gettext(
            "View TURN server stats (active allocations, relay ports in use) and list active allocations."
          )
      },
      %{
        id: "cmd-admin-nuke",
        title: gettext("/admin nuke"),
        category: gettext("Admin & Server"),
        keywords: [
          "admin",
          "nuke",
          "wipe",
          "reset",
          "factory",
          "destroy",
          "clean",
          gettext("delete all")
        ],
        icon: :icon_shield,
        description:
          gettext(
            "Factory reset — destroys ALL data (users, channels, messages, preferences, bots, P2P sessions) "
          ) <>
            gettext("except admin roles, audit logs, and server bans. ") <>
            gettext(
              "Run without --confirm for a preview; with --confirm to execute. IRREVERSIBLE."
            )
      },
      %{
        id: "cmd-op",
        title: "/op",
        category: gettext("Moderation"),
        keywords: ["op", "operator", "promote", gettext("channel operator")],
        icon: :icon_tab_modes,
        description: gettext("Give operator status to a user in the current channel.")
      },
      %{
        id: "cmd-deop",
        title: "/deop",
        category: gettext("Moderation"),
        keywords: ["deop", gettext("remove operator"), "demote"],
        icon: :icon_tab_modes,
        description: gettext("Remove operator status from a user in the current channel.")
      },
      %{
        id: "cmd-voice",
        title: "/voice",
        category: gettext("Moderation"),
        keywords: ["voice", gettext("give voice"), "speak", "promote"],
        icon: :icon_tab_modes,
        description: gettext("Give voice status to a user in the current channel.")
      },
      %{
        id: "cmd-devoice",
        title: "/devoice",
        category: gettext("Moderation"),
        keywords: ["devoice", gettext("remove voice"), "silence"],
        icon: :icon_tab_modes,
        description: gettext("Remove voice status from a user in the current channel.")
      },
      %{
        id: "cmd-slow",
        title: "/slow",
        category: gettext("Moderation"),
        keywords: ["slow", "throttle", gettext("rate limit"), "flood"],
        icon: :icon_clock,
        description:
          gettext("Enable or disable slow mode (join throttle) in the current channel.")
      },
      %{
        id: "cmd-mute",
        title: "/mute",
        category: gettext("Moderation"),
        keywords: ["mute", "silence", gettext("channel mute"), "quiet"],
        icon: :icon_mute,
        description:
          gettext("Mute a user in the current channel, preventing them from sending messages.")
      },
      %{
        id: "cmd-unmute",
        title: "/unmute",
        category: gettext("Moderation"),
        keywords: ["unmute", "unsilence", gettext("channel unmute")],
        icon: :icon_mute,
        description:
          gettext("Remove a channel mute from a user, allowing them to send messages again.")
      },
      %{
        id: "cmd-transfer",
        title: "/transfer",
        category: gettext("Moderation"),
        keywords: ["transfer", "ownership", gettext("channel owner"), "founder"],
        icon: :icon_tab_modes,
        description: gettext("Transfer channel ownership to another user.")
      }
    ]
  end
end
