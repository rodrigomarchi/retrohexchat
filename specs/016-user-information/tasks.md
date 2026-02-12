# Tasks: User Information

**Input**: Design documents from `/specs/016-user-information/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/user-information.md, quickstart.md

**Tests**: Included per project constitution (TDD approach).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration, shared utility modules, Session integration, WhowasCache GenServer

- [X] T001 Create user_bios database migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDD_create_user_bios.exs`
- [X] T002 Create UserBio Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/user_bio.ex`
- [X] T003 [P] Create TimeFormatter utility module (format_duration/1 for seconds→human-friendly string, format_relative/1 for DateTime→"X ago" string) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/time_formatter.ex`
- [X] T004 [P] Write TimeFormatter tests (seconds→string, edge cases: 0, 59, 60, 3600, mixed hours/minutes) in `apps/retro_hex_chat/test/retro_hex_chat/chat/time_formatter_test.exs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain modules, WhowasCache GenServer, Session integration, command registration — MUST be complete before ANY user story UI work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create UserBio domain module with save/2, load/1, delete/1 persistence functions in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_bio.ex`
- [X] T006 [P] Write UserBio domain tests (save, load, delete, not_found) in `apps/retro_hex_chat/test/retro_hex_chat/chat/user_bio_test.exs`
- [X] T007 Create WhowasCache GenServer + ETS module (start_link, record/3, lookup/1, size/0, clear/0, periodic cleanup every 10min, 1-hour TTL, 1000-entry cap with oldest eviction) in `apps/retro_hex_chat/lib/retro_hex_chat/presence/whowas_cache.ex`
- [X] T008 [P] Write WhowasCache tests (record/lookup, TTL expiry, capacity eviction, case-insensitive lookup, overwrite on re-disconnect, clear, periodic cleanup) in `apps/retro_hex_chat/test/retro_hex_chat/presence/whowas_cache_test.exs`
- [X] T009 Add WhowasCache to Application supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- [X] T010 Add `bio` field to Session struct with getter/setter (get_bio/set_bio) and integrate UserBio.load into `load_persisted_data` chain in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [X] T011 Register new commands in dispatcher: `"whowas"` → Whowas handler, `"bio"` → Bio handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/dispatcher.ex`

**Checkpoint**: Foundation ready — UserBio persistence, WhowasCache, TimeFormatter, Session integration, command registration all complete

---

## Phase 3: User Story 1 — Expanded /whois Output (Priority: P1) 🎯 MVP

**Goal**: Users see comprehensive information when typing /whois — shared channels, online time, idle time, registration status, away message, bio — as text in the chat stream. Double-click nicklist triggers /whois.

**Independent Test**: Type `/whois <nickname>` and verify expanded output. Double-click a nicklist entry and verify /whois output appears.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T012 [P] [US1] Write /whois handler tests (validate, execute with target, self-whois, missing args) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/whois_test.exs`
- [X] T013 [P] [US1] Write expanded /whois LiveView tests (output lines in chat stream, shared channels, registration status, conditional bio/away display, double-click nicklist) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/whois_test.exs`

### Implementation for User Story 1

- [X] T014 [US1] Enhance /whois handler to return `{:ok, :ui_action, :show_whois_info, %{nickname: target}}` instead of `:open_whois` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/whois.ex`
- [X] T015 [US1] Add `show_whois_info` event handler in ChatLive — gather user info (channels, shared channels, online time, idle time, registration status, away, bio), format with TimeFormatter, insert as multiple system_message lines in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T016 [US1] Add `last_activity_at` socket assign (initialized on mount, updated on Presence tracking meta), add `last_nick_click` assign for double-click detection in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T017 [US1] Add `last_activity_at` to Presence metadata on track_user calls and update meta on user activity (send_message, send_pm, command dispatch) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T018 [US1] Add double-click detection on nicklist: add `phx-click="nick_click"` event, detect double-click (same nick within 300ms), trigger show_whois_info in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: User Story 1 fully functional — /whois shows all expanded fields, double-click nicklist works

---

## Phase 4: User Story 2 — Idle Time Tracking (Priority: P2)

**Goal**: System accurately tracks user idle time, resetting on any activity (messages, PMs, commands). Idle time displayed correctly in /whois output.

