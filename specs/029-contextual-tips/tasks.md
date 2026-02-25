# Tasks: Contextual Tips & Progressive Disclosure

**Input**: Design documents from `/specs/029-contextual-tips/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD is mandated by Constitution IV. Tests are written first (Vitest for JS, ExUnit for Elixir).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new files, register hook, import CSS

- [ ] T001 Create toast CSS file with retro window styling, fixed bottom-right positioning, fade animations in `apps/retro_hex_chat_web/assets/css/toast.css`
- [ ] T002 Import `toast.css` in Layer 4 (Components) section of `apps/retro_hex_chat_web/assets/css/app.css`
- [ ] T003 Create Phoenix function component `toast.ex` with a container div that attaches the `ContextualTipsHook` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toast.ex`
- [ ] T004 Register `ContextualTipsHook` in the hooks index file at `apps/retro_hex_chat_web/assets/js/hooks/index.js`
- [ ] T005 Render the `<.toast_container />` component in ChatLive's template (inside `chat_live.html.heex` or the layout rendered by `chat_live.ex`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core JS libraries (tip state + toast DOM) with tests — MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests (write FIRST, ensure they FAIL)

- [ ] T006 [P] Write unit tests for `tips.js` in `apps/retro_hex_chat_web/assets/test/lib/tips.test.js` — cover `isSuppressed`, `setSuppressed` (primary + backup keys), `isTipSeen`, `markTipSeen`, `shouldShowTip`, `markPreempted`, `getTipById`, localStorage full error handling, and resilient suppression backup
- [ ] T007 [P] Write unit tests for `toast.js` in `apps/retro_hex_chat_web/assets/test/lib/toast.test.js` — cover `createToastElement` (retro window structure, title-bar, dismiss button, checkbox, callback invocation), `positionToast`, `animateIn`, `animateOut`

### Implementation

- [ ] T008 [P] Implement `tips.js` with constants (`TIP_IDS`, `TIPS`, `STORAGE_KEYS`, `AUTO_DISMISS_MS`, `QUEUE_GAP_MS`, `IDLE_TIMEOUT_MS`) and functions (`isSuppressed`, `setSuppressed`, `isTipSeen`, `markTipSeen`, `shouldShowTip`, `markPreempted`, `getTipById`, `resetAllTips`) in `apps/retro_hex_chat_web/assets/js/lib/tips.js`
- [ ] T009 [P] Implement `toast.js` with functions (`createToastElement`, `positionToast`, `animateIn`, `animateOut`) in `apps/retro_hex_chat_web/assets/js/lib/toast.js`
- [ ] T010 Run `npm test --prefix apps/retro_hex_chat_web/assets` to verify T006 and T007 tests pass with T008 and T009 implementations

**Checkpoint**: Foundation ready — `tips.js` and `toast.js` tested and passing. User story implementation can begin.

---

## Phase 3: User Story 1 — First Message Tip & Toast Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Send first message → toast appears in bottom-right with "Use ↑ para editar sua última mensagem", "Entendi!" button, "Não mostrar mais dicas" checkbox. Auto-dismisses after 8s. Never appears again.

**Independent Test**: Send a message in a channel, verify toast appears with correct text, dismiss, send another message, verify no toast.

### Tests (write FIRST)

