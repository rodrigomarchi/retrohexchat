defmodule RetroHexChat.Chat.HelpTopics.Features do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "feature-notify-list.html")
  @external_resource Path.join(@help_dir, "feature-address-book.html")
  @external_resource Path.join(@help_dir, "feature-highlight-words.html")
  @external_resource Path.join(@help_dir, "feature-url-catcher.html")
  @external_resource Path.join(@help_dir, "feature-ignore-list.html")
  @external_resource Path.join(@help_dir, "feature-channel-central.html")
  @external_resource Path.join(@help_dir, "feature-ban-exceptions.html")
  @external_resource Path.join(@help_dir, "feature-invite-exceptions.html")
  @external_resource Path.join(@help_dir, "feature-channel-invites.html")
  @external_resource Path.join(@help_dir, "feature-search.html")
  @external_resource Path.join(@help_dir, "feature-log-viewer.html")
  @external_resource Path.join(@help_dir, "feature-log-export.html")
  @external_resource Path.join(@help_dir, "feature-perform.html")
  @external_resource Path.join(@help_dir, "feature-auto-reconnect.html")
  @external_resource Path.join(@help_dir, "feature-notices.html")
  @external_resource Path.join(@help_dir, "feature-ctcp.html")
  @external_resource Path.join(@help_dir, "feature-flood-protection.html")
  @external_resource Path.join(@help_dir, "feature-sounds.html")
  @external_resource Path.join(@help_dir, "feature-mute.html")
  @external_resource Path.join(@help_dir, "feature-typing-indicator.html")
  @external_resource Path.join(@help_dir, "feature-visual-notifications.html")
  @external_resource Path.join(@help_dir, "feature-favorites.html")
  @external_resource Path.join(@help_dir, "feature-organize-favorites.html")
  @external_resource Path.join(@help_dir, "feature-aliases.html")
  @external_resource Path.join(@help_dir, "feature-timers.html")
  @external_resource Path.join(@help_dir, "feature-custom-menus.html")
  @external_resource Path.join(@help_dir, "feature-options-dialog.html")
  @external_resource Path.join(@help_dir, "feature-display-settings.html")
  @external_resource Path.join(@help_dir, "feature-key-bindings.html")
  @external_resource Path.join(@help_dir, "feature-autorespond.html")
  @external_resource Path.join(@help_dir, "feature-interactive-elements.html")
  @external_resource Path.join(@help_dir, "feature-nick-alignment.html")
  @external_resource Path.join(@help_dir, "feature-copy.html")
  @external_resource Path.join(@help_dir, "feature-paste-dialog.html")
  @external_resource Path.join(@help_dir, "feature-char-counter.html")
  @external_resource Path.join(@help_dir, "feature-quit-message.html")
  @external_resource Path.join(@help_dir, "feature-away-reply.html")
  @external_resource Path.join(@help_dir, "feature-emoji.html")
  @external_resource Path.join(@help_dir, "feature-timestamp-format.html")
  @external_resource Path.join(@help_dir, "feature-autocomplete.html")
  @external_resource Path.join(@help_dir, "feature-command-syntax-tooltip.html")
  @external_resource Path.join(@help_dir, "feature-smart-input.html")
  @external_resource Path.join(@help_dir, "feature-cheatsheet.html")
  @external_resource Path.join(@help_dir, "feature-context-menus.html")
  @external_resource Path.join(@help_dir, "feature-enhanced-history.html")
  @external_resource Path.join(@help_dir, "feature-contextual-tips.html")
  @external_resource Path.join(@help_dir, "feature-unread-indicators.html")
  @external_resource Path.join(@help_dir, "feature-kick-notifications.html")
  @external_resource Path.join(@help_dir, "feature-copy-feedback.html")
  @external_resource Path.join(@help_dir, "feature-status-bar.html")
  @external_resource Path.join(@help_dir, "feature-lag-indicator.html")
  @external_resource Path.join(@help_dir, "feature-connection-states.html")
  @external_resource Path.join(@help_dir, "feature-notifications.html")
  @external_resource Path.join(@help_dir, "feature-dnd.html")
  @external_resource Path.join(@help_dir, "feature-notification-center.html")
  @external_resource Path.join(@help_dir, "feature-notification-settings.html")
  @external_resource Path.join(@help_dir, "feature-message-reply.html")
  @external_resource Path.join(@help_dir, "feature-message-edit.html")
  @external_resource Path.join(@help_dir, "feature-message-delete.html")
  @external_resource Path.join(@help_dir, "feature-audio-call.html")
  @external_resource Path.join(@help_dir, "feature-video-call.html")
  @external_resource Path.join(@help_dir, "feature-media-devices.html")
  @external_resource Path.join(@help_dir, "feature-call-quality.html")
  @external_resource Path.join(@help_dir, "feature-p2p-sessions.html")
  @external_resource Path.join(@help_dir, "feature-file-transfer.html")
  @external_resource Path.join(@help_dir, "feature-privacy-settings.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "feature-notify-list",
        title: "Notify List (Buddy List)",
        category: "Features",
        keywords: ["notify", "buddy", "friend list", "online", "offline", "track"],
        content: File.read!(Path.join(@help_dir, "feature-notify-list.html"))
      },
      %{
        id: "feature-address-book",
        title: "Address Book",
        category: "Features",
        keywords: ["address book", "contacts", "nick colors", "color override"],
        content: File.read!(Path.join(@help_dir, "feature-address-book.html"))
      },
      %{
        id: "feature-highlight-words",
        title: "Highlight Words",
        category: "Features",
        keywords: ["highlight", "mention", "alert", "notification", "flash"],
        content: File.read!(Path.join(@help_dir, "feature-highlight-words.html"))
      },
      %{
        id: "feature-url-catcher",
        title: "URL Catcher",
        category: "Features",
        keywords: ["url", "link", "catcher", "preview", "web"],
        content: File.read!(Path.join(@help_dir, "feature-url-catcher.html"))
      },
      %{
        id: "feature-ignore-list",
        title: "Ignore List",
        category: "Features",
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide", "unignore"],
        content: File.read!(Path.join(@help_dir, "feature-ignore-list.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-channel-central.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-ban-exceptions.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-invite-exceptions.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-channel-invites.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-search.html"))
      },
      %{
        id: "feature-log-viewer",
        title: "Log Viewer",
        category: "Features",
        keywords: ["log", "viewer", "search", "history", "browse", "export", "logs"],
        content: File.read!(Path.join(@help_dir, "feature-log-viewer.html"))
      },
      %{
        id: "feature-log-export",
        title: "Log Export",
        category: "Features",
        keywords: ["export", "download", "txt", "html", "log", "save"],
        content: File.read!(Path.join(@help_dir, "feature-log-export.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-perform.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-auto-reconnect.html"))
      },
      %{
        id: "feature-notices",
        title: "Notices",
        category: "Features",
        keywords: ["notice", "notification", "announce", "lightweight message"],
        content: File.read!(Path.join(@help_dir, "feature-notices.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-ctcp.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-flood-protection.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-sounds.html"))
      },
      %{
        id: "feature-mute",
        title: "Mute",
        category: "Features",
        keywords: ["mute", "unmute", "silence", "sound off", "quiet"],
        content: File.read!(Path.join(@help_dir, "feature-mute.html"))
      },
      %{
        id: "feature-typing-indicator",
        title: "Typing Indicator",
        category: "Features",
        keywords: ["typing", "indicator", "is typing", "pm typing"],
        content: File.read!(Path.join(@help_dir, "feature-typing-indicator.html"))
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
          "treebar",
          "title",
          "activity",
          "indicator"
        ],
        content: File.read!(Path.join(@help_dir, "feature-visual-notifications.html"))
      },
      %{
        id: "feature-favorites",
        title: "Favorites",
        category: "Features",
        keywords: [
          "favorites",
          "bookmarks",
          "channels",
          "auto-join",
          "autojoin",
          "quick",
          "access"
        ],
        content: File.read!(Path.join(@help_dir, "feature-favorites.html"))
      },
      %{
        id: "feature-organize-favorites",
        title: "Organize Favorites",
        category: "Features",
        keywords: [
          "organize",
          "favorites",
          "reorder",
          "edit",
          "remove",
          "manage",
          "bookmarks"
        ],
        content: File.read!(Path.join(@help_dir, "feature-organize-favorites.html"))
      },
      %{
        id: "feature-aliases",
        title: "Aliases",
        category: "Features",
        keywords: ["alias", "aliases", "shortcut", "macro", "expansion", "scripting"],
        content: File.read!(Path.join(@help_dir, "feature-aliases.html"))
      },
      %{
        id: "feature-timers",
        title: "Timers",
        category: "Features",
        keywords: ["timer", "timers", "schedule", "delay", "repeat", "interval"],
        content: File.read!(Path.join(@help_dir, "feature-timers.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-custom-menus.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-options-dialog.html"))
      },
      %{
        id: "feature-display-settings",
        title: "Display Settings",
        category: "Features",
        keywords: [
          "display",
          "toolbar",
          "treebar",
          "switchbar",
          "status bar",
          "compact mode",
          "line shading"
        ],
        content: File.read!(Path.join(@help_dir, "feature-display-settings.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-key-bindings.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-autorespond.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-interactive-elements.html"))
      },
      %{
        id: "feature-nick-alignment",
        title: "Nick Column Alignment",
        category: "Features",
        keywords: ["nick", "alignment", "column", "grid", "layout", "readability"],
        content: File.read!(Path.join(@help_dir, "feature-nick-alignment.html"))
      },
      %{
        id: "feature-copy",
        title: "Right-Click Copy",
        category: "Features",
        keywords: ["copy", "clipboard", "right-click", "context menu", "select", "text"],
        content: File.read!(Path.join(@help_dir, "feature-copy.html"))
      },
      %{
        id: "feature-paste-dialog",
        title: "Multi-Line Paste Dialog",
        category: "Features",
        keywords: ["paste", "multiline", "flood", "confirmation", "send"],
        content: File.read!(Path.join(@help_dir, "feature-paste-dialog.html"))
      },
      %{
        id: "feature-char-counter",
        title: "Character Counter",
        category: "Features",
        keywords: ["character", "counter", "limit", "length", "input"],
        content: File.read!(Path.join(@help_dir, "feature-char-counter.html"))
      },
      %{
        id: "feature-quit-message",
        title: "Quit Messages",
        category: "Features",
        keywords: ["quit", "disconnect", "message", "goodbye", "leaving"],
        content: File.read!(Path.join(@help_dir, "feature-quit-message.html"))
      },
      %{
        id: "feature-away-reply",
        title: "Away Auto-Reply",
        category: "Features",
        keywords: ["away", "auto-reply", "automatic", "reply", "pm", "message"],
        content: File.read!(Path.join(@help_dir, "feature-away-reply.html"))
      },
      %{
        id: "feature-emoji",
        title: "Emoji Picker",
        category: "Features",
        keywords: ["emoji", "smiley", "picker", "unicode", "emoticon"],
        content: File.read!(Path.join(@help_dir, "feature-emoji.html"))
      },
      %{
        id: "feature-timestamp-format",
        title: "Timestamp Configuration",
        category: "Features",
        keywords: ["timestamp", "time", "format", "clock", "date"],
        content: File.read!(Path.join(@help_dir, "feature-timestamp-format.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-autocomplete.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-command-syntax-tooltip.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-smart-input.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-cheatsheet.html"))
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
          "treebar menu",
          "mute channel"
        ],
        content: File.read!(Path.join(@help_dir, "feature-context-menus.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-enhanced-history.html"))
      },
      %{
        id: "feature-contextual-tips",
        title: "Contextual Tips",
        category: "Features",
        keywords: [
          "tips",
          "dicas",
          "contextual",
          "toast",
          "hint",
          "progressive disclosure"
        ],
        content: File.read!(Path.join(@help_dir, "feature-contextual-tips.html"))
      },
      %{
        id: "feature-unread-indicators",
        title: "Unread Indicators",
        category: "Features",
        keywords: [
          "unread",
          "badge",
          "indicator",
          "treebar",
          "count",
          "mention",
          "highlight",
          "muted",
          "disconnected"
        ],
        content: File.read!(Path.join(@help_dir, "feature-unread-indicators.html"))
      },
      %{
        id: "feature-kick-notifications",
        title: "Kick Notifications",
        category: "Features",
        keywords: ["kick", "kicked", "expelled", "dialog", "notification"],
        content: File.read!(Path.join(@help_dir, "feature-kick-notifications.html"))
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
          "copiado",
          "settings",
          "saved"
        ],
        content: File.read!(Path.join(@help_dir, "feature-copy-feedback.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-status-bar.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-lag-indicator.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-connection-states.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-notifications.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-dnd.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-notification-center.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-notification-settings.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-message-reply.html"))
      },
      %{
        id: "feature-message-edit",
        title: "Message Edit",
        category: "Features",
        keywords: [
          "edit",
          "editar",
          "editado",
          "modify",
          "correct",
          "typo",
          "fix message"
        ],
        content: File.read!(Path.join(@help_dir, "feature-message-edit.html"))
      },
      %{
        id: "feature-message-delete",
        title: "Message Delete",
        category: "Features",
        keywords: [
          "delete",
          "apagar",
          "remove",
          "mensagem removida",
          "soft delete"
        ],
        content: File.read!(Path.join(@help_dir, "feature-message-delete.html"))
      },
      %{
        id: "feature-audio-call",
        title: "Chamada de Audio",
        category: "Features",
        keywords: [
          "audio",
          "call",
          "chamada",
          "voice",
          "voz",
          "mute",
          "silenciar",
          "p2p"
        ],
        content: File.read!(Path.join(@help_dir, "feature-audio-call.html"))
      },
      %{
        id: "feature-video-call",
        title: "Chamada de Video",
        category: "Features",
        keywords: [
          "video",
          "call",
          "chamada",
          "camera",
          "pip",
          "picture-in-picture",
          "p2p"
        ],
        content: File.read!(Path.join(@help_dir, "feature-video-call.html"))
      },
      %{
        id: "feature-media-devices",
        title: "Dispositivos de Midia",
        category: "Features",
        keywords: [
          "device",
          "dispositivo",
          "microphone",
          "microfone",
          "camera",
          "speaker",
          "fallback"
        ],
        content: File.read!(Path.join(@help_dir, "feature-media-devices.html"))
      },
      %{
        id: "feature-call-quality",
        title: "Qualidade da Chamada",
        category: "Features",
        keywords: [
          "quality",
          "qualidade",
          "bitrate",
          "preset",
          "indicator",
          "bars"
        ],
        content: File.read!(Path.join(@help_dir, "feature-call-quality.html"))
      },
      %{
        id: "feature-p2p-sessions",
        title: "Sessoes P2P",
        category: "Features",
        keywords: [
          "p2p",
          "peer",
          "sessao",
          "session",
          "lobby",
          "consent",
          "bilateral",
          "invite"
        ],
        content: File.read!(Path.join(@help_dir, "feature-p2p-sessions.html"))
      },
      %{
        id: "feature-file-transfer",
        title: "Transferencia de Arquivos",
        category: "Features",
        keywords: [
          "file",
          "transfer",
          "arquivo",
          "transferencia",
          "sendfile",
          "drag",
          "drop",
          "hash",
          "p2p"
        ],
        content: File.read!(Path.join(@help_dir, "feature-file-transfer.html"))
      },
      %{
        id: "feature-privacy-settings",
        title: "Configuracoes de Privacidade",
        category: "Features",
        keywords: [
          "privacy",
          "privacidade",
          "turn",
          "relay",
          "ip",
          "esconder",
          "hide",
          "modo privado"
        ],
        content: File.read!(Path.join(@help_dir, "feature-privacy-settings.html"))
      }
    ]
  end
end
