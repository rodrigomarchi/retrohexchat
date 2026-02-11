# Tasks: Ignore System

**Input**: Design documents from `/specs/006-ignore-system/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (TDD non-negotiable). Tests are written FIRST in each phase.

**Organization**: Tasks grouped by user story. US5 (Persistence) is implemented after US4 (Dialog) to match spec priority order — both are independently functional.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Domain structs, in-memory CRUD, and Session extension that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T001 [P] Write unit tests for IgnoreEntry struct (new/1, expired?/1, permanent?/1, remaining_seconds/1, valid_type?/1) in apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_entry_test.exs
- [x] T002 [P] Write unit tests for IgnoreList in-memory CRUD (new/0, add_entry/4, remove_entry/2, ignored?/3, get_entry/2, update_nickname/3, sorted_entries/1, count/1, full?/1, remove_expired/1) in apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_list_test.exs — cover: case-insensitive matching, upsert on duplicate nickname, max 100 entries (:list_full), :not_found on remove, :invalid_type validation, type matching matrix (`:all` matches all message types, specific types match only their kind)
- [x] T003 [P] Implement IgnoreEntry struct with @enforce_keys [:nickname, :ignore_type, :created_at], @valid_types, new/1, expired?/1, permanent?/1, remaining_seconds/1, valid_type?/1, @spec on all public functions in apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex
- [x] T004 Implement IgnoreList in-memory CRUD module: new/0, add_entry/4 (upsert behavior, case-insensitive dedup, max 100), remove_entry/2, ignored?/3 (type matching matrix per contracts/ignore-list-api.md), get_entry/2, update_nickname/3, sorted_entries/1, count/1, full?/1, remove_expired/1 — all with @spec in apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex
- [x] T005 Extend Session struct: add ignore_list field (type map(), default IgnoreList.new()), add get_ignore_list/1 and set_ignore_list/2 with @spec, add alias for IgnoreList in apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex

**Checkpoint**: Domain foundation ready — IgnoreEntry, IgnoreList, Session all have passing tests

---

## Phase 2: User Story 1 — Ignore and Unignore a User (Priority: P1) 🎯 MVP

**Goal**: Users can `/ignore <nick>` to hide all content from a user, `/unignore <nick>` to remove, and `/ignore` to list. System messages confirm actions. Nick rename tracking updates ignore entries.

**Independent Test**: Connect two users, have one ignore the other, verify messages from ignored user are hidden while system messages (joins/parts) remain visible.

### Tests for User Story 1

- [x] T006 [P] [US1] Write unit tests for Handlers.Ignore: validate/1 (empty string → :ok, nickname only → :ok, missing args where needed → error), execute/2 (bare → :ignore_list ui_action, with nick → :ignore_add ui_action with type: :all and duration: nil, self-ignore via context.nickname match → error) in apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ignore_test.exs
- [x] T007 [P] [US1] Write unit tests for Handlers.Unignore: validate/1 (empty → error "Usage:", with nick → :ok), execute/2 (with nick → :ignore_remove ui_action) in apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/unignore_test.exs
- [x] T008 [P] [US1] Write LiveView integration tests for ignore filtering: channel message from ignored user not shown, PM from ignored user not shown, system messages (join/part/kick) from ignored user still shown, /ignore command dispatches correctly, /unignore command dispatches correctly, /ignore bare shows ignore list, self-ignore error message, unignore non-ignored user error message, nick rename updates ignore list in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs

### Implementation for User Story 1

- [x] T009 [P] [US1] Implement Handlers.Ignore with @behaviour Handler: validate/1 (accept empty and nick-only for US1), execute/2 (bare → {:ok, :ui_action, :ignore_list, %{}}, nick → {:ok, :ui_action, :ignore_add, %{nickname: nick, type: :all, duration: nil}}, self-ignore check using context.nickname), help/0 in apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ignore.ex
- [x] T010 [P] [US1] Implement Handlers.Unignore with @behaviour Handler: validate/1 (require nickname), execute/2 (→ {:ok, :ui_action, :ignore_remove, %{nickname: nick}}), help/0 in apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/unignore.ex
- [x] T011 [US1] Register "ignore" and "unignore" commands in @commands map in apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex
- [x] T012 [US1] Add ignore-related assigns to ChatLive assign_defaults: ignore_timers (empty map), show_ignore_dialog (false), ignore_selected (nil), show_ignore_add_dialog (false) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T013 [US1] Add ignore check at top of handle_info(%{event: "new_message"}, ...) — if IgnoreList.ignored?(session.ignore_list, payload.author, message_type_atom), return {:noreply, socket} early (where message_type_atom is :action for type: :action payloads, :message otherwise) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T014 [US1] Add ignore check at top of handle_info(%{event: "new_pm"}, ...) — if IgnoreList.ignored?(session.ignore_list, payload.sender, :pm), return {:noreply, socket} early in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T015 [US1] Wire :ignore_add, :ignore_remove, :ignore_list ui_actions in ChatLive handle_ui_action: :ignore_add → call IgnoreList.add_entry, update session, push system message ("* Nick is now ignored"); :ignore_remove → call IgnoreList.remove_entry, update session, push system message or error if :not_found ("* Nick is not in your ignore list"); :ignore_list → format and display current list or "Your ignore list is empty" in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T016 [US1] Add IgnoreList.update_nickname call in existing handle_info for :nick_changed — update session.ignore_list when an ignored user renames, same pattern as NotifyList.update_nickname in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex

**Checkpoint**: US1 complete — `/ignore Nick`, `/unignore Nick`, `/ignore` list, channel+PM filtering, system messages not filtered, nick rename tracking all working

---

## Phase 3: User Story 2 — Ignore by Type (Priority: P2)

**Goal**: Users can specify ignore type: `/ignore Nick pms` to only block PMs while allowing channel messages. Available types: all, messages, pms, invites, actions. Re-ignoring updates the entry.

**Independent Test**: Ignore a user with type `pms`, verify their PMs are hidden but channel messages remain visible.

### Tests for User Story 2

- [x] T017 [P] [US2] Write unit tests for /ignore handler type parameter: validate accepts "nick type" format, rejects invalid types, execute returns correct type atom in payload in apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ignore_test.exs
- [x] T018 [P] [US2] Write LiveView tests for type-specific filtering: /ignore nick messages → channel msgs hidden but PMs visible; /ignore nick pms → PMs hidden but channel msgs visible; /ignore nick actions → /me actions hidden but regular msgs visible; re-ignore updates type and shows "ignore updated to: type" system message in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs

### Implementation for User Story 2

- [x] T019 [US2] Extend Handlers.Ignore validate/1 and execute/2 to parse optional type parameter: split args into [nick] or [nick, type], validate type against IgnoreEntry.valid_type?/1, return {:error, "Invalid ignore type..."} for invalid types in apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ignore.ex
- [x] T020 [US2] Update :ignore_add ui_action handler in ChatLive to pass type from payload to IgnoreList.add_entry, update system message to show "ignore updated to: type" when entry already exists (upsert) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex

**Checkpoint**: US2 complete — type-specific ignoring works, re-ignoring updates type with confirmation message

---

## Phase 4: User Story 3 — Temporary Ignore with Timer (Priority: P3)

**Goal**: Users can set timed ignores: `/ignore Nick all 5m`. Timer auto-expires with system message. Supports Nm (minutes), Nh (hours), Nd (days).

**Independent Test**: Set a timed ignore, verify it's active, manually trigger expiry, verify system message and ignore removal.

### Tests for User Story 3

- [x] T021 [P] [US3] Write unit tests for duration parsing in Handlers.Ignore: "5m"→300s, "2h"→7200s, "1d"→86400s, "0m"→error, "xyz"→error, "-5m"→error, validate accepts "nick type duration" format in apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ignore_test.exs
- [x] T022 [P] [US3] Write LiveView tests for timer: timed ignore creates Process.send_after timer, {:ignore_expired, nick} removes entry and pushes "no longer ignored (timer expired)" message, /unignore cancels active timer, re-ignore with duration replaces timer, system message for timed add shows "expires in X minutes" in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs

### Implementation for User Story 3

- [x] T023 [US3] Add duration parsing to Handlers.Ignore: parse_duration/1 private function for "Nm"/"Nh"/"Nd" format, extend validate/1 for 3-arg form [nick, type, duration], extend execute/2 to compute expires_at DateTime and include duration_seconds in payload in apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ignore.ex
- [x] T024 [US3] Add timer management helpers in ChatLive: start_ignore_timer/3 (creates Process.send_after, stores ref in ignore_timers assign), cancel_ignore_timer/2 (cancels timer if exists, removes from map), format_duration/1 (seconds → "X minutes"/"X hours"/"X days" display string) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T025 [US3] Add handle_info({:ignore_expired, nickname}, socket) — remove entry from ignore list, clean up timer ref, push system message "* Nick is no longer ignored (timer expired)", persist if identified in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T026 [US3] Wire timer creation/cancellation into :ignore_add and :ignore_remove ui_action handlers: on add with duration → cancel old timer if exists, start new timer, update system message to include "(expires in X)"; on remove → cancel timer if exists in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex

**Checkpoint**: US3 complete — timed ignores work with auto-expiry, timer cancellation on unignore, correct system messages

---

## Phase 5: User Story 4 — Ignore List Management Dialog (Priority: P4)

**Goal**: Visual dialog for managing ignore list — 98.css window with Nickname/Type/Expires columns, Add/Remove buttons. Accessible via menu bar and Alt+I shortcut.

**Independent Test**: Open dialog, verify it shows current ignores, add a new ignore via dialog, remove one, verify list updates.

### Tests for User Story 4

- [x] T027 [P] [US4] Write component tests for IgnoreListDialog: renders 98.css window with correct structure, displays entries with nickname/type/expires columns, empty state message, selected row highlighting, Add/Remove button states in apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ignore_list_dialog_test.exs
- [x] T028 [P] [US4] Write LiveView integration tests for dialog: Alt+I opens dialog, menu bar item opens dialog, close button closes, select entry, add via dialog creates ignore entry, remove via dialog removes entry, dialog reflects timed ignore countdown in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs

### Implementation for User Story 4

- [x] T029 [US4] Create IgnoreListDialog component: 98.css window with title "Ignore List", sunken-panel table (Nickname, Type, Expires columns), row selection with highlight, Add/Remove buttons (Remove disabled when no selection), empty state "No users ignored", permanent entries show "Permanent", timed entries show remaining time. Attrs: ignore_entries, ignore_selected, show_ignore_add_dialog. Add sub-dialog for Add (nickname input field, type select dropdown, optional duration input) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ignore_list_dialog.ex
- [x] T030 [US4] Wire IgnoreListDialog into ChatLive template: render conditionally on show_ignore_dialog assign, pass session.ignore_list entries + ignore_selected + show_ignore_add_dialog as attrs in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T031 [US4] Add ChatLive event handlers: "open_ignore_dialog" (set show_ignore_dialog=true), "close_ignore_dialog" (set false + clear selection), "ignore_select" (set ignore_selected), "ignore_dialog_add" (open add sub-dialog), "ignore_dialog_add_confirm" (add entry from dialog inputs, close sub-dialog), "ignore_dialog_remove" (remove selected entry) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T032 [US4] Add Alt+I keyboard shortcut in ChatLive handle_event("keydown") and menu bar "Ignore List" item with phx-click="open_ignore_dialog" in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex

**Checkpoint**: US4 complete — dialog opens/closes, shows entries, add/remove via dialog, keyboard shortcut works

---

## Phase 6: User Story 5 — Ignore List Persistence (Priority: P5)

**Goal**: Registered users' ignore lists persist across sessions. Load on NickServ identify, save on mutations. Expired timed ignores filtered on load with adjusted remaining time.

**Independent Test**: Identify with NickServ, add ignores, disconnect, reconnect, re-identify, verify ignore list restored.

### Tests for User Story 5

- [x] T033 [P] [US5] Write tests for IgnoreListEntry Ecto schema: changeset validations (required fields, length limits, type inclusion), valid changeset creation in apps/retro_hex_chat/test/retro_hex_chat/chat/schemas/ignore_list_entry_test.exs
- [x] T034 [P] [US5] Write integration tests for IgnoreList.save/2 and load/1: save stores entries, load retrieves them, load filters expired entries, load returns {:error, :not_found} for empty, save replaces all entries (delete+reinsert), case-insensitive unique constraint in apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_list_persistence_test.exs
- [x] T035 [P] [US5] Write LiveView tests for persistence wiring: NickServ identify triggers load_persisted_data with ignore list, mutations call maybe_persist_ignore_list when identified, guest mutations do not persist in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs

### Implementation for User Story 5

- [x] T036 [US5] Create migration for ignore_list_entries table: owner_nickname FK to registered_nicks (on_delete: :delete_all), ignored_nickname varchar(16), ignore_type varchar(10), expires_at nullable timestamptz, timestamps(utc_datetime_usec), unique index on lower(owner_nickname)+lower(ignored_nickname), owner lookup index in apps/retro_hex_chat/priv/repo/migrations/20260211180000_create_ignore_list.exs
- [x] T037 [US5] Create IgnoreListEntry Ecto schema: fields (owner_nickname, ignored_nickname, ignore_type as string, expires_at as utc_datetime_usec), changeset/2 with validate_required, validate_length, validate_inclusion for ignore_type in apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/ignore_list_entry.ex
- [x] T038 [US5] Add save/2 and load/1 persistence functions to IgnoreList module: save/2 — Repo.transaction delete-all then reinsert (convert IgnoreEntry atoms to strings for DB), load/1 — query by owner, filter out expired, convert DB strings to atoms for IgnoreEntry structs, set up adjusted expires_at for timed entries in apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex
- [x] T039 [US5] Wire persistence in ChatLive: add |> load_if_found(IgnoreList.load(nick), &Session.set_ignore_list/2) to load_persisted_data/2, add maybe_persist_ignore_list/2 helper (Task.start if identified), call maybe_persist on all ignore mutations (add, remove, timer expiry, dialog add/remove) in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T040 [US5] Run migration with mix ecto.migrate, verify schema loads correctly, run full test suite to confirm no regressions

**Checkpoint**: US5 complete — ignore list persists for registered users, loads on identify, expired entries filtered

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Context menu integration, help documentation, E2E tests, data-testid attributes

- [x] T041 [P] Add "Ignore" menu item to context_menu.ex component: show "Ignore" for non-ignored users, show "Unignore" for ignored users (check via IgnoreList.get_entry), pass ignore status as new attr, phx-click="context_ignore" / "context_unignore" with phx-value-nick, data-testid="ctx-ignore" / "ctx-unignore" in apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex
- [x] T042 [P] Wire context menu events in ChatLive: handle_event("context_ignore") → add to ignore list with type :all permanent, close menu, push system message; handle_event("context_unignore") → remove from ignore list, close menu, push system message; pass ignore_list to context_menu component for ignored? check in apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T043 [P] Write tests for context menu ignore integration: right-click shows Ignore for non-ignored user, shows Unignore for ignored user, clicking Ignore adds entry, clicking Unignore removes entry in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_test.exs
- [x] T044 [P] Add help topics to HelpTopics module: "cmd-ignore" (Commands category — syntax, types, duration format, examples), "cmd-unignore" (Commands category — syntax, examples), "feature-ignore-list" (Features category — overview, dialog, context menu, persistence), update "keyboard-shortcuts" topic with Alt+I, add cross-references to related topics (cmd-notify, feature-address-book, ui-context-menu) in apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex
- [x] T045 Add data-testid attributes to all ignore-related UI: ignore-list-dialog, ignore-entry-{nick}, ignore-add-btn, ignore-remove-btn, ignore-add-dialog, ctx-ignore, ctx-unignore, tab items and menu bar items in apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ignore_list_dialog.ex and apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex
- [x] T046 Write E2E tests for ignore system: /ignore adds and filters, /unignore removes, /ignore bare lists, type-specific filtering, timed ignore with expiry, dialog open/add/remove, context menu ignore/unignore, nick rename tracking, self-ignore error, persistence after identify in apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ignore_e2e_test.exs
- [x] T047 Run full test suite (make test), all linters (make lint), fix any warnings or failures. Verify all new tests pass, coverage does not regress, Credo strict clean, Dialyxir clean, mix format clean
- [x] T048 Update CLAUDE.md Active Technologies section with 006-ignore-system entry, update memory notes with implementation progress in CLAUDE.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — can start immediately. BLOCKS all user stories.
- **US1 (Phase 2)**: Depends on Phase 1 completion.
- **US2 (Phase 3)**: Depends on US1 (extends /ignore handler and filtering).
- **US3 (Phase 4)**: Depends on US1 (extends /ignore handler with duration, adds timer to ChatLive).
- **US4 (Phase 5)**: Depends on US1 (dialog reads from ignore list). Can start alongside US2/US3 if needed.
- **US5 (Phase 6)**: Depends on US1 (persistence of ignore list). Can start alongside US2/US3/US4.
- **Polish (Phase 7)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Foundation only → MVP
- **US2 (P2)**: US1 → extends command handler + filtering
- **US3 (P3)**: US1 → extends command handler + adds timers
- **US4 (P4)**: US1 → dialog reads session.ignore_list
- **US5 (P5)**: US1 → persistence of session.ignore_list

### Within Each User Story

- Tests written FIRST, verified to FAIL
- Domain/handler changes before LiveView changes
- Core implementation before integration wiring

### Parallel Opportunities

**Phase 1**: T001, T002, T003 can run in parallel (different files)
**Phase 2**: T006, T007, T008 (tests) can run in parallel; T009, T010 can run in parallel
**Phase 3**: T017, T018 (tests) can run in parallel
**Phase 4**: T021, T022 (tests) can run in parallel
**Phase 5**: T027, T028 (tests) can run in parallel; T033, T034, T035 (tests) can run in parallel
**Phase 7**: T041, T042, T043, T044 can run in parallel (different files)

---

## Parallel Example: Phase 1 (Foundational)

```bash
# Launch all parallel foundational tasks:
Task: T001 "Write IgnoreEntry tests"        # apps/retro_hex_chat/test/.../ignore_entry_test.exs
Task: T002 "Write IgnoreList tests"          # apps/retro_hex_chat/test/.../ignore_list_test.exs
Task: T003 "Implement IgnoreEntry struct"    # apps/retro_hex_chat/lib/.../ignore_entry.ex

