# Tasks: P2P Actions in Context Menus

**Input**: Design documents from `/specs/040-p2p-context-menus/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/events.md

**Tests**: Included — constitution mandates TDD (Principle IV).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Extract shared P2P invite helper and add registration check plumbing needed by all stories

- [ ] T001 Extract `handle_p2p_invite/3` and `p2p_invite_content/2` from `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` into new shared helper `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/p2p_invite.ex`. Update `command_dispatch.ex` to import from the new helper. Existing tests must still pass.
- [ ] T002 Add `is_target_registered` field to the `context_menu` assign map in `nick_right_click` handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`. Call `NickServ.registered?/1` at menu-open time. Also add it to `close_context_menu/1` reset (default `false`).
- [ ] T003 Add `is_target_registered` computation to `open_chat_context_menu/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` for `:nick` type menus only. Call `NickServ.registered?/1` when type is `:nick`. Store in the `chat_context_menu` map. Default `false` for other types and in `close_chat_context_menu/1`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add new component attributes and template pass-throughs needed by all stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 [P] Add `attr :viewer_is_identified, :boolean, default: false` and `attr :is_target_registered, :boolean, default: false` to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`
- [ ] T005 [P] Add `attr :viewer_is_identified, :boolean, default: false` and `attr :is_target_registered, :boolean, default: false` to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`
- [ ] T006 Pass `viewer_is_identified={@session.identified}` and `is_target_registered={@context_menu[:is_target_registered] || false}` to the `<ContextMenu.context_menu>` call in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [ ] T007 Pass `viewer_is_identified={@session.identified}` and `is_target_registered={@chat_context_menu[:is_target_registered] || false}` to the `<ChatContextMenu.chat_context_menu>` call in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`

**Checkpoint**: Attributes wired through — components can now use `@viewer_is_identified` and `@is_target_registered`

---

## Phase 3: User Story 1 - P2P Actions via Nicklist Context Menu (Priority: P1) 🎯 MVP

**Goal**: Registered user can right-click a nick in the nicklist and start any of the 4 P2P session types

**Independent Test**: Right-click nick in nicklist → P2P items appear → click one → session created → navigated to lobby

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T008 [P] [US1] Write component tests for P2P items visibility in nicklist context menu: (a) items rendered when `viewer_is_identified=true`, (b) items not rendered when `viewer_is_identified=false`. File: `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/context_menu_test.exs`
- [ ] T009 [P] [US1] Write event handler tests for `context_p2p`, `context_call`, `context_video_call`, `context_sendfile` events — verify they call `P2p.do_execute/3` with correct session types and navigate to `/p2p/:token` on success. File: `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_events_test.exs`

### Implementation for User Story 1

- [ ] T010 [US1] Add P2P menu items (separator + 4 items) to `context_menu/1` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`. Position after "Ignore/Unignore" and before the op separator. Guard with `:if={@viewer_is_identified}`. Items enabled when `@is_target_registered` is true. Events: `context_p2p`, `context_call`, `context_video_call`, `context_sendfile`. All pass `phx-value-nick={@target_nick}`.
- [ ] T011 [US1] Add P2P event handlers (`context_p2p`, `context_call`, `context_video_call`, `context_sendfile`) to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`. Each handler: close menu → build context from session → call `P2p.do_execute/3` → on success call `handle_p2p_invite/3` from shared helper + `push_navigate` to `/p2p/#{token}` → on error show flash. Import `push_navigate` from `Phoenix.LiveView`.
- [ ] T012 [US1] Update `@moduledoc` in `context_menu_events.ex` to include the 4 new nicklist P2P events in the event listing.

**Checkpoint**: Nicklist P2P items functional — right-click → see items → click → session created → lobby

---

## Phase 4: User Story 2 - P2P Actions via Chat Nick Context Menu (Priority: P1)

**Goal**: Registered user can right-click a nick in a chat message and start any of the 4 P2P session types

