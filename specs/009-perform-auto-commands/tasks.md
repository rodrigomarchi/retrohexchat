# Tasks: Perform / Auto-Commands

**Input**: Design documents from `/specs/009-perform-auto-commands/`
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/domain.md, contracts/web.md, research.md, quickstart.md

**Tests**: Included (TDD is non-negotiable per Constitution Principle IV).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Branch creation and initial verification.

- [X] T001 Verify branch `009-perform-auto-commands` exists and dependencies are up to date

---

## Phase 2: Foundational (Domain Structs, CRUD, Persistence)

**Purpose**: Core domain modules and database tables that MUST be complete before ANY user story can be implemented.

**CRITICAL**: No user story work can begin until this phase is complete.

### Tests (TDD — write first, verify they fail)

- [X] T002 [P] Write unit tests for PerformEntry struct (new/1, field defaults, position) in `apps/retro_hex_chat/test/retro_hex_chat/chat/perform_entry_test.exs`
- [X] T003 [P] Write unit tests for AutoJoinEntry struct (new/1, channel_name, channel_key, position) in `apps/retro_hex_chat/test/retro_hex_chat/chat/autojoin_entry_test.exs`
- [X] T004 [P] Write unit tests for PerformList CRUD (new, add_entry, remove_entry, move_entry, clear, entries, count, full?, enabled?, set_enabled, mask_command, disallowed_command?, valid_command?) in `apps/retro_hex_chat/test/retro_hex_chat/chat/perform_list_test.exs`
- [X] T005 [P] Write unit tests for AutoJoinList CRUD (new, add_entry, remove_entry, update_entry, clear, entries, count, full?) in `apps/retro_hex_chat/test/retro_hex_chat/chat/autojoin_list_test.exs`

### Implementation

- [X] T006 [P] Implement PerformEntry struct with `new/1` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_entry.ex`
- [X] T007 [P] Implement AutoJoinEntry struct with `new/1` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_entry.ex`
- [X] T008 Implement PerformList in-memory CRUD (new/0, add_entry/2, remove_entry/2, move_entry/3, clear/1, entries/1, count/1, full?/1, enabled?/1, set_enabled/2, mask_command/1, disallowed_command?/1, valid_command?/1) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_list.ex`
- [X] T009 Implement AutoJoinList in-memory CRUD (new/0, add_entry/3, remove_entry/2, update_entry/3, clear/1, entries/1, count/1, full?/1) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_list.ex`
- [X] T010 Extend Session struct with `perform_list` and `autojoin_list` fields (defaults: PerformList.new(), AutoJoinList.new()) and add `set_perform_list/2`, `set_autojoin_list/2` functions in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`

### Persistence

- [X] T011 [P] Create migration for `perform_entries` table (owner_nickname FK, command TEXT, position INTEGER, timestamps) and `perform_settings` table (owner_nickname PK+FK, enable_on_connect BOOLEAN) in `apps/retro_hex_chat/priv/repo/migrations/20260212100000_create_perform_tables.exs`
- [X] T012 [P] Create migration for `autojoin_entries` table (owner_nickname FK, channel_name VARCHAR(50), channel_key VARCHAR(50), position INTEGER, timestamps) in `apps/retro_hex_chat/priv/repo/migrations/20260212100001_create_autojoin_entries.exs`
- [X] T013 [P] Implement PerformListEntry Ecto schema with changeset in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/perform_list_entry.ex`
- [X] T014 [P] Implement AutoJoinListEntry Ecto schema with changeset in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/autojoin_list_entry.ex`
- [X] T015 [P] Implement PerformSettings Ecto schema (PK=owner_nickname, enable_on_connect boolean) with changeset in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/perform_settings.ex`
- [X] T016 Add save/2 and load/1 persistence functions to PerformList (save entries + settings, load from DB) and write integration tests in `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_list.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/perform_list_test.exs`
- [X] T017 Add save/2 and load/1 persistence functions to AutoJoinList (save entries, load from DB) and write integration tests in `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_list.ex` and `apps/retro_hex_chat/test/retro_hex_chat/chat/autojoin_list_test.exs`

**Checkpoint**: All domain structs, CRUD, and persistence are functional. `mix test --only unit` and `mix test --only integration` pass.

---

## Phase 3: User Story 1 — Perform Commands on Connect (Priority: P1) MVP

