# Quickstart: Keyboard Shortcuts & Chat Search

**Feature**: 025-shortcuts-chat-search
**Date**: 2026-02-13

## Prerequisites

```bash
make setup    # First-time setup (docker + deps + db)
make server   # Dev server at localhost:4000
```

No new migrations required. The existing `user_preferences` table with `key_bindings` JSON column handles all persistence.

## Implementation Order

The feature has 6 user stories with clear dependencies:

```
P1: Cheatsheet Dialog ──→ P3: Global Dispatcher ──→ P4: Window Navigation
                                                 ──→ (enhances P1, P2)
P2: Search Highlighting ──→ P5: Search Filters ──→ P6: History Search
```

**Recommended implementation sequence**:

1. **KeyBindings registry extension** (domain) — add categories, metadata, new actions
2. **Cheatsheet dialog component** (web) — retro design system modal, reads from registry
3. **ShortcutDispatcherHook** (JS) — global keydown, bubble-up, push to server
4. **Search highlighting** (JS + LiveView) — SearchHighlightHook, push_event coordination
5. **Window navigation** (LiveView) — NavigationEvents module, window_list assign
6. **Search filters** (domain + web) — case-sensitive, regex, my-mentions toggles
7. **History search** (domain + web) — database query with filters, result rendering
8. **Help topics** — update keyboard shortcuts, add search enhancements topic

## Key Files to Understand

| File | Purpose | Read First? |
|------|---------|-------------|
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex` | Binding definitions, validation, reserved keys | Yes |
| `apps/retro_hex_chat_web/live/chat_live/keyboard_events.ex` | Server-side shortcut dispatch | Yes |
| `apps/retro_hex_chat_web/components/search_bar.ex` | Search UI component | Yes |
| `apps/retro_hex_chat_web/live/chat_live/search_events.ex` | Search state management | Yes |
| `apps/retro_hex_chat_web/assets/js/hooks/autocomplete_hook.js` | Existing keyboard handling (formatting shortcuts) | Yes |
| `apps/retro_hex_chat_web/assets/js/hooks/key_binding_capture_hook.js` | Rebinding capture pattern | Skim |
| `apps/retro_hex_chat_web/live/chat_live/options_events.ex` | Options dialog keybinding handlers | Skim |

## Development Workflow

```bash
# Run all checks (CI-equivalent)
mix compile --warnings-as-errors

# Then in parallel:
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Testing Strategy

| Layer | What to Test | Tag |
|-------|-------------|-----|
| Unit | KeyBindings registry, categories, new actions | `@tag :unit` |
| Unit | Search.valid_regex?, filter options | `@tag :unit` |
| Integration | Search with DB filters (case, regex, mentions) | `@tag :integration` |
| LiveView | Cheatsheet open/close, content rendering | `@tag :liveview` |
| LiveView | Search events with filters, highlight coordination | `@tag :liveview` |
| LiveView | Window navigation (next/prev/select) | `@tag :liveview` |
| E2E | Global shortcut dispatch from different focus states | `@tag :e2e` |
| E2E | Search highlighting visible in rendered HTML | `@tag :e2e` |

## Architecture Notes

### Bubble-Up Dispatch Pattern

```
User presses Ctrl+Shift+F
  │
  ▼
AutocompleteHook (if input focused)
  │── Does this hook handle Ctrl+Shift+F? NO (it handles B/Y/U/D/V/X)
  │── Event bubbles up
  ▼
ShortcutDispatcherHook (global, on #app-container)
  │── Looks up "f" + [ctrl, shift] in bindings map
  │── Finds: toggle_search
  │── Calls: this.pushEvent("shortcut_action", {action: "toggle_search"})
  │── Calls: e.preventDefault()
  ▼
Server: KeyboardEvents.handle_event("shortcut_action", %{"action" => "toggle_search"}, socket)
  │── Dispatches to: SearchEvents.toggle_search(socket)
```

### Search Highlight Flow

```
User types "terraform" in search bar
  │
  ▼
SearchBar component: phx-change="search_input" (300ms debounce)
  │
  ▼
Server: SearchEvents.handle_event("search_input", ...)
  │── Updates assigns: search_query, search_last_query
  │── If history enabled: runs Search.search_messages/3
  │── push_event("search_highlight", %{query: "terraform", ...})
  ▼
Client: SearchHighlightHook.handleEvent("search_highlight")
  │── Scans .message-body elements with TreeWalker
  │── Wraps matches in <mark class="search-highlight">
  │── Counts matches, pushes "search_highlight_count" to server
  │── Scrolls to first match
  ▼
Server: Updates search_result_count and search_current_index assigns
```
