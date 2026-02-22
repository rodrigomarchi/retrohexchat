# Quickstart: Ignore System

**Feature**: 006-ignore-system
**Branch**: `006-ignore-system`

## Prerequisites

```bash
# Ensure on correct branch
git checkout 006-ignore-system

# Setup (if not done)
make setup

# Run existing tests to confirm clean baseline
make test
make lint
```

## Implementation Order

### Phase 1: Domain Foundation
1. Create `IgnoreEntry` struct (`apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex`)
2. Create `IgnoreList` module with in-memory CRUD (`apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex`)
3. Extend `Session` struct with `ignore_list` field

### Phase 2: Persistence
4. Create migration for `ignore_list_entries` table
5. Create `IgnoreListEntry` Ecto schema
6. Add `save/2` and `load/1` to IgnoreList module

### Phase 3: Command Handlers
7. Create `Handlers.Ignore` (with duration parsing)
8. Create `Handlers.Unignore`
9. Register both in `Commands.Registry`

### Phase 4: ChatLive Integration (US1 — Core Filtering)
10. Add ignore check in `handle_info` for `new_message`
11. Add ignore check in `handle_info` for `new_pm`
12. Wire `/ignore` and `/unignore` ui_actions
13. Add nick rename tracking in `:nick_changed` handler
14. Wire persistence (load on NickServ identify, save on mutations)

### Phase 5: Timer Support (US3)
15. Add `ignore_timers` assign management
16. Add `handle_info({:ignore_expired, nickname})` handler
17. Wire timer creation/cancellation in ignore add/remove/update

### Phase 6: Dialog (US4)
18. Create `IgnoreListDialog` component
19. Wire dialog open/close events in ChatLive
20. Wire Add/Remove via dialog
21. Add Alt+I shortcut + menu bar item

### Phase 7: Context Menu & Polish
22. Add "Ignore" / "Unignore" to context menu
23. Wire context menu events in ChatLive

### Phase 8: Help & Documentation
24. Add help topics to HelpTopics module
25. Update Keyboard Shortcuts topic

### Phase 9: E2E Tests
26. Add data-testid attributes
27. Write E2E test suite

## Key Commands

```bash
# Run domain tests only
mix test apps/retro_hex_chat/test/ --exclude e2e

# Run web tests only
mix test apps/retro_hex_chat_web/test/ --exclude e2e

# Run specific test file
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_list_test.exs

# Run all tests including E2E
make test.all

# Lint
make lint

# Dev server
make server
```

## Key Patterns to Follow

- **Session field**: See NotifyList/HighlightWords for getter/setter pattern
- **CRUD module**: See `Chat.HighlightWords` for in-memory + persistence pattern
- **Command handler**: See `Commands.Handlers.Notify` for subcommand pattern
- **Dialog component**: See `Components.HighlightDialog` for retro window pattern
- **Context menu**: See `Components.ContextMenu` for menu item pattern
- **Persistence wiring**: See `load_persisted_data/2` and `maybe_persist_*` in ChatLive
- **Help topics**: See `Chat.HelpTopics` for topic structure and cross-references
