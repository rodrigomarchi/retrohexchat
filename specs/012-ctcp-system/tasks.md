# Tasks: CTCP (Client-to-Client Protocol)

**Input**: Design documents from `/specs/012-ctcp-system/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: TDD approach per Constitution Principle IV. Tests written before implementation.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Database migration, Ecto schema, domain module, Session struct changes, and command registration — shared infrastructure for all user stories.

- [X] T001 Create migration for `ctcp_settings` table in `apps/retro_hex_chat/priv/repo/migrations/20260212110000_create_ctcp_settings.exs`
- [X] T002 Create Ecto schema `RetroHexChat.Chat.Schemas.CtcpSetting` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/ctcp_setting.ex` with fields: owner_nickname (PK, FK → registered_nicks), enabled (boolean, default true), version_string (string, default "RetroHexChat v1.0", max 200), finger_text (string, nullable, max 200)
- [X] T003 Create domain module `RetroHexChat.Chat.CtcpSettings` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/ctcp_settings.ex` with functions: new/0, get_enabled/1, get_version_string/1, get_finger_text/1, set_enabled/2, set_version_string/2, set_finger_text/2, save/2, load/1
- [X] T004 Add `ctcp_settings` and `last_message_at` fields to Session struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` with getter/setter functions: get_ctcp_settings/1, set_ctcp_settings/2, get_last_message_at/1, set_last_message_at/2
- [X] T005 [P] Add `{:ok, :ctcp, map()}` to Handler result type union in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex`
- [X] T006 [P] Register "ctcp" command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` pointing to `RetroHexChat.Commands.Handlers.Ctcp`

**Checkpoint**: Foundation ready — schema, domain module, session fields, and command registration in place.

---

## Phase 2: Foundational — /ctcp Command Handler

**Purpose**: The command handler that parses `/ctcp <target> <type>` and returns structured results. Blocks all user story implementation.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 [P] Write unit tests for `/ctcp` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/ctcp_test.exs`: validate/1 (empty, valid, invalid args), execute/2 (no args → error with usage, one arg → error with usage, valid types → {:ok, :ctcp, %{target, type}}, invalid type → error listing valid types, case insensitivity)
- [X] T008 [P] Write unit tests for `CtcpSettings` domain module in `apps/retro_hex_chat/test/retro_hex_chat/chat/ctcp_settings_test.exs`: new/0 returns defaults, getters/setters work, version_string truncation at 200 chars, finger_text truncation at 200 chars, save/load round-trip for registered users
- [X] T009 Create `/ctcp` handler `RetroHexChat.Commands.Handlers.Ctcp` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/ctcp.ex` implementing Handler behaviour: validate/1 always :ok, execute/2 parses target + type, returns {:ok, :ctcp, %{target: target, type: atom}}, help/0 with syntax and examples

**Checkpoint**: `/ctcp` command parses correctly and returns structured results. All unit tests pass.

---

## Phase 3: User Story 1 — CTCP PING (Priority: P1) 🎯 MVP

**Goal**: Users can send `/ctcp <target> ping` and see round-trip latency in milliseconds. Self-CTCP returns 0ms instantly. Offline users show "not found". 10-second timeout for disabled CTCP. Rate limiting enforced.