**Independent Test**: Connect, wait without activity, verify /whois shows correct idle time. Send a message, verify idle time resets.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T019 [P] [US2] Write idle time tracking LiveView tests (idle time shown in whois, resets on message, resets on PM, resets on command) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/idle_time_test.exs`

### Implementation for User Story 2

- [X] T020 [US2] Ensure all user activity event handlers (send_message, send_pm, command dispatch) call a shared `reset_activity/1` helper that updates both the socket assign and Presence metadata for `last_activity_at` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: User Stories 1 AND 2 both work — idle time accurately tracked and displayed in /whois

---

## Phase 5: User Story 3 — User Bio / Profile (Priority: P3)

**Goal**: Users can set, view, and clear their bio via `/bio` command. Bios persist for registered users. Bio appears in /whois output.

**Independent Test**: Set bio with `/bio text`, verify via `/bio` (view), verify in `/whois` output, clear with `/bio clear`, verify persistence after reconnect+identify.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T021 [P] [US3] Write /bio handler tests (set, view, clear, truncation at 200 chars, empty args) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/bio_test.exs`
- [X] T022 [P] [US3] Write /bio LiveView tests (set bio and verify in session, view bio, clear bio, bio appears in /whois, bio persistence after identify, truncation warning) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/bio_test.exs`

### Implementation for User Story 3

- [X] T023 [US3] Create /bio command handler implementing Handler behaviour (set/view/clear, truncation at 200 graphemes with warning, returns system messages) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/bio.ex`
- [X] T024 [US3] Add bio-related event handling in ChatLive — handle /bio command results (set_bio updates session + persists for identified users, clear_bio, view_bio) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: User Stories 1, 2, AND 3 all work — full bio lifecycle (set, view, clear, persist, display in /whois)

---

## Phase 6: User Story 4 — /whowas Command (Priority: P4)

**Goal**: Users can look up recently disconnected users via `/whowas`. System caches disconnect info for 1 hour.

**Independent Test**: Connect as Bob, join channels, disconnect. Type `/whowas Bob` from another user and verify output. Wait 1 hour (or adjust TTL) and verify data expires.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T025 [P] [US4] Write /whowas handler tests (validate, execute with cached entry, not found, missing args) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/whowas_test.exs`
- [X] T026 [P] [US4] Write /whowas LiveView tests (whowas output in chat stream, not-found message, data recording on disconnect) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/whowas_test.exs`

### Implementation for User Story 4

- [X] T027 [US4] Create /whowas command handler implementing Handler behaviour (lookup WhowasCache, format output with TimeFormatter, not-found message) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/whowas.ex`
- [X] T028 [US4] Add whowas recording in ChatLive terminate/2 callback — call WhowasCache.record with nickname, channels, quit_message on user disconnect in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T029 [US4] Add show_whowas_info event handler in ChatLive — format whowas data as system messages in chat stream in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: All user stories complete — /whowas shows recently disconnected user info

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge case handling, and full validation

- [X] T030 [P] Add /bio and /whowas help topics, update /whois help topic with new fields documentation in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [X] T031 [P] Handle edge cases: /whois on non-existent user ("not online" message), bio with special characters (formatting codes preserved), idle time formatting edge cases (0 seconds, large values) in relevant handlers and components
- [X] T032 Run full CI-equivalent validation pipeline: `mix compile --warnings-as-errors` then parallel `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Phase 2 completion
  - US1 (P1): Can start after Phase 2
  - US2 (P2): Depends on US1 (needs the /whois output and Presence metadata setup)
  - US3 (P3): Can start after Phase 2, independent of US1/US2 (but bio display in /whois needs US1)
  - US4 (P4): Can start after Phase 2, independent of other stories
- **Polish (Phase 7)**: Depends on all user stories being complete

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Domain logic before LiveView integration
- Handler before ChatLive event handling
- Core implementation before edge case handling

### Parallel Opportunities

**Phase 1**:
- T003 (TimeFormatter) and T004 (TimeFormatter tests) can run in parallel with T001/T002

**Phase 2**:
- T006 (UserBio tests) and T008 (WhowasCache tests) can run in parallel
- T005 → T006, T007 → T008 (tests after implementation)

**Phase 3 (US1)**:
- T012 (handler tests) and T013 (LiveView tests) can run in parallel
- T014 → T015 → T016 → T017 → T018 (sequential within implementation)

**Phase 4 (US2)**:
- T019 (tests) can start independently
- T020 (implementation) depends on T019

**Phase 5 (US3)**:
- T021 (handler tests) and T022 (LiveView tests) can run in parallel
- T023 → T024 (sequential)

**Phase 6 (US4)**:
- T025 (handler tests) and T026 (LiveView tests) can run in parallel
- T027 → T028 → T029 (sequential)

**Phase 7**:
- T030 and T031 can run in parallel

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration, schema, TimeFormatter)
2. Complete Phase 2: Foundational (UserBio, WhowasCache, Session, dispatcher)
3. Complete Phase 3: User Story 1 (expanded /whois, double-click)
4. **STOP and VALIDATE**: Test /whois independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Expanded /whois → MVP ready
3. Add User Story 2 → Idle time tracking → Accurate idle display
4. Add User Story 3 → Bio system → User identity
5. Add User Story 4 → /whowas → Recently disconnected lookup
6. Complete Phase 7 → Help docs, edge cases, CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- WhowasCache is a GenServer backed by ETS — test with :timer.sleep or inject time for TTL tests
- Idle time tracking uses Presence metadata — testable via Presence.list queries
- Bio persistence follows existing single-row-per-user pattern (like NoticeRouting, CtcpSettings)
- /whois output is text in chat stream (not a dialog) — each field is a separate system_message