# Then sequential:
Task: T004 "Implement IgnoreList CRUD"       # depends on T003 (uses IgnoreEntry)
Task: T005 "Extend Session struct"           # depends on T004 (uses IgnoreList)
```

## Parallel Example: Phase 2 (US1)

```bash
# Launch all tests in parallel:
Task: T006 "Tests for /ignore handler"       # apps/retro_hex_chat/test/.../ignore_test.exs
Task: T007 "Tests for /unignore handler"     # apps/retro_hex_chat/test/.../unignore_test.exs
Task: T008 "LiveView ignore filtering tests" # apps/retro_hex_chat_web/test/.../chat_live_ignore_test.exs

# Then implementation (handlers in parallel, then sequential ChatLive):
Task: T009 "Implement /ignore handler"       # apps/retro_hex_chat/lib/.../ignore.ex
Task: T010 "Implement /unignore handler"     # apps/retro_hex_chat/lib/.../unignore.ex
Task: T011 "Register commands"               # depends on T009, T010
Task: T012-T016 "ChatLive wiring"            # sequential (same file)
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Foundational (T001-T005)
2. Complete Phase 2: US1 (T006-T016)
3. **STOP and VALIDATE**: `/ignore Nick` works, filtering works, system messages appear
4. This alone delivers the core value proposition

### Incremental Delivery

1. Foundation → Domain ready
2. US1 → Core ignore/unignore → **MVP** (demonstrable)
3. US2 → Type-specific ignore → Enhanced control
4. US3 → Timed ignore → Convenience feature
5. US4 → Dialog → Visual management
6. US5 → Persistence → Cross-session durability
7. Polish → Context menu, help, E2E → Production-ready

### Single Developer Strategy (Recommended)

Execute phases sequentially in priority order. Each phase builds on the previous. Stop at any checkpoint to validate independently.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Self-ignore validation is in /ignore handler (domain), not ChatLive
- Duplicate ignore upsert is in IgnoreList.add_entry (domain), not ChatLive
- System messages from ignored users (joins/parts/kicks) are NOT filtered per FR-005
- Timer refs stored in socket assigns (ignore_timers), NOT in IgnoreList domain struct
- Persistence follows existing delete-all-then-reinsert transaction pattern
- E2E test nick prefixes must be ≤10 chars to stay within 16-char nick limit
