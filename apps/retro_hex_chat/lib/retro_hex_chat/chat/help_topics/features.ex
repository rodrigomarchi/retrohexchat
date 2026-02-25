defmodule RetroHexChat.Chat.HelpTopics.Features do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "feature-notify-list",
        title: "Notify List (Buddy List)",
        category: "Features",
        keywords: ["notify", "buddy", "friend list", "online", "offline", "track"],
        icon: :icon_tab_notify,
        description: "Track when specific users connect or disconnect with the notify list."
      },
      %{
        id: "feature-address-book",
        title: "Address Book",
        category: "Features",
        keywords: ["address book", "contacts", "nick colors", "color override"],
        icon: :icon_dialog_address_book,
        description: "Manage contacts, assign custom nick colors, and organize your notify list."
      },
      %{
        id: "feature-highlight-words",
        title: "Highlight Words",
        category: "Features",
        keywords: ["highlight", "mention", "alert", "notification", "flash"],
        icon: :icon_dialog_highlight,
        description:
          "Configure words that trigger visual and audio alerts when mentioned in chat."
      },
      %{
        id: "feature-url-catcher",
        title: "URL Catcher",
        category: "Features",
        keywords: ["url", "link", "catcher", "preview", "web"],
        icon: :icon_dialog_url,
        description: "View and manage URLs shared across all channels with link previews."
      },
      %{
        id: "feature-ignore-list",
        title: "Ignore List",
        category: "Features",
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide", "unignore"],
        icon: :icon_dialog_ignore,
        description: "Manage your ignore list to hide messages and actions from specific users."
      },
      %{
        id: "feature-channel-central",
        title: "Channel Central",
        category: "Features",
        keywords: [
          "channel central",
          "channel info",
          "channel settings",
          "modes",
          "bans",
          "ban exceptions",
          "invite exceptions",
          "tabs"
        ],
        icon: :icon_dialog_channel_central,
        description:
          "View and manage channel settings, bans, exceptions, and modes in one dialog."
      },
      %{
        id: "feature-ban-exceptions",
        title: "Ban Exceptions (+e)",
        category: "Features",
        keywords: [
          "ban exception",
          "ban exempt",
          "exception",
          "exempt",
          "bypass ban",
          "+e"
        ],
        icon: :icon_tab_exceptions,
        description: "Allow specific users to bypass channel bans using ban exception masks."
      },
      %{
        id: "feature-invite-exceptions",
        title: "Invite Exceptions (+I)",
        category: "Features",
        keywords: [
          "invite exception",
          "invite exempt",
          "invite bypass",
          "+I",
          "invite-only bypass"
        ],
        icon: :icon_tab_exceptions,
        description:
          "Allow specific users to join invite-only channels without an explicit invitation."
      },
      %{
        id: "feature-channel-invites",
        title: "Channel Invites",
        category: "Features",
        keywords: [
          "invite",
          "channel invite",
          "invite dialog",
          "auto-join on invite",
          "invite expiration",
          "invite-only"
        ],
        icon: :icon_dialog_invite,
        description: "Receive and manage channel invitations with optional auto-join on invite."
      },
      %{
        id: "feature-search",
        title: "Search",
        category: "Features",
        keywords: [
          "search",
          "find",
          "ctrl+f",
          "text search",
          "highlight",
          "regex",
          "case sensitive",
          "history search"
        ],
        icon: :icon_btn_search,
        description:
          "Find text in the current channel using search with regex and case-sensitive options."
      },
      %{
        id: "feature-perform",
        title: "Perform / Auto-Commands",
        category: "Features",
        keywords: [
          "perform",
          "auto-commands",
          "auto commands",
          "on connect",
          "autojoin",
          "auto-join",
          "perform list",
          "auto execute"
        ],
        icon: :icon_dialog_perform,
        description:
          "Configure commands and channels that execute automatically when you connect."
      },
      %{
        id: "feature-auto-reconnect",
        title: "Auto-Reconnect",
        category: "Features",
        keywords: [
          "reconnect",
          "auto-reconnect",
          "auto reconnect",
          "disconnect",
          "connection lost",
          "retry",
          "backoff"
        ],
        icon: :icon_retry,
        description:
          "Automatically reconnect to the server when the connection is lost with exponential backoff."
      },
      %{
        id: "feature-notices",
        title: "Notices",
        category: "Features",
        keywords: ["notice", "notification", "announce", "lightweight message"],
        icon: :icon_megaphone,
        description: "Lightweight messages used for server announcements and automated responses."
      },
      %{
        id: "feature-ctcp",
        title: "CTCP (Client-to-Client Protocol)",
        category: "Features",
        keywords: [
          "ctcp",
          "ping",
          "version",
          "time",
          "finger",
          "client-to-client",
          "latency"
        ],
        icon: :icon_dialog_ctcp,
        description:
          "Configure Client-to-Client Protocol responses for PING, VERSION, TIME, and more."
      },
      %{
        id: "feature-flood-protection",
        title: "Flood Protection",
        category: "Features",
        keywords: [
          "flood",
          "spam",
          "duplicate",
          "auto-ignore",
          "protection",
          "anti-spam",
          "rate limit"
        ],
        icon: :icon_dialog_flood,
        description:
          "Protect against message flooding with rate limiting and automatic ignore rules."
      },
      %{
        id: "feature-sounds",
        title: "Sounds",
        category: "Features",
        keywords: [
          "sounds",
          "sound",
          "audio",
          "beep",
          "ding",
          "alert",
          "chime",
          "notification sound"
        ],
        icon: :icon_dialog_sound,
        description:
          "Configure sound notifications for events like mentions, private messages, and joins."
      },
      %{
        id: "feature-mute",
        title: "Mute",
        category: "Features",
        keywords: ["mute", "unmute", "silence", "sound off", "quiet"],
        icon: :icon_mute,
        description: "Mute all sounds globally or per-channel to silence notifications."
      },
      %{
        id: "feature-typing-indicator",
        title: "Typing Indicator",
        category: "Features",
        keywords: ["typing", "indicator", "is typing", "pm typing"],
        icon: :icon_chat,
        description: "See when someone is typing a message in a private conversation."
      },
      %{
        id: "feature-visual-notifications",
        title: "Visual Notifications",
        category: "Features",
        keywords: [
          "visual",
          "notifications",
          "flash",
          "blink",
          "conversations",
          "title",
          "activity",
          "indicator"
        ],
        icon: :icon_document_alert,
        description:
          "Visual indicators for activity including title bar flashing and conversations panel highlights."
      },
      %{
        id: "feature-aliases",
        title: "Aliases",
        category: "Features",
        keywords: ["alias", "aliases", "shortcut", "macro", "expansion", "scripting"],
        icon: :icon_dialog_alias,
        description:
          "Create custom command shortcuts that expand into one or more commands with variable support."
      },
      %{
        id: "feature-timers",
        title: "Timers",
        category: "Features",
        keywords: ["timer", "timers", "schedule", "delay", "repeat", "interval"],
        icon: :icon_clock,
        description: "Schedule commands to execute after a delay or repeat at regular intervals."
      },
      %{
        id: "feature-custom-menus",
        title: "Custom Menus",
        category: "Features",
        keywords: [
          "custom menu",
          "popup",
          "context menu",
          "right-click",
          "nicklist menu",
          "channel menu"
        ],
        icon: :icon_dialog_custom_menus,
        description: "Add custom items to right-click context menus for quick access to commands."
      },
      %{
        id: "feature-options-dialog",
        title: "Options Dialog",
        category: "Features",
        keywords: [
          "options",
          "preferences",
          "settings",
          "configure",
          "customize",
          "Ctrl+Shift+O"
        ],
        icon: :icon_dialog_options,
        description:
          "Configure display, font, behavior, and notification preferences in the options dialog."
      },
      %{
        id: "feature-display-settings",
        title: "Display Settings",
        category: "Features",
        keywords: [
          "display",
          "toolbar",
          "conversations",
          "switchbar",
          "status bar",
          "compact mode",
          "line shading"
        ],
        icon: :icon_tab_display,
        description:
          "Customize which interface elements are visible and toggle compact display mode."
      },
      %{
        id: "feature-key-bindings",
        title: "Key Bindings",
        category: "Features",
        keywords: [
          "key bindings",
          "keybindings",
          "keyboard shortcuts",
          "customize shortcuts",
          "rebind",
          "shortcut"
        ],
        icon: :icon_dialog_cheatsheet,
        description: "Customize keyboard shortcuts by rebinding keys to different actions."
      },
      %{
        id: "feature-autorespond",
        title: "Auto-Respond",
        category: "Features",
        keywords: [
          "auto-respond",
          "autorespond",
          "auto greet",
          "trigger",
          "event",
          "join greet",
          "welcome"
        ],
        icon: :icon_dialog_auto_respond,
        description:
          "Configure automatic responses triggered by events like user joins or keyword matches."
      },
      %{
        id: "feature-interactive-elements",
        title: "Interactive Chat Elements",
        category: "Features",
        keywords: [
          "interactive",
          "clickable",
          "hover",
          "tooltip",
          "hover card",
          "channel click",
          "nick click",
          "url hover",
          "link preview"
        ],
        icon: :icon_community,
        description: "Clickable nicknames, channels, and URLs with hover cards and link previews."
      },
      %{
        id: "feature-nick-alignment",
        title: "Nick Column Alignment",
        category: "Features",
        keywords: ["nick", "alignment", "column", "grid", "layout", "readability"],
        icon: :icon_tab_nicklist,
        description: "Align nicknames in a fixed-width column for improved chat readability."
      },
      %{
        id: "feature-copy",
        title: "Right-Click Copy",
        category: "Features",
        keywords: ["copy", "clipboard", "right-click", "context menu", "select", "text"],
        icon: :icon_copy,
        description: "Copy message text to the clipboard using the right-click context menu."
      },
      %{
        id: "feature-paste-dialog",
        title: "Multi-Line Paste Dialog",
        category: "Features",
        keywords: ["paste", "multiline", "flood", "confirmation", "send"],
        icon: :icon_dialog_paste,
        description:
          "Review and confirm multi-line pastes before sending to prevent accidental flooding."
      },
      %{
        id: "feature-char-counter",
        title: "Character Counter",
        category: "Features",
        keywords: ["character", "counter", "limit", "length", "input"],
        icon: :icon_notepad,
        description: "See how many characters remain before reaching the message length limit."
      },
      %{
        id: "feature-quit-message",
        title: "Quit Messages",
        category: "Features",
        keywords: ["quit", "disconnect", "message", "goodbye", "leaving"],
        icon: :icon_close,
        description:
          "Customize the message displayed to others when you disconnect from the server."
      },
      %{
        id: "feature-away-reply",
        title: "Away Auto-Reply",
        category: "Features",
        keywords: ["away", "auto-reply", "automatic", "reply", "pm", "message"],
        icon: :icon_clock,
        description: "Automatically reply to private messages when you are marked as away."
      },
      %{
        id: "feature-emoji",
        title: "Emoji Picker",
        category: "Features",
        keywords: ["emoji", "smiley", "picker", "unicode", "emoticon"],
        icon: :icon_heart,
        description: "Browse and insert emoji into your messages using the emoji picker."
      },
      %{
        id: "feature-timestamp-format",
        title: "Timestamp Configuration",
        category: "Features",
        keywords: ["timestamp", "time", "format", "clock", "date"],
        icon: :icon_clock,
        description: "Customize how timestamps are displayed next to messages."
      },
      %{
        id: "feature-autocomplete",
        title: "Autocomplete",
        category: "Features",
        keywords: [
          "autocomplete",
          "auto-complete",
          "tab complete",
          "command palette",
          "fuzzy search",
          "nick completion",
          "channel completion"
        ],
        icon: :icon_btn_search,
        description: "Tab-complete nicknames, commands, channels, and emoji with fuzzy matching."
      },
      %{
        id: "feature-command-syntax-tooltip",
        title: "Command Syntax Tooltip",
        category: "Features",
        keywords: [
          "syntax",
          "tooltip",
          "command help",
          "parameter",
          "hint",
          "inline help",
          "mode helper"
        ],
        icon: :icon_code,
        description: "See command syntax and parameter hints as you type slash commands."
      },
      %{
        id: "feature-smart-input",
        title: "Smart Input",
        category: "Features",
        keywords: [
          "smart input",
          "textarea",
          "multiline",
          "placeholder",
          "expand",
          "input box"
        ],
        icon: :icon_terminal,
        description:
          "Auto-expanding input box with multi-line support and contextual placeholders."
      },
      %{
        id: "feature-cheatsheet",
        title: "Shortcut Cheatsheet",
        category: "Features",
        keywords: [
          "cheatsheet",
          "cheat sheet",
          "shortcut list",
          "keyboard reference",
          "quick reference"
        ],
        icon: :icon_dialog_cheatsheet,
        description: "Quick reference overlay showing all keyboard shortcuts, opened with Ctrl+/."
      },
      %{
        id: "feature-context-menus",
        title: "Context Menus",
        category: "Features",
        keywords: [
          "context menu",
          "right-click",
          "right click",
          "popup menu",
          "nick menu",
          "url menu",
          "channel menu",
          "message menu",
          "conversations menu",
          "mute channel"
        ],
        icon: :icon_dialog_custom_menus,
        description:
          "Right-click context menus for nicknames, messages, URLs, channels, and conversations."
      },
      %{
        id: "feature-enhanced-history",
        title: "Enhanced History",
        category: "Features",
        keywords: [
          "history",
          "ctrl+up",
          "ctrl+down",
          "ctrl+r",
          "reverse search",
          "draft",
          "persistence",
          "localStorage"
        ],
        icon: :icon_backup,
        description:
          "Navigate command history with Ctrl+Up/Down and search with Ctrl+R. Drafts persist per channel."
      },
      %{
        id: "feature-contextual-tips",
        title: "Contextual Tips",
        category: "Features",
        keywords: [
          "tips",
          "contextual",
          "toast",
          "hint",
          "progressive disclosure"
        ],
        icon: :icon_lightbulb,
        description:
          "Helpful tips that appear contextually to guide you through features as you use them."
      },
      %{
        id: "feature-unread-indicators",
        title: "Unread Indicators",
        category: "Features",
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
          "Unread message badges on tabs and conversations showing message and mention counts."
      },
      %{
        id: "feature-kick-notifications",
        title: "Kick Notifications",
        category: "Features",
        keywords: ["kick", "kicked", "expelled", "dialog", "notification"],
        icon: :icon_dialog_kick,
        description:
          "Dialog notification when you are kicked from a channel with the reason and rejoin option."
      },
      %{
        id: "feature-copy-feedback",
        title: "Copy Feedback",
        category: "Features",
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
          "Visual toast confirmation when text or settings are copied to the clipboard."
      },
      %{
        id: "feature-status-bar",
        title: "Status Bar",
        category: "Features",
        keywords: [
          "status bar",
          "lag",
          "clock",
          "connection",
          "mute",
          "channel info"
        ],
        icon: :icon_tab_status,
        description:
          "Bottom bar showing connection status, lag indicator, clock, and channel information."
      },
      %{
        id: "feature-lag-indicator",
        title: "Lag Indicator",
        category: "Features",
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
          "Real-time latency indicator in the status bar showing network delay to the server."
      },
      %{
        id: "feature-connection-states",
        title: "Connection States",
        category: "Features",
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
          "Visual indicators for connection status including banners, overlays, and status bar changes."
      },
      %{
        id: "feature-notifications",
        title: "Notifications",
        category: "Features",
        keywords: [
          "notifications",
          "notification",
          "toast",
          "browser notification",
          "favicon",
          "badge",
          "mention",
          "alert"
        ],
        icon: :icon_dialog_notifications,
        description:
          "Multi-channel notification system with toasts, browser notifications, sounds, and favicon badges."
      },
      %{
        id: "feature-dnd",
        title: "Do Not Disturb",
        category: "Features",
        keywords: [
          "do not disturb",
          "dnd",
          "quiet",
          "silence",
          "suppress",
          "moon"
        ],
        icon: :icon_mute,
        description: "Suppress all notifications while keeping messages visible in channels."
      },
      %{
        id: "feature-notification-center",
        title: "Notification Center",
        category: "Features",
        keywords: [
          "notification center",
          "bell",
          "bell icon",
          "recent notifications",
          "mark all read"
        ],
        icon: :icon_group_notifications,
        description:
          "Review recent notifications in the bell dropdown with mark-all-read support."
      },
      %{
        id: "feature-notification-settings",
        title: "Notification Settings",
        category: "Features",
        keywords: [
          "notification settings",
          "notification preferences",
          "per-channel",
          "trigger rules",
          "privacy mode"
        ],
        icon: :icon_dialog_notifications,
        description:
          "Fine-tune notification preferences per channel with custom trigger rules and privacy mode."
      },
      %{
        id: "feature-message-reply",
        title: "Message Reply",
        category: "Features",
        keywords: [
          "reply",
          "quote",
          "respond",
          "responder",
          "reply to",
          "quote message"
        ],
        icon: :icon_chat,
        description: "Reply to specific messages with quoted context for threaded conversations."
      },
      %{
        id: "feature-message-edit",
        title: "Message Edit",
        category: "Features",
        keywords: [
          "edit",
          "edited",
          "modify",
          "correct",
          "typo",
          "fix message"
        ],
        icon: :icon_btn_edit,
        description: "Edit your recently sent messages to fix typos or update content."
      },
      %{
        id: "feature-message-delete",
        title: "Message Delete",
        category: "Features",
        keywords: [
          "delete",
          "remove",
          "message removed",
          "soft delete"
        ],
        icon: :icon_dialog_delete,
        description: "Delete your own messages with a soft-delete that shows a removal notice."
      },
      %{
        id: "feature-audio-call",
        title: "Audio Call",
        category: "Features",
        keywords: [
          "audio",
          "call",
          "voice",
          "mute",
          "p2p"
        ],
        icon: :icon_microphone,
        description: "Make peer-to-peer audio calls with mute controls and quality indicators."
      },
      %{
        id: "feature-video-call",
        title: "Video Call",
        category: "Features",
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
          "Make video calls with camera controls, picture-in-picture, and quality settings."
      },
      %{
        id: "feature-media-devices",
        title: "Media Devices",
        category: "Features",
        keywords: [
          "device",
          "microphone",
          "camera",
          "speaker",
          "fallback"
        ],
        icon: :icon_devices,
        description: "Select and switch between microphones, cameras, and speakers during calls."
      },
      %{
        id: "feature-call-quality",
        title: "Call Quality",
        category: "Features",
        keywords: [
          "quality",
          "bitrate",
          "preset",
          "indicator",
          "bars"
        ],
        icon: :icon_quality_high,
        description:
          "Monitor and adjust call quality with bitrate presets and real-time quality indicators."
      },
      %{
        id: "feature-p2p-sessions",
        title: "P2P Sessions",
        category: "Features",
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
          "Establish peer-to-peer sessions with bilateral consent for calls and file transfers."
      },
      %{
        id: "feature-connection-diagram",
        title: "Connection Diagram",
        category: "Features",
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
          "Animated visual diagram showing the bilateral P2P link with real-time status and peer info."
      },
      %{
        id: "feature-file-transfer",
        title: "File Transfer",
        category: "Features",
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
          "Send files directly to other users via peer-to-peer with drag-and-drop support."
      },
      %{
        id: "feature-privacy-settings",
        title: "Privacy Settings",
        category: "Features",
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
          "Enable TURN-only relay mode to hide your IP address during peer-to-peer connections."
      },
      %{
        id: "feature-pm-persistence",
        title: "PM Persistence",
        category: "Features",
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
          "Private message conversations are restored automatically on reconnect, ordered by recency."
      },
      %{
        id: "feature-auto-join-channels",
        title: "Auto-Join Channels",
        category: "Features",
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
        description: "Channels are automatically remembered and rejoined when you reconnect."
      },
      %{
        id: "feature-single-session",
        title: "Single Session",
        category: "Features",
        keywords: [
          "single session",
          "session",
          "duplicate",
          "multiple tabs",
          "another window",
          "disconnect",
          "expired",
          "one session"
        ],
        icon: :icon_lock,
        description: "Only one active session per nickname is allowed to prevent conflicts."
      },
      %{
        id: "feature-nick-expiry",
        title: "Nick Expiration",
        category: "Features",
        keywords: [
          "nick expiry",
          "expiration",
          "inactive",
          "purge",
          "7 days",
          "automatic",
          "freed",
          "released"
        ],
        icon: :icon_clock,
        description:
          "Registered nicknames expire after 7 days of inactivity and become available again."
      },
      %{
        id: "feature-admin-console",
        title: "Admin Console",
        category: "Features",
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
          "Execute multiple commands at once by pasting them into the Admin Console (admin only)."
      },
      %{
        id: "feature-p2p-games",
        title: "P2P Games",
        category: "Features",
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
        icon: :icon_star,
        description:
          "Play retro arcade games directly with other users via peer-to-peer WebRTC connections.",
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
          "feature-hex-invaders-blitz"
        ]
      },
      %{
        id: "feature-hex-pong",
        title: "Hex Pong",
        category: "Features",
        keywords: ["hex pong", "pong", "paddle", "ball", "game", "cyberpunk", "neon"],
        icon: :icon_star,
        description:
          "Cyberpunk Pong with neon visuals, CRT effects, and synth audio. First to 11 (win by 2). Use Arrow keys or W/S.",
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-light-trails",
        title: "Light Trails",
        category: "Features",
        keywords: ["light trails", "tron", "trails", "grid", "arena", "game"],
        icon: :icon_star,
        description:
          "Race across a grid leaving a glowing trail. Hit a trail or wall and you lose.",
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-pixel-tanks",
        title: "Pixel Tanks",
        category: "Features",
        keywords: [
          "pixel tanks",
          "tank",
          "combat",
          "maze",
          "ricochet",
          "game",
          "shooter",
          "missile"
        ],
        icon: :icon_star,
        description:
          "Top-down tank combat in a maze arena. Rotate your tank, drive forward, and fire " <>
            "missiles to hit your opponent. One missile at a time — miss and you're vulnerable. " <>
            "2-minute rounds, best of 3. Modes: Classic (open field) and Maze Battle. " <>
            "Controls: Arrow keys (Left/Right rotate, Up forward) or A/D/W, Space or Shift to fire.",
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-star-duel",
        title: "Star Duel",
        category: "Features",
        keywords: [
          "star duel",
          "space",
          "spaceship",
          "dogfight",
          "game",
          "newtonian",
          "warp",
          "hyperspace"
        ],
        icon: :icon_star,
        description:
          "Newtonian space combat in open vacuum. Thrust, rotate, and fire missiles. " <>
            "Wraparound edges, hyperspace warp with 20% death chance. First to 7 wins. " <>
            "Controls: Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp.",
        see_also: ["feature-gravity-well", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-gravity-well",
        title: "Gravity Well",
        category: "Features",
        keywords: [
          "gravity well",
          "gravity",
          "orbital",
          "star",
          "slingshot",
          "game",
          "space"
        ],
        icon: :icon_star,
        description:
          "Orbital combat around a central gravity star. Ships are pulled toward the star — " <>
            "use gravity slingshots for speed, but fly too close and you die. Same controls " <>
            "as Star Duel. First to 7 wins.",
        see_also: ["feature-star-duel", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-debris-field",
        title: "Debris Field",
        category: "Features",
        keywords: [
          "debris field",
          "debris",
          "asteroids",
          "obstacles",
          "wreckage",
          "game",
          "space"
        ],
        icon: :icon_star,
        description:
          "Space combat through floating asteroid obstacles. Asteroids block missiles and " <>
            "kill ships on contact. Use debris for cover or it destroys you. Same controls " <>
            "as Star Duel. First to 7 wins.",
        see_also: ["feature-star-duel", "feature-gravity-well", "feature-p2p-games"]
      },
      %{
        id: "feature-block-breakers",
        title: "Block Breakers",
        category: "Features",
        keywords: [
          "block breakers",
          "breakout",
          "cooperative",
          "coop",
          "blocks",
          "paddle",
          "game",
          "lives",
          "cyberpunk"
        ],
        icon: :icon_star,
        description:
          "Cooperative Breakout with cyberpunk visuals. P1 controls the bottom paddle, P2 the top. " <>
            "3 shared lives, 50 neon blocks (5 rows), ball speeds up. Arrow keys or A/D to move.",
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-warlords",
        title: "Hex Warlords",
        category: "Features",
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
        icon: :icon_star,
        description:
          "Versus Breakout battle — each player defends a brick castle with a king inside. " <>
            "Deflect or catch the fireball with your shield to smash your opponent's walls. " <>
            "Hold Space to catch, release to aim. Best of 3 lives. " <>
            "Controls: Arrow keys (Up/Down) to move shield, Space to catch/release fireball.",
        see_also: ["feature-block-breakers", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid",
        title: "Hex Raid",
        category: "Features",
        keywords: [
          "hex raid",
          "river raid",
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
        icon: :icon_star,
        description:
          "River Raid reimagined for two — race through a scrolling toxic canal, " <>
            "destroy enemies for points, steal fuel, and drop mines on your rival. " <>
            "10 sections of increasing difficulty. Destroy bridges to advance. " <>
            "Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine.",
        see_also: [
          "feature-hex-raid-pacifist",
          "feature-hex-raid-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-raid-pacifist",
        title: "Hex Raid: Pacifist",
        category: "Features",
        keywords: [
          "hex raid",
          "pacifist",
          "river raid",
          "no mines",
          "pure",
          "skill",
          "game"
        ],
        icon: :icon_star,
        description:
          "River Raid without sabotage — no mines allowed. " <>
            "Pure competition for points, fuel, and survival across 10 sections. " <>
            "Controls: Arrow keys to move/speed, Space to fire.",
        see_also: ["feature-hex-raid", "feature-hex-raid-blitz", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid-blitz",
        title: "Hex Raid: Blitz",
        category: "Features",
        keywords: [
          "hex raid",
          "blitz",
          "river raid",
          "fast",
          "quick",
          "intense",
          "game"
        ],
        icon: :icon_star,
        description:
          "5 sections of intense River Raid action — river starts narrow, " <>
            "fuel is scarce, mines recharge faster. Quick and chaotic. " <>
            "Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine.",
        see_also: ["feature-hex-raid", "feature-hex-raid-pacifist", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-boxing",
        title: "Hex Boxing",
        category: "Features",
        keywords: [
          "hex boxing",
          "boxing",
          "fight",
          "punch",
          "fists",
          "ko",
          "knockout",
          "ring",
          "game"
        ],
        icon: :icon_star,
        description:
          "Top-down boxing in a cyberpunk ring — close punches score 3 points, " <>
            "medium 2, far 1. First to 100 is KO! Best of 3 rounds, 2 minutes each. " <>
            "Controls: Arrow keys or WASD to move, Space or Shift to punch.",
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-outlaw",
        title: "Hex Outlaw",
        category: "Features",
        keywords: [
          "hex outlaw",
          "outlaw",
          "western",
          "duel",
          "gunslinger",
          "cowboy",
          "shooter",
          "quick draw",
          "cactus",
          "game"
        ],
        icon: :icon_star,
        description:
          "Western duel — two gunslingers face off across a cactus obstacle. " <>
            "Dodge visible bullets and shoot your opponent. First to 10, best of 3 rounds. " <>
            "Controls: Arrow keys or WASD to move, Space or Shift to fire.",
        see_also: [
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-ricochet",
        title: "Hex Outlaw: Ricochet",
        category: "Features",
        keywords: [
          "hex outlaw",
          "ricochet",
          "bounce",
          "western",
          "duel",
          "angle",
          "game"
        ],
        icon: :icon_star,
        description:
          "Western duel with bouncing bullets — fire at angles to bypass the wall. " <>
            "Bullets ricochet once off ceiling/floor. Aim up or down with arrow keys. " <>
            "First to 10, best of 3 rounds. " <>
            "Controls: Arrow keys or WASD to move/aim, Space or Shift to fire.",
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-stagecoach",
        title: "Hex Outlaw: Stagecoach",
        category: "Features",
        keywords: [
          "hex outlaw",
          "stagecoach",
          "moving",
          "western",
          "duel",
          "obstacle",
          "game"
        ],
        icon: :icon_star,
        description:
          "Western duel with a stagecoach rolling across the arena. " <>
            "Time your shots around the moving obstacle. First to 10, best of 3 rounds. " <>
            "Controls: Arrow keys or WASD to move, Space or Shift to fire.",
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-nml",
        title: "Hex Outlaw: No Man's Land",
        category: "Features",
        keywords: [
          "hex outlaw",
          "no man's land",
          "open",
          "western",
          "duel",
          "free",
          "game"
        ],
        icon: :icon_star,
        description:
          "Western duel in open field — no obstacle, full horizontal movement. " <>
            "Dodge freely in your half of the arena. First to 10, best of 3 rounds. " <>
            "Controls: Arrow keys or WASD to move, Space or Shift to fire.",
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders",
        title: "Hex Invaders",
        category: "Features",
        keywords: [
          "hex invaders",
          "space invaders",
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
        icon: :icon_star,
        description:
          "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. " <>
            "Combos send extra drops. UFO kills send armored aliens. 10 waves of escalating chaos. " <>
            "Controls: Arrow keys or A/D to move, Space to fire.",
        see_also: [
          "feature-hex-invaders-coop",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-coop",
        title: "Hex Invaders: Co-op",
        category: "Features",
        keywords: [
          "hex invaders",
          "coop",
          "co-op",
          "cooperative",
          "space invaders",
          "shared",
          "game"
        ],
        icon: :icon_star,
        description:
          "Classic co-op Space Invaders — two cannons fighting the same alien waves on a shared screen. " <>
            "No alien drop mechanic. Survive together or fall together. " <>
            "Controls: Arrow keys or A/D to move, Space to fire.",
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-blitz",
        title: "Hex Invaders: Blitz",
        category: "Features",
        keywords: [
          "hex invaders",
          "blitz",
          "fast",
          "quick",
          "intense",
          "space invaders",
          "game"
        ],
        icon: :icon_star,
        description:
          "Blitz Space Invaders — instant alien drops, easier combo thresholds, " <>
            "5 waves of pure chaos from the start. " <>
            "Controls: Arrow keys or A/D to move, Space to fire.",
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-coop",
          "feature-p2p-games"
        ]
      }
    ]
  end
end
