# Tasks: Channel Central Dialog

**Input**: Design documents from `/specs/007-channel-central/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required — Constitution Principle IV mandates TDD. Tests written alongside implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Migrations & Schemas)

**Purpose**: Database tables and Ecto schemas for new entities

- [x] T001 [P] Create ban_exceptions migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_ban_exceptions.exs` — table with channel_name (string 50, not null), nickname (string 16, not null), added_by (string 16, not null), timestamps(updated_at: false); unique index on (channel_name, nickname); index on channel_name
- [x] T002 [P] Create invite_exceptions migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_invite_exceptions.exs` — same structure as ban_exceptions table
- [x] T003 [P] Create BanException Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/ban_exception.ex` — fields: channel_name, nickname, added_by; changeset validating required fields, length constraints, unique constraint on (channel_name, nickname)
- [x] T004 [P] Create InviteException Ecto schema in `apps/retro_hex_chat/lib/retro_hex_chat/services/invite_exception.ex` — same structure as BanException schema

---

## Phase 2: Foundational (Domain Layer Extensions)

**Purpose**: Core domain infrastructure that MUST be complete before ANY user story UI work

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [P] Add ban exception CRUD queries to `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex` — add_ban_exception/3, remove_ban_exception/2, list_ban_exceptions/1; add tests in `apps/retro_hex_chat/test/retro_hex_chat/services/queries_test.exs` covering insert, duplicate (idempotent), remove, remove non-existent, list empty, list multiple
- [x] T006 [P] Add invite exception CRUD queries to `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex` — add_invite_exception/3, remove_invite_exception/2, list_invite_exceptions/1; add tests in `apps/retro_hex_chat/test/retro_hex_chat/services/queries_test.exs` with same coverage as T005
- [x] T007 Extend load_persisted_state in `apps/retro_hex_chat/lib/retro_hex_chat/channels/queries.ex` to also load ban_exceptions and invite_exceptions from Services.Queries; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/queries_test.exs` verifying exceptions are loaded for registered channels and empty for unregistered
- [x] T008 Extend Server GenServer state in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — add topic_set_by (nil), topic_set_at (nil), ban_exceptions (MapSet.new()), invite_exceptions (MapSet.new()) to init state; load ban_exceptions and invite_exceptions from persisted state in load_persisted_state/1; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` verifying new state fields are initialized and loaded correctly
- [x] T009 Extend set_topic handler in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — store topic_set_by and topic_set_at alongside the topic string; extend {:topic_changed, ...} broadcast payload to include set_at field; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` verifying metadata is stored and broadcast
- [x] T010 Extend state_to_map/1 (get_state return) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — add modes_detail map (%{moderated: bool, invite_only: bool, topic_lock: bool, key: string|nil, limit: int|nil}), topic_set_by, topic_set_at, ban_exceptions list, invite_exceptions list; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` verifying all new fields are present in get_state return
- [x] T011 Extend ChanServ cleanup in `apps/retro_hex_chat/lib/retro_hex_chat/services/chan_serv.ex` — delete all ban_exceptions and invite_exceptions when a channel is dropped (cleanup_channel function); add tests in `apps/retro_hex_chat/test/retro_hex_chat/services/chan_serv_test.exs` verifying cascade cleanup

**Checkpoint**: Domain layer complete — Server state enriched, queries available, persistence pipeline ready

---

## Phase 3: User Story 1 — Read-Only Channel Central (Priority: P1) MVP

**Goal**: Any channel member can open the Channel Central dialog and view all channel information in a read-only, tabbed dialog

**Independent Test**: Open Channel Central as a non-operator and verify all 5 tabs display correct, read-only information with no editable controls

### Tests for User Story 1

