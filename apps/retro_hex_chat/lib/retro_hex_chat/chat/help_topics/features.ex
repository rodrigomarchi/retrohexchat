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
        id: "feature-user-lookup",
        title: dgettext("help", "User Lookup"),
        category: dgettext("help", "Users & Identity"),
        keywords: [
          dgettext("help", "user lookup"),
          "whois",
          "whowas",
          dgettext("help", "last seen"),
          dgettext("help", "result card"),
          dgettext("help", "context menu"),
          dgettext("help", "Tools menu")
        ],
        icon: :icon_btn_search,
        description:
          dgettext(
            "help",
            "Look up current or recent user information from a dialog, nickname context menus, or slash commands."
          ),
        see_also: ["cmd-whois", "cmd-whowas", "feature-context-menus", "keyboard-shortcuts"]
      },
      %{
        id: "feature-server-broadcasts",
        title: dgettext("help", "Server Broadcasts"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "server broadcasts",
          "broadcast",
          "wallops",
          "announce",
          "announcement",
          "admin console",
          "broadcast tab",
          "+w",
          "umode"
        ],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Send wallops messages to users with +w enabled or urgent announcements to every connected user."
          ),
        see_also: ["feature-admin-console", "cmd-wallops", "cmd-announce", "cmd-umode"]
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
          dgettext("help", "contact notes")
        ],
        icon: :icon_dialog_address_book,
        description: dgettext("help", "Keep a list of contacts with notes about each person."),
        see_also: ["feature-nick-colors", "feature-ignore-list", "feature-notify-list"]
      },
      %{
        id: "feature-nick-colors",
        title: dgettext("help", "Nick Colors"),
        category: dgettext("help", "Contacts & Notify"),
        keywords: [
          dgettext("help", "nick colors"),
          dgettext("help", "color override"),
          "palette",
          "colour"
        ],
        icon: :icon_dialog_nick_colors,
        description:
          dgettext("help", "Assign a fixed color to a nickname, overriding the automatic one."),
        see_also: ["feature-address-book"]
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
          dgettext(
            "help",
            "View and manage URLs shared across all channels with standards-based link previews."
          ),
        see_also: ["feature-link-previews"]
      },
      %{
        id: "feature-link-previews",
        title: dgettext("help", "Link Previews"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "url",
          "link",
          "preview",
          "card",
          "markdown",
          "image",
          "description",
          "open graph",
          "schema.org",
          "oembed",
          "rss"
        ],
        icon: :icon_dialog_url,
        description:
          dgettext(
            "help",
            "A link pasted in a conversation gets a card under the message — source, headline, byline, image and summary. RSS cards use the same renderer, enriched with feed metadata when the publisher page is thin."
          ),
        see_also: ["feature-url-catcher", "bot-rss"]
      },
      %{
        id: "feature-message-attachments",
        title: dgettext("help", "Message Attachments"),
        category: dgettext("help", "Chat & Messaging"),
        keywords: [
          dgettext("help", "attachments"),
          dgettext("help", "files"),
          dgettext("help", "upload"),
          dgettext("help", "download"),
          dgettext("help", "signed URL")
        ],
        icon: :icon_file_send,
        description:
          dgettext(
            "help",
            "Attach uploaded files to channel and private messages, then download them through authorized links."
          )
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
          "chanserv",
          "registration tab",
          "access lists",
          dgettext("help", "access lists tab"),
          "tabs"
        ],
        icon: :icon_dialog_channel_central,
        description:
          dgettext(
            "help",
            "View and manage channel settings, bans, exceptions, and modes in one dialog."
          ),
        see_also: ["chanserv-ui", "chanserv", "chanserv-register", "chanserv-access"]
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
          dgettext("help", "perform list"),
          dgettext("help", "perform window"),
          dgettext("help", "auto execute")
        ],
        icon: :icon_dialog_perform,
        description:
          dgettext(
            "help",
            "Configure the commands that run automatically when you connect."
          ),
        see_also: ["cmd-perform", "feature-auto-join-channels", "feature-auto-reconnect"]
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
        keywords: [
          "notice",
          "send notice",
          "context menu",
          "notification",
          "announce",
          dgettext("help", "lightweight message")
        ],
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
            "Clickable nicknames, channels, and URLs, with hover cards and a preview card under any message carrying a link."
          ),
        see_also: ["feature-session-cards", "feature-message-layout"]
      },
      %{
        id: "feature-session-cards",
        title: dgettext("help", "Session Cards and P2P History"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "p2p",
          "lobby",
          "arcade",
          "invite",
          "session",
          dgettext("help", "session card"),
          dgettext("help", "game link"),
          dgettext("help", "p2p request")
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "Arcade links can render as rich cards with Join/Open actions while they are live. P2P requests use the PM header for Start/Join/Decline and keep transcript rows as inert history showing request, connected and ended states."
          ),
        see_also: ["feature-interactive-elements", "feature-message-layout"]
      },
      %{
        id: "feature-message-layout",
        title: dgettext("help", "Message Layout"),
        category: dgettext("help", "Chat Display"),
        keywords: [
          "nick",
          "alignment",
          "column",
          "layout",
          "timestamp",
          "readability",
          dgettext("help", "message format")
        ],
        icon: :icon_tab_nicklist,
        description:
          dgettext(
            "help",
            "Each message uses a compact metadata column — the author's nick (or the origin, like System or Error) above a smaller timestamp — beside the message text, which gets the wider column. This reads well on phones while keeping the retro monospace look."
          ),
        see_also: ["feature-timestamp-format", "feature-session-cards"]
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
          dgettext("help", "last seen"),
          "whowas",
          dgettext("help", "user lookup"),
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
          dgettext("help", "account history")
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
            "Bar showing your live session: active call or P2P session, online buddies, lag indicator, clock, and mute state. Who you are and what you are reading are named in the chat window's title bar."
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
            "Make video calls with camera controls, picture-in-picture, and quality settings. " <>
              "See also: P2P Session."
          )
      },
      %{
        id: "feature-channel-conference",
        title: dgettext("help", "Channel Conference"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "conference",
          "group call",
          "channel call",
          "sfu",
          "pre-join",
          "devices",
          "receive-only",
          "recovery",
          "reactions",
          "screen share",
          "moderation",
          "statistics"
        ],
        icon: :icon_conference,
        description:
          dgettext(
            "help",
            "Join a channel-scoped audio/video conference. Group Call in the channel toolbar opens the room and posts a card in the channel carrying its address; everyone goes in through that card, including whoever opened it. If a conference is already running, Group Call is a link into it rather than a second one — one room, one card. Following the address opens the antechamber in a browser tab of its own: a camera preview, the microphone/camera/speaker pickers, and who is already inside. Join call puts you in; Cancel closes it, and whichever way you leave the antechamber it remembers how you left the microphone and camera set for next time. Inside there are layout controls, participant moderation and live statistics. Moderation follows channel permissions: half-operators and above can moderate lower-ranked participants."
          ),
        see_also: [
          "feature-conference-tab",
          "feature-conference-share",
          "feature-media-devices",
          "feature-call-quality",
          "ui-conversations"
        ]
      },
      %{
        id: "feature-conference-tab",
        title: dgettext("help", "Conference in Its Own Tab"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "conference",
          "tab",
          "window",
          "browser",
          "close",
          "reconnect",
          "rejoin"
        ],
        icon: :icon_conference,
        description:
          dgettext(
            "help",
            "A conference always runs in a browser tab of its own, so the call gets the whole window and the chat stays the chat. While it is over there the chat says so along the bottom of its window — click that to go to the tab, which is why there is no Leave beside it: you leave a call from the screen that is in it. Ctrl+Shift with the arrow keys works inside that tab: Up for the microphone, Left for the camera, Right for the layout, Down to move the focus; Ctrl+Shift+Q leaves. Closing the tab is not leaving either: the room keeps you for the reconnection window, and reopening the address puts you straight back in. Only Leave, which asks first, actually ends your part in the call — and being removed from the channel ends it for you."
          ),
        see_also: ["feature-channel-conference", "feature-conference-share"]
      },
      %{
        id: "feature-conference-share",
        title: dgettext("help", "Sharing a Conference Link"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "share",
          "link",
          "invite",
          "url",
          "conference",
          "call",
          "paste",
          "card",
          "copy link"
        ],
        icon: :icon_btn_link,
        description:
          dgettext(
            "help",
            "Opening a conference already posts its card in the channel, and Share, above the conference, hands you that same address to paste anywhere else — pressing it again gives you the link you already have rather than a second one. Pasted into a conversation it draws a card instead of a bare address, and that card is the room as it is now: it counts who is inside and changes on its own as people come and go, with Join to go in and Copy link to pass it on. When the room finishes — or you revoke the link — the card stays and becomes the record of what happened: how long the conference ran and how many different people were in it, with the next thing you can still do instead of a button that no longer works. A P2P session says how long it lasted; a space and a solo game say neither, because a place has no beginning to measure from. The link carries which room it is and never permission to be in it: whoever follows it still has to be registered and a member of the channel, so a link is an invitation to a room you can already reach, not a way around the channel's door. Only a registered nickname can mint one."
          ),
        see_also: [
          "feature-channel-conference",
          "feature-conference-tab",
          "feature-share-revoke"
        ]
      },
      %{
        id: "feature-share-revoke",
        title: dgettext("help", "Undoing a Link You Shared"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "revoke",
          "undo",
          "unshare",
          "stop",
          "link",
          "share",
          "cancel"
        ],
        icon: :icon_close,
        description:
          dgettext(
            "help",
            "Revoke, beside the address on any Share bar, stops the link working. The room is untouched: whoever is already inside stays inside, and anyone who can reach it another way still can. Only the address dies. Asking to share the same room again hands you a new one, so a link you pasted in the wrong place is fixable rather than permanent. Share gives you one address per room rather than a fresh one per press, which is what makes revoking it a whole answer instead of closing one of several. Your own links are yours to revoke, and a channel operator can also revoke a link that leads into their channel."
          ),
        see_also: [
          "feature-conference-share",
          "feature-space-share",
          "feature-p2p-starting-room"
        ]
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
          "indicator",
          "bars"
        ],
        icon: :icon_quality_high,
        description:
          dgettext(
            "help",
            "Monitor call quality with real-time quality indicators. See also: Network Statistics."
          )
      },
      %{
        id: "feature-universal-lobby",
        title: dgettext("help", "P2P Session"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "lobby",
          "p2p lobby",
          "p2p",
          "everything",
          "concurrent",
          "call",
          "file",
          "game",
          "window"
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "The P2P Session is the persistent peer-to-peer connection behind /p2p — one link " <>
              "that hosts a call, file transfers and games all at the same time. It lives " <>
              "inside the chat: accepting an invite opens the P2P Session Console right on " <>
              "the chat desktop, and ending any one activity never drops the others. " <>
              "See also: P2P Sessions in Chat."
          )
      },
      %{
        id: "feature-p2p-in-chat",
        title: dgettext("help", "P2P Sessions in Chat"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "p2p",
          "session",
          "private message",
          "invite",
          "accept",
          "decline",
          "call",
          "file",
          "game",
          "statistics",
          "status bar",
          "privacy",
          "switch"
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "Run a P2P session without leaving the chat: /p2p <nick> sends the request " <>
              "line into the private message straight away and puts you in the session's " <>
              "starting room, where you pick your microphone, camera and speaker while you " <>
              "wait for an answer. The invited person's PM tab opens in the background with " <>
              "Join/Decline in the PM header; Join takes them to the same room. Nothing is " <>
              "negotiated until both of you press Ready and the person who invited presses " <>
              "Start. After Start you get the P2P Session Console — Call, Files, Games and " <>
              "Stats — reachable again from the P2P menu and the Start menu. The " <>
              "conversation IS the private message: session events (connected, file " <>
              "received, game results, who ended it) are saved into the PM history as P2P " <>
              "lines, and the PM tab shows a small P2P icon while the session is live. The " <>
              "status bar always shows the active session: click it to bring the console to " <>
              "the front, or use its stop button to cancel a pending invite or end the " <>
              "session. You can hold ONE session at a time — accepting a new invite (or " <>
              "inviting someone else) asks to end the current one first. When a TURN relay " <>
              "is configured, Privacy relay in the starting room, and Toggle Privacy Mode in " <>
              "the P2P menu afterwards, force the connection through the relay so your IP " <>
              "address is never shared with the peer. " <>
              "See also: P2P Starting Room, P2P Session in Its Own Tab, Video Call, File " <>
              "Transfer, Private Messages."
          )
      },
      %{
        id: "feature-p2p-starting-room",
        title: dgettext("help", "P2P Starting Room"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "p2p",
          "starting room",
          "ready",
          "start",
          "host",
          "waiting",
          "devices",
          "microphone",
          "camera",
          "speaker",
          "preview",
          "privacy",
          "relay"
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "Every P2P session opens in a starting room before anything is negotiated. It " <>
              "shows both of you and what each is still doing, a camera preview, and the " <>
              "microphone, camera and speaker you will use — plus Route and privacy, where " <>
              "you can force the connection through the relay. Press Ready when your " <>
              "devices are chosen. The person who sent the invite is the host and is the " <>
              "only one with Start, which stays disabled until both of you are ready: the " <>
              "connection is always offered by whoever invited, and the line under the " <>
              "roster says exactly who is being waited for. If the host cancels before " <>
              "starting, the session ends and any link to it stops working."
          ),
        see_also: ["feature-p2p-in-chat", "feature-p2p-tab"]
      },
      %{
        id: "feature-p2p-tab",
        title: dgettext("help", "P2P Session in Its Own Tab"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "p2p",
          "tab",
          "window",
          "browser",
          "share",
          "link",
          "another window",
          "moved"
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "A P2P session can run in a browser tab of its own. In the starting room, " <>
              "choose Open in a tab: the session gets the whole window and stops competing " <>
              "with the chat for the browser. Share there mints a link you can paste " <>
              "anywhere; only the two people in the session can actually enter it. A " <>
              "session can only be live in one window at a time — opening it somewhere " <>
              "else moves it there, and the window that lost it says so and offers Bring it " <>
              "back here. Closing the tab is not ending the session; the stop button and " <>
              "the window's X ask first, and only they end it."
          ),
        see_also: ["feature-p2p-in-chat", "feature-p2p-starting-room"]
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
        id: "feature-network-stats",
        title: dgettext("help", "Network Statistics"),
        category: dgettext("help", "P2P & Calls"),
        keywords: [
          "network",
          "stats",
          "statistics",
          "telemetry",
          "latency",
          "rtt",
          "ping",
          "jitter",
          "packet loss",
          "bitrate",
          "bandwidth",
          "fps",
          "mos",
          "health",
          "webrtc"
        ],
        icon: :icon_status_signal,
        description:
          dgettext(
            "help",
            "The Network panel during a call shows live connection health (a MOS score), latency, jitter, packet loss, up/download bitrate, video resolution and frame rate, and whether quality is limited by CPU or bandwidth. Collapse it with the toolbar button. See also: Call Quality, Connection Diagram."
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
            "Send files directly to other users via peer-to-peer with drag-and-drop support. " <>
              "See also: P2P Session."
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
          "private mode",
          "telemetry",
          "monitoring",
          "performance",
          "errors",
          "rum"
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
          "reconnect",
          dgettext("help", "auto-join window"),
          dgettext("help", "channel key")
        ],
        icon: :icon_dialog_autojoin,
        description:
          dgettext(
            "help",
            "Channels are automatically remembered and rejoined when you reconnect."
          ),
        see_also: ["cmd-autojoin", "feature-perform", "cmd-join", "cmd-part"]
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
        id: "feature-admin-server-settings",
        title: dgettext("help", "Admin Server Settings"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "server settings",
          "configuration",
          dgettext("help", "server name"),
          "registration",
          "whowas",
          "max channels",
          "welcome message"
        ],
        icon: :icon_server,
        description:
          dgettext(
            "help",
            "Edit the server's name, description, welcome message, channel limit and registration policy."
          ),
        see_also: ["feature-admin-console", "cmd-admin-server"]
      },
      %{
        id: "feature-admin-audit-log",
        title: dgettext("help", "Admin Audit Log"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "audit log",
          "history",
          "who did what",
          "log"
        ],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "Read the administrative history, filtered by row count and by the admin who acted."
          ),
        see_also: ["feature-admin-console", "cmd-admin-log"]
      },
      %{
        id: "feature-admin-motd",
        title: dgettext("help", "Admin MOTD"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "motd",
          "message of the day",
          "setmotd",
          "clearmotd",
          "welcome"
        ],
        icon: :icon_notepad,
        description: dgettext("help", "Set, replace or clear the server's message of the day."),
        see_also: [
          "feature-admin-console",
          "cmd-motd",
          "cmd-setmotd",
          "cmd-clearmotd",
          "ui-message-of-the-day"
        ]
      },
      %{
        id: "feature-admin-turn",
        title: dgettext("help", "Admin TURN"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "turn",
          "relay",
          "webrtc",
          "allocations",
          "stats"
        ],
        icon: :icon_websocket,
        description: dgettext("help", "Read TURN relay statistics and active allocations."),
        see_also: ["feature-admin-console", "cmd-admin-turn", "feature-network-stats"]
      },
      %{
        id: "feature-admin-broadcast",
        title: dgettext("help", "Admin Broadcast"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "broadcast",
          "wallops",
          "announce",
          "announcement",
          "server message"
        ],
        icon: :icon_megaphone,
        description:
          dgettext("help", "Send a wallops to +w users or an announcement to everyone connected."),
        see_also: [
          "feature-admin-console",
          "feature-server-broadcasts",
          "cmd-wallops",
          "cmd-announce"
        ]
      },
      %{
        id: "feature-admin-danger-zone",
        title: dgettext("help", "Admin Danger Zone"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "danger zone",
          "nuke",
          "factory reset",
          "wipe",
          "reset server"
        ],
        icon: :icon_warning,
        description:
          dgettext(
            "help",
            "Preview and execute a full server wipe, guarded by typing the server name."
          ),
        see_also: ["feature-admin-console", "cmd-admin-nuke"]
      },
      %{
        id: "feature-admin-channels",
        title: dgettext("help", "Admin Channels"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "channels",
          dgettext("help", "channel delete"),
          dgettext("help", "channel purge"),
          "create",
          dgettext("help", "chanserv admin"),
          "access list",
          "transfer",
          "drop",
          "banlist"
        ],
        icon: :icon_channels,
        description:
          dgettext(
            "help",
            "Inspect, create, delete and purge channels, and administer their ChanServ registration."
          ),
        see_also: [
          "feature-admin-console",
          "feature-admin-users",
          "cmd-admin-channel",
          "cmd-admin-cs"
        ]
      },
      %{
        id: "feature-admin-users",
        title: dgettext("help", "Admin Users"),
        category: dgettext("help", "Admin & Server"),
        keywords: [
          "admin",
          "users",
          dgettext("help", "user moderation"),
          dgettext("help", "user roles"),
          "ban",
          "unban",
          "kick",
          "mute",
          "unmute",
          "rename",
          dgettext("help", "nickserv admin"),
          "resetpass",
          "drop"
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "Moderate users, manage accounts and roles, and run NickServ admin actions."
          ),
        see_also: [
          "feature-admin-console",
          "cmd-admin-user",
          "cmd-admin-ns",
          "channel-permissions"
        ]
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
            "Use the tabbed Admin Console for server administration, with the raw batch command console preserved for power users."
          ),
        see_also: [
          "cmd-admin",
          "cmd-admin-server",
          "cmd-admin-user",
          "cmd-admin-channel",
          "cmd-admin-log",
          "cmd-admin-turn",
          "cmd-admin-nuke",
          "cmd-setmotd",
          "cmd-clearmotd",
          "feature-server-broadcasts",
          "ui-message-of-the-day"
        ]
      },
      %{
        id: "feature-game-match-link",
        title: dgettext("help", "Playing a Game with Somebody"),
        category: dgettext("help", "Retro Games"),
        keywords: [
          dgettext("help", "match link"),
          dgettext("help", "play with someone"),
          "multiplayer",
          "match",
          "link",
          "invite",
          "share",
          "seat",
          "lobby"
        ],
        icon: :icon_protocol_p2p,
        description:
          dgettext(
            "help",
            "Open a game and choose Play with someone: it creates a match room and puts you in it as host. Share, inside the room, mints a link you can paste into any conversation. Whoever follows it takes the empty seat, and when you both press Ready the host's Start begins the game the link named — there is nothing to accept, because following the link was the agreement. You need a registered, identified nickname to create one, and so does whoever joins."
          ),
        see_also: ["feature-retro-games", "feature-game-match-full", "feature-p2p-starting-room"]
      },
      %{
        id: "feature-game-match-full",
        title: dgettext("help", "Why a Match Link Stopped Working"),
        category: dgettext("help", "Retro Games"),
        keywords: [
          dgettext("help", "match full"),
          dgettext("help", "seat taken"),
          "full",
          "expired",
          "link",
          "match",
          "already"
        ],
        icon: :icon_ban,
        description:
          dgettext(
            "help",
            "A match link has exactly one seat, so it stops working the moment somebody takes it — the card then says the match is full rather than that the link expired. An unclaimed link also expires on its own after about fifteen minutes, which is what keeps an address you pasted somewhere from being a way in for the rest of the day. Cancel, in the room, kills it immediately, and either way you make a new one from the game."
          ),
        see_also: ["feature-game-match-link", "feature-retro-games"]
      },
      %{
        id: "feature-retro-games",
        title: dgettext("help", "Retro Games"),
        category: dgettext("help", "Retro Games"),
        keywords: [
          dgettext("help", "retro games"),
          "single player",
          "solo",
          "ai",
          "/play",
          dgettext("help", "own tab"),
          dgettext("help", "share a game"),
          "hex pong",
          "pong",
          "light trails",
          "pixel tanks",
          "tank",
          "maze",
          "star duel",
          "gravity well",
          "debris field",
          "space",
          "block breakers",
          "breakout",
          "hex warlords",
          "warlords",
          "castle",
          "fireball",
          "hex raid",
          "river raid",
          "fuel",
          "mine",
          "hex boxing",
          "boxing",
          "punch",
          "hex outlaw",
          "outlaw",
          "western",
          "hex tennis",
          "tennis",
          "serve",
          "hex invaders",
          "invaders",
          "aliens",
          "hex enduro",
          "enduro",
          "racing",
          "turbo",
          "hex skiing",
          "skiing",
          "slalom",
          "avalanche",
          "hex frost",
          "frostbite",
          "igloo",
          "blizzard",
          "hex hockey",
          "hockey",
          "puck"
        ],
        icon: :icon_game_pong,
        description:
          dgettext(
            "help",
            "Play browser-native RetroHexChat games solo against AI inside the chat desktop. Hex Pong, Light Trails, Star Duel variants, Block Breakers, Hex Warlords, Hex Raid variants, Hex Outlaw variants, Hex Tennis variants, Hex Invaders variants, Hex Enduro variants, Hex Skiing variants, Hex Frost variants, and Hex Hockey variants are available."
          ) <>
            " " <>
            dgettext("help", "Hex Boxing is also available.") <>
            " " <> dgettext("help", "Pixel Tanks is also available."),
        see_also: [
          "feature-hex-pong",
          "feature-light-trails",
          "feature-pixel-tanks",
          "feature-star-duel",
          "feature-gravity-well",
          "feature-debris-field",
          "feature-block-breakers",
          "feature-hex-warlords",
          "feature-hex-raid",
          "feature-hex-boxing",
          "feature-hex-outlaw",
          "feature-hex-tennis",
          "feature-hex-invaders",
          "feature-hex-enduro",
          "feature-hex-skiing",
          "feature-hex-frost",
          "feature-hex-hockey",
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
          )
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
          )
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
            ) <>
            " " <>
            dgettext(
              "help",
              "It is also available in Retro Games solo mode against an AI tank."
            )
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
        see_also: ["feature-gravity-well", "feature-debris-field"]
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
        see_also: ["feature-star-duel", "feature-debris-field"]
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
        see_also: ["feature-star-duel", "feature-gravity-well"]
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
            )
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
        see_also: ["feature-block-breakers"]
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
          "feature-hex-raid-blitz"
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
        see_also: ["feature-hex-raid", "feature-hex-raid-blitz"]
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
        see_also: ["feature-hex-raid", "feature-hex-raid-pacifist"]
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
        see_also: ["feature-retro-games", "feature-universal-lobby"]
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
          "feature-hex-outlaw-nml"
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
          "feature-hex-outlaw-nml"
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
          "feature-hex-outlaw-nml"
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
          "feature-hex-outlaw-stagecoach"
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
          "feature-hex-invaders-blitz"
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
          "feature-hex-invaders-blitz"
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
          "feature-hex-invaders-coop"
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
          "feature-hex-enduro-sprint"
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
          "feature-hex-enduro-sprint"
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
          "feature-hex-enduro-night"
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
          "feature-hex-tennis-sudden"
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
          "feature-hex-tennis-sudden"
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
          "feature-hex-tennis-quick"
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
          "feature-hex-skiing-clean"
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
          "feature-hex-skiing-clean"
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
          "feature-hex-skiing-escape"
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
          "feature-hex-frost-peaceful"
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
          "feature-hex-frost-peaceful"
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
          "feature-hex-frost-blizzard"
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
          "feature-hex-hockey-showdown"
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
          "feature-hex-hockey-showdown"
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
          "feature-hex-hockey-blitz"
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
            "Beneath a Steel Sky, Dreamweb, Drascula, Flight of the Amazon Queen, " <>
            "Lure of the Temptress, Soltys, Half-Life: Uplink, Wolfenstein 3D, DOOM, " <>
            "Quake, Quake II, Freedoom, Chex Quest, HacX, REKKR, " <>
            dgettext("help", "and") <>
            " LibreQuake. " <>
            dgettext(
              "help",
              "Click any game to see its detailed description, keyboard controls, and "
            ) <>
            dgettext(
              "help",
              "gameplay tips before launching. Open Start ▸ Games and choose Arcade to " <>
                "start (you must be registered and identified). "
            ) <>
            dgettext(
              "help",
              "The game library opens as a draggable, maximizable window right on the chat " <>
                "desktop — no separate page. Launching a game opens it in a new browser " <>
                "window so it gets full keyboard focus."
            ) <>
            " " <>
            dgettext(
              "help",
              "The library is the only list: the menu carries one entry for the arcade " <>
                "rather than a row per game."
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
        title: "DOOM (Arcade)",
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
        title: "Quake (Arcade)",
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
            dgettext("help", "Powered by") <>
            " Qwasm (QuakeSpasm → WebAssembly).",
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
        title: "Wolfenstein 3D (Arcade)",
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
            dgettext("help", "Powered by") <>
            " ECWolf-JS (ECWolf → WebAssembly).",
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
        title: "Half-Life (Arcade)",
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
        title: "Quake II (Arcade)",
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
            dgettext("help", "Powered by") <>
            " Qwasm2 (Yamagi Quake II → WebAssembly).",
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
          dgettext("help", "Play classic point & click adventures in your browser — ") <>
            "Beneath a Steel Sky (1994), " <>
            "Drascula (1996), Dreamweb (1994), Flight of the Amazon Queen (1995), " <>
            "Lure of the Temptress (1992), " <>
            dgettext("help", "and") <>
            " Soltys (1995). " <>
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
        title: "DOOM: Knee-Deep in the Dead",
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
        title: "Freedoom: Phase 1",
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
        title: "Freedoom: Phase 2",
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
        title: "FreeDM",
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
        title: "Chex Quest",
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
        title: "HacX: Twitch 'n Kill",
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
        title: "REKKR: Sunken Land",
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
        title: "Quake: Dimension of the Doomed",
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
        title: "LibreQuake",
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
        title: "Quake II: The Invasion",
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
        title: "Wolfenstein 3D: Escape from Castle",
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
        title: "Half-Life: Uplink",
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
        title: "Beneath a Steel Sky",
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
        title: "Drascula: The Vampire Strikes Back",
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
        title: "Dreamweb",
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
        title: "Flight of the Amazon Queen",
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
        title: "Lure of the Temptress",
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
        title: "Soltys",
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
      },
      %{
        id: "feature-virtual-spaces",
        title: dgettext("help", "Virtual Spaces"),
        category: dgettext("help", "Virtual Spaces"),
        keywords: [
          "space",
          "virtual",
          "office",
          "map",
          "avatar",
          "multiplayer",
          "walk",
          "sit",
          dgettext("help", "virtual office"),
          dgettext("help", "tile map")
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "A multiplayer 8-bit virtual space built into every channel: people in the channel can switch from Chat to Space, walk around the shared map, and keep using the same channel conversation. Move with the Arrow keys, WASD or the on-screen pad in the bottom-right corner — tap for a single step or hold to walk continuously; Space or the pad's sword button swings your weapon. The translucent button in the top-right corner switches the space to fullscreen and back."
          ),
        see_also: [
          "feature-choose-character",
          "feature-space-combat",
          "feature-space-tab",
          "feature-space-share"
        ]
      },
      %{
        id: "feature-choose-character",
        title: dgettext("help", "Choosing a Character"),
        category: dgettext("help", "Virtual Spaces"),
        keywords: [
          "character",
          "avatar",
          "class",
          "hero",
          "sorceress",
          "knight",
          "archer",
          "barbarian",
          "rogue",
          "cleric",
          "monk",
          dgettext("help", "pick character")
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "When you enter a Space, a character picker appears first: choose from the classic Hero or one of seven classes — Sorceress, Knight, Archer, Barbarian, Rogue, Cleric or Monk. Each shows an animated preview and has its own walking and attack animations; click one to enter the map wearing it, and everyone in the space sees your choice. The picker shows again each time you re-enter, defaulting to your last pick."
          ),
        see_also: ["feature-virtual-spaces", "feature-space-combat"]
      },
      %{
        id: "feature-space-combat",
        title: dgettext("help", "Space Combat"),
        category: dgettext("help", "Virtual Spaces"),
        keywords: [
          "combat",
          "attack",
          "sword",
          "hit",
          "damage",
          "hp",
          "knockout",
          "ko",
          dgettext("help", "sword fight"),
          dgettext("help", "health bar")
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "Characters in a Space can spar with each other: press Space (or the pad's sword button) next to another standing character to land a hit. Each hit deals damage and shows a small health bar under their name; at zero HP the character is knocked down for a few seconds, then gets back up on their own with full health. Sitting characters are out of combat, and a knockout never has any lasting effect — it is all in good fun."
          ),
        see_also: ["feature-virtual-spaces", "feature-choose-character"]
      },
      %{
        id: "feature-space-tab",
        title: dgettext("help", "A Space in Its Own Tab"),
        category: dgettext("help", "Virtual Spaces"),
        keywords: [
          "space",
          "tab",
          "window",
          "browser",
          "address",
          "url",
          dgettext("help", "open in a tab")
        ],
        icon: :icon_community,
        description:
          dgettext(
            "help",
            "A space can run in a browser tab of its own. On the character picker, choose Open in a tab: the map gets the whole window and stops competing with the chat for the browser, which is the difference you feel when several people are walking around at once. It is the same space either way — the Space tab beside the conversation keeps working for when you would rather not leave the page. A space has no beginning and no end, so its address stays good: bookmark it and it takes you back."
          ),
        see_also: ["feature-virtual-spaces", "feature-space-share"]
      },
      %{
        id: "feature-space-share",
        title: dgettext("help", "Inviting Someone to a Space"),
        category: dgettext("help", "Virtual Spaces"),
        keywords: [
          "share",
          "link",
          "invite",
          "url",
          "space",
          "paste"
        ],
        icon: :icon_btn_link,
        description:
          dgettext(
            "help",
            "Share, on the character picker, mints a link you can paste anywhere. Pasting it into a conversation draws a card instead of a bare address. The link carries which space it is and never permission to be in it: a channel's space still asks whoever follows the link to be in that channel, and a private space still belongs to its two people. Only a registered nickname can mint one."
          ),
        see_also: ["feature-virtual-spaces", "feature-space-tab"]
      }
    ]
  end
end