**Goal**: Users can add perform commands via `/perform` CLI and they auto-execute sequentially on connect with system messages.

**Independent Test**: Add commands via `/perform add`, reconnect, verify sequential execution with masked system messages.

### Tests

- [X] T018 [P] [US1] Write unit tests for Handlers.Perform (validate/execute for all subcommands: bare, list, add, remove, move, clear, error cases) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/perform_test.exs`

### Implementation

- [X] T019 [US1] Implement Handlers.Perform with Handler behaviour (validate/1, execute/2, help/0) returning `{:ok, :ui_action, action, payload}` for all subcommands in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/perform.ex`
- [X] T020 [US1] Register `"perform" => Handlers.Perform` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X] T021 [US1] Add `handle_ui_action` clauses for `:open_perform_dialog`, `:perform_add`, `:perform_remove`, `:perform_move`, `:perform_clear`, `:perform_list_display` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T022 [US1] Add `maybe_persist_perform_list/2` helper and extend `load_persisted_data/2` to load PerformList from DB on NickServ identify in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T023 [US1] Implement `handle_info({:execute_perform, index})` — parse command via Parser, dispatch via dispatch_command, schedule next with `Process.send_after(self(), {:execute_perform, index + 1}, 100)`, show masked system messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T024 [US1] Trigger perform execution after mount — check if perform list is enabled and non-empty, `send(self(), {:execute_perform, 0})`, chain to `{:execute_autojoin, 0}` after last perform command (note: autojoin handler is a no-op until US3/T039 is implemented — unhandled message is silently ignored) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T025 [US1] Write LiveView tests for perform execution flow (sequential execution, error isolation, system messages, disabled toggle) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_perform_test.exs`

**Checkpoint**: `/perform` command works, commands execute on connect with masked system messages. MVP is functional.

---

## Phase 4: User Story 2 — Perform Dialog (Priority: P2)

**Goal**: Users can manage perform commands via a retro dialog with visual CRUD, accessible via Alt+P and menu bar.

**Independent Test**: Open dialog, add/edit/remove/reorder commands, verify password masking, toggle enable checkbox.

### Tests

- [X] T026 [P] [US2] Write component tests for PerformDialog (Commands tab rendering, masked passwords, button states, sub-dialogs) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/perform_dialog_test.exs`

### Implementation

- [X] T027 [US2] Implement PerformDialog component — Commands tab with listbox (masked passwords), Add/Edit/Remove/Move Up/Move Down buttons, "Enable on connect" checkbox, Add/Edit sub-dialogs in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/perform_dialog.ex`
- [X] T028 [US2] Add dialog state assigns (`show_perform_dialog`, `perform_dialog_tab`, `perform_selected`, `show_perform_add_dialog`, `show_perform_edit_dialog`) to `assign_defaults/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T029 [US2] Add dialog event handlers (open_perform_dialog, close_perform_dialog, perform_dialog_tab, perform_select, perform_dialog_add/edit/remove/move_up/move_down, perform_toggle_enabled, confirm/close sub-dialogs) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T030 [US2] Add Alt+P keyboard shortcut to `window_keydown` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T031 [US2] Add "Perform" item under Tools menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex`
- [X] T032 [US2] Add dialog CSS (if needed beyond retro design system) to `apps/retro_hex_chat_web/assets/css/layout.css` and dark theme counterparts to `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [X] T033 [US2] Write LiveView tests for dialog interactions (open/close, CRUD via dialog, tab switch, keyboard shortcut, menu bar) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_perform_dialog_test.exs`

**Checkpoint**: Perform dialog fully functional. Users can visually manage commands.

---

## Phase 5: User Story 3 — Auto-Join Channel List (Priority: P3)

**Goal**: Users can configure a dedicated auto-join list that executes after perform commands, managed via `/autojoin` CLI and Auto-Join tab in Perform dialog.

**Independent Test**: Add channels via `/autojoin add`, connect, verify they auto-join after perform. Manage via dialog Auto-Join tab.

**Dependencies**: US1 (perform execution chain triggers autojoin after last perform command)

### Tests

- [X] T034 [P] [US3] Write unit tests for Handlers.AutoJoin (validate/execute for all subcommands: bare, list, add, remove, clear, error cases) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/autojoin_test.exs`

### Implementation