**Independent Test**: Two connected users exchange CTCP PING and verify latency display. Self-ping shows 0ms. Offline target shows error.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T010 [US1] Write LiveView tests for CTCP PING in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ctcp_test.exs`: sending /ctcp <target> ping shows request sent, receiving {:ctcp_request, %{type: :ping}} auto-replies, receiving {:ctcp_reply, %{type: :ping}} shows latency, self-ping returns 0ms immediately, offline target shows "User not found", timeout after 10 seconds shows timeout message, rate limiting blocks 4th request within 30s, no PM windows created

### Implementation for User Story 1

- [X] T011 [US1] Add `handle_dispatch_result` clause for `{:ok, :ctcp, %{target, type}}` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — calls `handle_ctcp_send/3`
- [X] T012 [US1] Implement `handle_ctcp_send/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` with: rate limit check (socket assigns `ctcp_rate_limits`), validate_target_online/1, self-CTCP shortcut (immediate reply, 0ms for ping), PubSub broadcast {:ctcp_request, payload} to `user:#{target}`, start 10s timeout via Process.send_after, store pending request in socket assigns `ctcp_pending`
- [X] T013 [US1] Implement `handle_info({:ctcp_request, %{type: :ping, ...}})` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — check ctcp_enabled, auto-reply via PubSub {:ctcp_reply, ...}, show "* CTCP PING request from <sender>" system message
- [X] T014 [US1] Implement `handle_info({:ctcp_reply, %{type: :ping, ...}})` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — match pending request by request_id, cancel timeout timer, calculate latency, show "* CTCP PING reply from <target>: <N>ms"
- [X] T015 [US1] Implement `handle_info({:ctcp_timeout, request_id})` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — remove from pending, show "* No CTCP reply from <target> (timed out)"
- [X] T016 [US1] Initialize socket assigns `ctcp_pending: %{}` and `ctcp_rate_limits: %{}` in mount/3 of `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: CTCP PING works end-to-end. Self-ping returns 0ms. Offline users show error. Timeout works. Rate limiting enforced. All tests pass.

---

## Phase 4: User Story 2 — VERSION, TIME, FINGER (Priority: P1)

**Goal**: Users can send `/ctcp <target> version|time|finger` and see formatted replies. VERSION returns client string, TIME returns server UTC, FINGER returns profile text or idle time. Invalid types show error with valid types list.

**Independent Test**: Send each CTCP type to an online user and verify correct reply format.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T017 [US2] Write LiveView tests for VERSION/TIME/FINGER in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ctcp_test.exs`: VERSION reply shows client string, TIME reply shows UTC time, FINGER reply shows idle time (default), FINGER reply shows custom text when configured, invalid type shows error with valid types, self-CTCP for VERSION/TIME/FINGER returns own values

### Implementation for User Story 2

- [X] T018 [US2] Extend `handle_info({:ctcp_request, ...})` to handle `:version`, `:time`, `:finger` types in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — generate appropriate reply values (version_string from settings, DateTime.utc_now for time, finger_text or idle time default)
- [X] T019 [US2] Extend `handle_info({:ctcp_reply, ...})` to handle non-ping types in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — display "* CTCP <TYPE> reply from <target>: <value>"
- [X] T020 [US2] Extend self-CTCP in `handle_ctcp_send/3` to handle `:version`, `:time`, `:finger` types in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — return own settings values immediately
- [X] T021 [US2] Update `last_message_at` in Session on every sent message in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — update in handle_event("send_message", ...) and handle_dispatch_result for :message and :action types
- [X] T022 [US2] Implement idle time formatting helper `format_idle_time/1` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — converts seconds to human-readable string ("5 minutes", "2 hours", etc.)

**Checkpoint**: All four CTCP types work. VERSION/TIME/FINGER return correct values. Idle time shows for default FINGER. All tests pass.

---

## Phase 5: User Story 3 — CTCP Settings Dialog (Priority: P2)

**Goal**: Users can customize CTCP replies and disable CTCP responses via a retro settings dialog accessible from the Tools menu. Settings persist for registered users.