**Independent Test**: Right-click nick in chat message → P2P items appear → click one → session created → navigated to lobby

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [P] [US2] Write component tests for P2P items visibility in chat context menu `:nick` variant: (a) items rendered when `viewer_is_identified=true`, (b) items not rendered when `viewer_is_identified=false`. File: `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/chat_context_menu_test.exs`
- [ ] T014 [P] [US2] Write event handler tests for `ctx_chat_p2p`, `ctx_chat_call`, `ctx_chat_video_call`, `ctx_chat_sendfile` events — verify they call `P2p.do_execute/3` with correct session types and navigate to `/p2p/:token`. File: `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_events_test.exs`

### Implementation for User Story 2

- [ ] T015 [US2] Add P2P menu items (separator + 4 items) to `nick_menu_items/1` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`. Position after "Set Nick Color" and before the op separator. Guard with `:if={@viewer_is_identified}`. Items enabled when `@is_target_registered` is true. Events: `ctx_chat_p2p`, `ctx_chat_call`, `ctx_chat_video_call`, `ctx_chat_sendfile`. All pass `phx-value-nick={@menu.target_nick}`.
- [ ] T016 [US2] Add chat area P2P event handlers (`ctx_chat_p2p`, `ctx_chat_call`, `ctx_chat_video_call`, `ctx_chat_sendfile`) to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`. Same flow as nicklist handlers but use `close_chat_context_menu/1`.
- [ ] T017 [US2] Update `@moduledoc` in `context_menu_events.ex` to include the 4 new chat area P2P events.

**Checkpoint**: Both context menus have full P2P functionality for registered users with registered targets

---

## Phase 5: User Story 3 - Guest Users Cannot See P2P Items (Priority: P2)

**Goal**: Guest users see no P2P items in either context menu

**Independent Test**: Log in as guest → right-click any nick → no P2P items visible

### Tests for User Story 3

- [ ] T018 [P] [US3] Write component tests verifying P2P items are absent when `viewer_is_identified=false` in both `context_menu_test.exs` and `chat_context_menu_test.exs`. These tests may already be covered by T008/T013 — if so, add explicit test names for guest scenario (e.g., `"does not render P2P items for guest user"`).

### Implementation for User Story 3

> No new implementation — guest visibility is already handled by the `:if={@viewer_is_identified}` guards added in T010 and T015. This phase validates that the guard works end-to-end.

- [ ] T019 [US3] Verify guest user E2E: ensure `@session.identified` is `false` for guest users and that the template pass-through in `chat_live.html.heex` correctly sends `viewer_is_identified={false}`.

**Checkpoint**: Guest users confirmed to have no P2P items in either context menu

---

## Phase 6: User Story 4 - Disabled State for Unregistered Targets (Priority: P2)

**Goal**: P2P items appear grayed out with "Usuário não registrado" tooltip when target is not registered

**Independent Test**: As registered user, right-click a guest nick → P2P items grayed out with tooltip

### Tests for User Story 4

- [ ] T020 [P] [US4] Write component tests for disabled state in both context menus: (a) items have `class="disabled"` when `is_target_registered=false`, (b) items have `title="Usuário não registrado"` tooltip, (c) `phx-click` is nil when disabled. Files: `context_menu_test.exs` and `chat_context_menu_test.exs`

### Implementation for User Story 4

> Disabled styling is partially implemented in T010 and T015 (items enabled based on `@is_target_registered`). This phase ensures the disabled class, tooltip, and no-op click are fully implemented.

- [ ] T021 [US4] In `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`, ensure P2P items use conditional `class={if !@is_target_registered, do: "disabled"}`, `title={if !@is_target_registered, do: "Usuário não registrado"}`, and `phx-click={if @is_target_registered, do: "context_p2p"}` (nil when disabled). Apply to all 4 items.
- [ ] T022 [US4] In `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`, apply same disabled pattern to all 4 P2P items in `nick_menu_items/1`.

**Checkpoint**: Unregistered targets show disabled P2P items with tooltip in both menus

---

## Phase 7: User Story 5 - Self-Targeting Disabled (Priority: P3)

**Goal**: P2P items appear disabled (no tooltip) when user right-clicks their own nick

**Independent Test**: Right-click your own nick → P2P items grayed out, no tooltip

### Tests for User Story 5

