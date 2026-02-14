# Data Model: Context Menus

**Date**: 2026-02-14 | **Feature**: 026-context-menus

## Overview

Context menus are ephemeral UI elements — no new database tables or migrations required. State lives in socket assigns (LiveView) and DOM (JS hooks). The only persistent change is adding `muted_channels` to the existing `user_preferences.message_settings` JSON column.

## Socket Assigns (LiveView State)

### Chat Context Menu State

```elixir
# New assign for chat area context menus
chat_context_menu: %{
  visible: boolean(),          # Whether any chat context menu is open
  type: :nick | :url | :channel | :message | nil,  # Which menu variant
  x: integer(),               # Mouse X coordinate (viewport-relative)
  y: integer(),               # Mouse Y coordinate (viewport-relative)
  target_nick: String.t() | nil,      # For :nick menu — the clicked nickname
  target_url: String.t() | nil,       # For :url menu — the clicked URL
  target_channel: String.t() | nil,   # For :channel menu — the clicked channel
  target_message: %{                  # For :message menu — message context
    id: String.t() | nil,             # DOM id of the message element
    author: String.t() | nil,         # Message author nickname
    content: String.t() | nil,        # Full formatted message line (for copy)
    is_system: boolean(),             # Whether it's a system message (join/part/quit)
    urls: [String.t()]                # URLs found in the message (for URL sub-items)
  } | nil,
  has_selection: boolean()     # Whether text is currently selected (for Copy Selected)
}
```

Default value:
```elixir
%{visible: false, type: nil, x: 0, y: 0, target_nick: nil, target_url: nil,
  target_channel: nil, target_message: nil, has_selection: false}
```

### Extended Treebar Context Menu State

```elixir
# Existing assign — structure unchanged, but the component renders more items
treebar_context_menu: %{
  visible: boolean(),
  x: integer(),
  y: integer(),
  channel: String.t() | nil
}
```

### Muted Channels State

```elixir
# New assign — runtime set derived from user preferences on mount
muted_channels: MapSet.t()   # Set of channel names that are muted
```

## User Preferences Changes

### message_settings (existing JSON column)

New key added to `message_settings` map:

```elixir
message_settings: %{
  # ... existing keys ...
  muted_channels: [String.t()]  # List of muted channel names, default: []
}
```

**Persistence**: Via existing `UserPreferences.save/2` — no migration needed.

**Guest handling**: Stored in in-memory `Session` struct. Lost on disconnect (acceptable).

## HTML Data Attributes (DOM Model)

### New/Modified Attributes on Chat Messages

```html
<!-- Message wrapper — add data-author, data-message-id, data-system-message -->
<div class="chat-message chat-message--normal"
     id="msg-123"
     data-author="Alice"
     data-message-id="msg-123"
     data-testid="chat-message">
  <div class="chat-msg-grid">
    <span class="chat-timestamp">[14:32]</span>
    <!-- Nick prefix — add data-nick -->
    <span class="chat-nick" data-nick="Alice" style="color: #3498db">&lt;Alice&gt;</span>
    <span class="chat-content">
      <!-- URLs already have class="chat-link", add data-url -->
      <a href="https://example.com" class="chat-link" data-url="https://example.com"
         target="_blank" rel="noopener noreferrer">https://example.com</a>
      <!-- Channels already have class="chat-channel-link" data-channel="#general" -->
      <span class="chat-channel-link" data-channel="#general">#general</span>
    </span>
  </div>
</div>

<!-- System message — data-system-message="true", no data-author -->
<div class="chat-message chat-message--system"
     id="msg-124"
     data-system-message="true"
     data-testid="chat-message">
  ...
</div>
```

## Key Entities Summary

| Entity | Storage | Lifecycle | Notes |
|--------|---------|-----------|-------|
| Chat Context Menu | Socket assign | Per-interaction (open→close) | Ephemeral, reset on close |
| Treebar Context Menu | Socket assign | Per-interaction | Already exists, extend items |
| Muted Channels | UserPreferences JSON + socket assign | Persistent (registered) / session (guest) | MapSet in runtime, list in DB |
| Menu Focus Index | JS hook state | Per-menu-open | For keyboard navigation |
