# Quickstart: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12

## Prerequisites

```bash
git checkout 009-perform-auto-commands
make setup  # Ensure DB is running and deps are installed
```

## Implementation Order

### Phase 1: Domain Structs & CRUD (No DB)

Start with pure in-memory modules — testable without database.

1. **PerformEntry struct** — `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_entry.ex`
2. **PerformList CRUD** — `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_list.ex`
   - `new/0`, `add_entry/2`, `remove_entry/2`, `move_entry/3`, `clear/1`
   - `mask_command/1`, `disallowed_command?/1`, `valid_command?/1`
   - `entries/1`, `count/1`, `full?/1`, `enabled?/1`, `set_enabled/2`
3. **AutoJoinEntry struct** — `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_entry.ex`
4. **AutoJoinList CRUD** — `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_list.ex`
   - `new/0`, `add_entry/3`, `remove_entry/2`, `update_entry/3`, `clear/1`
   - `entries/1`, `count/1`, `full?/1`
5. **Session extension** — Add `perform_list` and `autojoin_list` fields

**Test**: `mix test --only unit` — all CRUD operations, masking, validation

### Phase 2: Persistence (DB)

Add database tables and save/load functions.

1. **Migration: create_perform_entries** — `perform_entries` + `perform_settings` tables
2. **Migration: create_autojoin_entries** — `autojoin_entries` table
3. **Ecto schemas** — `PerformListEntry`, `AutoJoinListEntry`, `PerformSettings`
4. **PerformList.save/2, load/1** — DB operations
5. **AutoJoinList.save/2, load/1** — DB operations

**Test**: `mix test --only integration` — save/load round-trips

### Phase 3: Command Handlers

Wire up `/perform` and `/autojoin` commands.

1. **Handler.Perform** — validate + execute with subcommands
2. **Handler.AutoJoin** — validate + execute with subcommands
3. **Registry** — Register both handlers
4. **ChatLive** — Add `handle_ui_action` clauses for all perform/autojoin actions
5. **Session persistence** — `load_persisted_data` + `maybe_persist_*` helpers

**Test**: `mix test --only unit` — handler validation and execution

### Phase 4: Perform Execution on Connect

The core auto-execute logic.

1. **ChatLive mount** — Check localStorage state via `handle_event("restore_session")`
2. **handle_info({:execute_perform, index})** — Sequential command execution with 100ms delay
3. **handle_info({:execute_autojoin, index})** — Sequential channel joining
4. **System messages** — "* Performing: /join #elixir..." (masked)
5. **push_event("save_reconnect_state")** — Save state to localStorage on changes

**Test**: `mix test --only liveview` — mount with perform commands, execution order

### Phase 5: Perform Dialog UI

Visual management interface.

1. **PerformDialog component** — Two tabs (Commands, Auto-Join), retro styling
2. **Sub-dialogs** — Add/Edit for both tabs
3. **ChatLive integration** — Alt+P shortcut, menu bar item, event handlers
4. **CSS** — layout.css + dark-theme.css for dialog styles

**Test**: `mix test --only liveview` — dialog open/close, CRUD, tab switching

### Phase 6: Auto-Reconnect (JS)

Client-side reconnection with overlay.

1. **ReconnectHook** — Disconnect detection, overlay UI, countdown, cancel
2. **app.js** — Register hook, customize `reconnectAfterMs` for exponential backoff
3. **ChatLive** — `push_event("intentional_disconnect")` in quit handler
4. **CSS** — Reconnect overlay styles (retro themed)

**Test**: `mix test --only e2e` — intentional disconnect does not trigger reconnect

### Phase 7: Session Restoration

Complete the reconnection experience.

1. **ChatLive mount** — Detect reconnect via `handle_event("restore_session")`
2. **handle_info({:execute_rejoin, index})** — Rejoin previous channels with deduplication
3. **Active tab restoration** — Set active_channel from saved state
4. **Nickname conflict detection** — Check if nickname is taken
5. **push_event("save_reconnect_state")** — Update state after significant changes

**Test**: `mix test --only liveview` — reconnect with channels, deduplication, conflict

### Phase 8: Help & E2E

Documentation and end-to-end testing.

1. **Help topics** — `/perform`, `/autojoin`, Perform feature, Auto-reconnect
2. **Keyboard shortcuts topic** — Add Alt+P
3. **E2E tests** — Full user journeys
4. **data-testid attributes** — All dialog elements

**Test**: `mix test --only e2e` — complete user journeys

## Key Commands

```bash
make test         # Run full test suite (excludes E2E)
make test.all     # Run all tests including E2E
make lint         # Format + Credo + Dialyzer
make ci            # Full CI validation (9 parallel checks)
make server       # Dev server at localhost:4000
```

## Verification Checklist

After each phase:
- [ ] `mix test` passes (0 failures)
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes (after phases with new public functions)
