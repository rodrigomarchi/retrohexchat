# Tasks: Visual Feedback & Unread Indicators

**Input**: Design documents from `/specs/030-visual-feedback-unread/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

**Tests**: Yes — JS lib tests (Vitest) and Elixir E2E tests (LiveViewTest) are included per Constitution IV (TDD).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: CSS scaffolding, app.css import, domain module skeleton

- [X] T001 Create treebar CSS file with badge, muted, and disconnected styles in `apps/retro_hex_chat_web/assets/css/treebar.css`
- [X] T002 Add treebar.css import to `apps/retro_hex_chat_web/assets/css/app.css` (Components layer)
- [X] T003 [P] Create UnreadTracker domain module skeleton with @moduledoc and @spec in `apps/retro_hex_chat/lib/retro_hex_chat/chat/unread_tracker.ex`
- [X] T004 [P] Create feedback_toast.js lib with showFeedbackToast and createFeedbackToastElement in `apps/retro_hex_chat_web/assets/js/lib/feedback_toast.js`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: UnreadTracker domain logic and JS unread lib — required by US1 and used across other stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests

- [X] T005 [P] Write UnreadTracker ExUnit tests (increment, reset, display_count, system message filtering) in `apps/retro_hex_chat/test/retro_hex_chat/chat/unread_tracker_test.exs`
- [X] T006 [P] Write unread.js Vitest tests (formatCount, createBadgeElement, updateBadge, clearBadge) in `apps/retro_hex_chat_web/assets/test/lib/unread.test.js`
- [X] T007 [P] Write feedback_toast.js Vitest tests (showFeedbackToast, createFeedbackToastElement) in `apps/retro_hex_chat_web/assets/test/lib/feedback_toast.test.js`

### Implementation

- [X] T008 Implement UnreadTracker functions (increment/2, reset/2, get_count/2, display_count/1) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/unread_tracker.ex`
- [X] T009 [P] Create unread.js lib with formatCount, createBadgeElement, updateBadge, clearBadge in `apps/retro_hex_chat_web/assets/js/lib/unread.js`
- [X] T010 [P] Implement feedback_toast.js functions (showFeedbackToast, createFeedbackToastElement) in `apps/retro_hex_chat_web/assets/js/lib/feedback_toast.js`

**Checkpoint**: UnreadTracker passes all unit tests. JS libs pass all Vitest tests. Foundation ready.

---

## Phase 3: User Story 1 — Treebar Unread Indicators (Priority: P1) 🎯 MVP

**Goal**: Display 6 visual states in the treebar: normal, unread (bold + numeric badge), highlight (red dot), active (selected bg), muted (grayed, no badges), disconnected (⚡ + gray). Reset unread on channel switch. Cap at "99+".

**Independent Test**: Join 3+ channels, send messages from another user in non-active channels, verify bold text / numeric badges / red dots appear. Switch to channel, verify badges clear.

### Tests for US1

- [X] T011 [P] [US1] Write treebar component test for badge rendering (6 states, 99+ cap, muted suppression) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/treebar_test.exs`
- [ ] T012 [P] [US1] Write E2E test for unread indicator flow (message → badge → switch → reset) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/visual_feedback_test.exs`

### Implementation for US1

