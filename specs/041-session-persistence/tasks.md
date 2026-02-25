# Tasks: Session Persistence — PM Conversations, Auto-Join & Notifications

**Input**: Design documents from `/specs/041-session-persistence/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — TDD is non-negotiable per Constitution Principle IV.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Domain-layer query and Session struct changes that all user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T001 Write unit tests for `list_pm_partners/2` query — test with 0, 3, 60 partners (50 limit), self-PM exclusion, soft-deleted PM exclusion, recency ordering in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs`
- [X] T002 Implement `list_pm_partners/2` in `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex` — SQL query using UNION of sender/recipient perspectives, GROUP BY partner nick with MAX(inserted_at), ORDER BY recency DESC, LIMIT opts[:limit] (default 50), excluding self-nick and soft-deleted messages
- [X] T003 Write unit tests for modified `Session.add_pm_conversation/2` (prepend-to-head, move-to-head if exists) and new `Session.move_pm_to_front/2` in `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`
- [X] T004 Modify `Session.add_pm_conversation/2` to prepend nickname to head of `pm_conversations` list (move to head if already present) and add `Session.move_pm_to_front/2` (no-op if not found) in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`

**Checkpoint**: Domain-layer query and session struct changes ready. All user stories can now proceed.

---

## Phase 2: User Story 1 — PM Conversation Restore on Connect (Priority: P1) MVP

**Goal**: Registered users see their PM conversation partners in the treebar immediately upon connecting, ordered by most recent conversation first.

**Independent Test**: Create a registered user with PM history, connect, verify treebar Private section is populated with correct partners in recency order.

### Tests for User Story 1

- [X] T005 [US1] Write LiveView test for PM conversation restore on connect — test registered user sees partners in recency order, 50-partner limit, empty history case, guest user sees nothing, self-nick excluded, in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`

### Implementation for User Story 1

- [X] T006 [US1] Add `restore_pm_conversations/2` to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex` — calls `Queries.list_pm_partners/2`, extracts nicknames (already in recency order), sets `pm_conversations` on session. Also subscribe to PubSub topics for each restored PM conversation.
- [X] T007 [US1] Wire `restore_pm_conversations/2` into `load_persisted_data/2` pipeline in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex` — add as the last step in the pipeline so it runs after other persisted data is loaded

**Checkpoint**: PM conversation restore working. Registered users see partners on connect.

---

## Phase 3: User Story 2 — Incoming PM Auto-Opens Conversation (Priority: P1)

**Goal**: When an incoming PM arrives from a contact not in the conversation list, the conversation auto-opens in the treebar with all notification signals.

