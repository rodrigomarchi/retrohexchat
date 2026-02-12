# Tasks: Channel Invite System

**Input**: Design documents from `/specs/010-channel-invite-system/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (Test-First Development). Tests are written first, verified to fail, then implementation follows.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain app**: `apps/retro_hex_chat/lib/retro_hex_chat/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/`
- **Web app**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **Web tests**: `apps/retro_hex_chat_web/test/retro_hex_chat_web/`

---

## Phase 1: Setup

**Purpose**: No project initialization needed — this feature extends existing infrastructure. No new dependencies, no migrations, no new bounded contexts.

_No setup tasks required._

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain extensions that MUST be complete before ANY user story can be implemented. These are shared building blocks used across multiple stories.

- [x] T001 [P] Add `auto_join_on_invite` field to Session struct and @type t in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [x] T002 [P] Add `get_auto_join_on_invite/1`, `set_auto_join_on_invite/2`, `toggle_auto_join_on_invite/1` functions with @spec to `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- [x] T003 [P] Write unit tests for `get_auto_join_on_invite/1`, `set_auto_join_on_invite/2`, `toggle_auto_join_on_invoke/1` in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`
- [x] T004 [P] Create `/invite` command handler module implementing Handler behaviour (`validate/1`, `execute/2`, `help/0`) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/invite.ex`
- [x] T005 [P] Write unit tests for Invite handler — all execute/2 clauses (no args, "auto", single nickname, nickname + channel) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/invite_test.exs`
- [x] T006 Register `"invite" => RetroHexChat.Commands.Handlers.Invite` in @commands map in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [x] T007 Add `"invite"` to lookup test in `apps/retro_hex_chat/test/retro_hex_chat/commands/registry_test.exs`
- [x] T008 Initialize `pending_invites: []` assign in `assign_defaults/2` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

**Checkpoint**: Foundation ready — Session extended, command handler created and registered, socket assigns initialized. User story implementation can now begin.

---

## Phase 3: User Story 1 — Operator Invites User to Invite-Only Channel (Priority: P1) 🎯 MVP

**Goal**: An operator can type `/invite Alice #private` (or `/invite Alice` using active channel) and the system validates permissions, adds a transient invite_exception, broadcasts to the invitee's PubSub topic, and shows the operator a confirmation message.

**Independent Test**: Send `/invite` as an operator in a +i channel → verify confirmation system message appears. Test all error paths (non-operator, non-+i channel, user not found, user already in channel).

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Write unit tests for `:send_invite` ui_action — success path (confirmation message, broadcast, invite_exception added) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T010 [P] [US1] Write unit tests for `:send_invite` ui_action — error paths (non-operator, non-+i, user not found, user already in channel) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`

### Implementation for User Story 1

- [x] T011 [US1] Implement `handle_ui_action(socket, :send_invite, payload)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — validate operator/channel/+i/target, call `Channel.Server.add_invite_exception/3`, broadcast `{:channel_invite, payload}` to `"user:#{target}"`, show `"* Inviting <target> to <channel>"` system message
- [x] T012 [US1] Implement edge case handling in `:send_invite` — `"* Alice is already in #private"` (FR-015), `"* User 'Alice' not found"` (FR-016), `"* You are not a channel operator"` (FR-017), `"* #general is not invite-only — anyone can join"` (FR-014) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T013 [US1] Run tests: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs` — verify T009, T010 pass

**Checkpoint**: Operator can send invites with full validation and error handling. Broadcast is sent but no receiver-side handling yet.

---

## Phase 4: User Story 2 — Invited User Receives Notification and Joins (Priority: P1)

**Goal**: When the invitee's ChatLive receives the `{:channel_invite, payload}` broadcast, it renders a Windows 98-style dialog with Join/Ignore buttons. Clicking Join joins the channel; clicking Ignore dismisses the dialog.

**Independent Test**: Simulate receiving a `:channel_invite` PubSub message → verify dialog renders with correct inviter/channel. Click Join → verify user joins channel and dialog disappears. Click Ignore → verify dialog disappears without joining.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T014 [P] [US2] Write test for `handle_info({:channel_invite, ...})` — invite added to `pending_invites`, dialog renders with inviter name and channel in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T015 [P] [US2] Write test for `"invite_accept"` event — user joins channel, invite removed from `pending_invites`, invite_exception removed in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T016 [P] [US2] Write test for `"invite_ignore"` event — dialog dismissed, invite removed from `pending_invites`, invite_exception removed, user NOT joined in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T017 [P] [US2] Write test for cascading dialogs — multiple invites to different channels render as stacked Win98 dialogs with offset in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`