- [X] T013 [US1] Replace `unread_channels` MapSet with `unread_counts` Map in ChatLive assigns in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T014 [US1] Update treebar.ex to accept `unread_counts` map, render numeric badges, red dot for highlights, muted/disconnected states in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex`
- [X] T015 [US1] Update messages.ex `apply_background_message` to use UnreadTracker.increment instead of MapSet.put, filter system messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- [X] T016 [US1] Update core_events.ex `switch_channel`/`switch_pm` to use UnreadTracker.reset instead of MapSet.delete in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [X] T017 [US1] Update all other references to `unread_channels` MapSet across ChatLive and components to use `unread_counts` Map

**Checkpoint**: US1 fully functional — treebar shows 6 visual states, badges appear/clear correctly, 99+ cap works.

---

## Phase 4: User Story 2 — Kick Notification Dialog (Priority: P2)

**Goal**: Show a retro design system modal dialog when user is kicked, with channel/operator/reason info. Queue multiple kicks. Require OK to dismiss.

**Independent Test**: Have an operator kick a user, verify dialog appears with correct info. Kick from 2 channels, verify dialogs queue.

### Tests for US2

- [ ] T018 [P] [US2] Write kick_dialog component test (rendering, no-reason variant, queue display) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/kick_dialog_test.exs`
- [ ] T019 [P] [US2] Write E2E test for kick dialog flow (kick → dialog → OK → next dialog) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/kick_dialog_test.exs`

### Implementation for US2

- [X] T020 [US2] Create KickDialog function component (retro window, OK button, conditional reason) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/kick_dialog.ex`
- [X] T021 [US2] Add `kick_queue` assign (list) to ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [X] T022 [US2] Render KickDialog conditionally in chat_live.html.heex when kick_queue is non-empty in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [X] T023 [US2] Update channel_state.ex `:user_kicked` handler to enqueue kick events into `kick_queue` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`
- [X] T024 [US2] Create kick_events.ex with `kick_dialog_dismiss` handler (dequeue first item) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/kick_events.ex`

**Checkpoint**: US2 fully functional — kick dialog appears with correct info, queues properly, dismisses on OK.

---

## Phase 5: User Story 3 — Copy & Settings Confirmation Toasts (Priority: P3)

**Goal**: Show "Copiado!" toast on clipboard copy and "Configurações salvas" toast on settings save, both via Z2 toast infrastructure.

**Independent Test**: Copy text → verify toast appears. Save settings → verify toast appears. Both auto-dismiss after 2s.

### Tests for US3

- [ ] T025 [P] [US3] Write Vitest test for scroll_hook copy toast trigger in `apps/retro_hex_chat_web/assets/test/hooks/scroll_hook.test.js`

### Implementation for US3

- [X] T026 [US3] Update scroll_hook.js clipboard handlers to trigger feedback toast client-side after successful copy in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [X] T027 [US3] Update options_events.ex `apply_draft` to push `feedback_toast` event on settings save in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex`
- [X] T028 [US3] Add `feedback_toast` handleEvent handler in treebar_hook.js (delegates to feedback_toast.js) in `apps/retro_hex_chat_web/assets/js/hooks/treebar_hook.js`

**Checkpoint**: US3 fully functional — copy and settings toasts appear and auto-dismiss.

---

## Phase 6: User Story 4 — Optimistic Message Send with Retry (Priority: P4)

**Goal**: Messages appear instantly with pending state. Server confirms → pending clears. Server fails → warning icon with retry. Each failed message has independent retry.

**Independent Test**: Send a message, verify it appears immediately with pending indicator. Simulate failure, verify warning icon and retry button appear.

### Tests for US4

- [ ] T029 [P] [US4] Write E2E test for optimistic send flow (send → pending → confirmed) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/visual_feedback_test.exs`

### Implementation for US4

- [X] T030 [US4] Update core_events.ex `send_plain_message` to insert message optimistically with `:pending` status and temp_id, then push `message_confirmed` or `message_failed` events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [X] T031 [US4] Add pending/failed message CSS styles (faded for pending, warning icon for failed) in `apps/retro_hex_chat_web/assets/css/chat.css`
- [X] T032 [US4] Add `message_confirmed` and `message_failed` handleEvent handlers in scroll_hook.js (update DOM status) in `apps/retro_hex_chat_web/assets/js/hooks/scroll_hook.js`
- [X] T033 [US4] Add `retry_message` event handler in core_events.ex (re-send failed message) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [X] T034 [US4] Render retry button in message template for failed messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex` or equivalent HEEx template

**Checkpoint**: US4 fully functional — optimistic send, pending state, failure detection, retry works.

---

## Phase 7: User Story 5 — Channel Join Flash (Priority: P5)

**Goal**: Treebar entry flashes green for ~1 second when a channel is successfully joined.

**Independent Test**: Join a channel via /join, verify treebar item flashes green briefly.

### Tests for US5

- [ ] T035 [P] [US5] Write Vitest test for treebar_hook join flash handler in `apps/retro_hex_chat_web/assets/test/hooks/treebar_hook.test.js`

### Implementation for US5

- [X] T036 [US5] Add `tree-join-flash` CSS animation (green highlight, 1s) to `apps/retro_hex_chat_web/assets/css/treebar.css`
- [X] T037 [US5] Add `channel_joined_flash` handleEvent in treebar_hook.js (add/remove CSS class) in `apps/retro_hex_chat_web/assets/js/hooks/treebar_hook.js`
- [X] T038 [US5] Push `channel_joined_flash` event after successful join in channel.ex helper in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex`