**Independent Test**: Have User A send a PM to User B (not in B's conversation list), verify conversation auto-appears with unread badge, toast, sound, title flash.

### Tests for User Story 2

- [X] T008 [US2] Write LiveView test for PM auto-open — test new contact appears in treebar on incoming PM, ignored user does NOT auto-open, existing contact moves to top, sender's own conversation list updated on send, in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`

### Implementation for User Story 2

- [X] T009 [US2] Modify `apply_new_pm/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` — before existing unread/sound/notification logic, check if `other_nick` is NOT in `session.pm_conversations` AND NOT `IgnoreList.ignored?(session.ignore_list, other_nick, :pm)`: if so, call `Session.add_pm_conversation(session, other_nick)` to auto-add, and subscribe to the PM PubSub topic via `ensure_pm_subscription/2`
- [X] T010 [US2] Modify the outbound PM send path (where the sender's own conversation list is updated) to also call `Session.add_pm_conversation/2` to ensure the recipient appears in the sender's list — verify this already happens in `handle_pm_send` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex` (may already work, confirm and adjust if needed)

**Checkpoint**: PM auto-open working. All incoming PMs from non-ignored contacts auto-appear in treebar.

---

## Phase 4: User Story 3 — Auto-Join Channel on Join, Remove on Part (Priority: P2)

**Goal**: Channels are automatically added to auto-join on `/join` and removed on `/part` for registered users.

**Independent Test**: Join a channel as identified user, verify auto-join list updated. Part, verify removed. Reconnect, verify auto-joined.

### Tests for User Story 3

- [X] T011 [US3] Write LiveView test for auto-join on `/join` — test channel added to auto-join for identified user, NOT added for guest, NOT added for #lobby, limit of 20 with system message, channel key stored, no duplicates on rejoin, in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autojoin_auto_add_test.exs`
- [X] T012 [US3] Write LiveView test for auto-remove on `/part` — test channel removed from auto-join for identified user, NOT removed for guest, in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autojoin_auto_add_test.exs`

### Implementation for User Story 3

- [X] T013 [US3] Modify `handle_dispatch_result/2` for `{:ok, :join, channel, key}` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` — after successful join, if `session.identified` and channel != "#lobby": call `AutoJoinList.add_entry(session.autojoin_list, channel, key)`. On `{:ok, _}` update session and persist async. On `{:error, :list_full}` emit system message "Auto-join list is full (20 channels). #{channel} was not added to auto-join." On `{:error, :duplicate}` do nothing (idempotent).
- [X] T014 [US3] Modify `handle_dispatch_result/2` for `{:ok, :part, channel, _msg}` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` — after successful part, if `session.identified`: call `AutoJoinList.remove_entry(session.autojoin_list, channel)`, update session, persist async.

**Checkpoint**: Auto-join add/remove working. Channels remembered across sessions for registered users.

---

## Phase 5: User Story 4 — PM Conversation Ordering by Recency (Priority: P2)

**Goal**: PM conversation list always reflects most recent activity — new messages (sent or received) move that conversation to the top.

**Independent Test**: With multiple PM conversations, send/receive messages and verify the list reorders by recency.

### Tests for User Story 4

- [X] T015 [US4] Write LiveView test for PM recency ordering — test incoming PM moves conversation to top, outgoing PM moves conversation to top, restored conversations maintain DB recency order, in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`

### Implementation for User Story 4

- [X] T016 [US4] Modify `apply_new_pm/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` — for ALL incoming PMs (not just new contacts), call `Session.move_pm_to_front(session, other_nick)` to reorder the conversation list by recency. This should happen after the auto-add logic from T009.
- [X] T017 [US4] Modify the outbound PM send path in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex` — after sending a PM, call `Session.move_pm_to_front(session, target_nick)` to move the recipient to the top of the conversation list

**Checkpoint**: PM recency ordering working. Conversations always reflect latest activity.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation and final validation

- [X] T018 [P] Add help topic "PM Persistence" to the Features category in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — explain that PM conversations are restored on connect for registered users, ordered by recency, limited to 50, closing is session-only. Add "See Also" cross-references to "Private Messages" and "Ignore List" topics.
- [X] T019 [P] Add help topic "Auto-Join Channels" to the Features category in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — explain that channels are auto-added on `/join` and auto-removed on `/part` for registered users, 20-channel limit, #lobby excluded. Add "See Also" cross-references to "AutoJoin" command topic.
- [X] T020 [P] Update existing `/join` and `/part` command help topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/commands.ex` — add note that `/join` auto-adds to auto-join list and `/part` auto-removes for identified users
- [X] T021 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — start immediately
- **US1 (Phase 2)**: Depends on Phase 1 (needs `list_pm_partners/2` query)
- **US2 (Phase 3)**: Depends on Phase 1 (needs modified `add_pm_conversation/2`). Can run in parallel with US1.
- **US3 (Phase 4)**: Depends on Phase 1 only. Can run in parallel with US1 and US2.
- **US4 (Phase 5)**: Depends on Phase 1 (needs `move_pm_to_front/2`). Can run in parallel with US1, US2, US3.
- **Polish (Phase 6)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Independent — needs only foundational query
- **US2 (P1)**: Independent — needs only foundational session changes
- **US3 (P2)**: Fully independent — no PM-related dependencies
- **US4 (P2)**: Independent at code level, but logically enhances US1+US2

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Implementation tasks within a story are sequential (each builds on prior)

### Parallel Opportunities

- T001 and T003 can run in parallel (different files: queries_test vs session_test)
- T002 and T004 can run in parallel after their respective tests (different files: queries.ex vs session.ex)
- US1, US2, US3, US4 can all start in parallel after Phase 1
- T018, T019, T020 can all run in parallel (different sections of help topics)

---

## Parallel Example: Phase 1

```bash
# Launch foundational tests in parallel:
Task: "T001 - Unit tests for list_pm_partners/2 in queries_test.exs"
Task: "T003 - Unit tests for modified Session functions in session_test.exs"

# Then launch implementations in parallel:
Task: "T002 - Implement list_pm_partners/2 in queries.ex"
Task: "T004 - Modify Session.add_pm_conversation/2, add move_pm_to_front/2 in session.ex"
```

## Parallel Example: User Stories (after Phase 1)

```bash
# All user stories can start simultaneously:
Task: "T005-T007 - US1: PM Conversation Restore"
Task: "T008-T010 - US2: PM Auto-Open"
Task: "T011-T014 - US3: Auto-Join on Join/Part"
Task: "T015-T017 - US4: PM Recency Ordering"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Foundational query + session changes
2. Complete Phase 2: US1 — PM restore on connect
3. Complete Phase 3: US2 — PM auto-open on incoming
4. **STOP and VALIDATE**: PM persistence is fully functional
5. Both P1 stories deliver the highest-impact user value

### Incremental Delivery

1. Phase 1 → Foundation ready
2. US1 → PM conversations appear on connect (MVP!)
3. US2 → Incoming PMs auto-open (critical complement to US1)
4. US3 → Channels auto-remembered (independent improvement)
5. US4 → PM list ordered by recency (polish)
6. Phase 6 → Help docs + CI validation

---

## Notes

- No new database migrations needed — all queries use existing tables and indexes
- `list_pm_partners/2` leverages the existing `idx_pm_conversation` composite index
- Circular auto-join prevention is architectural: auto-join timer calls `join_channel/4` directly, bypassing `CommandDispatch` where the auto-add logic lives
- PM PubSub subscription on restore is important — without it, clicking a restored conversation works but real-time messages won't arrive
- Total: 21 tasks across 6 phases
