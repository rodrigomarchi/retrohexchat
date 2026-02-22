# Quickstart: Interactive Chat Elements

**Feature**: 027-interactive-chat-elements
**Date**: 2026-02-14

## Prerequisites

- Dev server running: `make server`
- At least 2 users connected (to test nick interactions)
- At least 1 channel with multiple users (to test channel tooltips)

## Implementation Order

### Step 1: URL Tooltips (P1 — simplest, client-only)

1. **Modify `scroll_hook.js`**: In the existing `link_preview` event handler, update the `title` attribute of matching `<a>` tags to show the page title instead of the raw URL.
2. **Add CSS**: Add `:hover` underline style to `.chat-link` (if not already present — check existing styles).
3. **Test**: Hover over a URL in chat → should show page title in native tooltip.

### Step 2: Channel Tooltips & Click (P2)

1. **Create `interactive.js`**: Extract hover/click utility functions:
   - `createTooltip(text, x, y)` — creates and positions a tooltip element
   - `removeTooltip()` — removes active tooltip
   - `isClickNotDrag(mouseDownPos, mouseUpPos)` — returns true if mouse moved < 3px
   - `isContextMenuOpen()` — checks context menu flag
2. **Add channel hover listener in `scroll_hook.js`**: On `mouseenter` of `.chat-channel-link`, push `"channel_hover"` event. On `mouseleave`, remove tooltip.
3. **Add channel click listener in `scroll_hook.js`**: On `click` of `.chat-channel-link`, push `"channel_click"` event (with drag check).
4. **Create `hover_events.ex`**: Handle `"channel_hover"` and `"channel_click"` events.
5. **Handle `"channel_tooltip"` in `scroll_hook.js`**: Render tooltip from pushed event data.
6. **Test**: Hover over `#channel` → tooltip shows count. Click → joins/switches.

### Step 3: Nick Hover Card (P3)

1. **Add nick hover listener in `scroll_hook.js`**: On `mouseenter` of `.chat-nick`, start 500ms idle timer. On `mousemove` within nick, reset timer. On `mouseleave`, cancel timer and push dismiss.
2. **Create `hover_card.ex` component**: Render nick hover card with retro window styling.
3. **Add `hover_card` assign** to `ChatLive.mount/3` and template.
4. **Handle `"nick_hover"` in `hover_events.ex`**: Gather whois data, update assign.
5. **Add nick click handler**: Insert "Nick: " into input (client-side only).
6. **Add nick double-click handler**: Push `"nick_dblclick"` event → open PM.
7. **Add hover card CSS** in `hover-card.css`.
8. **Test**: Hover nick 500ms → card appears. Click → inserts. Double-click → PM opens.

### Step 4: Edge Cases & Polish

1. **Context menu coexistence**: Add `contextMenuOpen` flag coordination.
2. **Nick change dismissal**: Add check in existing nick change handler.
3. **Viewport boundary detection**: Reposition hover card/tooltip if near edges.
4. **Text selection suppression**: Ensure hover cards don't trigger during selection.
5. **Help documentation**: Add help topic to `HelpTopics`.

## Key Files to Read First

| File | Why |
|------|-----|
| `assets/js/hooks/scroll_hook.js` | Main hook where all listeners will be added |
| `assets/js/lib/chat.js` | Existing detection patterns to follow |
| `assets/js/lib/input.js` | `insertAtCursor` function for nick click |
| `lib/chat_live/context_menu_events.ex` | Pattern for event handler modules |
| `lib/components/chat_context_menu.ex` | Pattern for positioned overlay components |
| `lib/chat_live/helpers/whois.ex` | Whois data gathering to reuse |
| `lib/chat_live/helpers/channel.ex` | Channel join/switch logic to reuse |
| `lib/chat_live/helpers/pm.ex` | PM open logic to reuse |
| `assets/css/context-menu.css` | Positioning patterns for hover card CSS |

## Validation

Run the full CI pipeline after implementation:

```bash
mix compile --warnings-as-errors
# Then in parallel:
mix format --check-formatted
mix credo --strict
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer
```