- [ ] T011 [P] [US1] Write hook behavioral tests in `apps/retro_hex_chat_web/assets/test/hooks/contextual_tips_hook.test.js` — cover: `handleEvent("tip_trigger")` shows toast for unseen tip, skips seen tip, skips when suppressed, `handleEvent("tips_toggle")` updates suppression, auto-dismiss after 8s, dismiss button marks seen, checkbox sets suppression, toast does not steal focus, destroyed() cleans up timers
- [ ] T012 [P] [US1] Write LiveView test for `tip_trigger` push on message send in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/tip_events_test.exs` — cover: `tips_state_sync` event stores suppression state in assigns

### Implementation

- [ ] T013 [US1] Implement `ContextualTipsHook` in `apps/retro_hex_chat_web/assets/js/hooks/contextual_tips_hook.js` — mounted(): init queue, attach `handleEvent("tip_trigger")` and `handleEvent("tips_toggle")`, push `tips_state_sync`; enqueueTip(): check suppression/seen/dialog-overlay/onboarding, add to queue, process; processQueue(): show one toast at a time, 8s auto-dismiss, 2s gap between tips; showToast(): create element via `toast.js`, append to container, manage focus; dismissToast(): mark seen, animate out, schedule next; destroyed(): cleanup timers and listeners
- [ ] T014 [US1] Create `tip_events.ex` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/tip_events.ex` — implement `handle_event("tips_state_sync", %{"suppressed" => suppressed}, socket)` to store tips_suppressed in assigns
- [ ] T015 [US1] Attach `tip_events` hook in `chat_live.ex` — add `attach_hook(:tip_events, :handle_event, ...)` for the `tips_state_sync` event, add `tips_suppressed: false` to default assigns
- [ ] T016 [US1] Add `push_event(socket, "tip_trigger", %{tip: "first_message"})` in the `{:message, text}` branch of `handle_event("send_input", ...)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [ ] T017 [US1] Run full test suite: `npm test --prefix apps/retro_hex_chat_web/assets` (JS) and `mix test --include e2e` (Elixir)

**Checkpoint**: User Story 1 complete — first message tip works end-to-end, toast infrastructure is reusable.

---

## Phase 4: User Story 2 — Tip Queuing and Conflict Resolution (Priority: P1)

**Goal**: Multiple simultaneous tips queue and display one at a time with 2-second gap. Tips pause while dialogs/modals are open. Tips do not fire during onboarding wizard. Suppress checkbox clears queue.

**Independent Test**: Trigger two tips simultaneously, verify sequential display with gap. Open a dialog, trigger a tip, close dialog, verify tip appears.

### Tests (write FIRST)

- [ ] T018 [US2] Add queue-specific tests to `apps/retro_hex_chat_web/assets/test/hooks/contextual_tips_hook.test.js` — cover: two simultaneous triggers queue and show sequentially with 2s gap, dialog-overlay presence pauses queue, onboarding-incomplete suppresses tips entirely, suppress checkbox clears pending queue, MutationObserver or polling detects dialog close and resumes queue

### Implementation

- [ ] T019 [US2] Enhance `ContextualTipsHook` queue processing in `apps/retro_hex_chat_web/assets/js/hooks/contextual_tips_hook.js` — add dialog detection (`document.querySelector('.dialog-overlay')`), onboarding check (`localStorage.getItem('retro_hex_chat_onboarding_complete')`), MutationObserver or setInterval polling to detect dialog close and resume queue, post-onboarding delay (5s if onboarding tip banner is visible)
- [ ] T020 [US2] Run JS tests: `npm test --prefix apps/retro_hex_chat_web/assets`

**Checkpoint**: User Stories 1 and 2 complete — toast infrastructure with robust queuing, dialog awareness, and onboarding awareness.

---

## Phase 5: User Story 3 — Channel Join Tip (Priority: P2)

**Goal**: First `/join` success → toast "Canais que você entra aparecem no painel esquerdo"

**Independent Test**: Join a channel with `/join #test`, verify toast appears.

- [ ] T021 [US3] Add `push_event(socket, "tip_trigger", %{tip: "first_join"})` in the `{:ok, _state}` branch of `join_channel/4` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex`
- [ ] T022 [US3] Run Elixir tests to verify no regressions: `mix test --include e2e`

**Checkpoint**: Channel join tip works.

---

## Phase 6: User Story 4 — PM Received Tip (Priority: P2)

**Goal**: First PM received → toast "PMs aparecem como janelas separadas no treebar"

**Independent Test**: Send a PM to the user, verify toast appears.

- [ ] T023 [US4] Add `push_event(socket, "tip_trigger", %{tip: "first_pm"})` in the `handle_info(%{event: "new_pm", ...})` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- [ ] T024 [US4] Run Elixir tests: `mix test --include e2e`

**Checkpoint**: PM received tip works.

---

## Phase 7: User Story 5 — Nick Highlight Tip (Priority: P2)

**Goal**: First nick mention → toast "Seu nick foi mencionado! Configure alertas em Settings"

**Independent Test**: Have another user mention this user's nick, verify toast appears.

- [ ] T025 [US5] Add `push_event(socket, "tip_trigger", %{tip: "first_highlight"})` after `maybe_highlight` returns `highlighted: true` in the `handle_info(%{event: "new_message", ...})` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- [ ] T026 [US5] Run Elixir tests: `mix test --include e2e`

**Checkpoint**: Nick highlight tip works.

---

## Phase 8: User Story 6 — Idle Help Tip (Priority: P3)

**Goal**: 30s idle → toast "Digite /help para ver todos os comandos". Preempted if user already used `/help`.

**Independent Test**: Stay idle for 30s, verify toast. Use `/help` first, stay idle, verify no toast.

### Tests (write FIRST)

- [ ] T027 [P] [US6] Add idle timer tests to `apps/retro_hex_chat_web/assets/test/hooks/contextual_tips_hook.test.js` — cover: idle timer fires after 30s of no activity, activity resets timer, timer is one-shot (never fires twice), /help preemption marks idle_help as seen

### Implementation

- [ ] T028 [US6] Implement idle timer in `ContextualTipsHook` in `apps/retro_hex_chat_web/assets/js/hooks/contextual_tips_hook.js` — add keydown/mousemove/click listeners on document, 30s setTimeout, one-shot fire, cleanup on destroyed()
- [ ] T029 [US6] Add `push_event(socket, "tip_trigger", %{tip: "help_used"})` in the `/help` command dispatch path in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`
- [ ] T030 [US6] Run full test suite: `npm test --prefix apps/retro_hex_chat_web/assets` and `mix test --include e2e`