- [x] T012 [P] [US1] Write component tests for ChannelCentralDialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/channel_central_dialog_test.exs` — test all 5 tabs render with mock channel_state data; test non-operator view shows disabled checkboxes, no action buttons; test tab switching; test close button; test dialog not visible when visible=false; test empty state placeholders for bans/exceptions lists

### Implementation for User Story 1

- [x] T013 [US1] Create ChannelCentralDialog component shell in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — retro window with title-bar ("Channel Central — #channel_name"), tab bar with 5 tabs (General, Modes, Bans, Ban Exceptions, Invite Exceptions), window-body; attrs: visible, channel_state, active_tab, operator, plus all sub-dialog/selection assigns per contracts/liveview-events.md
- [x] T014 [US1] Implement General tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — Info section (channel name, creation date formatted, member count); Topic section showing topic text, "Set by X at Y" metadata; non-operator: read-only display only
- [x] T015 [US1] Implement Modes tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — labeled checkboxes for Moderated (+m), Invite Only (+i), Topic Lock (+t), Key (+k) with password field, Limit (+l) with number input; non-operator: all disabled, no Apply button
- [x] T016 [US1] Implement Bans tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — sunken-panel table showing banned nickname, banned_by, when; row selection via phx-click; non-operator: no Add/Remove buttons; empty state "No bans"
- [x] T017 [US1] Implement Ban Exceptions tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — sunken-panel table showing nickname, added_by, when; row selection; non-operator: no Add/Remove buttons; empty state "No ban exceptions"
- [x] T018 [US1] Implement Invite Exceptions tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — sunken-panel table showing nickname, added_by, when; row selection; non-operator: no Add/Remove buttons; empty state "No invite exceptions"
- [x] T019 [US1] Add phx-dblclick="open_channel_central" to channel items in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/tree_bar.ex` — add phx-dblclick with phx-value-channel on each channel <li> element
- [ ] T020 [US1] Add channel context menu to treebar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/tree_bar.ex` — right-click context menu on channel names with "Channel Central" as first item; phx-click="open_channel_central" with channel value; reuse existing context menu CSS pattern (z-index 300)
- [x] T021 [US1] Add Channel Central assigns and open/close event handlers to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add all Channel Central assigns to assign_defaults; implement "open_channel_central" handler (validate membership, fetch Server.get_state, determine operator status, assign state); implement "close_channel_central" handler (reset all CC assigns); implement "channel_central_tab" handler; implement Escape key handling for dialog
- [x] T022 [US1] Render ChannelCentralDialog in ChatLive template `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add component call at bottom of template (same pattern as other dialogs); pass all CC assigns
- [x] T023 [US1] Add "Channel Central" menu item to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add under Channel or Tools menu dropdown; phx-click="open_channel_central" using active_channel assign
- [x] T024 [US1] Write integration tests for open/close Channel Central in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test double-click opens dialog; test context menu opens dialog; test close button closes; test Escape closes; test non-member rejection; test all tabs display data; test non-operator sees disabled controls

**Checkpoint**: Channel Central dialog opens and displays all channel info in read-only mode. MVP complete.

---

## Phase 4: User Story 2 — Operator Topic Editing (Priority: P2)

**Goal**: Operators can edit the topic directly from the Channel Central dialog's General tab

**Independent Test**: Open as operator, change topic text, click "Set Topic", verify topic updates channel-wide

- [x] T025 [US2] Extend General tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — when operator=true: show editable text input pre-filled with current topic and "Set Topic" button (phx-submit="cc_set_topic"); when operator=false: read-only display (no input, no button)
- [x] T026 [US2] Implement cc_set_topic event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — call Server.set_topic with channel name, user's nickname, and new topic text; refresh channel_central_state on success; handle errors
- [x] T027 [US2] Write integration tests for topic editing in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test operator sees editable field; test non-operator does NOT see editable field; test setting topic updates dialog and channel; test clearing topic works

**Checkpoint**: Operators can edit topics from Channel Central

---

## Phase 5: User Story 3 — Operator Mode Toggles (Priority: P3)

**Goal**: Operators can toggle channel modes via checkboxes and an "Apply" button in the Modes tab

**Independent Test**: Open as operator, check "Moderated", click "Apply", verify +m is set on channel

- [x] T028 [US3] Extend Modes tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — when operator=true: enable all checkboxes, show key/limit input fields, show "Apply" button (phx-submit="cc_apply_modes"); form tracks pending changes in cc_modes_form assign
- [x] T029 [US3] Implement cc_apply_modes event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — compute diff between current modes_detail and form values; for each changed mode, call Server.set_mode with appropriate mode_string and params; validate: +k requires non-empty key, +l requires positive integer; show validation errors; refresh channel_central_state on success
- [x] T030 [US3] Write integration tests for mode toggles in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test operator sees enabled checkboxes + Apply; test non-operator sees disabled checkboxes, no Apply; test setting +m; test removing -i; test +k with key value; test +k with empty key shows error; test +l with valid number; test +l with 0 shows error; test multiple mode changes in one Apply

