defmodule RetroHexChat.Chat.HelpTopics.Features do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "feature-notify-list",
        title: gettext("Notify List (Buddy List)"),
        category: gettext("Contacts & Notify"),
        keywords: ["notify", "buddy", gettext("friend list"), "online", "offline", "track"],
        icon: :icon_tab_notify,
        description:
          gettext("Track when specific users connect or disconnect with the notify list.")
      },
      %{
        id: "feature-address-book",
        title: gettext("Address Book"),
        category: gettext("Contacts & Notify"),
        keywords: [
          gettext("address book"),
          "contacts",
          gettext("nick colors"),
          gettext("color override")
        ],
        icon: :icon_dialog_address_book,
        description:
          gettext("Manage contacts, assign custom nick colors, and organize your notify list.")
      },
      %{
        id: "feature-highlight-words",
        title: gettext("Highlight Words"),
        category: gettext("Contacts & Notify"),
        keywords: ["highlight", "mention", "alert", "notification", "flash"],
        icon: :icon_dialog_highlight,
        description:
          gettext("Configure words that trigger visual and audio alerts when mentioned in chat.")
      },
      %{
        id: "feature-url-catcher",
        title: gettext("URL Catcher"),
        category: gettext("Chat Display"),
        keywords: ["url", "link", "catcher", "preview", "web"],
        icon: :icon_dialog_url,
        description:
          gettext("View and manage URLs shared across all channels with link previews.")
      },
      %{
        id: "feature-ignore-list",
        title: gettext("Ignore List"),
        category: gettext("Contacts & Notify"),
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide", "unignore"],
        icon: :icon_dialog_ignore,
        description:
          gettext("Manage your ignore list to hide messages and actions from specific users.")
      },
      %{
        id: "feature-channel-central",
        title: gettext("Channel Central"),
        category: gettext("Channel Settings"),
        keywords: [
          gettext("channel central"),
          gettext("channel info"),
          gettext("channel settings"),
          "modes",
          "bans",
          gettext("ban exceptions"),
          gettext("invite exceptions"),
          "tabs"
        ],
        icon: :icon_dialog_channel_central,
        description:
          gettext("View and manage channel settings, bans, exceptions, and modes in one dialog.")
      },
      %{
        id: "feature-ban-exceptions",
        title: gettext("Ban Exceptions (+e)"),
        category: gettext("Channel Settings"),
        keywords: [
          gettext("ban exception"),
          gettext("ban exempt"),
          "exception",
          "exempt",
          gettext("bypass ban"),
          "+e"
        ],
        icon: :icon_tab_exceptions,
        description:
          gettext("Allow specific users to bypass channel bans using ban exception masks.")
      },
      %{
        id: "feature-invite-exceptions",
        title: gettext("Invite Exceptions (+I)"),
        category: gettext("Channel Settings"),
        keywords: [
          gettext("invite exception"),
          gettext("invite exempt"),
          gettext("invite bypass"),
          "+I",
          gettext("invite-only bypass")
        ],
        icon: :icon_tab_exceptions,
        description:
          gettext(
            "Allow specific users to join invite-only channels without an explicit invitation."
          )
      },
      %{
        id: "feature-channel-invites",
        title: gettext("Channel Invites"),
        category: gettext("Channel Settings"),
        keywords: [
          "invite",
          gettext("channel invite"),
          gettext("invite dialog"),
          gettext("auto-join on invite"),
          gettext("invite expiration"),
          "invite-only"
        ],
        icon: :icon_dialog_invite,
        description:
          gettext("Receive and manage channel invitations with optional auto-join on invite.")
      },
      %{
        id: "feature-search",
        title: gettext("Search"),
        category: gettext("Channel Settings"),
        keywords: [
          "search",
          "find",
          "ctrl+f",
          gettext("text search"),
          "highlight",
          "regex",
          gettext("case sensitive"),
          gettext("history search")
        ],
        icon: :icon_btn_search,
        description:
          gettext(
            "Find text in the current channel using search with regex and case-sensitive options."
          )
      },
      %{
        id: "feature-perform",
        title: gettext("Perform / Auto-Commands"),
        category: gettext("Automation"),
        keywords: [
          "perform",
          "auto-commands",
          gettext("auto commands"),
          gettext("on connect"),
          "autojoin",
          "auto-join",
          gettext("perform list"),
          gettext("auto execute")
        ],
        icon: :icon_dialog_perform,
        description:
          gettext("Configure commands and channels that execute automatically when you connect.")
      },
      %{
        id: "feature-auto-reconnect",
        title: gettext("Auto-Reconnect"),
        category: gettext("Connection"),
        keywords: [
          "reconnect",
          "auto-reconnect",
          gettext("auto reconnect"),
          "disconnect",
          gettext("connection lost"),
          "retry",
          "backoff"
        ],
        icon: :icon_retry,
        description:
          gettext(
            "Automatically reconnect to the server when the connection is lost with exponential backoff."
          )
      },
      %{
        id: "feature-notices",
        title: gettext("Notices"),
        category: gettext("Notifications & Sounds"),
        keywords: ["notice", "notification", "announce", gettext("lightweight message")],
        icon: :icon_megaphone,
        description:
          gettext("Lightweight messages used for server announcements and automated responses.")
      },
      %{
        id: "feature-flood-protection",
        title: gettext("Flood Protection"),
        category: gettext("Notifications & Sounds"),
        keywords: [
          "flood",
          "spam",
          "duplicate",
          "auto-ignore",
          "protection",
          "anti-spam",
          gettext("rate limit")
        ],
        icon: :icon_dialog_flood,
        description:
          gettext(
            "Protect against message flooding with rate limiting and automatic ignore rules."
          )
      },
      %{
        id: "feature-sounds",
        title: gettext("Sounds"),
        category: gettext("Notifications & Sounds"),
        keywords: [
          "sounds",
          "sound",
          "audio",
          "beep",
          "ding",
          "alert",
          "chime",
          gettext("notification sound")
        ],
        icon: :icon_dialog_sound,
        description:
          gettext(
            "Configure sound notifications for events like mentions, private messages, and joins."
          )
      },
      %{
        id: "feature-mute",
        title: gettext("Mute"),
        category: gettext("Notifications & Sounds"),
        keywords: ["mute", "unmute", "silence", gettext("sound off"), "quiet"],
        icon: :icon_mute,
        description: gettext("Mute all sounds globally or per-channel to silence notifications.")
      },
      %{
        id: "feature-typing-indicator",
        title: gettext("Typing Indicator"),
        category: gettext("Chat & Messaging"),
        keywords: ["typing", "indicator", gettext("is typing"), gettext("pm typing")],
        icon: :icon_chat,
        description: gettext("See when someone is typing a message in a private conversation.")
      },
      %{
        id: "feature-aliases",
        title: gettext("Aliases"),
        category: gettext("Automation"),
        keywords: ["alias", "aliases", "shortcut", "macro", "expansion", "scripting"],
        icon: :icon_dialog_alias,
        description:
          gettext(
            "Create custom command shortcuts that expand into one or more commands with variable support."
          )
      },
      %{
        id: "feature-timers",
        title: gettext("Timers"),
        category: gettext("Automation"),
        keywords: ["timer", "timers", "schedule", "delay", "repeat", "interval"],
        icon: :icon_clock,
        description:
          gettext("Schedule commands to execute after a delay or repeat at regular intervals.")
      },
      %{
        id: "feature-custom-menus",
        title: gettext("Custom Menus"),
        category: gettext("Automation"),
        keywords: [
          gettext("custom menu"),
          "popup",
          gettext("context menu"),
          "right-click",
          gettext("nicklist menu"),
          gettext("channel menu"),
          gettext("chat menu")
        ],
        icon: :icon_dialog_custom_menus,
        description:
          gettext("Add custom items to right-click context menus for quick access to commands.")
      },
      %{
        id: "feature-display-settings",
        title: gettext("Display Settings"),
        category: gettext("Settings & Preferences"),
        keywords: [
          "display",
          "toolbar",
          "conversations",
          "switchbar",
          gettext("status bar"),
          gettext("compact mode"),
          gettext("line shading")
        ],
        icon: :icon_tab_display,
        description:
          gettext(
            "Customize which interface elements are visible and toggle compact display mode."
          )
      },
      %{
        id: "feature-key-bindings",
        title: gettext("Key Bindings"),
        category: gettext("Settings & Preferences"),
        keywords: [
          gettext("key bindings"),
          "keybindings",
          gettext("keyboard shortcuts"),
          gettext("customize shortcuts"),
          "rebind",
          "shortcut"
        ],
        icon: :icon_dialog_cheatsheet,
        description:
          gettext("Customize keyboard shortcuts by rebinding keys to different actions.")
      },
      %{
        id: "feature-autorespond",
        title: gettext("Auto-Respond"),
        category: gettext("Automation"),
        keywords: [
          "auto-respond",
          "autorespond",
          gettext("auto greet"),
          "trigger",
          "event",
          gettext("join greet"),
          "welcome"
        ],
        icon: :icon_dialog_auto_respond,
        description:
          gettext(
            "Configure automatic responses triggered by events like user joins or keyword matches."
          )
      },
      %{
        id: "feature-interactive-elements",
        title: gettext("Interactive Chat Elements"),
        category: gettext("Chat Display"),
        keywords: [
          "interactive",
          "clickable",
          "hover",
          "tooltip",
          gettext("hover card"),
          gettext("channel click"),
          gettext("nick click"),
          gettext("url hover"),
          gettext("link preview")
        ],
        icon: :icon_community,
        description:
          gettext("Clickable nicknames, channels, and URLs with hover cards and link previews.")
      },
      %{
        id: "feature-nick-alignment",
        title: gettext("Nick Column Alignment"),
        category: gettext("Chat Display"),
        keywords: ["nick", "alignment", "column", "grid", "layout", "readability"],
        icon: :icon_tab_nicklist,
        description:
          gettext("Align nicknames in a fixed-width column for improved chat readability.")
      },
      %{
        id: "feature-copy",
        title: gettext("Right-Click Copy"),
        category: gettext("Chat Display"),
        keywords: ["copy", "clipboard", "right-click", gettext("context menu"), "select", "text"],
        icon: :icon_copy,
        description:
          gettext("Copy message text to the clipboard using the right-click context menu.")
      },
      %{
        id: "feature-paste-dialog",
        title: gettext("Multi-Line Paste Dialog"),
        category: gettext("Chat Input"),
        keywords: ["paste", "multiline", "flood", "confirmation", "send"],
        icon: :icon_dialog_paste,
        description:
          gettext(
            "Review and confirm multi-line pastes before sending to prevent accidental flooding."
          )
      },
      %{
        id: "feature-char-counter",
        title: gettext("Character Counter"),
        category: gettext("Chat Input"),
        keywords: ["character", "counter", "limit", "length", "input"],
        icon: :icon_notepad,
        description:
          gettext("See how many characters remain before reaching the message length limit.")
      },
      %{
        id: "feature-quit-message",
        title: gettext("Quit Messages"),
        category: gettext("Users & Identity"),
        keywords: ["quit", "disconnect", "message", "goodbye", "leaving"],
        icon: :icon_close,
        description:
          gettext(
            "Customize the message displayed to others when you disconnect from the server."
          )
      },
      %{
        id: "feature-away-reply",
        title: gettext("Away Auto-Reply"),
        category: gettext("Users & Identity"),
        keywords: ["away", "auto-reply", "automatic", "reply", "pm", "message"],
        icon: :icon_clock,
        description:
          gettext("Automatically reply to private messages when you are marked as away.")
      },
      %{
        id: "feature-emoji",
        title: gettext("Emoji Picker"),
        category: gettext("Chat Input"),
        keywords: ["emoji", "smiley", "picker", "unicode", "emoticon"],
        icon: :icon_heart,
        description: gettext("Browse and insert emoji into your messages using the emoji picker.")
      },
      %{
        id: "feature-timestamp-format",
        title: gettext("Timestamp Configuration"),
        category: gettext("Chat Display"),
        keywords: ["timestamp", "time", "format", "clock", "date"],
        icon: :icon_clock,
        description: gettext("Customize how timestamps are displayed next to messages.")
      },
      %{
        id: "feature-autocomplete",
        title: gettext("Autocomplete"),
        category: gettext("Chat Input"),
        keywords: [
          "autocomplete",
          "auto-complete",
          gettext("tab complete"),
          gettext("command palette"),
          gettext("fuzzy search"),
          gettext("nick completion"),
          gettext("channel completion")
        ],
        icon: :icon_btn_search,
        description:
          gettext("Tab-complete nicknames, commands, channels, and emoji with fuzzy matching.")
      },
      %{
        id: "feature-command-syntax-tooltip",
        title: gettext("Command Syntax Tooltip"),
        category: gettext("Chat Input"),
        keywords: [
          "syntax",
          "tooltip",
          gettext("command help"),
          "parameter",
          "hint",
          "inline help",
          "mode helper"
        ],
        icon: :icon_code,
        description: gettext("See command syntax and parameter hints as you type slash commands.")
      },
      %{
        id: "feature-smart-input",
        title: gettext("Smart Input"),
        category: gettext("Chat Input"),
        keywords: [
          gettext("smart input"),
          "textarea",
          "multiline",
          "placeholder",
          "expand",
          gettext("input box")
        ],
        icon: :icon_terminal,
        description:
          gettext("Auto-expanding input box with multi-line support and contextual placeholders.")
      },
      %{
        id: "feature-cheatsheet",
        title: gettext("Shortcut Cheatsheet"),
        category: gettext("User Interface"),
        keywords: [
          "cheatsheet",
          gettext("cheat sheet"),
          gettext("shortcut list"),
          gettext("keyboard reference"),
          gettext("quick reference")
        ],
        icon: :icon_dialog_cheatsheet,
        description:
          gettext("Quick reference overlay showing all keyboard shortcuts, opened with Ctrl+/.")
      },
      %{
        id: "feature-context-menus",
        title: gettext("Context Menus"),
        category: gettext("Settings & Preferences"),
        keywords: [
          gettext("context menu"),
          "right-click",
          gettext("right click"),
          "popup menu",
          gettext("nick menu"),
          gettext("url menu"),
          gettext("channel menu"),
          "message menu",
          gettext("conversations menu"),
          gettext("mute channel")
        ],
        icon: :icon_dialog_custom_menus,
        description:
          gettext(
            "Right-click context menus for nicknames, messages, URLs, channels, and conversations."
          )
      },
      %{
        id: "feature-enhanced-history",
        title: gettext("Enhanced History"),
        category: gettext("Chat Input"),
        keywords: [
          "history",
          "ctrl+up",
          "ctrl+down",
          "ctrl+r",
          gettext("reverse search"),
          "draft",
          "persistence",
          "localStorage"
        ],
        icon: :icon_backup,
        description:
          gettext(
            "Navigate command history with Ctrl+Up/Down and search with Ctrl+R. Drafts persist per channel."
          )
      },
      %{
        id: "feature-contextual-tips",
        title: gettext("Contextual Tips"),
        category: gettext("Chat Display"),
        keywords: [
          "tips",
          "contextual",
          "toast",
          "hint",
          gettext("progressive disclosure")
        ],
        icon: :icon_lightbulb,
        description:
          gettext(
            "Helpful tips that appear contextually to guide you through features as you use them."
          )
      },
      %{
        id: "feature-unread-indicators",
        title: gettext("Unread Indicators"),
        category: gettext("Chat Display"),
        keywords: [
          "unread",
          "badge",
          "indicator",
          "conversations",
          "count",
          "mention",
          "highlight",
          "muted",
          "disconnected"
        ],
        icon: :icon_document_alert,
        description:
          gettext(
            "Unread message badges on tabs and conversations showing message and mention counts."
          )
      },
      %{
        id: "feature-kick-notifications",
        title: gettext("Kick Notifications"),
        category: gettext("Chat Display"),
        keywords: ["kick", "kicked", "expelled", "dialog", "notification"],
        icon: :icon_dialog_kick,
        description:
          gettext(
            "Dialog notification when you are kicked from a channel with the reason and rejoin option."
          )
      },
      %{
        id: "feature-copy-feedback",
        title: gettext("Copy Feedback"),
        category: gettext("Chat Display"),
        keywords: [
          "copy",
          "clipboard",
          "toast",
          "copied",
          "settings",
          "saved"
        ],
        icon: :icon_copy,
        description:
          gettext("Visual toast confirmation when text or settings are copied to the clipboard.")
      },
      %{
        id: "feature-status-bar",
        title: gettext("Status Bar"),
        category: gettext("User Interface"),
        keywords: [
          gettext("status bar"),
          "lag",
          "clock",
          "connection",
          "mute",
          gettext("channel info")
        ],
        icon: :icon_tab_status,
        description:
          gettext(
            "Bottom bar showing connection status, lag indicator, clock, and channel information."
          )
      },
      %{
        id: "feature-lag-indicator",
        title: gettext("Lag Indicator"),
        category: gettext("Connection"),
        keywords: [
          "lag",
          "latency",
          "ping",
          "pong",
          "network",
          "delay",
          "timeout"
        ],
        icon: :icon_status_signal,
        description:
          gettext(
            "Real-time latency indicator in the status bar showing network delay to the server."
          )
      },
      %{
        id: "feature-connection-states",
        title: gettext("Connection States"),
        category: gettext("Connection"),
        keywords: [
          "connection",
          "connected",
          "disconnected",
          "reconnecting",
          "connecting",
          "banner",
          "overlay"
        ],
        icon: :icon_websocket,
        description:
          gettext(
            "Visual indicators for connection status including banners, overlays, and status bar changes."
          )
      },
      %{
        id: "feature-message-reply",
        title: gettext("Message Reply"),
        category: gettext("Chat & Messaging"),
        keywords: [
          "reply",
          "quote",
          "respond",
          "responder",
          gettext("reply to"),
          gettext("quote message")
        ],
        icon: :icon_chat,
        description:
          gettext("Reply to specific messages with quoted context for threaded conversations.")
      },
      %{
        id: "feature-message-edit",
        title: gettext("Message Edit"),
        category: gettext("Chat & Messaging"),
        keywords: [
          "edit",
          "edited",
          "modify",
          "correct",
          "typo",
          gettext("fix message")
        ],
        icon: :icon_btn_edit,
        description: gettext("Edit your recently sent messages to fix typos or update content.")
      },
      %{
        id: "feature-message-delete",
        title: gettext("Message Delete"),
        category: gettext("Chat & Messaging"),
        keywords: [
          "delete",
          "remove",
          gettext("message removed"),
          gettext("soft delete")
        ],
        icon: :icon_dialog_delete,
        description:
          gettext("Delete your own messages with a soft-delete that shows a removal notice.")
      },
      %{
        id: "feature-audio-call",
        title: gettext("Audio Call"),
        category: gettext("P2P & Calls"),
        keywords: [
          "audio",
          "call",
          "voice",
          "mute",
          "p2p"
        ],
        icon: :icon_microphone,
        description:
          gettext("Make peer-to-peer audio calls with mute controls and quality indicators.")
      },
      %{
        id: "feature-video-call",
        title: gettext("Video Call"),
        category: gettext("P2P & Calls"),
        keywords: [
          "video",
          "call",
          "camera",
          "pip",
          "picture-in-picture",
          "p2p"
        ],
        icon: :icon_camera,
        description:
          gettext(
            "Make video calls with camera controls, picture-in-picture, and quality settings."
          )
      },
      %{
        id: "feature-media-devices",
        title: gettext("Media Devices"),
        category: gettext("P2P & Calls"),
        keywords: [
          "device",
          "microphone",
          "camera",
          "speaker",
          "fallback"
        ],
        icon: :icon_devices,
        description:
          gettext("Select and switch between microphones, cameras, and speakers during calls.")
      },
      %{
        id: "feature-call-quality",
        title: gettext("Call Quality"),
        category: gettext("P2P & Calls"),
        keywords: [
          "quality",
          "bitrate",
          "preset",
          "indicator",
          "bars"
        ],
        icon: :icon_quality_high,
        description:
          gettext(
            "Monitor and adjust call quality with bitrate presets and real-time quality indicators."
          )
      },
      %{
        id: "feature-p2p-sessions",
        title: gettext("P2P Sessions"),
        category: gettext("P2P & Calls"),
        keywords: [
          "p2p",
          "peer",
          "session",
          "lobby",
          "consent",
          "bilateral",
          "invite"
        ],
        icon: :icon_p2p,
        description:
          gettext(
            "Establish peer-to-peer sessions with bilateral consent for calls and file transfers."
          )
      },
      %{
        id: "feature-connection-diagram",
        title: gettext("Connection Diagram"),
        category: gettext("P2P & Calls"),
        keywords: [
          "connection",
          "diagram",
          "p2p",
          "webrtc",
          "status",
          "animation",
          "whois",
          "peer",
          "info",
          "browser"
        ],
        icon: :icon_p2p,
        description:
          gettext(
            "Animated visual diagram showing the bilateral P2P link with real-time status and peer info."
          )
      },
      %{
        id: "feature-file-transfer",
        title: gettext("File Transfer"),
        category: gettext("P2P & Calls"),
        keywords: [
          "file",
          "transfer",
          "sendfile",
          "drag",
          "drop",
          "hash",
          "p2p"
        ],
        icon: :icon_file_send,
        description:
          gettext(
            "Send files directly to other users via peer-to-peer with drag-and-drop support."
          )
      },
      %{
        id: "feature-privacy-settings",
        title: gettext("Privacy Settings"),
        category: gettext("Settings & Preferences"),
        keywords: [
          "privacy",
          "turn",
          "relay",
          "ip",
          "hide",
          "private mode"
        ],
        icon: :icon_privacy,
        description:
          gettext(
            "Enable TURN-only relay mode to hide your IP address during peer-to-peer connections."
          )
      },
      %{
        id: "feature-pm-persistence",
        title: gettext("PM Persistence"),
        category: gettext("Chat & Messaging"),
        keywords: [
          "pm",
          "private message",
          "persistence",
          "restore",
          "conversation",
          "reconnect",
          "auto-open",
          "recency"
        ],
        icon: :icon_p2p,
        description:
          gettext(
            "Private message conversations are restored automatically on reconnect, ordered by recency."
          )
      },
      %{
        id: "feature-auto-join-channels",
        title: gettext("Auto-Join Channels"),
        category: gettext("Channel Settings"),
        keywords: [
          "auto-join",
          "autojoin",
          "remember",
          "channel",
          "persistence",
          "rejoin",
          "reconnect"
        ],
        icon: :icon_tab_autojoin,
        description:
          gettext("Channels are automatically remembered and rejoined when you reconnect.")
      },
      %{
        id: "feature-single-session",
        title: gettext("Single Session"),
        category: gettext("Users & Identity"),
        keywords: [
          gettext("single session"),
          "session",
          "duplicate",
          gettext("multiple tabs"),
          gettext("another window"),
          "disconnect",
          "expired",
          gettext("one session")
        ],
        icon: :icon_lock,
        description:
          gettext("Only one active session per nickname is allowed to prevent conflicts.")
      },
      %{
        id: "feature-nick-expiry",
        title: gettext("Nick Expiration"),
        category: gettext("Users & Identity"),
        keywords: [
          gettext("nick expiry"),
          "expiration",
          "inactive",
          "purge",
          gettext("7 days"),
          "automatic",
          "freed",
          "released"
        ],
        icon: :icon_clock,
        description:
          gettext(
            "Registered nicknames expire after 7 days of inactivity and become available again."
          )
      },
      %{
        id: "feature-admin-console",
        title: gettext("Admin Console"),
        category: gettext("Admin & Server"),
        keywords: [
          "admin",
          "console",
          "batch",
          "script",
          "commands",
          "bulk",
          "configure",
          "setup"
        ],
        icon: :icon_terminal,
        description:
          gettext(
            "Execute multiple commands at once by pasting them into the Admin Console (admin only)."
          )
      },
      %{
        id: "feature-p2p-games",
        title: gettext("P2P Games"),
        category: gettext("P2P Games: Action"),
        keywords: [
          "game",
          "games",
          "p2p",
          "arcade",
          "retro",
          "multiplayer",
          "pong",
          "lobby",
          "play"
        ],
        icon: :icon_game_generic,
        description:
          gettext(
            "Play retro arcade games directly with other users via peer-to-peer WebRTC connections."
          ),
        see_also: [
          "feature-hex-pong",
          "feature-light-trails",
          "feature-block-breakers",
          "feature-star-duel",
          "feature-gravity-well",
          "feature-debris-field",
          "feature-hex-warlords",
          "feature-pixel-tanks",
          "feature-hex-raid",
          "feature-hex-raid-pacifist",
          "feature-hex-raid-blitz",
          "feature-hex-boxing",
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-hex-invaders",
          "feature-hex-invaders-coop",
          "feature-hex-invaders-blitz",
          "feature-hex-enduro",
          "feature-hex-enduro-night",
          "feature-hex-enduro-sprint",
          "feature-hex-tennis",
          "feature-hex-tennis-quick",
          "feature-hex-tennis-sudden",
          "feature-hex-skiing",
          "feature-hex-skiing-escape",
          "feature-hex-skiing-clean",
          "feature-hex-frost",
          "feature-hex-frost-blizzard",
          "feature-hex-frost-peaceful",
          "feature-hex-hockey",
          "feature-hex-hockey-blitz",
          "feature-hex-hockey-showdown",
          "feature-arcade"
        ]
      },
      %{
        id: "feature-hex-pong",
        title: gettext("Hex Pong"),
        category: gettext("P2P Games: Action"),
        keywords: ["hex pong", "pong", "paddle", "ball", "game", "cyberpunk", "neon"],
        icon: :icon_game_pong,
        description:
          gettext(
            "Cyberpunk Pong with neon visuals, CRT effects, and synth audio. First to 11 (win by 2). Use Arrow keys or W/S."
          ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-light-trails",
        title: gettext("Light Trails"),
        category: gettext("P2P Games: Action"),
        keywords: [gettext("light trails"), "tron", "trails", "grid", "arena", "game"],
        icon: :icon_game_trails,
        description:
          gettext("Race across a grid leaving a glowing trail. Hit a trail or wall and you lose."),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-pixel-tanks",
        title: gettext("Pixel Tanks"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("pixel tanks"),
          "tank",
          "combat",
          "maze",
          "ricochet",
          "game",
          "shooter",
          "missile"
        ],
        icon: :icon_game_tanks,
        description:
          gettext(
            "Top-down tank combat in a maze arena. Rotate your tank, drive forward, and fire "
          ) <>
            gettext(
              "missiles to hit your opponent. One missile at a time — miss and you're vulnerable. "
            ) <>
            gettext("2-minute rounds, best of 3. Modes: Classic (open field) and Maze Battle. ") <>
            gettext(
              "Controls: Arrow keys (Left/Right rotate, Up forward) or A/D/W, Space or Shift to fire."
            ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-star-duel",
        title: gettext("Star Duel"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("star duel"),
          "space",
          "spaceship",
          "dogfight",
          "game",
          "newtonian",
          "warp",
          "hyperspace"
        ],
        icon: :icon_game_space,
        description:
          gettext("Newtonian space combat in open vacuum. Thrust, rotate, and fire missiles. ") <>
            gettext("Wraparound edges, hyperspace warp with 20% death chance. First to 7 wins. ") <>
            gettext(
              "Controls: Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp."
            ),
        see_also: ["feature-gravity-well", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-gravity-well",
        title: gettext("Gravity Well"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("gravity well"),
          "gravity",
          "orbital",
          "star",
          "slingshot",
          "game",
          "space"
        ],
        icon: :icon_game_gravity,
        description:
          gettext(
            "Orbital combat around a central gravity star. Ships are pulled toward the star — "
          ) <>
            gettext(
              "use gravity slingshots for speed, but fly too close and you die. Same controls "
            ) <>
            gettext("as Star Duel. First to 7 wins."),
        see_also: ["feature-star-duel", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-debris-field",
        title: gettext("Debris Field"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("debris field"),
          "debris",
          "asteroids",
          "obstacles",
          "wreckage",
          "game",
          "space"
        ],
        icon: :icon_game_debris,
        description:
          gettext(
            "Space combat through floating asteroid obstacles. Asteroids block missiles and "
          ) <>
            gettext(
              "kill ships on contact. Use debris for cover or it destroys you. Same controls "
            ) <>
            gettext("as Star Duel. First to 7 wins."),
        see_also: ["feature-star-duel", "feature-gravity-well", "feature-p2p-games"]
      },
      %{
        id: "feature-block-breakers",
        title: gettext("Block Breakers"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("block breakers"),
          "breakout",
          "cooperative",
          "coop",
          "blocks",
          "paddle",
          "game",
          "lives",
          "cyberpunk"
        ],
        icon: :icon_game_breakout,
        description:
          gettext(
            "Cooperative Breakout with cyberpunk visuals. P1 controls the bottom paddle, P2 the top. "
          ) <>
            gettext(
              "3 shared lives, 50 neon blocks (5 rows), ball speeds up. Arrow keys or A/D to move."
            ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-warlords",
        title: gettext("Hex Warlords"),
        category: gettext("P2P Games: Action"),
        keywords: [
          "hex warlords",
          "warlords",
          "castle",
          "fireball",
          "shield",
          "catch",
          "versus",
          "game",
          "bricks",
          "king"
        ],
        icon: :icon_game_warlords,
        description:
          gettext(
            "Versus Breakout battle — each player defends a brick castle with a king inside. "
          ) <>
            gettext(
              "Deflect or catch the fireball with your shield to smash your opponent's walls. "
            ) <>
            gettext("Hold Space to catch, release to aim. Best of 3 lives. ") <>
            gettext(
              "Controls: Arrow keys (Up/Down) to move shield, Space to catch/release fireball."
            ),
        see_also: ["feature-block-breakers", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid",
        title: gettext("Hex Raid"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex raid"),
          gettext("river raid"),
          "river",
          "raid",
          "plane",
          "jet",
          "fuel",
          "mine",
          "bridge",
          "scroll",
          "game"
        ],
        icon: :icon_game_raid,
        description:
          gettext("River Raid reimagined for two — race through a scrolling toxic canal, ") <>
            gettext("destroy enemies for points, steal fuel, and drop mines on your rival. ") <>
            gettext("10 sections of increasing difficulty. Destroy bridges to advance. ") <>
            gettext("Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine."),
        see_also: [
          "feature-hex-raid-pacifist",
          "feature-hex-raid-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-raid-pacifist",
        title: gettext("Hex Raid: Pacifist"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex raid"),
          "pacifist",
          gettext("river raid"),
          gettext("no mines"),
          "pure",
          "skill",
          "game"
        ],
        icon: :icon_game_raid,
        description:
          gettext("River Raid without sabotage — no mines allowed. ") <>
            gettext("Pure competition for points, fuel, and survival across 10 sections. ") <>
            gettext("Controls: Arrow keys to move/speed, Space to fire."),
        see_also: ["feature-hex-raid", "feature-hex-raid-blitz", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid-blitz",
        title: gettext("Hex Raid: Blitz"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex raid"),
          "blitz",
          gettext("river raid"),
          "fast",
          "quick",
          "intense",
          "game"
        ],
        icon: :icon_game_raid,
        description:
          gettext("5 sections of intense River Raid action — river starts narrow, ") <>
            gettext("fuel is scarce, mines recharge faster. Quick and chaotic. ") <>
            gettext("Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine."),
        see_also: ["feature-hex-raid", "feature-hex-raid-pacifist", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-boxing",
        title: gettext("Hex Boxing"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex boxing"),
          "boxing",
          "fight",
          "punch",
          "fists",
          "ko",
          "knockout",
          "ring",
          "game"
        ],
        icon: :icon_game_boxing,
        description:
          gettext("Top-down boxing in a cyberpunk ring — close punches score 3 points, ") <>
            gettext("medium 2, far 1. First to 100 is KO! Best of 3 rounds, 2 minutes each. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to punch."),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-outlaw",
        title: gettext("Hex Outlaw"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex outlaw"),
          "outlaw",
          "western",
          "duel",
          "gunslinger",
          "cowboy",
          "shooter",
          gettext("quick draw"),
          "cactus",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          gettext("Western duel — two gunslingers face off across a cactus obstacle. ") <>
            gettext(
              "Dodge visible bullets and shoot your opponent. First to 10, best of 3 rounds. "
            ) <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-ricochet",
        title: gettext("Hex Outlaw: Ricochet"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex outlaw"),
          "ricochet",
          "bounce",
          "western",
          "duel",
          "angle",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          gettext("Western duel with bouncing bullets — fire at angles to bypass the wall. ") <>
            gettext("Bullets ricochet once off ceiling/floor. Aim up or down with arrow keys. ") <>
            gettext("First to 10, best of 3 rounds. ") <>
            gettext("Controls: Arrow keys or WASD to move/aim, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-stagecoach",
        title: gettext("Hex Outlaw: Stagecoach"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex outlaw"),
          "stagecoach",
          "moving",
          "western",
          "duel",
          "obstacle",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          gettext("Western duel with a stagecoach rolling across the arena. ") <>
            gettext("Time your shots around the moving obstacle. First to 10, best of 3 rounds. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-nml",
        title: gettext("Hex Outlaw: No Man's Land"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex outlaw"),
          gettext("no man's land"),
          "open",
          "western",
          "duel",
          "free",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          gettext("Western duel in open field — no obstacle, full horizontal movement. ") <>
            gettext("Dodge freely in your half of the arena. First to 10, best of 3 rounds. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders",
        title: gettext("Hex Invaders"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex invaders"),
          gettext("space invaders"),
          "invaders",
          "alien",
          "aliens",
          "cannon",
          "shield",
          "ufo",
          "drop",
          "combo",
          "wave",
          "game"
        ],
        icon: :icon_game_invaders,
        description:
          gettext(
            "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. "
          ) <>
            gettext(
              "Combos send extra drops. UFO kills send armored aliens. 10 waves of escalating chaos. "
            ) <>
            gettext("Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders-coop",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-coop",
        title: gettext("Hex Invaders: Co-op"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex invaders"),
          "coop",
          "co-op",
          "cooperative",
          gettext("space invaders"),
          "shared",
          "game"
        ],
        icon: :icon_game_invaders,
        description:
          gettext(
            "Classic co-op Space Invaders — two cannons fighting the same alien waves on a shared screen. "
          ) <>
            gettext("No alien drop mechanic. Survive together or fall together. ") <>
            gettext("Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-blitz",
        title: gettext("Hex Invaders: Blitz"),
        category: gettext("P2P Games: Action"),
        keywords: [
          gettext("hex invaders"),
          "blitz",
          "fast",
          "quick",
          "intense",
          gettext("space invaders"),
          "game"
        ],
        icon: :icon_game_invaders,
        description:
          gettext("Blitz Space Invaders — instant alien drops, easier combo thresholds, ") <>
            gettext("5 waves of pure chaos from the start. ") <>
            gettext("Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-coop",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-enduro",
        title: gettext("Hex Enduro"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex enduro"),
          "enduro",
          "racing",
          "road",
          "pseudo-3d",
          "overtake",
          "fuel",
          "weather",
          "game"
        ],
        icon: :icon_game_enduro,
        description:
          gettext("Pseudo-3D racing duel through day, snow, fog, and night. ") <>
            gettext(
              "Both players race on the same road — overtake AI cars and your opponent for points. "
            ) <>
            gettext("Manage fuel, use turbo boosts, and draft in slipstreams. Best of 3 days. ") <>
            gettext(
              "Controls: Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo."
            ),
        see_also: [
          "feature-hex-enduro-night",
          "feature-hex-enduro-sprint",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-enduro-night",
        title: gettext("Hex Enduro: Night Race"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex enduro"),
          "night",
          "dark",
          "headlights",
          "racing",
          "game"
        ],
        icon: :icon_game_enduro,
        description:
          gettext("3-minute race in permanent darkness with fog bursts. ") <>
            gettext("Headlights-only visibility — pure reflexes. Most overtakes wins. ") <>
            gettext(
              "Controls: Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo."
            ),
        see_also: [
          "feature-hex-enduro",
          "feature-hex-enduro-sprint",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-enduro-sprint",
        title: gettext("Hex Enduro: Sprint"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex enduro"),
          "sprint",
          "fast",
          "quick",
          "daylight",
          "racing",
          "game"
        ],
        icon: :icon_game_enduro,
        description:
          gettext("Daylight sprint — no weather changes, no fuel drain, just speed. ") <>
            gettext("90 seconds to score maximum overtakes. ") <>
            gettext(
              "Controls: Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo."
            ),
        see_also: [
          "feature-hex-enduro",
          "feature-hex-enduro-night",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-tennis",
        title: gettext("Hex Tennis"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex tennis"),
          "tennis",
          "serve",
          "rally",
          "deuce",
          "tiebreak",
          "court",
          "game"
        ],
        icon: :icon_game_tennis,
        description:
          gettext(
            "Top-down tennis duel — automatic hitting where shot angle depends on contact position. "
          ) <>
            gettext("Full set with deuce, advantage, and tiebreak at 6-6. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis-quick",
          "feature-hex-tennis-sudden",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-tennis-quick",
        title: gettext("Hex Tennis: Quick Match"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex tennis"),
          "tennis",
          "quick",
          "fast",
          "short",
          "game"
        ],
        icon: :icon_game_tennis,
        description:
          gettext("Quick tennis match — first to 3 games wins. ") <>
            gettext("Same gameplay, shorter format. No tiebreak needed. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis",
          "feature-hex-tennis-sudden",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-tennis-sudden",
        title: gettext("Hex Tennis: Sudden Death"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex tennis"),
          "tennis",
          gettext("sudden death"),
          gettext("one point"),
          "pressure",
          "game"
        ],
        icon: :icon_game_tennis,
        description:
          gettext("Every point wins a game — no 15-30-40, no deuce. ") <>
            gettext("First to 6 games takes the set. Pure pressure. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis",
          "feature-hex-tennis-quick",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing",
        title: gettext("Hex Skiing"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex skiing"),
          "skiing",
          "alpine",
          "avalanche",
          "slalom",
          "downhill",
          "snow",
          "game"
        ],
        icon: :icon_game_skiing,
        description:
          gettext(
            "Top-down alpine descent through toxic wastelands — dodge mutant trees and irradiated rocks, "
          ) <>
            gettext("clear slalom gates for time bonuses, and outrun the radioactive avalanche. ") <>
            gettext("Best of 3 runs with rising difficulty. ") <>
            gettext("Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing-escape",
          "feature-hex-skiing-clean",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing-escape",
        title: gettext("Hex Skiing: Escape"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex skiing"),
          "skiing",
          "escape",
          "avalanche",
          "survival",
          "infinite",
          "game"
        ],
        icon: :icon_game_skiing,
        description:
          gettext("Infinite descent — the avalanche never stops accelerating. ") <>
            gettext("Last skier standing wins. Pure survival mode. ") <>
            gettext("Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing",
          "feature-hex-skiing-clean",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing-clean",
        title: gettext("Hex Skiing: Clean Run"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex skiing"),
          "skiing",
          "clean",
          "pure",
          gettext("no avalanche"),
          gettext("time trial"),
          "game"
        ],
        icon: :icon_game_skiing,
        description:
          gettext("No avalanche, no items — just trees, rocks, and slalom gates. ") <>
            gettext("Fastest time down the mountain wins. The purist mode. ") <>
            gettext("Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing",
          "feature-hex-skiing-escape",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-frost",
        title: gettext("Hex Frost"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex frost"),
          "frostbite",
          "igloo",
          "ice",
          "arctic",
          "block",
          "steal",
          "construction",
          "game"
        ],
        icon: :icon_game_frost,
        description:
          gettext(
            "Arctic construction race — jump on floating ice blocks to build your igloo while "
          ) <>
            gettext(
              "stealing your opponent's blocks. Blocks have 3 states: white (neutral), your color, "
            ) <>
            gettext(
              "or opponent's color. Stepping on opponent's block steals it (2-piece swing!). "
            ) <>
            gettext(
              "Dodge polar bears, crabs, geese, and clams. Best of 5 rounds with progressive difficulty. "
            ) <>
            gettext(
              "Temperature timer adds urgency. Controls: Arrow keys or WASD to move, Up/Down to jump between rows."
            ),
        see_also: [
          "feature-hex-frost-blizzard",
          "feature-hex-frost-peaceful",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-frost-blizzard",
        title: gettext("Hex Frost: Blizzard"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex frost"),
          "frostbite",
          "blizzard",
          "endurance",
          "long",
          "game"
        ],
        icon: :icon_game_frost,
        description:
          gettext("1 long epic round — igloo needs 20 pieces, all enemies from the start, ") <>
            gettext("temperature starts at 60° and drops slowly. Arctic endurance mode. ") <>
            gettext("Controls: Arrow keys or WASD to move, Up/Down to jump between rows."),
        see_also: [
          "feature-hex-frost",
          "feature-hex-frost-peaceful",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-frost-peaceful",
        title: gettext("Hex Frost: Peaceful"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          gettext("hex frost"),
          "frostbite",
          "peaceful",
          gettext("no steal"),
          "pure",
          "race",
          "game"
        ],
        icon: :icon_game_frost,
        description:
          gettext(
            "Pure construction race — no block stealing allowed. Stepping on opponent's blocks "
          ) <>
            gettext("has no effect. First to complete the igloo wins. Fair and square. ") <>
            gettext("Controls: Arrow keys or WASD to move, Up/Down to jump between rows."),
        see_also: [
          "feature-hex-frost",
          "feature-hex-frost-blizzard",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey",
        title: gettext("Hex Hockey"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          "hex hockey",
          gettext("ice hockey"),
          "hockey",
          "puck",
          "goalie",
          "goal",
          "tackle",
          "shoot",
          "rink",
          "arena",
          "neon",
          "game"
        ],
        icon: :icon_game_hockey,
        description:
          gettext(
            "Top-down ice hockey in a cyberpunk neon arena. Control your field player while "
          ) <>
            gettext(
              "an AI goalie defends your net. Capture the puck, shoot with Space, or tackle "
            ) <>
            gettext(
              "to steal (60% chance, fail = stun). 3 periods of 2 minutes. Tied? Sudden death. "
            ) <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."),
        see_also: [
          "feature-hex-hockey-blitz",
          "feature-hex-hockey-showdown",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey-blitz",
        title: gettext("Hex Hockey: Blitz"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          "hex hockey",
          "hockey",
          "blitz",
          "fast",
          "puck",
          "game"
        ],
        icon: :icon_game_hockey,
        description:
          gettext(
            "One intense period of 3 minutes. Puck moves 25% faster, tackles succeed 80% of the time. "
          ) <>
            gettext("Pure intensity from start to finish. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."),
        see_also: [
          "feature-hex-hockey",
          "feature-hex-hockey-showdown",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey-showdown",
        title: gettext("Hex Hockey: Showdown"),
        category: gettext("P2P Games: Sports"),
        keywords: [
          "hex hockey",
          "hockey",
          "showdown",
          gettext("first to five"),
          "puck",
          "game"
        ],
        icon: :icon_game_hockey,
        description:
          gettext(
            "No timer — first to 5 goals wins. The puck speeds up after every goal scored, "
          ) <>
            gettext("building pressure as the match intensifies. ") <>
            gettext("Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."),
        see_also: [
          "feature-hex-hockey",
          "feature-hex-hockey-blitz",
          "feature-p2p-games"
        ]
      },
      # ── Solo Arcade ──────────────────────────────────
      %{
        id: "feature-arcade",
        title: gettext("Solo Arcade"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "arcade",
          "singleplayer",
          gettext("single player"),
          "solo",
          "doom",
          "quake",
          "wolfenstein",
          "wolf3d",
          "freedoom",
          "freedm",
          gettext("chex quest"),
          "hacx",
          "rekkr",
          "librequake",
          "half-life",
          "halflife",
          "uplink",
          "xash3d",
          "valve",
          "scummvm",
          gettext("point and click"),
          "adventure",
          gettext("beneath a steel sky"),
          "wasm",
          "webassembly",
          "fps",
          "retro",
          "classic"
        ],
        icon: :icon_game_arcade,
        description:
          gettext("Play classic games in your browser via WebAssembly — 18 games including ") <>
            gettext("Beneath a Steel Sky, Dreamweb, Drascula, Flight of the Amazon Queen, ") <>
            gettext("Lure of the Temptress, Soltys, Half-Life: Uplink, Wolfenstein 3D, DOOM, ") <>
            gettext("Quake, Quake II, Freedoom, Chex Quest, HacX, REKKR, and LibreQuake. ") <>
            gettext("Click any game to see its detailed description, keyboard controls, and ") <>
            gettext("gameplay tips before launching. Join #games and type !play to start."),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-quake",
          "feature-arcade-quake2",
          "feature-arcade-wolfenstein",
          "feature-arcade-halflife",
          "feature-arcade-scummvm",
          "feature-arcade-doom-shareware",
          "feature-arcade-scummvm-bass",
          "feature-arcade-quake-shareware",
          "feature-arcade-wolfenstein-3d",
          "feature-arcade-halflife-uplink"
        ]
      },
      %{
        id: "feature-arcade-doom",
        title: gettext("DOOM (Arcade)"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "doom",
          "freedoom",
          "freedm",
          gettext("chex quest"),
          "chex",
          "hacx",
          "rekkr",
          "viking",
          "cyberpunk",
          "fps",
          "shareware",
          gettext("knee deep"),
          "phobos",
          "wasm",
          gettext("id software")
        ],
        icon: :icon_game_doom,
        description:
          gettext(
            "Play 7 DOOM-engine games in your browser — DOOM shareware, Freedoom Phase 1 & 2, "
          ) <>
            gettext(
              "FreeDM, Chex Quest, HacX, and REKKR. Powered by Dwasm (PrBoom+ → WebAssembly)."
            ),
        see_also: [
          "feature-arcade",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx",
          "feature-arcade-rekkr",
          "feature-arcade-quake",
          "feature-arcade-scummvm"
        ]
      },
      %{
        id: "feature-arcade-quake",
        title: gettext("Quake (Arcade)"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "quake",
          "librequake",
          "fps",
          "shareware",
          gettext("dimension of the doomed"),
          "wasm",
          gettext("id software"),
          "lovecraft"
        ],
        icon: :icon_game_quake,
        description:
          gettext(
            "Play 2 Quake-engine games in your browser — Quake shareware and LibreQuake (open-source). "
          ) <>
            gettext("Powered by Qwasm (QuakeSpasm → WebAssembly)."),
        see_also: [
          "feature-arcade",
          "feature-arcade-quake-shareware",
          "feature-arcade-librequake",
          "feature-arcade-doom",
          "feature-arcade-scummvm"
        ]
      },
      %{
        id: "feature-arcade-wolfenstein",
        title: gettext("Wolfenstein 3D (Arcade)"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "wolfenstein",
          "wolf3d",
          gettext("wolf 3d"),
          "fps",
          "shareware",
          "castle",
          "wasm",
          gettext("id software"),
          "1992",
          "ecwolf"
        ],
        icon: :icon_game_wolfenstein,
        description:
          gettext("Play Wolfenstein 3D Episode 1 (shareware) in your browser — 10 levels of the ") <>
            gettext("classic that launched the FPS genre. ") <>
            gettext("Powered by ECWolf-JS (ECWolf → WebAssembly)."),
        see_also: [
          "feature-arcade",
          "feature-arcade-wolfenstein-3d",
          "feature-arcade-doom",
          "feature-arcade-quake",
          "feature-arcade-scummvm"
        ]
      },
      %{
        id: "feature-arcade-halflife",
        title: gettext("Half-Life (Arcade)"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "half-life",
          "halflife",
          "uplink",
          "demo",
          "fps",
          "valve",
          "goldsource",
          "xash3d",
          gettext("black mesa"),
          "wasm",
          "1998"
        ],
        icon: :icon_game_halflife,
        description:
          gettext(
            "Play Half-Life: Uplink in your browser — the official 1999 demo with 3 unique levels "
          ) <>
            gettext("not found in the full game. ") <>
            gettext("Powered by Xash3D-FWGS (GoldSource reimplementation → WebAssembly)."),
        see_also: [
          "feature-arcade",
          "feature-arcade-halflife-uplink",
          "feature-arcade-doom",
          "feature-arcade-quake",
          "feature-arcade-scummvm"
        ]
      },
      %{
        id: "feature-arcade-quake2",
        title: gettext("Quake II (Arcade)"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          gettext("quake 2"),
          gettext("quake ii"),
          "quake2",
          "strogg",
          "fps",
          "shareware",
          "demo",
          "wasm",
          gettext("id software"),
          "yamagi",
          "qwasm2",
          "1997"
        ],
        icon: :icon_game_quake2,
        description:
          gettext(
            "Play the Quake II demo in your browser — Unit 1 of the singleplayer campaign. "
          ) <>
            gettext("Powered by Qwasm2 (Yamagi Quake II → WebAssembly)."),
        see_also: [
          "feature-arcade",
          "feature-arcade-quake2-shareware",
          "feature-arcade-quake",
          "feature-arcade-doom",
          "feature-arcade-scummvm"
        ]
      },
      # ── ScummVM (Point & Click Adventures) ──────────
      %{
        id: "feature-arcade-scummvm",
        title: gettext("ScummVM Adventures (Arcade)"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          "scummvm",
          gettext("point and click"),
          gettext("point & click"),
          "adventure",
          gettext("beneath a steel sky"),
          "bass",
          gettext("revolution software"),
          "cyberpunk",
          "1994",
          "drascula",
          "vampire",
          "1996",
          "dreamweb",
          gettext("creative reality"),
          "top-down",
          gettext("flight of the amazon queen"),
          "fotaq",
          gettext("joe king"),
          "amazon",
          "1995",
          gettext("lure of the temptress"),
          "lure",
          "turnvale",
          "selena",
          gettext("virtual theatre"),
          "1992",
          "soltys",
          gettext("lk avalon"),
          "polish",
          "puzzle",
          "underground",
          "freeware",
          "wasm"
        ],
        icon: :icon_game_bass,
        description:
          gettext(
            "Play classic point & click adventures in your browser — Beneath a Steel Sky (1994), "
          ) <>
            gettext("Drascula (1996), Dreamweb (1994), Flight of the Amazon Queen (1995), ") <>
            gettext("Lure of the Temptress (1992), and Soltys (1995). ") <>
            gettext("Powered by ScummVM (official Emscripten backend → WebAssembly)."),
        see_also: [
          "feature-arcade",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-lure",
          "feature-arcade-scummvm-soltys",
          "feature-arcade-doom",
          "feature-arcade-quake"
        ]
      },
      # ── Solo Arcade: Individual DOOM Engine Games ──────────
      %{
        id: "feature-arcade-doom-shareware",
        title: gettext("DOOM: Knee-Deep in the Dead"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "doom",
          "shareware",
          "phobos",
          gettext("episode 1"),
          gettext("id software"),
          "1993",
          gettext("knee deep")
        ],
        icon: :icon_game_doom,
        description:
          gettext(
            "The original 1993 shareware episode — 9 levels of demon-infested corridors on Phobos."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-freedoom1",
        title: gettext("Freedoom: Phase 1"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "freedoom",
          gettext("phase 1"),
          gettext("open source"),
          "bsd",
          "free",
          gettext("ultimate doom")
        ],
        icon: :icon_game_freedoom1,
        description:
          gettext(
            "A complete free replacement for Ultimate DOOM — 4 episodes, 36 levels with original art and music."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-freedoom2",
        title: gettext("Freedoom: Phase 2"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "freedoom",
          gettext("phase 2"),
          gettext("open source"),
          "bsd",
          "free",
          gettext("doom ii"),
          gettext("super shotgun"),
          "pwad"
        ],
        icon: :icon_game_freedoom2,
        description:
          gettext(
            "A complete free replacement for DOOM II — 32 levels with the Super Shotgun. Compatible with community PWAD mods."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-freedm",
        title: gettext("FreeDM"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "freedm",
          "deathmatch",
          "arena",
          gettext("open source"),
          "bsd",
          "free",
          "multiplayer"
        ],
        icon: :icon_game_freedm,
        description:
          gettext("32 deathmatch-focused arena maps for the DOOM engine. BSD license."),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-chex-quest",
        title: gettext("Chex Quest"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "chex",
          gettext("chex quest"),
          "cereal",
          "zorcher",
          "flemoid",
          "1996",
          gettext("digital cafe"),
          gettext("kid friendly")
        ],
        icon: :icon_game_chex,
        description:
          gettext(
            "The legendary 1996 cereal box promotion — a kid-friendly DOOM total conversion where you zap Flemoids with the Zorcher."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-hacx",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-hacx",
        title: gettext("HacX: Twitch 'n Kill"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "hacx",
          "cyberpunk",
          gettext("total conversion"),
          gettext("banjo software"),
          "1997",
          "hacker",
          "dystopian"
        ],
        icon: :icon_game_hacx,
        description:
          gettext(
            "A cyberpunk DOOM total conversion with new weapons, enemies, and levels. Standalone v1.2 IWAD."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-rekkr"
        ]
      },
      %{
        id: "feature-arcade-rekkr",
        title: gettext("REKKR: Sunken Land"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "rekkr",
          "viking",
          "norse",
          gettext("pixel art"),
          gettext("total conversion"),
          "cacoward",
          "2018",
          "axe",
          "bow"
        ],
        icon: :icon_game_rekkr,
        description:
          gettext(
            "A Viking-themed DOOM total conversion with hand-drawn pixel art — axes, bows, and runic magic. Cacoward 2018 winner."
          ),
        see_also: [
          "feature-arcade-doom",
          "feature-arcade-doom-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2",
          "feature-arcade-freedm",
          "feature-arcade-chex-quest",
          "feature-arcade-hacx"
        ]
      },
      # ── Solo Arcade: Individual Quake Engine Games ──────────
      %{
        id: "feature-arcade-quake-shareware",
        title: gettext("Quake: Dimension of the Doomed"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "quake",
          "shareware",
          gettext("episode 1"),
          gettext("id software"),
          "1996",
          "lovecraft",
          gettext("dimension of the doomed")
        ],
        icon: :icon_game_quake,
        description:
          gettext(
            "The original 1996 shareware episode — full 3D FPS with Lovecraftian horrors and a Trent Reznor soundtrack."
          ),
        see_also: [
          "feature-arcade-quake",
          "feature-arcade-librequake",
          "feature-arcade-doom-shareware",
          "feature-arcade-quake2-shareware"
        ]
      },
      %{
        id: "feature-arcade-librequake",
        title: gettext("LibreQuake"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "librequake",
          gettext("open source"),
          "bsd",
          "free",
          gettext("quake replacement"),
          "community"
        ],
        icon: :icon_game_librequake,
        description:
          gettext(
            "A complete free replacement for Quake — original levels, art, and music under BSD license."
          ),
        see_also: [
          "feature-arcade-quake",
          "feature-arcade-quake-shareware",
          "feature-arcade-freedoom1",
          "feature-arcade-freedoom2"
        ]
      },
      # ── Solo Arcade: Individual Quake II Game ──────────
      %{
        id: "feature-arcade-quake2-shareware",
        title: gettext("Quake II: The Invasion"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          gettext("quake 2"),
          gettext("quake ii"),
          "shareware",
          "demo",
          "strogg",
          "1997",
          gettext("id software"),
          gettext("unit 1")
        ],
        icon: :icon_game_quake2,
        description:
          gettext(
            "The official 1997 Quake II demo — Unit 1 of the singleplayer campaign against the Strogg."
          ),
        see_also: [
          "feature-arcade-quake2",
          "feature-arcade-quake-shareware",
          "feature-arcade-doom-shareware",
          "feature-arcade-wolfenstein-3d"
        ]
      },
      # ── Solo Arcade: Individual Wolfenstein 3D Game ──────────
      %{
        id: "feature-arcade-wolfenstein-3d",
        title: gettext("Wolfenstein 3D: Escape from Castle"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "wolfenstein",
          "wolf3d",
          "shareware",
          gettext("episode 1"),
          "1992",
          gettext("id software"),
          "castle",
          "raycasting"
        ],
        icon: :icon_game_wolfenstein,
        description:
          gettext(
            "The grandfather of FPS games (1992) — 10 levels of castle-storming action in the shareware episode."
          ),
        see_also: [
          "feature-arcade-wolfenstein",
          "feature-arcade-doom-shareware",
          "feature-arcade-quake-shareware",
          "feature-arcade-halflife-uplink"
        ]
      },
      # ── Solo Arcade: Individual Half-Life Game ──────────
      %{
        id: "feature-arcade-halflife-uplink",
        title: gettext("Half-Life: Uplink"),
        category: gettext("Solo Arcade: FPS"),
        keywords: [
          "half-life",
          "halflife",
          "uplink",
          "demo",
          "valve",
          "1999",
          gettext("black mesa"),
          gettext("gordon freeman")
        ],
        icon: :icon_game_halflife,
        description:
          gettext(
            "The official 1999 Valve demo — 3 unique levels not found in the full game, set in Black Mesa."
          ),
        see_also: [
          "feature-arcade-halflife",
          "feature-arcade-wolfenstein-3d",
          "feature-arcade-doom-shareware",
          "feature-arcade-quake-shareware"
        ]
      },
      # ── Solo Arcade: Individual ScummVM Adventure Games ──────────
      %{
        id: "feature-arcade-scummvm-bass",
        title: gettext("Beneath a Steel Sky"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          gettext("beneath a steel sky"),
          "bass",
          gettext("revolution software"),
          "cyberpunk",
          "1994",
          gettext("dave gibbons"),
          "joey",
          gettext("union city")
        ],
        icon: :icon_game_bass,
        description:
          gettext(
            "Cyberpunk masterpiece by Revolution Software (1994) — escape Union City with your robot companion Joey."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-lure",
          "feature-arcade-scummvm-soltys"
        ]
      },
      %{
        id: "feature-arcade-scummvm-drascula",
        title: gettext("Drascula: The Vampire Strikes Back"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          "drascula",
          "vampire",
          "spanish",
          gettext("alcachofa soft"),
          "1996",
          "comedy",
          "parody",
          "dracula"
        ],
        icon: :icon_game_drascula,
        description:
          gettext(
            "Hilarious Spanish point & click parody of Dracula (1996) — defeat the vampire Drascula with absurd humor."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-lure",
          "feature-arcade-scummvm-soltys"
        ]
      },
      %{
        id: "feature-arcade-scummvm-dreamweb",
        title: gettext("Dreamweb"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          "dreamweb",
          gettext("creative reality"),
          "cyberpunk",
          "top-down",
          "1994",
          "dark",
          "mature",
          "ryan"
        ],
        icon: :icon_game_dreamweb,
        description:
          gettext(
            "Dark cyberpunk top-down adventure by Creative Reality (1994) — explore the Dreamweb to save reality."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-lure",
          "feature-arcade-scummvm-soltys"
        ]
      },
      %{
        id: "feature-arcade-scummvm-fotaq",
        title: gettext("Flight of the Amazon Queen"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          gettext("flight of the amazon queen"),
          "fotaq",
          gettext("joe king"),
          "amazon",
          "1995",
          gettext("indiana jones"),
          "dinosaurs",
          "comedy"
        ],
        icon: :icon_game_fotaq,
        description:
          gettext(
            "Comic Indiana Jones-style adventure in the Amazon (1995) — pilot Joe King vs. a mad scientist's dinosaur plot."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-lure",
          "feature-arcade-scummvm-soltys"
        ]
      },
      %{
        id: "feature-arcade-scummvm-lure",
        title: gettext("Lure of the Temptress"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          gettext("lure of the temptress"),
          "lure",
          gettext("revolution software"),
          "1992",
          "medieval",
          gettext("virtual theatre"),
          "turnvale",
          "selena"
        ],
        icon: :icon_game_lure,
        description:
          gettext(
            "Revolution Software's 1992 debut — medieval fantasy with the pioneering Virtual Theatre NPC AI system."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-soltys"
        ]
      },
      %{
        id: "feature-arcade-scummvm-soltys",
        title: gettext("Soltys"),
        category: gettext("Solo Arcade: Adventures"),
        keywords: [
          "soltys",
          gettext("lk avalon"),
          "polish",
          "1995",
          "surreal",
          "puzzle",
          "pirates",
          "grandfather"
        ],
        icon: :icon_game_soltys,
        description:
          gettext(
            "Surreal Polish puzzle adventure by LK Avalon (1995) — rescue your grandfather from underground pirates."
          ),
        see_also: [
          "feature-arcade-scummvm",
          "feature-arcade-scummvm-bass",
          "feature-arcade-scummvm-drascula",
          "feature-arcade-scummvm-dreamweb",
          "feature-arcade-scummvm-fotaq",
          "feature-arcade-scummvm-lure"
        ]
      }
    ]
  end
end