**Independent Test**: Open settings dialog, modify values, verify CTCP replies reflect changes. Reconnect identified user and verify persistence.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T023 [US3] Write LiveView tests for CTCP settings dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_ctcp_test.exs`: open dialog from Tools menu, toggle CTCP enabled/disabled, set custom version string, set custom finger text, save settings persists for identified users, close dialog

### Implementation for User Story 3

- [X] T024 [US3] Create `RetroHexChatWeb.Components.CtcpSettingsDialog` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ctcp_settings_dialog.ex` — retro dialog with: enable/disable checkbox, version string text input, finger text text input, Save/Cancel buttons
- [X] T025 [US3] Add "CTCP Settings" menu item to Tools menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` with phx-click="open_ctcp_settings_dialog"
- [X] T026 [US3] Add socket assigns for dialog state (`show_ctcp_settings_dialog: false`) and render CtcpSettingsDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T027 [US3] Implement handle_event handlers for CTCP settings dialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`: open_ctcp_settings_dialog, close_ctcp_settings_dialog, ctcp_save_settings (update session, persist for identified users via Task.start)
- [X] T028 [US3] Add CtcpSettings.load to `load_persisted_data/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — load settings on identify

**Checkpoint**: Settings dialog works. Custom strings reflected in CTCP replies. Settings persist for registered users. All tests pass.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, static analysis, registry test update, final validation.

- [X] T029 [P] Add help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`: "cmd-ctcp" (Commands category — syntax, examples, see also), "feature-ctcp" (Features category — overview of CTCP types, usage, settings), update cross-references in related topics (cmd-msg, feature-notices)
- [X] T030 [P] Update registry test command count in `apps/retro_hex_chat/test/retro_hex_chat/commands/registry_test.exs`
- [X] T031 Run `mix credo --strict` and fix any warnings across all new/modified files
- [X] T032 Run full test suite (`make test`) and verify all tests pass, no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2. MVP — implements core PING flow
- **User Story 2 (Phase 4)**: Depends on Phase 3 (extends handle_info handlers from US1)
- **User Story 3 (Phase 5)**: Depends on Phase 1 (CtcpSettings module). Can run in parallel with US1/US2 for dialog creation, but integration requires US1/US2 for end-to-end testing
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (PING)**: Foundation only. Establishes the request/reply/timeout/rate-limit infrastructure
- **US2 (VERSION/TIME/FINGER)**: Depends on US1 — extends the same handle_info handlers
- **US3 (Settings Dialog)**: Mostly independent (dialog + persistence) but integration testing requires US1/US2

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- LiveView tests → handle_dispatch_result → handle_info handlers → socket assigns setup
- Story complete before moving to next priority

### Parallel Opportunities

- T005 and T006 can run in parallel (different files)
- T007 and T008 can run in parallel (different test files)
- T029 and T030 can run in parallel (different files)
- Dialog component T024 can be created in parallel with US1/US2 implementation

---

## Parallel Example: Phase 1

```bash
# After T004 completes (Session changes), these can run in parallel:
Task T005: "Add {:ok, :ctcp, map()} to Handler result type in handler.ex"
Task T006: "Register ctcp command in registry.ex"
```

## Parallel Example: Phase 2

```bash
# These test files can be created in parallel:
Task T007: "Unit tests for /ctcp handler in ctcp_test.exs"
Task T008: "Unit tests for CtcpSettings in ctcp_settings_test.exs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006)
2. Complete Phase 2: Foundational handler (T007-T009)
3. Complete Phase 3: US1 CTCP PING (T010-T016)
4. **STOP and VALIDATE**: Test PING end-to-end with two browser tabs
5. Deploy/demo if ready — PING alone delivers core value

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Add US1 (PING) → Test independently → Deploy (MVP!)
3. Add US2 (VERSION/TIME/FINGER) → Test all types → Deploy
4. Add US3 (Settings Dialog) → Test customization + persistence → Deploy
5. Polish → Help docs, credo, full test suite → Final deploy

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- CTCP uses existing `:system` message type — no new rendering type needed
- Pending requests stored in socket assigns (ephemeral, not Session struct)
- Rate limiting via socket assigns map (per-sender-target, 3 per 30s)
- PING latency uses System.monotonic_time(:millisecond) for accuracy
- TIME returns server UTC via DateTime.utc_now() (clarification decision)
- Self-CTCP handled locally without PubSub (instant reply, no timeout)