**Checkpoint**: Operators can toggle all channel modes from Channel Central

---

## Phase 6: User Story 4 — Operator Ban Management (Priority: P4)

**Goal**: Operators can add and remove bans from the Bans tab, including sub-dialogs

**Independent Test**: Open as operator, add a ban, verify it appears in list; remove it, verify it disappears

- [x] T031 [US4] Add ban management sub-dialog to ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — "Add Ban" sub-dialog (z-index 210) with nickname input and OK/Cancel buttons; operator view: show "Add Ban" and "Remove Ban" buttons below ban table; "Remove Ban" disabled when no selection
- [x] T032 [US4] Extend Bans tab in ChannelCentralDialog `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — operator=true: show Add Ban / Remove Ban buttons; row selection sets channel_central_ban_selected
- [x] T033 [US4] Implement ban CRUD event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — cc_ban_select, cc_open_add_ban, cc_close_add_ban, cc_add_ban (call Server.ban), cc_remove_ban (call Server.unban for selected); refresh channel_central_state after each mutation
- [x] T034 [US4] Write integration tests for ban management in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test operator sees Add/Remove buttons; test non-operator does NOT see buttons; test add ban flow (open sub-dialog, enter nick, confirm); test remove ban flow (select, click remove); test empty ban list placeholder

**Checkpoint**: Full ban management from Channel Central dialog

---

## Phase 7: User Story 5 — Ban Exceptions (+e) (Priority: P5)

**Goal**: Operators can manage ban exceptions; ban exceptions override bans in join policy

**Independent Test**: Add ban exception for user, ban that user, verify they can still join the channel

- [x] T035 [P] [US5] Implement Server.add_ban_exception/3 and Server.remove_ban_exception/3 in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — GenServer call handlers: check operator privilege, add/remove from ban_exceptions MapSet, persist if registered, broadcast {:ban_exception_added/removed, ...}; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` covering operator check, idempotent add/remove, broadcast, persistence for registered channels
- [x] T036 [P] [US5] Extend Policy.can_join? in `apps/retro_hex_chat/lib/retro_hex_chat/channels/policy.ex` — add ban_exceptions parameter (default MapSet.new()); move ban check from Server.join's check_not_banned/2 into Policy; check: if user in bans AND NOT in ban_exceptions → reject; update Server.join to pass ban_exceptions and call Policy instead of check_not_banned; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/policy_test.exs` covering: banned user rejected, banned user with exception allowed, non-banned user unaffected
- [x] T037 [US5] Add ban exception management sub-dialog and CRUD buttons to Ban Exceptions tab in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — "Add Exception" sub-dialog (z-index 210); operator: Add/Remove buttons; row selection sets channel_central_be_selected
- [x] T038 [US5] Implement ban exception CRUD event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — cc_ban_ex_select, cc_open_add_ban_ex, cc_close_add_ban_ex, cc_add_ban_exception (call Server.add_ban_exception), cc_remove_ban_exception (call Server.remove_ban_exception); refresh channel_central_state after mutations
- [x] T039 [US5] Write integration tests for ban exceptions in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test add/remove ban exception via dialog; test non-operator sees read-only list; test banned user with exception can join channel; test empty state placeholder

**Checkpoint**: Ban exceptions fully functional — backend override + UI management

---

## Phase 8: User Story 6 — Invite Exceptions (+I) (Priority: P6)

**Goal**: Operators can manage invite exceptions; invite exceptions bypass invite-only mode

**Independent Test**: Set channel +i, add invite exception for user, verify that user can join without invite

