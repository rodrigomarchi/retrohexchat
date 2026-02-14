# Quickstart: Context Menus

**Date**: 2026-02-14 | **Feature**: 026-context-menus

## Prerequisites

- RetroHexChat dev environment running (`make setup && make server`)
- Existing features 001–025 implemented (especially 025 keybindings)

## What This Feature Adds

5 context menu types triggered by right-click:

1. **Nick menu** (chat area) — PM, Whois, Copy, Ignore, Address Book, Nick Color, Op actions
2. **URL menu** (chat area) — Open, Copy, Save to URL list
3. **Channel menu** (chat area) — Join, Favorites, Copy, Channel Info
4. **Message menu** (chat area) — Copy Message, Copy Selection, Quote/Reply (disabled), Ignore Sender
5. **Extended treebar menu** — Mark Read, Mute, Favorites, Copy, Leave, Settings

All menus: 98.css styling, keyboard shortcut hints, disabled states, keyboard navigation (arrow keys), viewport repositioning.

## Key Files to Modify

### Domain Layer (retro_hex_chat)
- `chat/user_preferences.ex` — Add muted_channels getter/setter

### Web Layer (retro_hex_chat_web)
- `live/chat_live.ex` — Add data attributes to message rendering, add `chat_context_menu` assign
- `live/chat_live.html.heex` — Render new chat context menu component
- `live/chat_live/context_menu_events.ex` — Add chat context menu event handlers (extend existing module)
- `live/chat_live/favorites_events.ex` — Extend treebar context menu handlers
- `components/chat_context_menu.ex` — **NEW**: Chat area context menu component (4 variants)
- `components/treebar_context_menu.ex` — Extend with new menu items
- `components/context_menu.ex` — Add keyboard shortcut hints display (shared pattern)

### JavaScript
- `assets/js/hooks/scroll_hook.js` — Replace simple copy menu with smart contextmenu detection
- `assets/js/hooks/context_menu_hook.js` — **NEW**: Keyboard navigation + viewport repositioning

### CSS
- `assets/css/components.css` — Add disabled state styling, shortcut hint alignment, focused state

### Help System
- `chat/help_topics/features.ex` — Add "Context Menus" help topic

## Architecture Decisions

- **One component for 4 chat menu types**: `ChatContextMenu` renders different items based on `@menu.type`
- **JS hook for detection**: scroll_hook.js inspects `e.target` ancestry to determine element type
- **JS hook for keyboard nav**: context_menu_hook.js manages focus index, arrow key navigation
- **Viewport flip in JS**: Post-render measurement and position adjustment
- **Mute state**: Persisted in `user_preferences.message_settings.muted_channels`
- **No new migrations**: All state fits in existing JSON columns or socket assigns

## Test Strategy

- **Unit tests**: Muted channels preference helpers
- **LiveView tests**: Each menu type appears with correct items, disabled states, op filtering
- **JS behavior**: Viewport repositioning, keyboard navigation (E2E tests)
- **Integration**: Menu actions trigger correct commands (PM, whois, ignore, join, etc.)

## Running Tests

```bash
mix test --include e2e    # Full suite
mix test apps/retro_hex_chat_web/test/live/chat_live/context_menu_test.exs  # Focused
```

## Dev Workflow

```bash
make server               # Start dev server
# Open browser to localhost:4000
# Join a channel, send messages with URLs and #channel references
# Right-click on nicks, URLs, channels, and message area to test menus
# Test keyboard navigation: open menu, use arrow keys, Enter, Escape
# Resize browser window small and right-click near edges to test viewport flip
```