**Checkpoint**: US5 fully functional — join flash works on channel join.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, final validation

- [X] T039 [P] Add help topics for "Unread Indicators", "Kick Notifications", and "Copy Feedback" in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex`
- [X] T040 [P] Update "Keyboard Shortcuts" help topic if any new shortcuts were added in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex`
- [ ] T041 Run full CI-equivalent validation pipeline (see CLAUDE.md "CI-Equivalent Validation")

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T001-T004) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — MVP target
- **US2 (Phase 4)**: Depends on Phase 1 only (no UnreadTracker dependency) — can run in parallel with US1
- **US3 (Phase 5)**: Depends on Phase 2 (feedback_toast.js) — can run in parallel with US1/US2
- **US4 (Phase 6)**: Depends on Phase 1 only — can run in parallel with US1/US2/US3
- **US5 (Phase 7)**: Depends on Phase 1 (treebar.css) — can run in parallel with all other stories
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Requires UnreadTracker (Phase 2) + treebar.css (Phase 1). No dependency on other stories.
- **US2 (P2)**: Self-contained (new component + new event handler). Independent of other stories.
- **US3 (P3)**: Requires feedback_toast.js (Phase 2). Independent of US1/US2/US4/US5.
- **US4 (P4)**: Self-contained (core_events.ex + scroll_hook.js + CSS). Independent of other stories.
- **US5 (P5)**: Requires treebar.css (Phase 1) + treebar_hook.js. Independent of other stories.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Domain/lib modules before components/hooks
- Server-side before client-side integration
- Story complete before moving to next priority

### Parallel Opportunities

- T003 + T004 (Phase 1: different files)
- T005 + T006 + T007 (Phase 2 tests: different files/languages)
- T009 + T010 (Phase 2 impl: different JS files)
- T011 + T012 (US1 tests: different test files)
- T018 + T019 (US2 tests: same file but different describe blocks)
- US2, US4, US5 can all start in parallel with US1 after their respective dependencies complete

---

## Parallel Example: Phase 2 (Foundational)

```text
# Launch all foundational tests in parallel:
T005: UnreadTracker ExUnit tests (Elixir)
T006: unread.js Vitest tests (JS)
T007: feedback_toast.js Vitest tests (JS)

# After tests written, launch implementations in parallel:
T008: UnreadTracker implementation (Elixir)
T009: unread.js implementation (JS)
T010: feedback_toast.js implementation (JS)
```

## Parallel Example: User Story 1

```text
# Launch US1 tests in parallel:
T011: Treebar component test (Elixir)
T012: E2E visual feedback test (Elixir)

# Then implement sequentially (shared files):
T013: Replace unread_channels with unread_counts (chat_live.ex)
T014: Update treebar.ex badge rendering
T015: Update messages.ex increment logic
T016: Update core_events.ex reset logic
T017: Update remaining unread_channels references
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (CSS + imports + skeletons)
2. Complete Phase 2: Foundational (UnreadTracker + JS libs)
3. Complete Phase 3: User Story 1 (Treebar Unread Indicators)
4. **STOP and VALIDATE**: Test US1 independently — badges, reset, 99+ cap, muted suppression
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Treebar Unread Indicators) → Test → Deploy (MVP!)
3. Add US2 (Kick Dialog) → Test → Deploy
4. Add US3 (Copy/Settings Toasts) → Test → Deploy
5. Add US4 (Optimistic Send) → Test → Deploy
6. Add US5 (Join Flash) → Test → Deploy
7. Polish → Final CI validation → Complete

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verify tests fail before implementing
- `unread_channels` → `unread_counts` migration (T013/T017) is the riskiest change — touches multiple files
- US4 (Optimistic Send) is the most complex story — consider deferring if MVP timeline is tight
- All state is ephemeral (socket assigns, client-side) — no database migrations needed
