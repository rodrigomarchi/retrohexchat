defmodule RetroHexChat.Chat.HelpTopics.Commands do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "commands-overview",
        title: "IRC Commands Reference",
        category: "Commands",
        keywords: ["commands", "reference", "list", "help", "overview", "slash"],
        icon: :icon_terminal,
        description:
          "Complete reference of all available IRC slash commands with syntax and examples."
      },
      %{
        id: "cmd-alias",
        title: "/alias",
        category: "Commands",
        keywords: ["alias", "shortcut", "macro", "expansion", "abbreviation"],
        icon: :icon_dialog_alias,
        description: "Create custom command aliases that expand into one or more commands."
      },
      %{
        id: "cmd-autojoin",
        title: "/autojoin",
        category: "Commands",
        keywords: ["autojoin", "auto join", "auto-join", "channel", "on connect"],
        icon: :icon_tab_autojoin,
        description: "Manage the list of channels that are automatically joined on connect."
      },
      %{
        id: "cmd-autorespond",
        title: "/autorespond",
        category: "Commands",
        keywords: ["autorespond", "auto", "respond", "trigger", "event", "greet"],
        icon: :icon_dialog_auto_respond,
        description:
          "Configure automatic responses triggered by events like users joining a channel."
      },
      %{
        id: "cmd-away",
        title: "/away",
        category: "Commands",
        keywords: ["away", "afk", "absent", "back"],
        icon: :icon_clock,
        description: "Set or clear your away status to let others know you are not available."
      },
      %{
        id: "cmd-ban",
        title: "/ban",
        category: "Commands",
        keywords: ["ban", "block", "prohibit"],
        icon: :icon_ban,
        description: "Ban a user from a channel by nickname or hostmask pattern."
      },
      %{
        id: "cmd-bio",
        title: "/bio",
        category: "Commands",
        keywords: ["bio", "profile", "about me", "description"],
        icon: :icon_status_user,
        description: "Set or view a personal biography that appears in whois and hover cards."
      },
      %{
        id: "cmd-call",
        title: "/call",
        category: "Commands",
        keywords: ["call", "audio", "voice", "voice call", "p2p"],
        icon: :icon_microphone,
        description: "Start a peer-to-peer audio or video call with another user."
      },
      %{
        id: "cmd-clear",
        title: "/clear",
        category: "Commands",
        keywords: ["clear", "clean", "wipe", "reset"],
        icon: :icon_trash,
        description: "Clear all messages from the current channel or conversation view."
      },
      %{
        id: "cmd-cs",
        title: "/cs",
        category: "Commands",
        keywords: ["cs", "chanserv", "channel service", "register channel"],
        icon: :icon_shield,
        description: "Send commands to ChanServ for channel registration and management."
      },
      %{
        id: "cmd-ctcp",
        title: "/ctcp",
        category: "Commands",
        keywords: ["ctcp", "ping", "version", "time", "finger", "client-to-client"],
        icon: :icon_dialog_ctcp,
        description: "Send Client-to-Client Protocol queries like PING, VERSION, and TIME."
      },
      %{
        id: "cmd-help",
        title: "/help",
        category: "Commands",
        keywords: ["help", "commands", "usage"],
        icon: :icon_question,
        description: "Display help information for commands and features."
      },
      %{
        id: "cmd-ignore",
        title: "/ignore",
        category: "Commands",
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide"],
        icon: :icon_dialog_ignore,
        description: "Add a user to your ignore list to hide their messages and actions."
      },
      %{
        id: "cmd-invite",
        title: "/invite",
        category: "Commands",
        keywords: ["invite", "invite user", "channel invite", "invite-only", "auto-join"],
        icon: :icon_dialog_invite,
        description:
          "Invite a user to join a channel, especially useful for invite-only channels."
      },
      %{
        id: "cmd-join",
        title: "/join",
        category: "Commands",
        keywords: ["join", "enter", "channel"],
        icon: :icon_btn_join,
        description:
          "Join a chat channel to read and send messages. Creates the channel if it does not exist."
      },
      %{
        id: "cmd-kick",
        title: "/kick",
        category: "Commands",
        keywords: ["kick", "remove", "eject"],
        icon: :icon_dialog_kick,
        description: "Remove a user from a channel. Requires operator or higher privileges."
      },
      %{
        id: "cmd-list",
        title: "/list",
        category: "Commands",
        keywords: ["list", "channels", "channel list", "browse"],
        icon: :icon_dialog_channel_list,
        description: "Browse all available channels with their topics and user counts."
      },
      %{
        id: "cmd-me",
        title: "/me",
        category: "Commands",
        keywords: ["me", "action", "emote", "roleplay"],
        icon: :icon_chat,
        description: "Send an action message that describes what you are doing."
      },
      %{
        id: "cmd-mode",
        title: "/mode",
        category: "Commands",
        keywords: ["mode", "channel mode", "set mode", "operator"],
        icon: :icon_tab_modes,
        description: "View or change channel modes and user privilege modes."
      },
      %{
        id: "cmd-msg",
        title: "/msg",
        category: "Commands",
        keywords: ["msg", "message", "private", "whisper", "pm"],
        icon: :icon_send,
        description: "Send a private message to another user without opening a conversation tab."
      },
      %{
        id: "cmd-nick",
        title: "/nick",
        category: "Commands",
        keywords: ["nick", "nickname", "rename", "change name"],
        icon: :icon_dialog_nick,
        description: "Change your current nickname to a new one."
      },
      %{
        id: "cmd-notice",
        title: "/notice",
        category: "Commands",
        keywords: ["notice", "notification", "announce"],
        icon: :icon_megaphone,
        description:
          "Send a notice message to a user or channel. Notices do not open query windows."
      },
      %{
        id: "cmd-notice-routing",
        title: "/notice_routing",
        category: "Commands",
        keywords: ["notice", "routing", "preference", "setting"],
        icon: :icon_dialog_notifications,
        description:
          "Configure where incoming notices are displayed — active window, status, or source channel."
      },
      %{
        id: "cmd-notify",
        title: "/notify",
        category: "Commands",
        keywords: ["notify", "buddy", "friend", "watch"],
        icon: :icon_tab_notify,
        description:
          "Add or remove users from your notify list to track when they connect or disconnect."
      },
      %{
        id: "cmd-ns",
        title: "/ns",
        category: "Commands",
        keywords: ["ns", "nickserv", "register", "identify"],
        icon: :icon_lock,
        description: "Send commands to NickServ for nickname registration and identification."
      },
      %{
        id: "cmd-p2p",
        title: "/p2p",
        category: "Commands",
        keywords: ["p2p", "peer", "session", "direct", "peer-to-peer"],
        icon: :icon_p2p,
        description:
          "Manage peer-to-peer sessions for direct communication, calls, and file transfers."
      },
      %{
        id: "cmd-part",
        title: "/part",
        category: "Commands",
        keywords: ["part", "leave", "exit", "channel"],
        icon: :icon_btn_remove,
        description: "Leave the current channel with an optional part message."
      },
      %{
        id: "cmd-perform",
        title: "/perform",
        category: "Commands",
        keywords: ["perform", "auto", "on connect", "execute", "autorun"],
        icon: :icon_dialog_perform,
        description: "Manage commands that run automatically when you connect to the server."
      },
      %{
        id: "cmd-popups",
        title: "/popups",
        category: "Commands",
        keywords: ["popups", "popup", "context menu", "custom menu", "right-click"],
        icon: :icon_dialog_custom_menus,
        description: "Open the custom menus editor to add items to right-click context menus."
      },
      %{
        id: "cmd-query",
        title: "/query",
        category: "Commands",
        keywords: ["query", "pm", "private", "open conversation"],
        icon: :icon_tab_pm,
        description: "Open a private conversation tab with another user."
      },
      %{
        id: "cmd-quit",
        title: "/quit",
        category: "Commands",
        keywords: ["quit", "disconnect", "exit", "logout"],
        icon: :icon_close,
        description: "Disconnect from the server with an optional quit message."
      },
      %{
        id: "cmd-sendfile",
        title: "/sendfile",
        category: "Commands",
        keywords: ["sendfile", "send", "file", "transfer", "p2p"],
        icon: :icon_file_send,
        description: "Send a file to another user through a peer-to-peer connection."
      },
      %{
        id: "cmd-timer",
        title: "/timer",
        category: "Commands",
        keywords: ["timer", "schedule", "delay", "repeat", "interval", "cron"],
        icon: :icon_clock,
        description: "Schedule commands to run after a delay or at regular intervals."
      },
      %{
        id: "cmd-topic",
        title: "/topic",
        category: "Commands",
        keywords: ["topic", "channel topic", "set topic"],
        icon: :icon_btn_set_topic,
        description: "View or set the topic for the current channel."
      },
      %{
        id: "cmd-unban",
        title: "/unban",
        category: "Commands",
        keywords: ["unban", "remove ban", "lift ban", "pardon"],
        icon: :icon_accept,
        description: "Remove a ban from a channel to allow the user to rejoin."
      },
      %{
        id: "cmd-unignore",
        title: "/unignore",
        category: "Commands",
        keywords: ["unignore", "unblock", "unmute", "unsilence"],
        icon: :icon_accept,
        description: "Remove a user from your ignore list to see their messages again."
      },
      %{
        id: "cmd-whois",
        title: "/whois",
        category: "Commands",
        keywords: ["whois", "info", "user info", "lookup", "profile", "idle", "bio"],
        icon: :icon_status_user,
        description:
          "Look up detailed information about a user including channels, idle time, and bio."
      },
      %{
        id: "cmd-whowas",
        title: "/whowas",
        category: "Commands",
        keywords: ["whowas", "recently", "disconnected", "last seen", "offline"],
        icon: :icon_clock,
        description: "Look up information about a user who recently disconnected from the server."
      },
      # ── Admin & channel management commands ─────────────────
      %{
        id: "cmd-admin",
        title: "/admin",
        category: "Commands",
        keywords: ["admin", "administration", "server", "manage", "ban", "mute", "role"],
        icon: :icon_shield,
        description:
          "Server administration commands for managing users, channels, services, and server settings."
      },
      %{
        id: "cmd-admin-server",
        title: "/admin server",
        category: "Commands",
        keywords: ["admin", "server", "settings", "info", "config", "motd"],
        icon: :icon_shield,
        description:
          "View server information and manage server settings (name, description, registration, limits)."
      },
      %{
        id: "cmd-admin-user",
        title: "/admin user",
        category: "Commands",
        keywords: ["admin", "user", "ban", "kick", "mute", "rename", "role", "banlist"],
        icon: :icon_shield,
        description:
          "Manage server users: list, info, ban/unban, kick, mute/unmute, rename, set role."
      },
      %{
        id: "cmd-admin-channel",
        title: "/admin channel",
        category: "Commands",
        keywords: ["admin", "channel", "create", "delete", "purge", "banlist"],
        icon: :icon_shield,
        description:
          "Manage server channels: list, info, create, delete, purge messages, view bans."
      },
      %{
        id: "cmd-admin-ns",
        title: "/admin ns",
        category: "Commands",
        keywords: ["admin", "nickserv", "drop", "resetpass", "password", "registration"],
        icon: :icon_shield,
        description:
          "NickServ administration: drop nick registrations, view info, reset passwords."
      },
      %{
        id: "cmd-admin-cs",
        title: "/admin cs",
        category: "Commands",
        keywords: ["admin", "chanserv", "drop", "transfer", "access", "founder"],
        icon: :icon_shield,
        description:
          "ChanServ administration: drop registrations, transfer founder, manage access lists."
      },
      %{
        id: "cmd-admin-debug",
        title: "/admin debug",
        category: "Commands",
        keywords: ["admin", "debug", "connections", "processes", "memory", "stats"],
        icon: :icon_shield,
        description:
          "Server debug tools: view active connections, channel processes, and BEAM memory usage."
      },
      %{
        id: "cmd-admin-log",
        title: "/admin log",
        category: "Commands",
        keywords: ["admin", "audit", "log", "history", "actions"],
        icon: :icon_shield,
        description: "Query the audit log of admin actions with optional filters."
      },
      %{
        id: "cmd-op",
        title: "/op",
        category: "Commands",
        keywords: ["op", "operator", "promote", "channel operator"],
        icon: :icon_tab_modes,
        description: "Give operator status to a user in the current channel."
      },
      %{
        id: "cmd-deop",
        title: "/deop",
        category: "Commands",
        keywords: ["deop", "remove operator", "demote"],
        icon: :icon_tab_modes,
        description: "Remove operator status from a user in the current channel."
      },
      %{
        id: "cmd-voice",
        title: "/voice",
        category: "Commands",
        keywords: ["voice", "give voice", "speak", "promote"],
        icon: :icon_tab_modes,
        description: "Give voice status to a user in the current channel."
      },
      %{
        id: "cmd-devoice",
        title: "/devoice",
        category: "Commands",
        keywords: ["devoice", "remove voice", "silence"],
        icon: :icon_tab_modes,
        description: "Remove voice status from a user in the current channel."
      },
      %{
        id: "cmd-slow",
        title: "/slow",
        category: "Commands",
        keywords: ["slow", "throttle", "rate limit", "flood"],
        icon: :icon_clock,
        description: "Enable or disable slow mode (join throttle) in the current channel."
      },
      %{
        id: "cmd-mute",
        title: "/mute",
        category: "Commands",
        keywords: ["mute", "silence", "channel mute", "quiet"],
        icon: :icon_mute,
        description: "Mute a user in the current channel, preventing them from sending messages."
      },
      %{
        id: "cmd-unmute",
        title: "/unmute",
        category: "Commands",
        keywords: ["unmute", "unsilence", "channel unmute"],
        icon: :icon_mute,
        description: "Remove a channel mute from a user, allowing them to send messages again."
      },
      %{
        id: "cmd-transfer",
        title: "/transfer",
        category: "Commands",
        keywords: ["transfer", "ownership", "channel owner", "founder"],
        icon: :icon_tab_modes,
        description: "Transfer channel ownership to another user."
      }
    ]
  end
end