- [X] T035 [US3] Implement Handlers.AutoJoin with Handler behaviour (validate/1, execute/2, help/0) returning `{:ok, :ui_action, action, payload}` for all subcommands in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/autojoin.ex`
- [X] T036 [US3] Register `"autojoin" => Handlers.AutoJoin` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X] T037 [US3] Add `handle_ui_action` clauses for `:autojoin_add`, `:autojoin_remove`, `:autojoin_clear`, `:autojoin_list_display` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T038 [US3] Add `maybe_persist_autojoin_list/2` helper and extend `load_persisted_data/2` for AutoJoinList in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T039 [US3] Implement `handle_info({:execute_autojoin, index})` for sequential channel joining (call join_channel/4, schedule next, show "* Auto-joining #channel..." system messages) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T040 [US3] Add Auto-Join tab to PerformDialog (channel listbox with name+key, Add/Edit/Remove buttons, Add/Edit sub-dialogs with channel+key inputs) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/perform_dialog.ex`
- [X] T041 [US3] Add autojoin dialog state assigns (`autojoin_selected`, `show_autojoin_add_dialog`, `show_autojoin_edit_dialog`) and event handlers (autojoin_select, autojoin_dialog_add/edit/remove, confirm/close sub-dialogs) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T042 [US3] Write LiveView tests for autojoin execution flow and dialog interactions in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_perform_test.exs`

**Checkpoint**: Auto-join list works via CLI and dialog. Channels join after perform commands.

---

## Phase 6: User Story 4 — Auto-Reconnect (Priority: P4)

**Goal**: Client-side reconnection overlay with exponential backoff when connection drops unexpectedly. No reconnect on intentional disconnect.

**Independent Test**: Simulate connection drop, verify overlay with countdown/cancel. Use `/quit` and verify NO overlay appears.

### Implementation

- [X] T043 [P] [US4] Implement ReconnectHook JS (MutationObserver on phx-disconnected class, overlay DOM creation, countdown timer, cancel button, attempt counter, max 10 attempts, localStorage management) in `apps/retro_hex_chat_web/assets/js/hooks/reconnect_hook.js`
- [X] T044 [US4] Register ReconnectHook in hooks and customize `reconnectAfterMs` for exponential backoff (1s, 2s, 4s, 8s, 16s, 30s cap) in `apps/retro_hex_chat_web/assets/js/app.js`
- [X] T045 [US4] Add `push_event("intentional_disconnect")` in quit/disconnect handlers to set localStorage flag suppressing auto-reconnect in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T046 [US4] Add `push_event("save_reconnect_state", state)` on significant state changes (join, part, perform/autojoin modification) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T047 [US4] Add reconnect overlay CSS (retro themed window, centered, z-index 300, countdown text, cancel button) to `apps/retro_hex_chat_web/assets/css/layout.css` and dark theme to `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [X] T048 [US4] Write LiveView tests for reconnect push_events (verify `push_event("intentional_disconnect")` is called in quit handler, verify `push_event("save_reconnect_state")` includes expected fields on join/part) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_perform_test.exs`

**Checkpoint**: Auto-reconnect overlay shows on unexpected disconnect. Intentional `/quit` suppresses it.

---

## Phase 7: User Story 5 — Session Restoration on Reconnect (Priority: P5)

**Goal**: On successful reconnect, restore previous nickname, re-execute perform commands, rejoin channels with deduplication, restore active tab.

**Independent Test**: Join multiple channels, simulate disconnect, verify all channels rejoin and active tab restores.

**Dependencies**: US4 (auto-reconnect must be functional), US1 (perform execution)

### Implementation

- [X] T049 [US5] Implement `handle_event("restore_session", params)` — detect reconnect from localStorage, set `is_reconnect` assign, load previous state in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T050 [US5] Implement `handle_info({:execute_rejoin, index})` — rejoin previous session channels with deduplication (skip channels already joined by perform/autojoin/lobby), show "* Rejoining #channel..." system messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T051 [US5] Implement active tab restoration (set `active_channel` from saved state) and nickname conflict detection (check if nickname taken, return to connect screen if so) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T052 [US5] Write LiveView tests for reconnect flow (restore_session event, channel deduplication, nickname conflict, active tab restoration) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_perform_test.exs`

