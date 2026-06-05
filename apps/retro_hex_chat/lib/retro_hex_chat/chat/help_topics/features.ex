defmodule RetroHexChat.Chat.HelpTopics.Features do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "feature-identity-presence",
        title: dgettext("help", "Identity & Presence"),
        category: dgettext("help", "Users & Identity"),
        keywords: [
          "identity",
          "account",
          "presence",
          "nick",
          "nickname",
          "nickserv",
          "away",
          "bio",
          "umode",
          "wallops",
          "profile",
          "drop",
          "unregister",
          "ghost"
        ],
        icon: :icon_status_user,
        description:
          dgettext(
            "help",
            "Register or identify your nickname, change your nick, set a bio, toggle away status, and manage personal user modes."
          )
      },
      %{
        id: "feature-notify-list",
        title: dgettext("help", "Notify List (Buddy List)"),
        category: dgettext("help", "Contacts & Notify"),
        keywords: [
          "notify",
          "buddy",
          dgettext("help", "friend list"),
          "online",
          "offline",
          "track",
          dgettext("help", "status bar")
        ],
        icon: :icon_tab_notify,
        description:
          dgettext(
            "help",
            "Track when specific users connect or disconnect with the notify list."
          )
      },
      %{
        id: "feature-address-book",
        title: dgettext("help", "Address Book"),
        category: dgettext("help", "Contacts & Notify"),
        keywords: [
          dgettext("help", "address book"),
          "contacts",
          dgettext("help", "nick colors"),
          dgettext("help", "color override")
        ],
        icon: :icon_dialog_address_book,
        description:
          dgettext(
            "help",
            "Manage contacts, assign custom nick colors, and organize your notify list."
          )
      },
      %{
        id: "feature-highlight-words",
        title: dgettext("help", "Highlight Words"),
        category: dgettext("help", "Contacts & Notify"),
        keywords: ["highlight", "mention", "alert", "notification", "flash"],
        icon: :icon_dialog_highlight,
        description:
          dgettext(
            "help",
            "Configure words that trigger visual and audio alerts when mentioned in chat."
          )
      },
      %{
        id: "feature-url-catcher",
        title: dgettext("help", "URL Catcher"),
        category: dgettext("help", "Chat Display"),
        keywords: ["url", "link", "catcher", "preview", "web"],
        icon: :icon_dialog_url,
        description:
          dgettext("help", "View and manage URLs shared across all channels with link previews.")
      },
      %{
        id: "feature-ignore-list",
        title: dgettext("help", "Ignore List"),
        category: dgettext("help", "Contacts & Notify"),
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide", "unignore"],
        icon: :icon_dialog_ignore,
        description:
          dgettext(
            "help",
            "Manage your ignore list to hide messages and actions from specific users."
          )
      },
      %{
        id: "feature-channel-central",
        title: dgettext("help", "Channel Central"),
        category: dgettext("help", "Channel Settings"),
        keywords: [
          dgettext("help", "channel central"),
          dgettext("help", "channel info"),
          dgettext("help", "channel settings"),
          "modes",
          "bans",
          dgettext("help", "ban exceptions"),
          dgettext("help", "invite exceptions"),
          "tabs"
        ],
        icon: :icon_dialog_channel_central,
        description:
          dgettext(
            "help",
            "View and manage channel settings, bans, exceptions, and modes in one dialog."
          )
      },
      %{
        id: "feature-ban-exceptions",
        title: dgettext("help", "Ban Exceptions (+e)"),
        category: dgettext("help", "Channel Settings"),
        keywords: [
          dgettext("help", "ban exception"),
          dgettext("help", "ban exempt"),
          "exception",
          "exempt",
          dgettext("help", "bypass ban"),
          "+e"
        ],
        icon: :icon_tab_exceptions,
        description:
          dgettext(
            "help",
            "Allow specific users to bypass channel bans using ban exception masks."
          )
      },
      %{
        id: "feature-invite-exceptions",
        title: dgettext("help", "Invite Exceptions (+I)"),
        category: dgettext("help", "Channel Settings"),
        keywords: [
          dgettext("help", "invite exception"),
          dgettext("help", "invite exempt"),
          dgettext("help", "invite bypass"),
          "+I",
          dgettext("help", "invite-only bypass")
        ],
        icon: :icon_tab_exceptions,
        description:
          dgettext(
            "help",
            "Allow specific users to join invite-only channels without an explicit invitation."
          )
      },
      %{
        id: "feature-channel-invites",
        title: dgettext("help", "Channel Invites"),
        category: dgettext("help", "Channel Settings"),
        keywords: [
          "invite",
          dgettext("help", "channel invite"),
          dgettext("help", "invite dialog"),
          dgettext("help", "invite to channel"),
          dgettext("help", "send invite"),
          dgettext("help", "auto-join on invite"),
          dgettext("help", "invite expiration"),
          "invite-only",
          "knock"
        ],
        icon: :icon_dialog_invite,
        description:
          dgettext(
            "help",
            "Send, receive, and manage channel invitations with optional auto-join on invite."
          )
      },
      %{
        id: "feature-search",
        title: dgettext("help", "Search"),
        category: dgettext("help", "Channel Settings"),
        keywords: [
          "search",
          "find",
          "ctrl+shift+f",
          dgettext("help", "Edit menu"),
          dgettext("help", "text search"),
          "highlight",
          "regex",
          dgettext("help", "case sensitive"),
          dgettext("help", "history search")
        ],
        icon: :icon_btn_search,
        description:
          dgettext(
            "help",
            "Find text in the current channel using search with regex and case-sensitive options."
          )
      },
      %{
        id: "feature-perform",
        title: dgettext("help", "Perform / Auto-Commands"),
        category: dgettext("help", "Automation"),
        keywords: [
          "perform",
          "auto-commands",
          dgettext("help", "auto commands"),
          dgettext("help", "on connect"),
          "autojoin",
          "auto-join",
          dgettext("help", "perform list"),
          dgettext("help", "auto execute")
        ],
        icon: :icon_dialog_perform,
        description:
          dgettext(
            "help",
            "Configure commands and channels that execute automatically when you connect."
          )
      },
      %{
        id: "feature-auto-reconnect",
        title: dgettext("help", "Auto-Reconnect"),
        category: dgettext("help", "Connection"),
        keywords: [
          "reconnect",
          "auto-reconnect",
          dgettext("help", "auto reconnect"),
          "disconnect",
          dgettext("help", "connection lost"),
          "retry",
          "backoff"
        ],
        icon: :icon_retry,
        description:
          dgettext(
            "help",
            "Automatically reconnect to the server when the connection is lost with exponential backoff."
          )
      },
      %{
        id: "feature-notices",
        title: dgettext("help", "Notices"),
        category: dgettext("help", "Notifications & Sounds"),
        keywords: ["notice", "notification", "announce", dgettext("help", "lightweight message")],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Lightweight messages used for server announcements and automated responses."
          )
      },
      %{
        id: "feature-flood-protection",
        title: dgettext("help", "Flood Protection"),
        category: dgettext("help", "Notifications & Sounds"),
        keywords: [
          "flood",
          "spam",
          "duplicate",
          "auto-ignore",
          "protection",
          "anti-spam",
          dgettext("help", "rate limit")
        ],
        icon: :icon_dialog_flood,
        description:
          dgettext(
            "help",
            "Protect against message flooding with rate limiting and automatic ignore rules."
          )
      },
      %{
        id: "feature-sounds",
        title: dgettext("help", "Sounds"),
        category: dgettext("help", "Notifications & Sounds"),
        keywords: [
          "sounds",
          "sound",
          "audio",
          "beep",
          "ding",
          "alert",
          "chime",
          dgettext("help", "notification sound")
        ],
        icon: :icon_dialog_sound,
        description:
          dgettext(
            "help",
            "Configure sound notifications for events like mentions, private messages, and joins."
          )
      },
      %{
        id: "feature-mute",
        title: dgettext("help", "Mute"),
        category: dgettext("help", "Notifications & Sounds"),
        keywords: ["mute", "unmute", "silence", dgettext("help", "sound off"), "quiet"],
        icon: :icon_mute,
        description:
          dgettext("help", "Mute all sounds globally or per-channel to silence notifications.")
      },
      %{
        id: "feature-typing-indicator",
        title: dgettext("help", "Typing Indicator"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: [
          "typing",
          "indicator",
          dgettext("help", "is typing"),
          dgettext("help", "pm typing")
        ],
        icon: :icon_chat,
        description:
          dgettext("help", "See when someone is typing a message in a private conversation.")
      },
      %{
        id: "feature-aliases",
        title: dgettext("help", "Aliases"),
        category: dgettext("help", "Automation"),
        keywords: [
          "alias",
          "aliases",
          "shortcut",
          "macro",
          "expansion",
          "scripting",
          dgettext("help", "timers dialog")
        ],
        icon: :icon_dialog_alias,
        description:
          dgettext(
            "help",
            "Create custom command shortcuts that expand into one or more commands with variable support."
          )
      },
      %{
        id: "feature-timers",
        title: dgettext("help", "Timers"),
        category: dgettext("help", "Automation"),
        keywords: [
          "timer",
          "timers",
          "schedule",
          "delay",
          "repeat",
          "interval",
          dgettext("help", "timers dialog"),
          "open_timers_dialog",
          dgettext("help", "tools menu"),
          dgettext("help", "toolbar options"),
          dgettext("help", "session-only")
        ],
        icon: :icon_btn_timers,
        description:
          dgettext(
            "help",
            "Schedule commands to execute after a delay or repeat at regular intervals."
          )
      },
      %{
        id: "feature-custom-menus",
        title: dgettext("help", "Custom Menus"),
        category: dgettext("help", "Automation"),
        keywords: [
          dgettext("help", "custom menu"),
          "popup",
          dgettext("help", "context menu"),
          "right-click",
          dgettext("help", "nicklist menu"),
          dgettext("help", "channel menu"),
          dgettext("help", "chat menu")
        ],
        icon: :icon_dialog_custom_menus,
        description:
          dgettext(
            "help",
            "Add custom items to right-click context menus for quick access to commands."
          )
      },
      %{
        id: "feature-display-settings",
        title: dgettext("help", "Display Settings"),
        category: dgettext("help", "Settings & Preferences"),
        keywords: [
          "display",
          "toolbar",
          "conversations",
          "switchbar",
          dgettext("help", "status bar"),
          dgettext("help", "compact mode"),
          dgettext("help", "line shading")
        ],
        icon: :icon_tab_display,
        description:
          dgettext(
            "help",
            "Customize which interface elements are visible and toggle compact display mode."
          )
      },
      %{
        id: "feature-key-bindings",
        title: dgettext("help", "Key Bindings"),
        category: dgettext("help", "Settings & Preferences"),
        keywords: [
          dgettext("help", "key bindings"),
          "keybindings",
          dgettext("help", "keyboard shortcuts"),
          dgettext("help", "customize shortcuts"),
          "rebind",
          "shortcut"
        ],
        icon: :icon_dialog_cheatsheet,
        description:
          dgettext("help", "Customize keyboard shortcuts by rebinding keys to different actions.")
      },
      %{
        id: "feature-autorespond",
        title: dgettext("help", "Auto-Respond"),
        category: dgettext("help", "Automation"),
        keywords: [
          "auto-respond",
          "autorespond",
          dgettext("help", "auto greet"),
          "trigger",
          "event",
          "timers",
          dgettext("help", "join greet"),
          "welcome"
        ],
        icon: :icon_dialog_auto_respond,
        description:
          dgettext(
            "help",
            "Configure automatic responses triggered by events like user joins or keyword matches."
          )
      },
      %{
        id: "feature-interactive-elements",
        title: dgettext("help", "Interactive Chat Elements"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "interactive",
          "clickable",
          "hover",
          "tooltip",
          dgettext("help", "hover card"),
          dgettext("help", "channel click"),
          dgettext("help", "nick click"),
          dgettext("help", "url hover"),
          dgettext("help", "link preview")
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "Clickable nicknames, channels, and URLs with hover cards and link previews."
          )
      },
      %{
        id: "feature-nick-alignment",
        title: dgettext("help", "Nick Column Alignment"),
        category: dgettext("help", "Chat Display"),
        keywords: ["nick", "alignment", "column", "grid", "layout", "readability"],
        icon: :icon_tab_nicklist,
        description:
          dgettext(
            "help",
            "Align nicknames in a fixed-width column for improved chat readability."
          )
      },
      %{
        id: "feature-copy",
        title: dgettext("help", "Right-Click Copy"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "copy",
          "clipboard",
          "right-click",
          dgettext("help", "context menu"),
          "select",
          "text"
        ],
        icon: :icon_copy,
        description:
          dgettext(
            "help",
            "Copy message text to the clipboard using the right-click context menu."
          )
      },
      %{
        id: "feature-paste-dialog",
        title: dgettext("help", "Multi-Line Paste Dialog"),
        category: dgettext("help", "Chat Input"),
        keywords: ["paste", "multiline", "flood", "confirmation", "send"],
        icon: :icon_dialog_paste,
        description:
          dgettext(
            "help",
            "Review and confirm multi-line pastes before sending to prevent accidental flooding."
          )
      },
      %{
        id: "feature-char-counter",
        title: dgettext("help", "Character Counter"),
        category: dgettext("help", "Chat Input"),
        keywords: ["character", "counter", "limit", "length", "input"],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "See how many characters remain before reaching the message length limit."
          )
      },
      %{
        id: "feature-quit-message",
        title: dgettext("help", "Quit Messages"),
        category: dgettext("help", "Users & Identity"),
        keywords: ["quit", "disconnect", "message", "goodbye", "leaving"],
        icon: :icon_close,
        description:
          dgettext(
            "help",
            "Customize the message displayed to others when you disconnect from the server."
          )
      },
      %{
        id: "feature-away-reply",
        title: dgettext("help", "Away Auto-Reply"),
        category: dgettext("help", "Users & Identity"),
        keywords: ["away", "auto-reply", "automatic", "reply", "pm", "message"],
        icon: :icon_clock,
        description:
          dgettext("help", "Automatically reply to private messages when you are marked as away.")
      },
      %{
        id: "feature-emoji",
        title: dgettext("help", "Emoji Picker"),
        category: dgettext("help", "Chat Input"),
        keywords: ["emoji", "smiley", "picker", "unicode", "emoticon"],
        icon: :icon_heart,
        description:
          dgettext("help", "Browse and insert emoji into your messages using the emoji picker.")
      },
      %{
        id: "feature-timestamp-format",
        title: dgettext("help", "Timestamp Configuration"),
        category: dgettext("help", "Chat Display"),
        keywords: ["timestamp", "time", "format", "clock", "date"],
        icon: :icon_clock,
        description: dgettext("help", "Customize how timestamps are displayed next to messages.")
      },
      %{
        id: "feature-autocomplete",
        title: dgettext("help", "Autocomplete"),
        category: dgettext("help", "Chat Input"),
        keywords: [
          "autocomplete",
          "auto-complete",
          dgettext("help", "tab complete"),
          dgettext("help", "command palette"),
          dgettext("help", "fuzzy search"),
          dgettext("help", "nick completion"),
          dgettext("help", "channel completion")
        ],
        icon: :icon_btn_search,
        description:
          dgettext(
            "help",
            "Tab-complete nicknames, commands, channels, and emoji with fuzzy matching."
          )
      },
      %{
        id: "feature-command-syntax-tooltip",
        title: dgettext("help", "Command Syntax Tooltip"),
        category: dgettext("help", "Chat Input"),
        keywords: [
          "syntax",
          "tooltip",
          dgettext("help", "command help"),
          "parameter",
          "hint",
          "inline help",
          "mode helper"
        ],
        icon: :icon_code,
        description:
          dgettext("help", "See command syntax and parameter hints as you type slash commands.")
      },
      %{
        id: "feature-smart-input",
        title: dgettext("help", "Smart Input"),
        category: dgettext("help", "Chat Input"),
        keywords: [
          dgettext("help", "smart input"),
          "textarea",
          "multiline",
          "placeholder",
          "expand",
          dgettext("help", "input box")
        ],
        icon: :icon_terminal,
        description:
          dgettext(
            "help",
            "Auto-expanding input box with multi-line support and contextual placeholders."
          )
      },
      %{
        id: "feature-cheatsheet",
        title: dgettext("help", "Shortcut Cheatsheet"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "cheatsheet",
          dgettext("help", "cheat sheet"),
          dgettext("help", "shortcut list"),
          dgettext("help", "keyboard reference"),
          dgettext("help", "quick reference")
        ],
        icon: :icon_dialog_cheatsheet,
        description:
          dgettext(
            "help",
            "Quick reference overlay showing all keyboard shortcuts, opened with Ctrl+/."
          )
      },
      %{
        id: "feature-context-menus",
        title: dgettext("help", "Context Menus"),
        category: dgettext("help", "Settings & Preferences"),
        keywords: [
          dgettext("help", "context menu"),
          "right-click",
          dgettext("help", "right click"),
          "popup menu",
          dgettext("help", "nick menu"),
          dgettext("help", "url menu"),
          dgettext("help", "channel menu"),
          "message menu",
          dgettext("help", "conversations menu"),
          dgettext("help", "mute channel"),
          "deop",
          "devoice",
          dgettext("help", "channel mute"),
          dgettext("help", "moderation")
        ],
        icon: :icon_dialog_custom_menus,
        description:
          dgettext(
            "help",
            "Right-click context menus for nicknames, messages, URLs, channels, and conversations."
          )
      },
      %{
        id: "feature-enhanced-history",
        title: dgettext("help", "Enhanced History"),
        category: dgettext("help", "Chat Input"),
        keywords: [
          "history",
          "ctrl+up",
          "ctrl+down",
          "ctrl+r",
          dgettext("help", "reverse search"),
          "draft",
          "persistence",
          "localStorage"
        ],
        icon: :icon_backup,
        description:
          dgettext(
            "help",
            "Navigate command history with Ctrl+Up/Down and search with Ctrl+R. Drafts persist per channel."
          )
      },
      %{
        id: "feature-contextual-tips",
        title: dgettext("help", "Contextual Tips"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "tips",
          "contextual",
          "toast",
          "hint",
          dgettext("help", "progressive disclosure")
        ],
        icon: :icon_lightbulb,
        description:
          dgettext(
            "help",
            "Helpful tips that appear contextually to guide you through features as you use them."
          )
      },
      %{
        id: "feature-unread-indicators",
        title: dgettext("help", "Unread Indicators"),
        category: dgettext("help", "Chat Display"),
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
          dgettext(
            "help",
            "Unread message badges on tabs and conversations showing message and mention counts."
          )
      },
      %{
        id: "feature-kick-notifications",
        title: dgettext("help", "Kick Notifications"),
        category: dgettext("help", "Chat Display"),
        keywords: ["kick", "kicked", "expelled", "dialog", "notification"],
        icon: :icon_dialog_kick,
        description:
          dgettext(
            "help",
            "Dialog notification when you are kicked from a channel with the reason and rejoin option."
          )
      },
      %{
        id: "feature-copy-feedback",
        title: dgettext("help", "Copy Feedback"),
        category: dgettext("help", "Chat Display"),
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
          dgettext(
            "help",
            "Visual toast confirmation when text or settings are copied to the clipboard."
          )
      },
      %{
        id: "feature-status-bar",
        title: dgettext("help", "Status Bar"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "status bar"),
          "lag",
          "clock",
          "connection",
          "mute",
          "notify",
          "buddy",
          dgettext("help", "channel info")
        ],
        icon: :icon_tab_status,
        description:
          dgettext(
            "help",
            "Bottom bar showing channel information, online buddies, lag indicator, clock, and mute state."
          )
      },
      %{
        id: "feature-lag-indicator",
        title: dgettext("help", "Lag Indicator"),
        category: dgettext("help", "Connection"),
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
          dgettext(
            "help",
            "Real-time latency indicator in the status bar showing network delay to the server."
          )
      },
      %{
        id: "feature-connection-states",
        title: dgettext("help", "Connection States"),
        category: dgettext("help", "Connection"),
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
          dgettext(
            "help",
            "Visual indicators for connection status including banners, overlays, and status bar changes."
          )
      },
      %{
        id: "feature-message-reply",
        title: dgettext("help", "Message Reply"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: [
          "reply",
          "quote",
          "respond",
          "responder",
          dgettext("help", "reply to"),
          dgettext("help", "quote message")
        ],
        icon: :icon_chat,
        description:
          dgettext(
            "help",
            "Reply to specific messages with quoted context for threaded conversations."
          )
      },
      %{
        id: "feature-message-edit",
        title: dgettext("help", "Message Edit"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: [
          "edit",
          "edited",
          "modify",
          "correct",
          "typo",
          dgettext("help", "fix message")
        ],
        icon: :icon_btn_edit,
        description:
          dgettext("help", "Edit your recently sent messages to fix typos or update content.")
      },
      %{
        id: "feature-message-delete",
        title: dgettext("help", "Message Delete"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: [
          "delete",
          "remove",
          dgettext("help", "message removed"),
          dgettext("help", "soft delete")
        ],
        icon: :icon_dialog_delete,
        description:
          dgettext(
            "help",
            "Delete your own messages with a soft-delete that shows a removal notice."
          )
      },
      %{
        id: "feature-audio-call",
        title: dgettext("help", "Audio Call"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "audio",
          "call",
          "voice",
          "mute",
          "p2p"
        ],
        icon: :icon_microphone,
        description:
          dgettext(
            "help",
            "Make peer-to-peer audio calls with mute controls and quality indicators."
          )
      },
      %{
        id: "feature-video-call",
        title: dgettext("help", "Video Call"),
        category: dgettext("help", "P2P & Calls"),
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
          dgettext(
            "help",
            "Make video calls with camera controls, picture-in-picture, and quality settings."
          )
      },
      %{
        id: "feature-media-devices",
        title: dgettext("help", "Media Devices"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "device",
          "microphone",
          "camera",
          "speaker",
          "fallback"
        ],
        icon: :icon_devices,
        description:
          dgettext(
            "help",
            "Select and switch between microphones, cameras, and speakers during calls."
          )
      },
      %{
        id: "feature-call-quality",
        title: dgettext("help", "Call Quality"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "quality",
          "bitrate",
          "preset",
          "indicator",
          "bars"
        ],
        icon: :icon_quality_high,
        description:
          dgettext(
            "help",
            "Monitor and adjust call quality with bitrate presets and real-time quality indicators."
          )
      },
      %{
        id: "feature-p2p-sessions",
        title: dgettext("help", "P2P Sessions"),
        category: dgettext("help", "P2P & Calls"),
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
          dgettext(
            "help",
            "Establish peer-to-peer sessions with bilateral consent for calls and file transfers."
          )
      },
      %{
        id: "feature-connection-diagram",
        title: dgettext("help", "Connection Diagram"),
        category: dgettext("help", "P2P & Calls"),
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
          dgettext(
            "help",
            "Animated visual diagram showing the bilateral P2P link with real-time status and peer info."
          )
      },
      %{
        id: "feature-file-transfer",
        title: dgettext("help", "File Transfer"),
        category: dgettext("help", "P2P & Calls"),
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
          dgettext(
            "help",
            "Send files directly to other users via peer-to-peer with drag-and-drop support."
          )
      },
      %{
        id: "feature-privacy-settings",
        title: dgettext("help", "Privacy Settings"),
        category: dgettext("help", "Settings & Preferences"),
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
          dgettext(
            "help",
            "Enable TURN-only relay mode to hide your IP address during peer-to-peer connections."
          )
      },
      %{
        id: "feature-pm-persistence",
        title: dgettext("help", "PM Persistence"),
        category: dgettext("help", "Chat & Messaging"),
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
          dgettext(
            "help",
            "Private message conversations are restored automatically on reconnect, ordered by recency."
          )
      },
      %{
        id: "feature-auto-join-channels",
        title: dgettext("help", "Auto-Join Channels"),
        category: dgettext("help", "Channel Settings"),
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
          dgettext(
            "help",
            "Channels are automatically remembered and rejoined when you reconnect."
          )
      },
      %{
        id: "feature-single-session",
        title: dgettext("help", "Single Session"),
        category: dgettext("help", "Users & Identity"),
        keywords: [
          dgettext("help", "single session"),
          "session",
          "duplicate",
          dgettext("help", "multiple tabs"),
          dgettext("help", "another window"),
          "disconnect",
          "expired",
          dgettext("help", "one session")
        ],
        icon: :icon_lock,
        description:
          dgettext(
            "help",
            "Only one active session per nickname is allowed to prevent conflicts."
          )
      },
      %{
        id: "feature-nick-expiry",
        title: dgettext("help", "Nick Expiration"),
        category: dgettext("help", "Users & Identity"),
        keywords: [
          dgettext("help", "nick expiry"),
          "expiration",
          "inactive",
          "purge",
          dgettext("help", "7 days"),
          "automatic",
          "freed",
          "released"
        ],
        icon: :icon_clock,
        description:
          dgettext(
            "help",
            "Registered nicknames expire after 7 days of inactivity and become available again."
          )
      },
      %{
        id: "feature-admin-console",
        title: dgettext("help", "Admin Console"),
        category: dgettext("help", "Admin & Server"),
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
          dgettext(
            "help",
            "Execute multiple commands at once by pasting them into the Admin Console (admin only)."
          )
      },
      %{
        id: "feature-p2p-games",
        title: dgettext("help", "P2P Games"),
        category: dgettext("help", "P2P Games: Action"),
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
          dgettext(
            "help",
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
        title: dgettext("help", "Hex Pong"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: ["hex pong", "pong", "paddle", "ball", "game", "cyberpunk", "neon"],
        icon: :icon_game_pong,
        description:
          dgettext(
            "help",
            "Cyberpunk Pong with neon visuals, CRT effects, and synth audio. First to 11 (win by 2). Use Arrow keys or W/S."
          ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-light-trails",
        title: dgettext("help", "Light Trails"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [dgettext("help", "light trails"), "tron", "trails", "grid", "arena", "game"],
        icon: :icon_game_trails,
        description:
          dgettext(
            "help",
            "Race across a grid leaving a glowing trail. Hit a trail or wall and you lose."
          ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-pixel-tanks",
        title: dgettext("help", "Pixel Tanks"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "pixel tanks"),
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
          dgettext(
            "help",
            "Top-down tank combat in a maze arena. Rotate your tank, drive forward, and fire "
          ) <>
            dgettext(
              "help",
              "missiles to hit your opponent. One missile at a time — miss and you're vulnerable. "
            ) <>
            dgettext(
              "help",
              "2-minute rounds, best of 3. Modes: Classic (open field) and Maze Battle. "
            ) <>
            dgettext(
              "help",
              "Controls: Arrow keys (Left/Right rotate, Up forward) or A/D/W, Space or Shift to fire."
            ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-star-duel",
        title: dgettext("help", "Star Duel"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "star duel"),
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
          dgettext(
            "help",
            "Newtonian space combat in open vacuum. Thrust, rotate, and fire missiles. "
          ) <>
            dgettext(
              "help",
              "Wraparound edges, hyperspace warp with 20% death chance. First to 7 wins. "
            ) <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp."
            ),
        see_also: ["feature-gravity-well", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-gravity-well",
        title: dgettext("help", "Gravity Well"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "gravity well"),
          "gravity",
          "orbital",
          "star",
          "slingshot",
          "game",
          "space"
        ],
        icon: :icon_game_gravity,
        description:
          dgettext(
            "help",
            "Orbital combat around a central gravity star. Ships are pulled toward the star — "
          ) <>
            dgettext(
              "help",
              "use gravity slingshots for speed, but fly too close and you die. Same controls "
            ) <>
            dgettext("help", "as Star Duel. First to 7 wins."),
        see_also: ["feature-star-duel", "feature-debris-field", "feature-p2p-games"]
      },
      %{
        id: "feature-debris-field",
        title: dgettext("help", "Debris Field"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "debris field"),
          "debris",
          "asteroids",
          "obstacles",
          "wreckage",
          "game",
          "space"
        ],
        icon: :icon_game_debris,
        description:
          dgettext(
            "help",
            "Space combat through floating asteroid obstacles. Asteroids block missiles and "
          ) <>
            dgettext(
              "help",
              "kill ships on contact. Use debris for cover or it destroys you. Same controls "
            ) <>
            dgettext("help", "as Star Duel. First to 7 wins."),
        see_also: ["feature-star-duel", "feature-gravity-well", "feature-p2p-games"]
      },
      %{
        id: "feature-block-breakers",
        title: dgettext("help", "Block Breakers"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "block breakers"),
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
          dgettext(
            "help",
            "Cooperative Breakout with cyberpunk visuals. P1 controls the bottom paddle, P2 the top. "
          ) <>
            dgettext(
              "help",
              "3 shared lives, 50 neon blocks (5 rows), ball speeds up. Arrow keys or A/D to move."
            ),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-warlords",
        title: dgettext("help", "Hex Warlords"),
        category: dgettext("help", "P2P Games: Action"),
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
          dgettext(
            "help",
            "Versus Breakout battle — each player defends a brick castle with a king inside. "
          ) <>
            dgettext(
              "help",
              "Deflect or catch the fireball with your shield to smash your opponent's walls. "
            ) <>
            dgettext("help", "Hold Space to catch, release to aim. Best of 3 lives. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys (Up/Down) to move shield, Space to catch/release fireball."
            ),
        see_also: ["feature-block-breakers", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid",
        title: dgettext("help", "Hex Raid"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex raid"),
          dgettext("help", "river raid"),
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
          dgettext(
            "help",
            "River Raid reimagined for two — race through a scrolling toxic canal, "
          ) <>
            dgettext(
              "help",
              "destroy enemies for points, steal fuel, and drop mines on your rival. "
            ) <>
            dgettext("help", "10 sections of increasing difficulty. Destroy bridges to advance. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine."
            ),
        see_also: [
          "feature-hex-raid-pacifist",
          "feature-hex-raid-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-raid-pacifist",
        title: dgettext("help", "Hex Raid: Pacifist"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex raid"),
          "pacifist",
          dgettext("help", "river raid"),
          dgettext("help", "no mines"),
          "pure",
          "skill",
          "game"
        ],
        icon: :icon_game_raid,
        description:
          dgettext("help", "River Raid without sabotage — no mines allowed. ") <>
            dgettext(
              "help",
              "Pure competition for points, fuel, and survival across 10 sections. "
            ) <>
            dgettext("help", "Controls: Arrow keys to move/speed, Space to fire."),
        see_also: ["feature-hex-raid", "feature-hex-raid-blitz", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-raid-blitz",
        title: dgettext("help", "Hex Raid: Blitz"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex raid"),
          "blitz",
          dgettext("help", "river raid"),
          "fast",
          "quick",
          "intense",
          "game"
        ],
        icon: :icon_game_raid,
        description:
          dgettext("help", "5 sections of intense River Raid action — river starts narrow, ") <>
            dgettext("help", "fuel is scarce, mines recharge faster. Quick and chaotic. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys to move/speed, Space to fire, Shift to drop mine."
            ),
        see_also: ["feature-hex-raid", "feature-hex-raid-pacifist", "feature-p2p-games"]
      },
      %{
        id: "feature-hex-boxing",
        title: dgettext("help", "Hex Boxing"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex boxing"),
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
          dgettext("help", "Top-down boxing in a cyberpunk ring — close punches score 3 points, ") <>
            dgettext(
              "help",
              "medium 2, far 1. First to 100 is KO! Best of 3 rounds, 2 minutes each. "
            ) <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to punch."),
        see_also: ["feature-p2p-games"]
      },
      %{
        id: "feature-hex-outlaw",
        title: dgettext("help", "Hex Outlaw"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex outlaw"),
          "outlaw",
          "western",
          "duel",
          "gunslinger",
          "cowboy",
          "shooter",
          dgettext("help", "quick draw"),
          "cactus",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          dgettext("help", "Western duel — two gunslingers face off across a cactus obstacle. ") <>
            dgettext(
              "help",
              "Dodge visible bullets and shoot your opponent. First to 10, best of 3 rounds. "
            ) <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-ricochet",
        title: dgettext("help", "Hex Outlaw: Ricochet"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex outlaw"),
          "ricochet",
          "bounce",
          "western",
          "duel",
          "angle",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          dgettext(
            "help",
            "Western duel with bouncing bullets — fire at angles to bypass the wall. "
          ) <>
            dgettext(
              "help",
              "Bullets ricochet once off ceiling/floor. Aim up or down with arrow keys. "
            ) <>
            dgettext("help", "First to 10, best of 3 rounds. ") <>
            dgettext("help", "Controls: Arrow keys or WASD to move/aim, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-stagecoach",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-stagecoach",
        title: dgettext("help", "Hex Outlaw: Stagecoach"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex outlaw"),
          "stagecoach",
          "moving",
          "western",
          "duel",
          "obstacle",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          dgettext("help", "Western duel with a stagecoach rolling across the arena. ") <>
            dgettext(
              "help",
              "Time your shots around the moving obstacle. First to 10, best of 3 rounds. "
            ) <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-nml",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-outlaw-nml",
        title: dgettext("help", "Hex Outlaw: No Man's Land"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex outlaw"),
          dgettext("help", "no man's land"),
          "open",
          "western",
          "duel",
          "free",
          "game"
        ],
        icon: :icon_game_outlaw,
        description:
          dgettext("help", "Western duel in open field — no obstacle, full horizontal movement. ") <>
            dgettext(
              "help",
              "Dodge freely in your half of the arena. First to 10, best of 3 rounds. "
            ) <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to fire."),
        see_also: [
          "feature-hex-outlaw",
          "feature-hex-outlaw-ricochet",
          "feature-hex-outlaw-stagecoach",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders",
        title: dgettext("help", "Hex Invaders"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex invaders"),
          dgettext("help", "space invaders"),
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
          dgettext(
            "help",
            "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. "
          ) <>
            dgettext(
              "help",
              "Combos send extra drops. UFO kills send armored aliens. 10 waves of escalating chaos. "
            ) <>
            dgettext("help", "Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders-coop",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-coop",
        title: dgettext("help", "Hex Invaders: Co-op"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex invaders"),
          "coop",
          "co-op",
          "cooperative",
          dgettext("help", "space invaders"),
          "shared",
          "game"
        ],
        icon: :icon_game_invaders,
        description:
          dgettext(
            "help",
            "Classic co-op Space Invaders — two cannons fighting the same alien waves on a shared screen. "
          ) <>
            dgettext("help", "No alien drop mechanic. Survive together or fall together. ") <>
            dgettext("help", "Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-blitz",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-invaders-blitz",
        title: dgettext("help", "Hex Invaders: Blitz"),
        category: dgettext("help", "P2P Games: Action"),
        keywords: [
          dgettext("help", "hex invaders"),
          "blitz",
          "fast",
          "quick",
          "intense",
          dgettext("help", "space invaders"),
          "game"
        ],
        icon: :icon_game_invaders,
        description:
          dgettext(
            "help",
            "Blitz Space Invaders — instant alien drops, easier combo thresholds, "
          ) <>
            dgettext("help", "5 waves of pure chaos from the start. ") <>
            dgettext("help", "Controls: Arrow keys or A/D to move, Space to fire."),
        see_also: [
          "feature-hex-invaders",
          "feature-hex-invaders-coop",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-enduro",
        title: dgettext("help", "Hex Enduro"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex enduro"),
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
          dgettext("help", "Pseudo-3D racing duel through day, snow, fog, and night. ") <>
            dgettext(
              "help",
              "Both players race on the same road — overtake AI cars and your opponent for points. "
            ) <>
            dgettext(
              "help",
              "Manage fuel, use turbo boosts, and draft in slipstreams. Best of 3 days. "
            ) <>
            dgettext(
              "help",
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
        title: dgettext("help", "Hex Enduro: Night Race"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex enduro"),
          "night",
          "dark",
          "headlights",
          "racing",
          "game"
        ],
        icon: :icon_game_enduro,
        description:
          dgettext("help", "3-minute race in permanent darkness with fog bursts. ") <>
            dgettext("help", "Headlights-only visibility — pure reflexes. Most overtakes wins. ") <>
            dgettext(
              "help",
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
        title: dgettext("help", "Hex Enduro: Sprint"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex enduro"),
          "sprint",
          "fast",
          "quick",
          "daylight",
          "racing",
          "game"
        ],
        icon: :icon_game_enduro,
        description:
          dgettext("help", "Daylight sprint — no weather changes, no fuel drain, just speed. ") <>
            dgettext("help", "90 seconds to score maximum overtakes. ") <>
            dgettext(
              "help",
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
        title: dgettext("help", "Hex Tennis"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex tennis"),
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
          dgettext(
            "help",
            "Top-down tennis duel — automatic hitting where shot angle depends on contact position. "
          ) <>
            dgettext("help", "Full set with deuce, advantage, and tiebreak at 6-6. ") <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis-quick",
          "feature-hex-tennis-sudden",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-tennis-quick",
        title: dgettext("help", "Hex Tennis: Quick Match"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex tennis"),
          "tennis",
          "quick",
          "fast",
          "short",
          "game"
        ],
        icon: :icon_game_tennis,
        description:
          dgettext("help", "Quick tennis match — first to 3 games wins. ") <>
            dgettext("help", "Same gameplay, shorter format. No tiebreak needed. ") <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis",
          "feature-hex-tennis-sudden",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-tennis-sudden",
        title: dgettext("help", "Hex Tennis: Sudden Death"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex tennis"),
          "tennis",
          dgettext("help", "sudden death"),
          dgettext("help", "one point"),
          "pressure",
          "game"
        ],
        icon: :icon_game_tennis,
        description:
          dgettext("help", "Every point wins a game — no 15-30-40, no deuce. ") <>
            dgettext("help", "First to 6 games takes the set. Pure pressure. ") <>
            dgettext("help", "Controls: Arrow keys or WASD to move, Space or Shift to serve."),
        see_also: [
          "feature-hex-tennis",
          "feature-hex-tennis-quick",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing",
        title: dgettext("help", "Hex Skiing"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex skiing"),
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
          dgettext(
            "help",
            "Top-down alpine descent through toxic wastelands — dodge mutant trees and irradiated rocks, "
          ) <>
            dgettext(
              "help",
              "clear slalom gates for time bonuses, and outrun the radioactive avalanche. "
            ) <>
            dgettext("help", "Best of 3 runs with rising difficulty. ") <>
            dgettext("help", "Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing-escape",
          "feature-hex-skiing-clean",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing-escape",
        title: dgettext("help", "Hex Skiing: Escape"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex skiing"),
          "skiing",
          "escape",
          "avalanche",
          "survival",
          "infinite",
          "game"
        ],
        icon: :icon_game_skiing,
        description:
          dgettext("help", "Infinite descent — the avalanche never stops accelerating. ") <>
            dgettext("help", "Last skier standing wins. Pure survival mode. ") <>
            dgettext("help", "Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing",
          "feature-hex-skiing-clean",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-skiing-clean",
        title: dgettext("help", "Hex Skiing: Clean Run"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex skiing"),
          "skiing",
          "clean",
          "pure",
          dgettext("help", "no avalanche"),
          dgettext("help", "time trial"),
          "game"
        ],
        icon: :icon_game_skiing,
        description:
          dgettext("help", "No avalanche, no items — just trees, rocks, and slalom gates. ") <>
            dgettext("help", "Fastest time down the mountain wins. The purist mode. ") <>
            dgettext("help", "Controls: Arrow keys (←/→) or A/D to steer."),
        see_also: [
          "feature-hex-skiing",
          "feature-hex-skiing-escape",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-frost",
        title: dgettext("help", "Hex Frost"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex frost"),
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
          dgettext(
            "help",
            "Arctic construction race — jump on floating ice blocks to build your igloo while "
          ) <>
            dgettext(
              "help",
              "stealing your opponent's blocks. Blocks have 3 states: white (neutral), your color, "
            ) <>
            dgettext(
              "help",
              "or opponent's color. Stepping on opponent's block steals it (2-piece swing!). "
            ) <>
            dgettext(
              "help",
              "Dodge polar bears, crabs, geese, and clams. Best of 5 rounds with progressive difficulty. "
            ) <>
            dgettext(
              "help",
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
        title: dgettext("help", "Hex Frost: Blizzard"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex frost"),
          "frostbite",
          "blizzard",
          "endurance",
          "long",
          "game"
        ],
        icon: :icon_game_frost,
        description:
          dgettext(
            "help",
            "1 long epic round — igloo needs 20 pieces, all enemies from the start, "
          ) <>
            dgettext(
              "help",
              "temperature starts at 60° and drops slowly. Arctic endurance mode. "
            ) <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to move, Up/Down to jump between rows."
            ),
        see_also: [
          "feature-hex-frost",
          "feature-hex-frost-peaceful",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-frost-peaceful",
        title: dgettext("help", "Hex Frost: Peaceful"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          dgettext("help", "hex frost"),
          "frostbite",
          "peaceful",
          dgettext("help", "no steal"),
          "pure",
          "race",
          "game"
        ],
        icon: :icon_game_frost,
        description:
          dgettext(
            "help",
            "Pure construction race — no block stealing allowed. Stepping on opponent's blocks "
          ) <>
            dgettext("help", "has no effect. First to complete the igloo wins. Fair and square. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to move, Up/Down to jump between rows."
            ),
        see_also: [
          "feature-hex-frost",
          "feature-hex-frost-blizzard",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey",
        title: dgettext("help", "Hex Hockey"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          "hex hockey",
          dgettext("help", "ice hockey"),
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
          dgettext(
            "help",
            "Top-down ice hockey in a cyberpunk neon arena. Control your field player while "
          ) <>
            dgettext(
              "help",
              "an AI goalie defends your net. Capture the puck, shoot with Space, or tackle "
            ) <>
            dgettext(
              "help",
              "to steal (60% chance, fail = stun). 3 periods of 2 minutes. Tied? Sudden death. "
            ) <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."
            ),
        see_also: [
          "feature-hex-hockey-blitz",
          "feature-hex-hockey-showdown",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey-blitz",
        title: dgettext("help", "Hex Hockey: Blitz"),
        category: dgettext("help", "P2P Games: Sports"),
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
          dgettext(
            "help",
            "One intense period of 3 minutes. Puck moves 25% faster, tackles succeed 80% of the time. "
          ) <>
            dgettext("help", "Pure intensity from start to finish. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."
            ),
        see_also: [
          "feature-hex-hockey",
          "feature-hex-hockey-showdown",
          "feature-p2p-games"
        ]
      },
      %{
        id: "feature-hex-hockey-showdown",
        title: dgettext("help", "Hex Hockey: Showdown"),
        category: dgettext("help", "P2P Games: Sports"),
        keywords: [
          "hex hockey",
          "hockey",
          "showdown",
          dgettext("help", "first to five"),
          "puck",
          "game"
        ],
        icon: :icon_game_hockey,
        description:
          dgettext(
            "help",
            "No timer — first to 5 goals wins. The puck speeds up after every goal scored, "
          ) <>
            dgettext("help", "building pressure as the match intensifies. ") <>
            dgettext(
              "help",
              "Controls: Arrow keys or WASD to move, Space or Shift to shoot/tackle."
            ),
        see_also: [
          "feature-hex-hockey",
          "feature-hex-hockey-blitz",
          "feature-p2p-games"
        ]
      },
      # ── Solo Arcade ──────────────────────────────────
      %{
        id: "feature-arcade",
        title: dgettext("help", "Solo Arcade"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "arcade",
          "singleplayer",
          dgettext("help", "single player"),
          "solo",
          "doom",
          "quake",
          "wolfenstein",
          "wolf3d",
          "freedoom",
          "freedm",
          dgettext("help", "chex quest"),
          "hacx",
          "rekkr",
          "librequake",
          "half-life",
          "halflife",
          "uplink",
          "xash3d",
          "valve",
          "scummvm",
          dgettext("help", "point and click"),
          "adventure",
          dgettext("help", "beneath a steel sky"),
          "wasm",
          "webassembly",
          "fps",
          "retro",
          "classic"
        ],
        icon: :icon_game_arcade,
        description:
          dgettext(
            "help",
            "Play classic games in your browser via WebAssembly — 18 games including "
          ) <>
            dgettext(
              "help",
              "Beneath a Steel Sky, Dreamweb, Drascula, Flight of the Amazon Queen, "
            ) <>
            dgettext(
              "help",
              "Lure of the Temptress, Soltys, Half-Life: Uplink, Wolfenstein 3D, DOOM, "
            ) <>
            dgettext(
              "help",
              "Quake, Quake II, Freedoom, Chex Quest, HacX, REKKR, and LibreQuake. "
            ) <>
            dgettext(
              "help",
              "Click any game to see its detailed description, keyboard controls, and "
            ) <>
            dgettext(
              "help",
              "gameplay tips before launching. Join #games and type !play to start."
            ),
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
        title: dgettext("help", "DOOM (Arcade)"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "doom",
          "freedoom",
          "freedm",
          dgettext("help", "chex quest"),
          "chex",
          "hacx",
          "rekkr",
          "viking",
          "cyberpunk",
          "fps",
          "shareware",
          dgettext("help", "knee deep"),
          "phobos",
          "wasm",
          dgettext("help", "id software")
        ],
        icon: :icon_game_doom,
        description:
          dgettext(
            "help",
            "Play 7 DOOM-engine games in your browser — DOOM shareware, Freedoom Phase 1 & 2, "
          ) <>
            dgettext(
              "help",
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
        title: dgettext("help", "Quake (Arcade)"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "quake",
          "librequake",
          "fps",
          "shareware",
          dgettext("help", "dimension of the doomed"),
          "wasm",
          dgettext("help", "id software"),
          "lovecraft"
        ],
        icon: :icon_game_quake,
        description:
          dgettext(
            "help",
            "Play 2 Quake-engine games in your browser — Quake shareware and LibreQuake (open-source). "
          ) <>
            dgettext("help", "Powered by Qwasm (QuakeSpasm → WebAssembly)."),
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
        title: dgettext("help", "Wolfenstein 3D (Arcade)"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "wolfenstein",
          "wolf3d",
          dgettext("help", "wolf 3d"),
          "fps",
          "shareware",
          "castle",
          "wasm",
          dgettext("help", "id software"),
          "1992",
          "ecwolf"
        ],
        icon: :icon_game_wolfenstein,
        description:
          dgettext(
            "help",
            "Play Wolfenstein 3D Episode 1 (shareware) in your browser — 10 levels of the "
          ) <>
            dgettext("help", "classic that launched the FPS genre. ") <>
            dgettext("help", "Powered by ECWolf-JS (ECWolf → WebAssembly)."),
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
        title: dgettext("help", "Half-Life (Arcade)"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "half-life",
          "halflife",
          "uplink",
          "demo",
          "fps",
          "valve",
          "goldsource",
          "xash3d",
          dgettext("help", "black mesa"),
          "wasm",
          "1998"
        ],
        icon: :icon_game_halflife,
        description:
          dgettext(
            "help",
            "Play Half-Life: Uplink in your browser — the official 1999 demo with 3 unique levels "
          ) <>
            dgettext("help", "not found in the full game. ") <>
            dgettext(
              "help",
              "Powered by Xash3D-FWGS (GoldSource reimplementation → WebAssembly)."
            ),
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
        title: dgettext("help", "Quake II (Arcade)"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          dgettext("help", "quake 2"),
          dgettext("help", "quake ii"),
          "quake2",
          "strogg",
          "fps",
          "shareware",
          "demo",
          "wasm",
          dgettext("help", "id software"),
          "yamagi",
          "qwasm2",
          "1997"
        ],
        icon: :icon_game_quake2,
        description:
          dgettext(
            "help",
            "Play the Quake II demo in your browser — Unit 1 of the singleplayer campaign. "
          ) <>
            dgettext("help", "Powered by Qwasm2 (Yamagi Quake II → WebAssembly)."),
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
        title: dgettext("help", "ScummVM Adventures (Arcade)"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          "scummvm",
          dgettext("help", "point and click"),
          dgettext("help", "point & click"),
          "adventure",
          dgettext("help", "beneath a steel sky"),
          "bass",
          dgettext("help", "revolution software"),
          "cyberpunk",
          "1994",
          "drascula",
          "vampire",
          "1996",
          "dreamweb",
          dgettext("help", "creative reality"),
          "top-down",
          dgettext("help", "flight of the amazon queen"),
          "fotaq",
          dgettext("help", "joe king"),
          "amazon",
          "1995",
          dgettext("help", "lure of the temptress"),
          "lure",
          "turnvale",
          "selena",
          dgettext("help", "virtual theatre"),
          "1992",
          "soltys",
          dgettext("help", "lk avalon"),
          "polish",
          "puzzle",
          "underground",
          "freeware",
          "wasm"
        ],
        icon: :icon_game_bass,
        description:
          dgettext(
            "help",
            "Play classic point & click adventures in your browser — Beneath a Steel Sky (1994), "
          ) <>
            dgettext(
              "help",
              "Drascula (1996), Dreamweb (1994), Flight of the Amazon Queen (1995), "
            ) <>
            dgettext("help", "Lure of the Temptress (1992), and Soltys (1995). ") <>
            dgettext("help", "Powered by ScummVM (official Emscripten backend → WebAssembly)."),
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
        title: dgettext("help", "DOOM: Knee-Deep in the Dead"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "doom",
          "shareware",
          "phobos",
          dgettext("help", "episode 1"),
          dgettext("help", "id software"),
          "1993",
          dgettext("help", "knee deep")
        ],
        icon: :icon_game_doom,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Freedoom: Phase 1"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "freedoom",
          dgettext("help", "phase 1"),
          dgettext("help", "open source"),
          "bsd",
          "free",
          dgettext("help", "ultimate doom")
        ],
        icon: :icon_game_freedoom1,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Freedoom: Phase 2"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "freedoom",
          dgettext("help", "phase 2"),
          dgettext("help", "open source"),
          "bsd",
          "free",
          dgettext("help", "doom ii"),
          dgettext("help", "super shotgun"),
          "pwad"
        ],
        icon: :icon_game_freedoom2,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "FreeDM"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "freedm",
          "deathmatch",
          "arena",
          dgettext("help", "open source"),
          "bsd",
          "free",
          "multiplayer"
        ],
        icon: :icon_game_freedm,
        description:
          dgettext("help", "32 deathmatch-focused arena maps for the DOOM engine. BSD license."),
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
        title: dgettext("help", "Chex Quest"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "chex",
          dgettext("help", "chex quest"),
          "cereal",
          "zorcher",
          "flemoid",
          "1996",
          dgettext("help", "digital cafe"),
          dgettext("help", "kid friendly")
        ],
        icon: :icon_game_chex,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "HacX: Twitch 'n Kill"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "hacx",
          "cyberpunk",
          dgettext("help", "total conversion"),
          dgettext("help", "banjo software"),
          "1997",
          "hacker",
          "dystopian"
        ],
        icon: :icon_game_hacx,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "REKKR: Sunken Land"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "rekkr",
          "viking",
          "norse",
          dgettext("help", "pixel art"),
          dgettext("help", "total conversion"),
          "cacoward",
          "2018",
          "axe",
          "bow"
        ],
        icon: :icon_game_rekkr,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Quake: Dimension of the Doomed"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "quake",
          "shareware",
          dgettext("help", "episode 1"),
          dgettext("help", "id software"),
          "1996",
          "lovecraft",
          dgettext("help", "dimension of the doomed")
        ],
        icon: :icon_game_quake,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "LibreQuake"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "librequake",
          dgettext("help", "open source"),
          "bsd",
          "free",
          dgettext("help", "quake replacement"),
          "community"
        ],
        icon: :icon_game_librequake,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Quake II: The Invasion"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          dgettext("help", "quake 2"),
          dgettext("help", "quake ii"),
          "shareware",
          "demo",
          "strogg",
          "1997",
          dgettext("help", "id software"),
          dgettext("help", "unit 1")
        ],
        icon: :icon_game_quake2,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Wolfenstein 3D: Escape from Castle"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "wolfenstein",
          "wolf3d",
          "shareware",
          dgettext("help", "episode 1"),
          "1992",
          dgettext("help", "id software"),
          "castle",
          "raycasting"
        ],
        icon: :icon_game_wolfenstein,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Half-Life: Uplink"),
        category: dgettext("help", "Solo Arcade: FPS"),
        keywords: [
          "half-life",
          "halflife",
          "uplink",
          "demo",
          "valve",
          "1999",
          dgettext("help", "black mesa"),
          dgettext("help", "gordon freeman")
        ],
        icon: :icon_game_halflife,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Beneath a Steel Sky"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          dgettext("help", "beneath a steel sky"),
          "bass",
          dgettext("help", "revolution software"),
          "cyberpunk",
          "1994",
          dgettext("help", "dave gibbons"),
          "joey",
          dgettext("help", "union city")
        ],
        icon: :icon_game_bass,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Drascula: The Vampire Strikes Back"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          "drascula",
          "vampire",
          "spanish",
          dgettext("help", "alcachofa soft"),
          "1996",
          "comedy",
          "parody",
          "dracula"
        ],
        icon: :icon_game_drascula,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Dreamweb"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          "dreamweb",
          dgettext("help", "creative reality"),
          "cyberpunk",
          "top-down",
          "1994",
          "dark",
          "mature",
          "ryan"
        ],
        icon: :icon_game_dreamweb,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Flight of the Amazon Queen"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          dgettext("help", "flight of the amazon queen"),
          "fotaq",
          dgettext("help", "joe king"),
          "amazon",
          "1995",
          dgettext("help", "indiana jones"),
          "dinosaurs",
          "comedy"
        ],
        icon: :icon_game_fotaq,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Lure of the Temptress"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          dgettext("help", "lure of the temptress"),
          "lure",
          dgettext("help", "revolution software"),
          "1992",
          "medieval",
          dgettext("help", "virtual theatre"),
          "turnvale",
          "selena"
        ],
        icon: :icon_game_lure,
        description:
          dgettext(
            "help",
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
        title: dgettext("help", "Soltys"),
        category: dgettext("help", "Solo Arcade: Adventures"),
        keywords: [
          "soltys",
          dgettext("help", "lk avalon"),
          "polish",
          "1995",
          "surreal",
          "puzzle",
          "pirates",
          "grandfather"
        ],
        icon: :icon_game_soltys,
        description:
          dgettext(
            "help",
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