- [ ] T023 [P] [US5] Write component tests for self-targeting disabled state: (a) nicklist context menu: items disabled when target_nick matches viewer (need to add a way to detect self — either new attr or match in template), (b) chat context menu: items disabled when `@is_target_self` is true, no tooltip. Files: `context_menu_test.exs` and `chat_context_menu_test.exs`

### Implementation for User Story 5

- [ ] T024 [US5] In `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex`, add `attr :is_target_self, :boolean, default: false`. Update P2P items to also be disabled when `@is_target_self` (no tooltip for self). Disabled condition becomes: `!@is_target_registered || @is_target_self`. Tooltip only when `!@is_target_registered && !@is_target_self`.
- [ ] T025 [US5] In `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`, update P2P items to also be disabled when `@is_target_self` (already available as attr). Disabled condition: `!@is_target_registered || @is_target_self`. Tooltip only when `!@is_target_registered && !@is_target_self`.
- [ ] T026 [US5] Pass `is_target_self={@context_menu.target_nick == @session.nickname}` to the nicklist `<ContextMenu.context_menu>` call in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`.

**Checkpoint**: Self-targeting shows disabled P2P items without tooltip in both menus

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, error handling edge cases, and validation

- [ ] T027 [P] Update help topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`: add/update topic for context menu P2P actions. Mention "Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo" items in context menus. Update "See Also" cross-references in related P2P help topics.
- [ ] T028 [P] Write error handling tests: (a) test flash error when `P2p.do_execute/3` returns `{:error, message}`, (b) test rate-limit error shows wait time. File: `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/context_menu_events_test.exs`
- [ ] T029 Add data-testid attributes to all P2P menu items in both `context_menu.ex` and `chat_context_menu.ex` for test selectors: `data-testid="context-p2p"`, `data-testid="context-call"`, `data-testid="context-video-call"`, `data-testid="context-sendfile"` (and `ctx-chat-*` variants).
- [ ] T030 Run quickstart.md manual validation (verify all 6 testing scenarios pass)
- [ ] T031 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Stories (Phase 3–7)**: All depend on Phase 2 completion
  - US1 and US2 can proceed in parallel (different component files + different event names)
  - US3 depends on US1 + US2 (validates existing guards)
  - US4 depends on US1 + US2 (refines disabled styling already added)
  - US5 depends on US4 (extends disabled condition)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P1)**: Can start after Phase 2 — no dependencies on other stories (parallel with US1)
- **US3 (P2)**: Validates US1 + US2 guards — depends on US1 + US2
- **US4 (P2)**: Refines US1 + US2 disabled styling — depends on US1 + US2
- **US5 (P3)**: Extends US4 disabled condition — depends on US4

### Parallel Opportunities

- T004 + T005 (component attrs) can run in parallel
- T008 + T009 (US1 tests) can run in parallel
- T013 + T014 (US2 tests) can run in parallel
- US1 (Phase 3) + US2 (Phase 4) can run in parallel after Phase 2
- T027 + T028 + T029 (polish tasks) can run in parallel

---

## Parallel Example: User Story 1 + User Story 2

```
# After Phase 2 completes, launch both US1 and US2 in parallel:

# Stream A (US1 — nicklist):
T008 → T009 → T010 → T011 → T012

# Stream B (US2 — chat menu):
T013 → T014 → T015 → T016 → T017
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Extract shared helper + add registration check
2. Complete Phase 2: Wire attributes through templates
3. Complete Phase 3 + Phase 4 in parallel: Both context menus functional
4. **STOP and VALIDATE**: Both menus work for identified users with registered targets
5. Merge if sufficient — disabled states and guest handling are incremental refinements

### Incremental Delivery

1. Setup + Foundational → Attributes wired
2. US1 + US2 → P2P items visible and clickable (MVP!)
3. US3 → Guest visibility validated
4. US4 → Disabled state for unregistered targets
5. US5 → Self-targeting disabled
6. Polish → Help docs, error handling, CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- T001 (shared helper extraction) is the only refactoring task — must not break existing `/p2p`, `/call`, `/sendfile` commands
- The disabled item pattern follows the existing `chat_context_menu.ex` approach: conditional `class="disabled"` + conditional `phx-click`
- No new CSS needed — retro `.disabled` class provides the grayed-out styling
- No JavaScript changes — all behavior is server-side LiveView events