**Checkpoint**: Full reconnection experience — overlay, session restore, channel rejoin, tab restoration.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, E2E tests, data-testid attributes, final linter verification.

- [X] T053 [P] Add 4 help topics (cmd-perform, cmd-autojoin, feature-perform, feature-auto-reconnect) to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [X] T054 Update keyboard shortcuts help topic with Alt+P and update cross-references in related topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [X] T055 [P] Add data-testid attributes to all PerformDialog elements (dialog, tabs, listboxes, buttons, sub-dialogs, checkbox) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/perform_dialog.ex`
- [X] T056 Write E2E tests for complete user journeys (perform CRUD via dialog, auto-join via command, perform execution on connect, password masking, enable/disable toggle, tab switching, intentional disconnect no overlay) in `apps/retro_hex_chat_web/test/e2e/perform_e2e_test.exs`
- [X] T057 Run full linter suite (`mix format --check-formatted && mix credo --strict && mix dialyzer`) and fix any issues

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verify branch and environment
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion — MVP, delivers core perform execution
- **US2 (Phase 4)**: Depends on Phase 2 + Phase 3 (handler + UI actions must exist for dialog to wire to)
- **US3 (Phase 5)**: Depends on Phase 2 + Phase 3 (perform execution chain triggers autojoin; handler pattern from US1)
- **US4 (Phase 6)**: Depends on Phase 2 only — independent of perform (reconnect works without perform commands)
- **US5 (Phase 7)**: Depends on Phase 6 (auto-reconnect) + Phase 3 (perform execution for re-execute)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — No dependencies on other stories
- **US2 (P2)**: Depends on US1 (dialog wires to perform CRUD handlers from US1)
- **US3 (P3)**: Depends on US1 (autojoin executes after perform chain completes)
- **US4 (P4)**: Can start after Phase 2 — Independent of US1/US2/US3
- **US5 (P5)**: Depends on US4 (reconnect triggers restoration) + US1 (re-execute perform)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Domain modules before web layer
- Handlers before ChatLive integration
- Core functionality before dialog/UI
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 2**: T002+T003 (entry tests), T004+T005 (CRUD tests), T006+T007 (entry impls), T011+T012 (migrations), T013+T014+T015 (Ecto schemas) — all parallelizable within their groups
- **Phase 3+6**: US1 and US4 can proceed in parallel after Phase 2 (independent user stories)
- **Phase 8**: T053+T055 (help topics + data-testid) can run in parallel

---

## Parallel Example: Phase 2

```bash
# Launch entry tests in parallel:
Task: "Unit tests for PerformEntry in perform_entry_test.exs"
Task: "Unit tests for AutoJoinEntry in autojoin_entry_test.exs"

# Launch entry structs in parallel:
Task: "PerformEntry struct in perform_entry.ex"
Task: "AutoJoinEntry struct in autojoin_entry.ex"

# Launch migrations in parallel:
Task: "Migration for perform_entries + perform_settings"
Task: "Migration for autojoin_entries"

# Launch Ecto schemas in parallel:
Task: "PerformListEntry schema"
Task: "AutoJoinListEntry schema"
Task: "PerformSettings schema"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: US1 — Perform Commands on Connect
4. **STOP and VALIDATE**: Test perform execution independently
5. Users can `/perform add` commands and they auto-execute on connect

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 → `/perform` CLI + auto-execute on connect (MVP!)
3. US2 → Perform dialog for visual management
4. US3 → Auto-join channel list + dialog tab
5. US4 → Auto-reconnect overlay
6. US5 → Session restoration on reconnect
7. Polish → Help topics, E2E tests, linter verification

---

## Summary

| Phase | Story | Tasks | Parallel |
|-------|-------|-------|----------|
| Setup | — | 1 | 0 |
| Foundational | — | 16 | 10 |
| US1 | Perform on Connect | 8 | 1 |
| US2 | Perform Dialog | 8 | 1 |
| US3 | Auto-Join | 9 | 1 |
| US4 | Auto-Reconnect | 6 | 1 |
| US5 | Session Restoration | 4 | 0 |
| Polish | — | 5 | 2 |
| **Total** | | **57** | **16** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD — Principle IV)
- Stop at any checkpoint to validate story independently
- Password masking is critical — verify `mask_command/1` covers all display paths
- ReconnectHook JS is a justified constitution deviation — keep isolated in single file