**Checkpoint**: Idle help tip works with preemption.

---

## Phase 9: User Story 7 — Global Tip Toggle in Settings (Priority: P2)

**Goal**: "Mostrar dicas contextuais" checkbox in Options dialog Display panel. Syncs with localStorage suppression state via push_event.

**Independent Test**: Suppress tips via checkbox on toast, open Settings, verify toggle is off. Enable toggle, trigger an unseen tip, verify it appears.

### Tests (write FIRST)

- [ ] T031 [US7] Write LiveView test for tips toggle in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/tip_events_test.exs` — cover: `options_toggle_tips` event pushes `tips_toggle` to client and updates assigns

### Implementation

- [ ] T032 [US7] Add `show_contextual_tips` field to the display settings struct/map in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` (default: `true`)
- [ ] T033 [US7] Add "Mostrar dicas contextuais" checkbox to the Display panel in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` using the existing `display_checkbox` pattern
- [ ] T034 [US7] Add `handle_event("options_toggle_tips", ...)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` — toggle `show_contextual_tips` in draft, push_event `"tips_toggle"` to client
- [ ] T035 [US7] Update hook to handle `tips_toggle` event and sync localStorage in `apps/retro_hex_chat_web/assets/js/hooks/contextual_tips_hook.js`
- [ ] T036 [US7] Run full test suite: `npm test --prefix apps/retro_hex_chat_web/assets` and `mix test --include e2e`

**Checkpoint**: Settings toggle works bidirectionally with localStorage.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, help system, and full CI validation

- [ ] T037 [P] Add "Contextual Tips" help topic to the Features category in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — include: what tips are, when they appear, how to dismiss, how to re-enable in Settings, "See Also" cross-references to "Keyboard Shortcuts" and "Getting Started"
- [ ] T038 [P] Update "Keyboard Shortcuts" help topic in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` to cross-reference the new "Contextual Tips" topic
- [ ] T039 Run `mix compile --warnings-as-errors` to verify clean compilation
- [ ] T040 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phases 3-4 (US1, US2)**: Depend on Phase 2 — sequential (US2 extends US1's hook)
- **Phases 5-7 (US3, US4, US5)**: Depend on Phase 3 — can run in PARALLEL (each is a single `push_event` line in different files)
- **Phase 8 (US6)**: Depends on Phase 4 (needs queue infrastructure) — independent of US3-5
- **Phase 9 (US7)**: Depends on Phase 3 (needs hook basics) — independent of US3-6
- **Phase 10 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundational only — builds the entire toast + hook infrastructure
- **US2 (P1)**: Depends on US1 — extends hook with queuing, dialog detection, onboarding awareness
- **US3 (P2)**: Depends on US1 — adds one `push_event` line to `helpers/channel.ex`
- **US4 (P2)**: Depends on US1 — adds one `push_event` line to `pubsub_handlers/messages.ex`
- **US5 (P2)**: Depends on US1 — adds one `push_event` line to `pubsub_handlers/messages.ex`
- **US6 (P3)**: Depends on US2 — adds idle timer + preemption logic to hook
- **US7 (P2)**: Depends on US1 — adds Settings toggle + bidirectional sync

### Parallel Opportunities

```
Phase 1 (Setup)
  │
  ▼
Phase 2 (Foundational): T006 ║ T007 (parallel), then T008 ║ T009 (parallel)
  │
  ▼
Phase 3 (US1): T011 ║ T012 (parallel), then T013 → T014 → T015 → T016
  │
  ▼
Phase 4 (US2): T018 → T019
  │
  ├──────────────────┬────────────────────┐
  ▼                  ▼                    ▼
Phase 5 (US3)    Phase 6 (US4)     Phase 7 (US5)     ← ALL PARALLEL
  │                  │                    │
  └──────────────────┴────────────────────┘
  │                                       │
  ├───────────────────────────────────────┤
  ▼                                       ▼
Phase 8 (US6)                       Phase 9 (US7)     ← PARALLEL
  │                                       │
  └───────────────────┬───────────────────┘
                      ▼
                Phase 10 (Polish)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001–T005)
2. Complete Phase 2: Foundational (T006–T010)
3. Complete Phase 3: US1 — First Message Tip (T011–T017)
4. Complete Phase 4: US2 — Queuing (T018–T020)
5. **STOP and VALIDATE**: Toast works, queues correctly, respects dialogs/onboarding
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 → First message tip works (MVP!)
3. US2 → Queuing and conflict resolution
4. US3 + US4 + US5 → Three more tips (parallel)
5. US6 → Idle timer tip with preemption
6. US7 → Settings toggle
7. Polish → Help docs + CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution IV (TDD) is enforced: tests before implementation in all phases
- US3, US4, US5 are intentionally lightweight (one `push_event` line each) since the infrastructure is built in US1/US2
- All 5 server-side trigger points are in different files, enabling parallel development
- No database migrations needed — this is a fully client-side feature