- [x] T040 [P] [US6] Implement Server.add_invite_exception/3 and Server.remove_invite_exception/3 in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — GenServer call handlers: check operator privilege, add/remove from invite_exceptions MapSet, persist if registered, broadcast {:invite_exception_added/removed, ...}; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs` covering operator check, idempotent add/remove, broadcast, persistence
- [x] T041 [P] [US6] Extend Policy.can_join? in `apps/retro_hex_chat/lib/retro_hex_chat/channels/policy.ex` — add invite_exceptions parameter (default MapSet.new()); check: if invite-only AND user NOT in invite_exceptions → reject; if invite-only AND user IN invite_exceptions → allow; update Server.join to pass invite_exceptions; add tests in `apps/retro_hex_chat/test/retro_hex_chat/channels/policy_test.exs` covering: invite-only rejects non-listed user, invite-only allows listed user, non-invite-only unaffected
- [x] T042 [US6] Add invite exception management sub-dialog and CRUD buttons to Invite Exceptions tab in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — "Add Exception" sub-dialog (z-index 210); operator: Add/Remove buttons; row selection sets channel_central_ie_selected
- [x] T043 [US6] Implement invite exception CRUD event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — cc_invite_ex_select, cc_open_add_invite_ex, cc_close_add_invite_ex, cc_add_invite_exception (call Server.add_invite_exception), cc_remove_invite_exception (call Server.remove_invite_exception); refresh channel_central_state after mutations
- [x] T044 [US6] Write integration tests for invite exceptions in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test add/remove invite exception via dialog; test non-operator sees read-only list; test invite-only channel allows listed user; test invite-only channel rejects non-listed user; test empty state placeholder

**Checkpoint**: Invite exceptions fully functional — backend bypass + UI management

---

## Phase 9: User Story 7 — Real-Time Updates (Priority: P7)

**Goal**: The Channel Central dialog updates in real time when other users change channel state

**Independent Test**: Two users: one changes mode via /mode, the other's open Channel Central reflects the change

- [x] T045 [US7] Add PubSub-driven Channel Central refresh logic to existing handle_info handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in :topic_changed, :mode_changed, :user_banned, :user_joined, :user_left handlers: if show_channel_central is true AND event's channel matches channel_central_channel, re-fetch Server.get_state and update channel_central_state assign
- [x] T046 [US7] Add handle_info handlers for new exception broadcast events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — handle {:ban_exception_added, ...}, {:ban_exception_removed, ...}, {:invite_exception_added, ...}, {:invite_exception_removed, ...}; refresh channel_central_state if dialog is open for the affected channel
- [x] T047 [US7] Implement operator status change detection in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in :mode_changed handler: if mode change affects current user's operator status (e.g., -o current_user), re-determine operator flag for channel_central and re-assign; dialog switches between editable and read-only view
- [x] T048 [US7] Write integration tests for real-time updates in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test topic change by another user updates dialog; test mode change by another user updates dialog; test ban by another user updates dialog ban list; test exception add/remove by another user updates dialog; test operator status revoked switches to read-only view

**Checkpoint**: Channel Central is fully reactive to external changes

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, CSS, data-testid attributes, E2E tests, linter verification

- [x] T049 [P] Add help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — add "feature-channel-central" topic (Features category) describing the dialog, all tabs, how to open (dblclick/context menu/menu bar), operator vs non-operator views; add "feature-ban-exceptions" topic explaining +e mode; add "feature-invite-exceptions" topic explaining +I mode; update "Keyboard Shortcuts" topic if applicable; add cross-references (see_also) to existing cmd-ban, cmd-mode topics; add unit tests for new topics in `apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs`
- [x] T050 [P] Add CSS styles for Channel Central dialog tabs and layout in `apps/retro_hex_chat_web/assets/css/layout.css` — tab bar styling (if not already from AddressBookDialog), modes fieldset layout, ban table column widths; add dark-theme counterparts in `apps/retro_hex_chat_web/assets/css/dark-theme.css`
- [x] T051 [P] Add data-testid attributes to ChannelCentralDialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/channel_central_dialog.ex` — data-testid="channel-central-dialog" on overlay, "cc-tab-general/modes/bans/ban-ex/invite-ex" on tabs, "cc-ban-entry-{nick}" on ban rows, "cc-ban-ex-entry-{nick}" on exception rows, "cc-invite-ex-entry-{nick}" on invite exception rows, "cc-set-topic-btn", "cc-apply-modes-btn", "cc-add-ban-btn", "cc-remove-ban-btn", etc.
- [x] T052 Write E2E tests for Channel Central in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_e2e_test.exs` — test open via dblclick; test open via context menu; test all 5 tabs display; test close via button; test close via Escape; test non-member rejection; test operator topic edit; test operator mode toggle; test operator ban add/remove; test operator ban exception add/remove; test operator invite exception add/remove; test non-operator read-only view; test real-time topic update; test real-time mode update
- [x] T053 Run full linter suite and fix any issues — `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`; ensure all new public functions have @spec; ensure all aliases alphabetical; ensure Credo nesting depth ≤ 2
- [x] T054 Run full test suite and verify zero failures — `make test` (excluding E2E), `make test.all` (including E2E); verify test count increased; verify no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migrations must exist before queries can run)
- **US1 (Phase 3)**: Depends on Phase 2 — needs enriched get_state
- **US2 (Phase 4)**: Depends on US1 — needs the dialog component and General tab
- **US3 (Phase 5)**: Depends on US1 — needs the dialog component and Modes tab
- **US4 (Phase 6)**: Depends on US1 — needs the dialog component and Bans tab
- **US5 (Phase 7)**: Depends on US1 — needs dialog + backend exception infrastructure from Phase 2
- **US6 (Phase 8)**: Depends on US1 — needs dialog + backend exception infrastructure from Phase 2
- **US7 (Phase 9)**: Depends on US1 — can be done alongside US2-US6 but best after all tabs exist
- **Polish (Phase 10)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundation only — no dependency on other stories
- **US2 (P2)**: Depends on US1 General tab existing
- **US3 (P3)**: Depends on US1 Modes tab existing
- **US4 (P4)**: Depends on US1 Bans tab existing
- **US5 (P5)**: Depends on US1 Ban Exceptions tab existing; can run in parallel with US2-US4
- **US6 (P6)**: Depends on US1 Invite Exceptions tab existing; can run in parallel with US2-US5
- **US7 (P7)**: Best done after US2-US6 are complete (needs all tabs to have editable content to test)

### Within Each User Story

- Tests written alongside implementation (TDD)
- Domain/backend changes before UI changes
- Component rendering before event handlers
- Core implementation before integration tests

### Parallel Opportunities

- **Phase 1**: T001-T004 all run in parallel (4 independent files)
- **Phase 2**: T005-T006 in parallel (different query functions); T009-T010 sequential (both modify server.ex)
- **Phase 3**: T012 (tests) can start in parallel with T013 (component shell)
- **US2, US3, US4**: Can run in parallel after US1 (different tabs, different event handlers)
- **US5, US6**: Can run in parallel (different exception types, different server functions)
- **Phase 10**: T049-T051 all in parallel (help topics, CSS, data-testid)

---

## Parallel Example: Phase 1

```
Agent 1: T001 — ban_exceptions migration
Agent 2: T002 — invite_exceptions migration
Agent 3: T003 — BanException Ecto schema
Agent 4: T004 — InviteException Ecto schema
```

## Parallel Example: User Story 5

```
Agent 1: T035 — Server.add_ban_exception/remove_ban_exception (server.ex)
Agent 2: T036 — Policy.can_join? ban exception bypass (policy.ex)
→ then sequentially:
Agent 1: T037 — Ban Exceptions tab UI (component)
Agent 1: T038 — Event handlers (chat_live.ex)
Agent 1: T039 — Integration tests
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (4 tasks)
2. Complete Phase 2: Foundational (7 tasks)
3. Complete Phase 3: User Story 1 (13 tasks)
4. **STOP and VALIDATE**: Open Channel Central, verify all tabs display channel info read-only
5. Deploy/demo if ready — the read-only view already delivers value

### Incremental Delivery

1. Setup + Foundational → Domain layer ready
2. US1 → Read-only dialog (MVP!)
3. US2 → Topic editing
4. US3 → Mode toggles
5. US4 → Ban management
6. US5 → Ban exceptions (+e)
7. US6 → Invite exceptions (+I)
8. US7 → Real-time updates
9. Polish → Help, CSS, E2E, linters
10. Each story adds operator capability without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution Principle IV: TDD required — tests alongside each task
- Constitution Principle XI: Help topics mandatory (T049)
- Total: 54 tasks across 10 phases
- Suggested MVP: Phase 1 + 2 + 3 (24 tasks) delivers full read-only dialog
