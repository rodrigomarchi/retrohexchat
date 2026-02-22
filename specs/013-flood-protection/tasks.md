# Tasks: Flood Protection

**Input**: Design documents from `/specs/013-flood-protection/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Required by Constitution Principle IV (TDD). Tests MUST be written before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration and shared domain modules that all user stories depend on

- [x] T001 Create DB migration for `flood_protection_settings` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_flood_protection_settings.exs` — primary key `owner_nickname` referencing `registered_nicks` with ON DELETE CASCADE, integer columns for all 7 threshold fields with defaults and constraints per data-model.md, timestamps with `utc_datetime_usec`
- [x] T002 Create Ecto schema `RetroHexChat.Chat.Schemas.FloodProtectionSetting` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/flood_protection_setting.ex` — fields matching migration, changeset with validation (all thresholds > 0, upper bounds per data-model.md), `@primary_key {:owner_nickname, :string, autogenerate: false}`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain modules and Session integration that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T003 [P] Write unit tests for `RetroHexChat.Chat.FloodProtection` in `apps/retro_hex_chat/test/retro_hex_chat/chat/flood_protection_test.exs` — test `new/0` returns correct defaults, all 7 getters return expected values, all 7 setters update values correctly, setters reject invalid values (0, negative, above max), `@tag :unit`
- [x] T004 [P] Write unit tests for `RetroHexChat.Chat.FloodTracker` in `apps/retro_hex_chat/test/retro_hex_chat/chat/flood_tracker_test.exs` — test `new/0`, `record_message/2` increments count, `flooded?/4` returns false below threshold and true at/above threshold, `prune_expired/2` removes old timestamps, `reset_sender/2` clears sender data, 50-sender cap with LRU eviction, case-insensitive sender matching, `@tag :unit`
- [x] T005 [P] Write unit tests for `RetroHexChat.Chat.DuplicateTracker` in `apps/retro_hex_chat/test/retro_hex_chat/chat/duplicate_tracker_test.exs` — test `new/0`, `record_message/4` stores content, `is_duplicate?/6` returns false below threshold and true at/above, different targets tracked independently, `prune_expired/2` removes old entries, exact match only (similar but different content returns false), case-insensitive sender matching, `@tag :unit`
- [x] T006 [P] Write integration tests for `FloodProtectionSetting` schema persistence in `apps/retro_hex_chat/test/retro_hex_chat/chat/schemas/flood_protection_setting_test.exs` — test insert with valid attrs, changeset rejects invalid values, upsert pattern (insert then update), cascade delete when registered nick deleted, `@tag :integration`

### Implementation for Foundational Phase

- [x] T007 [P] Implement `RetroHexChat.Chat.FloodProtection` domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/flood_protection.ex` — `new/0` with 7 default settings, 7 getter functions, 7 setter functions with validation, `save/2` upsert to DB via schema, `load/1` from DB, all with `@spec` annotations. Follow the CTCP Settings pattern exactly.
- [x] T008 [P] Implement `RetroHexChat.Chat.FloodTracker` domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/flood_tracker.ex` — `new/0`, `record_message/2` with monotonic timestamps, `flooded?/4` with sliding window, `prune_expired/2`, `reset_sender/2`, 50-sender LRU eviction, all with `@spec` annotations
- [x] T009 [P] Implement `RetroHexChat.Chat.DuplicateTracker` domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/duplicate_tracker.ex` — `new/0`, `record_message/4` with target_key `{:channel, name}` or `{:pm, nick}`, `is_duplicate?/6` with exact string comparison, `duplicate_count/5`, `prune_expired/2`, 50-sender cap, all with `@spec` annotations
- [x] T010 Extend `RetroHexChat.Accounts.Session` in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — add `flood_protection: map()` to `@type t`, add to `defstruct` with default `nil`, initialize in `new/1` with `FloodProtection.new()`, add `get_flood_protection/1` and `set_flood_protection/2` with `@spec`
- [x] T011 Run migration and verify all foundational tests pass: `mix ecto.migrate && mix test apps/retro_hex_chat/test/retro_hex_chat/chat/flood_protection_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/flood_tracker_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/duplicate_tracker_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/schemas/flood_protection_setting_test.exs`