### Implementation for User Story 2

- [x] T018 [P] [US2] Create `InviteDialog` function component with `attr :pending_invites` — Win98 `.window`/`.title-bar` structure, cascading offset per index, Join/Ignore buttons with `phx-value-channel` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/invite_dialog.ex`
- [x] T019 [US2] Implement `handle_info({:channel_invite, payload})` — add invite to `pending_invites` (dedup by channel per FR-020) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T020 [US2] Implement `handle_event("invite_accept", params)` — find invite, join channel via existing join flow, remove from `pending_invites`, call `Channel.Server.remove_invite_exception/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T021 [US2] Implement `handle_event("invite_ignore", params)` — find invite, remove from `pending_invites`, call `Channel.Server.remove_invite_exception/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T022 [US2] Add `<InviteDialog.invite_dialog pending_invites={@pending_invites} />` to `render/1` and add Escape key handling for invite dialogs in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T023 [US2] Run tests: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs` — verify T014-T017 pass

**Checkpoint**: Complete invite flow works end-to-end (operator sends → invitee sees dialog → Join/Ignore). This is the MVP — Stories 1+2 together deliver full value.

---

## Phase 5: User Story 3 — Invite Expiration (Priority: P2)

**Goal**: Invites expire after 5 minutes. Expired invites are removed from `pending_invites` and `invite_exceptions`. Clicking Join on a stale dialog shows "This invitation has expired".

**Independent Test**: Receive an invite, simulate timer firing → verify invite removed from pending_invites and invite_exception cleaned up. Attempt to accept an expired invite → verify error message.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T024 [P] [US3] Write test for `Process.send_after` timer creation — verify timer_ref stored in pending invite map in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T025 [P] [US3] Write test for `handle_info({:invite_expired, channel})` — invite removed from `pending_invites`, `Channel.Server.remove_invite_exception/3` called in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T026 [P] [US3] Write test for accepting expired invite — `"invite_accept"` after expiration shows error "This invitation has expired" in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T027 [P] [US3] Write test for duplicate invite reset — second invite to same channel cancels old timer, resets expiration in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`

### Implementation for User Story 3

- [x] T028 [US3] Add `Process.send_after(self(), {:invite_expired, channel}, 300_000)` timer creation when adding invite to `pending_invites` — store `timer_ref` in invite map in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T029 [US3] Implement `handle_info({:invite_expired, channel})` — remove from `pending_invites`, call `Channel.Server.remove_invite_exception/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T030 [US3] Update `handle_event("invite_accept")` to check if invite still exists in `pending_invites` — show error "This invitation has expired" if not found in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T031 [US3] Update `handle_info({:channel_invite})` to cancel existing timer for same channel before creating new one (FR-020 dedup) — call `Process.cancel_timer/1` on old `timer_ref` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T032 [US3] Update `handle_event("invite_accept")` and `handle_event("invite_ignore")` to cancel timer via `Process.cancel_timer/1` before removing invite in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T033 [US3] Run tests: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs` — verify T024-T027 pass

**Checkpoint**: Invites now expire after 5 minutes. Timer management is complete. All security scenarios covered.

---

## Phase 6: User Story 4 — Auto-Join on Invite Preference (Priority: P3)

**Goal**: Users can toggle an "Auto-join on invite" preference via `/invite auto`. When enabled, receiving an invite skips the dialog and joins immediately with a system message.

**Independent Test**: Toggle auto-join via `/invite auto` → verify confirmation message. Receive invite with auto-join enabled → verify user is auto-joined without dialog.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T034 [P] [US4] Write test for `:toggle_auto_join_on_invite` ui_action — Session preference toggled, confirmation system message shown in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T035 [P] [US4] Write test for auto-join path in `handle_info({:channel_invite})` — when `auto_join_on_invite: true`, user auto-joined, system message `"* You have been invited to <channel> by <inviter> (auto-joined)"` shown, no dialog rendered in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`
- [x] T036 [P] [US4] Write test confirming default behavior — `auto_join_on_invite: false`, invite shows dialog (no auto-join) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs`

### Implementation for User Story 4

- [x] T037 [US4] Implement `handle_ui_action(socket, :toggle_auto_join_on_invite, _payload)` — call `Session.toggle_auto_join_on_invite/1`, show `"* Auto-join on invite: enabled/disabled"` system message in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T038 [US4] Update `handle_info({:channel_invite})` to check `Session.get_auto_join_on_invite/1` — if true, join channel immediately, show `"* You have been invited to <channel> by <inviter> (auto-joined)"`, remove invite_exception (consumed) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`
- [x] T039 [US4] Run tests: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_invite_test.exs` — verify T034-T036 pass

**Checkpoint**: Auto-join preference fully functional. All 4 user stories complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, lint compliance, and full integration validation

- [x] T040 [P] Add `"cmd-invite"` help topic (Commands category) with syntax, description, examples, see-also in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [x] T041 [P] Add `"feature-channel-invites"` help topic (Features category) with invite system overview, auto-join info in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [x] T042 Update "See Also" cross-references — add `cmd-invite` link to `cmd-join` topic, add `cmd-invite` and `feature-channel-invites` links to `mode-i` topic (if exists) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`
- [x] T043 Run full test suite: `make test` — verify all tests pass with zero regressions
- [x] T044 Run lint suite: `make lint` — verify `mix format`, Credo, and Dialyxir pass with no warnings
- [ ] T045 Run quickstart.md manual smoke test — verify end-to-end flow in browser

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Skipped — no setup needed
- **Foundational (Phase 2)**: No external dependencies — can start immediately
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion (T001-T008)
- **User Story 2 (Phase 4)**: Depends on Phase 3 completion (needs `:send_invite` to generate broadcasts)
- **User Story 3 (Phase 5)**: Depends on Phase 4 completion (needs `pending_invites` and dialog infrastructure)
- **User Story 4 (Phase 6)**: Depends on Phase 4 completion (needs `handle_info({:channel_invite})` to add auto-join branch)
- **Polish (Phase 7)**: Depends on all user story phases being complete

