# Module Contracts: Miscellaneous Polish (022)

**Date**: 2026-02-13

## Domain Layer (retro_hex_chat)

### Chat.EmojiData

```elixir
@type emoji :: %{char: String.t(), name: String.t(), keywords: [String.t()]}
@type category :: %{name: String.t(), emojis: [emoji()]}

@spec all() :: [category()]
@spec search(String.t()) :: [emoji()]
@spec by_category(String.t()) :: [emoji()]
@spec categories() :: [String.t()]
```

### Chat.UserPreferences (extension)

```elixir
# New keys in display_settings map:
# - "timestamp_format" => "hh_mm" | "hh_mm_ss" | "dd_mm_hh_mm" | "none"
# - "quit_message" => String.t()

@spec get_timestamp_format(map()) :: :hh_mm | :hh_mm_ss | :dd_mm_hh_mm | :none
@spec set_timestamp_format(map(), atom()) :: map()
@spec get_quit_message(map()) :: String.t()
@spec set_quit_message(map(), String.t()) :: map()
```

### Chat.DisplayPreferences (extension)

```elixir
# Add :none format to existing timestamp formats
@type timestamp_format :: :hh_mm | :hh_mm_ss | :dd_mm_hh_mm | :none

@spec format_timestamp(timestamp_format(), DateTime.t()) :: String.t()
# Returns "" for :none format
```

## Web Layer (retro_hex_chat_web)

### LiveView Events (ChatLive)

```elixir
# Double-click actions
handle_event("nicklist_dblclick", %{"nick" => nick}, socket)
handle_event("channel_dblclick", %{"channel" => channel}, socket)

# Paste handling
handle_event("paste_lines", %{"lines" => lines}, socket)
handle_event("paste_send", _params, socket)
handle_event("paste_cancel", _params, socket)

# Emoji picker
handle_event("toggle_emoji_picker", _params, socket)
handle_event("emoji_select", %{"emoji" => char}, socket)
handle_event("emoji_search", %{"query" => query}, socket)
handle_event("emoji_category", %{"category" => name}, socket)

# Timestamp format (Options Dialog extension)
handle_event("options_change_timestamp_format", %{"format" => format}, socket)

# Quit message (Options Dialog extension)
handle_event("options_change_quit_message", %{"value" => message}, socket)

# Help menu quick access
handle_event("open_help_at_topic", %{"topic" => topic_id}, socket)

# Quit broadcast (internal, during cleanup)
broadcast_quit(session, reason)
```

### JS Hooks

```javascript
// CharCounterHook — attached to input wrapper
// Updates counter display on every input event
// Sets maxlength attribute for hard cap
mounted() → listen input events, init counter display
updated() → sync counter after LiveView patches

// PasteHook — attached to chat input
// Intercepts paste events with multi-line content
mounted() → listen paste event on input
handlePaste(e) → count lines, push_event("paste_lines", {lines})

// ChatCopyHook — attached to .chat-messages container
// Right-click context menu with Copy option
mounted() → listen contextmenu event
handleContextMenu(e) → check selection, show/hide menu
handleCopy() → navigator.clipboard.writeText(selection)

// EmojiPickerHook — attached to emoji picker container
// Inserts emoji at cursor position in chat input
mounted() → listen for emoji insertion events
insertEmoji(char) → insert at cursor in #chat-input

// NicklistDblClickHook — attached to nicklist container
// Detects double-click on nick items
mounted() → listen dblclick on .nicklist-list li elements
handleDblClick(e) → pushEvent("nicklist_dblclick", {nick})
```

### Components

```elixir
# PasteConfirmDialog — 98.css confirmation dialog
attr :visible, :boolean, required: true
attr :line_count, :integer, required: true
attr :flood_warning, :boolean, default: false
attr :send_disabled, :boolean, default: false

# EmojiPicker — popup grid of emojis by category
attr :visible, :boolean, required: true
attr :categories, :list, required: true
attr :active_category, :string, required: true
attr :search_query, :string, default: ""
attr :search_results, :list, default: []

# AboutDialog — enhanced Windows 98-style about box
attr :visible, :boolean, required: true
# (replaces inline about dialog in chat_live.html.heex)
```