**Checkpoint**: Foundation ready — FloodProtection settings, FloodTracker, DuplicateTracker, and Session integration all working. User story implementation can now begin.

---

## Phase 3: User Story 1 — Anti-Spam Duplicate Detection (Priority: P1) MVP

**Goal**: Detect and silently drop exact duplicate messages from the same sender to the same target when the configured threshold is exceeded within the time window.

**Independent Test**: Send the same message 3+ times within 10 seconds to a channel; verify the receiving user stops seeing duplicates after the threshold.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Write LiveView tests for duplicate detection in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_flood_test.exs` — test that `handle_info` for `:new_message` with duplicate content from same sender to same channel is dropped after threshold, different senders are tracked independently, different channels are tracked independently, system messages are never filtered, messages below threshold are displayed normally, `@tag :liveview`

### Implementation for User Story 1

- [x] T013 [US1] Initialize flood protection assigns in ChatLive `assign_defaults/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `duplicate_tracker: DuplicateTracker.new()`, `flood_tracker: FloodTracker.new()`, `auto_ignore_state: %{active: %{}, cooldowns: %{}}`, `ctcp_reply_tracker: %{timestamps: []}`
- [x] T014 [US1] Integrate duplicate detection into ChatLive `handle_info` for channel messages (`%{event: "new_message"}`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — before existing ignore check, call `DuplicateTracker.record_message/4` and `DuplicateTracker.is_duplicate?/6` using settings from `session.flood_protection`; if duplicate, silently drop (return `{:noreply, socket}` with updated tracker); exempt system messages from check
- [x] T015 [US1] Integrate duplicate detection into ChatLive `handle_info` for PMs (`%{event: "new_pm"}`) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — same pattern as T014 but with target_key `{:pm, sender_nick}`; exempt system messages
- [x] T016 [US1] Load flood protection settings in `load_persisted_data/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `|> load_if_found(FloodProtection.load(nick), &Session.set_flood_protection/2)` following the existing pattern for CTCP/ignore/etc.

**Checkpoint**: Duplicate detection working — exact duplicate messages from the same sender to the same target are silently dropped after threshold. System messages always pass through.

---

## Phase 4: User Story 2 — Auto-Ignore on Flood (Priority: P2)

**Goal**: Automatically add flooding users to the receiver's ignore list for a configurable duration, with automatic expiry and cooldown on manual un-ignore.

**Independent Test**: Simulate 10+ messages in 15 seconds from one sender; verify auto-ignore triggers, system message appears, and auto-ignore expires after duration.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T017 [P] [US2] Write LiveView tests for auto-ignore in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_flood_test.exs` (append to existing file) — test that flood threshold triggers auto-ignore via `IgnoreList.add_entry/4` with correct `expires_at`, system message "* {nick} has been auto-ignored for flooding (5 minutes)" is displayed, timer is scheduled via `Process.send_after`, `{:auto_ignore_expired, nick}` removes ignore and shows un-ignore message, manual un-ignore sets cooldown preventing re-trigger for 60s, existing permanent ignore is not overridden, user's own messages don't trigger auto-ignore, `@tag :liveview`

### Implementation for User Story 2

- [x] T018 [US2] Integrate flood tracking into ChatLive `handle_info` for channel messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — after duplicate check, call `FloodTracker.record_message/2` and `FloodTracker.flooded?/4` using settings from `session.flood_protection`; if flooded and not already auto-ignored and no active cooldown and not already on permanent ignore list, trigger auto-ignore
- [x] T019 [US2] Implement auto-ignore trigger logic in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when flood detected: calculate `expires_at` from `auto_ignore_duration_seconds`, call `IgnoreList.add_entry(ignore_list, sender, :all, expires_at)`, update session, schedule `Process.send_after(self(), {:auto_ignore_expired, sender}, duration_ms)`, record in `auto_ignore_state`, display system message, persist if identified
- [x] T020 [US2] Implement `handle_info({:auto_ignore_expired, sender})` in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — remove sender from ignore list via `IgnoreList.remove_entry/2`, remove from `auto_ignore_state.active`, reset flood tracker for sender via `FloodTracker.reset_sender/2`, display system message "* {nick} is no longer auto-ignored", persist if identified
- [x] T021 [US2] Integrate flood tracking into ChatLive `handle_info` for PMs in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — same flood tracking pattern as T018 but for PM messages
- [x] T022 [US2] Add cooldown logic to manual un-ignore in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in `ignore_dialog_remove` and `/unignore` handler, check if removed nick is in `auto_ignore_state.active`; if so, cancel timer, remove from active, add cooldown entry with 60-second monotonic expiry; check cooldown before triggering auto-ignore in T018

**Checkpoint**: Auto-ignore working — flooding users are automatically ignored with timed expiry, manual un-ignore triggers cooldown, system messages inform the user.

---

## Phase 5: User Story 3 — CTCP Flood Protection (Priority: P3)

**Goal**: Limit outgoing CTCP replies to prevent the user's client from being used as a flood amplifier.

**Independent Test**: Send 5+ CTCP requests within 10 seconds; verify only the first 2 receive replies.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T023 [P] [US3] Write LiveView tests for CTCP reply limiting in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_flood_test.exs` (append to existing file) — test that first 2 CTCP requests within 10 seconds get replies, 3rd+ are silently dropped (no reply broadcast), counter resets after window expires, custom limit from settings is respected, `@tag :liveview`

### Implementation for User Story 3

- [x] T024 [US3] Integrate CTCP reply limiting into ChatLive `handle_info({:ctcp_request, ...})` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — before generating and sending a CTCP reply, check `ctcp_reply_tracker` timestamps against `ctcp_reply_limit` and `ctcp_reply_window_seconds` from flood protection settings; if limit reached, skip reply (still show the "CTCP request received" system message); if under limit, record timestamp and proceed with reply

**Checkpoint**: CTCP reply flooding eliminated — no more than the configured limit of replies per window.

---

## Phase 6: User Story 4 — Flood Protection Settings Dialog (Priority: P4)

**Goal**: Provide a retro-styled dialog for users to customize all flood protection thresholds, with DB persistence for registered users.

**Independent Test**: Open dialog, modify thresholds, save, verify changes persist after reconnection (registered users) and are applied to flood detection.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T025 [P] [US4] Write LiveView tests for settings dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_flood_test.exs` (append to existing file) — test dialog opens/closes, form submission updates session settings, invalid values show error, reset to defaults works, settings persist for identified users (mock `FloodProtection.save/2`), guest settings stay in memory, `@tag :liveview`

### Implementation for User Story 4

- [x] T026 [P] [US4] Create `RetroHexChatWeb.Components.FloodProtectionDialog` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/flood_protection_dialog.ex` — retro-styled dialog matching CTCP/Ignore dialog pattern: overlay, window with title-bar "Flood Protection", fieldsets for "Message Flood" (threshold + window), "Anti-Spam" (duplicate threshold + window), "Auto-Ignore" (duration), "CTCP Reply Limit" (limit + window), number inputs with min/max constraints, Save/Reset Defaults/Cancel buttons, `phx-submit="flood_save_settings"`, `phx-click="flood_reset_defaults"`, `phx-click="close_flood_protection_dialog"`
- [x] T027 [US4] Add dialog event handlers in ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — implement `handle_event("open_flood_protection_dialog")`, `handle_event("close_flood_protection_dialog")`, `handle_event("flood_save_settings", params)` (parse all 7 fields from string params, validate, update session, persist if identified via `Task.start`), `handle_event("flood_reset_defaults")` (reset to `FloodProtection.new()`, persist if identified); add `show_flood_protection_dialog: false` to `assign_defaults`
- [x] T028 [US4] Render dialog component in ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `<RetroHexChatWeb.Components.FloodProtectionDialog.flood_protection_dialog visible={@show_flood_protection_dialog} flood_protection={@session.flood_protection} />` in the render function, following the CTCP/Ignore dialog placement pattern
- [x] T029 [US4] Add "Flood Protection" menu item to Tools menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add `<div class="menu-dropdown-item" data-testid="menu-flood-protection" phx-click="open_flood_protection_dialog">Flood Protection</div>` in the Tools menu section

**Checkpoint**: Settings dialog working — users can customize all thresholds, changes persist for registered users, and are immediately applied to flood detection.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, cross-references, and final validation

- [x] T030 [P] Add flood protection help topic to `RetroHexChat.Chat.HelpTopics` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — topic ID `feature-flood-protection`, category "Features", keywords `["flood", "spam", "duplicate", "auto-ignore", "protection", "anti-spam"]`, HTML content covering: what flood protection does, default thresholds, how duplicate detection works, how auto-ignore works, how CTCP reply limiting works, how to access settings (Tools > Flood Protection), See Also links to `feature-ignore` and `feature-ctcp`
- [x] T031 [P] Update existing help topics with cross-references in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — add "Flood Protection" link (`data-help-topic="feature-flood-protection"`) to See Also section of `feature-ignore` and `feature-ctcp` topics
- [x] T032 Run full test suite and static analysis: `make precommit` — verify all tests pass, `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`
- [x] T033 Run quickstart.md manual validation scenarios — verify duplicate detection, auto-ignore with expiry, CTCP reply limiting, settings dialog, and persistence for registered users

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migration + schema) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — no dependencies on other stories
- **US2 (Phase 4)**: Depends on Phase 2 AND Phase 3 (US1) — uses flood tracker assigns initialized in US1
- **US3 (Phase 5)**: Depends on Phase 2 AND Phase 3 (US1) — uses CTCP reply tracker assigns initialized in US1
- **US4 (Phase 6)**: Depends on Phase 2 — can run in parallel with US1/US2/US3 but best done after to test settings impact on active features
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — initializes socket assigns used by US2 and US3
- **US2 (P2)**: Depends on US1 (needs flood_tracker, auto_ignore_state assigns from T013)
- **US3 (P3)**: Depends on US1 (needs ctcp_reply_tracker assign from T013)
- **US4 (P4)**: Can start after Foundational — independent of other stories (dialog + settings only)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Domain modules before LiveView integration
- Core filtering logic before timer/expiry logic
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 2**: T003, T004, T005, T006 (all test files) can run in parallel; T007, T008, T009 (all domain modules) can run in parallel
- **Phase 3**: T012 (test) runs first; T14 and T15 (channel + PM integration) can run in parallel after T13
- **Phase 5**: T23 (test) and T26 (dialog component) can run in parallel
- **Phase 7**: T030 and T031 (help topics) can run in parallel

---

## Parallel Example: Foundational Phase

```text
# Launch all tests in parallel (different files, no dependencies):
T003: Unit tests for FloodProtection in flood_protection_test.exs
T004: Unit tests for FloodTracker in flood_tracker_test.exs
T005: Unit tests for DuplicateTracker in duplicate_tracker_test.exs
T006: Integration tests for FloodProtectionSetting in flood_protection_setting_test.exs

# Then launch all implementations in parallel (different files):
T007: FloodProtection domain module in flood_protection.ex
T008: FloodTracker domain module in flood_tracker.ex
T009: DuplicateTracker domain module in duplicate_tracker.ex

# Then sequential (same file):
T010: Session struct extension in session.ex
T011: Run migration + verify tests pass
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration + schema)
2. Complete Phase 2: Foundational (domain modules + Session)
3. Complete Phase 3: User Story 1 (duplicate detection)
4. **STOP and VALIDATE**: Test duplicate detection independently
5. Deploy/demo — users immediately protected from duplicate spam

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 (Duplicate Detection) → Test independently → Deploy (MVP!)
3. Add US2 (Auto-Ignore) → Test independently → Deploy
4. Add US3 (CTCP Reply Limiting) → Test independently → Deploy
5. Add US4 (Settings Dialog) → Test independently → Deploy
6. Polish (Help topics, cross-references) → Final deploy

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All flood detection runs receiver-side in LiveView process (socket assigns)
- Auto-ignore entries use existing IgnoreList.add_entry/4 with expires_at
- Settings follow the CTCP Settings pattern: domain module + schema + Session getter/setter + load_persisted_data
- Monotonic time (`System.monotonic_time(:millisecond)`) for all tracker timestamps
- 50-sender cap with LRU eviction on both FloodTracker and DuplicateTracker