### User Story Dependencies

- **US1 (P1)**: Foundational → US1 (operator-side sending)
- **US2 (P1)**: Foundational → US1 → US2 (receiver-side dialog requires broadcast from US1)
- **US3 (P2)**: Foundational → US1 → US2 → US3 (expiration builds on dialog infrastructure from US2)
- **US4 (P3)**: Foundational → US1 → US2 → US4 (auto-join branches from the invite receive handler in US2)
- **US3 and US4**: Can run in parallel after US2 is complete (different code paths in `handle_info`)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implementation follows contract specifications from `contracts/domain.md` and `contracts/web.md`
- Run story-specific tests after implementation to verify they pass
- Checkpoint verification before moving to next story

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T001, T002, T003 (Session changes) can run in parallel with T004, T005 (handler creation)
- T006, T007 (registry) depend on T004 (handler must exist)
- T008 (socket assign) is independent of all other Phase 2 tasks

**Phase 3 (US1)**:
- T009, T010 (tests) can run in parallel
- T011, T012 (implementation) are sequential (core before edge cases)

**Phase 4 (US2)**:
- T014, T015, T016, T017 (tests) can all run in parallel
- T018 (component) can run in parallel with T019-T021 (LiveView handlers)

**Phase 5+6 (US3+US4)**:
- US3 and US4 can run in parallel after US2 completion
- Within each: all tests can run in parallel

**Phase 7 (Polish)**:
- T040, T041 (help topics) can run in parallel

---

## Parallel Example: User Story 2

```text
# Launch all tests for US2 together:
Task: T014 — test handle_info({:channel_invite, ...})
Task: T015 — test "invite_accept" event
Task: T016 — test "invite_ignore" event
Task: T017 — test cascading dialogs

# Then launch component + handlers in parallel:
Task: T018 — InviteDialog component (separate file)
Task: T019 — handle_info for :channel_invite (chat_live.ex — sequential with T020-T022)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 2: Foundational (T001-T008)
2. Complete Phase 3: User Story 1 — operator can send invites (T009-T013)
3. Complete Phase 4: User Story 2 — invitee sees dialog and can Join/Ignore (T014-T023)
4. **STOP and VALIDATE**: Full invite flow works end-to-end
5. Deploy/demo if ready — Stories 1+2 together form a complete, usable feature

### Incremental Delivery

1. Foundational → US1 → US2 → **MVP ready** (core invite flow)
2. Add US3 (expiration) → **Security hardened** (invites no longer permanent)
3. Add US4 (auto-join) → **Power user feature** (convenience for frequent invite recipients)
4. Polish → **Production ready** (help docs, lint, full validation)

### Key Insight

User Stories 3 and 4 can be developed in parallel after US2 is complete, as they modify different code paths:
- US3 modifies timer management and expiration handling
- US4 modifies the auto-join branch in `handle_info({:channel_invite})`

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No database migrations — all state is in-memory (socket assigns, Session struct, Channel.Server MapSet)
- Reference patterns: `handlers/ban.ex` (handler), `perform_dialog.ex` (dialog component), `chat_live.ex` (ui_action dispatch)
- Timer management is critical in US3 — always cancel timers on accept/ignore/expire to prevent leaks
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
