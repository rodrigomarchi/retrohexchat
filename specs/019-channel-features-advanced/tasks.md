# Tasks: Channel Features Advanced

**Input**: Design documents from `/specs/019-channel-features-advanced/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — Constitution Principle IV mandates TDD.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Database migration and shared infrastructure needed by multiple stories

- [X] T001 Create Ecto migration to add `mode_join_throttle` column to `registered_channels` table in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_add_advanced_channel_modes.exs`
- [X] T002 Add `mode_join_throttle` field to `RegisteredChannel` schema and changeset in `apps/retro_hex_chat/lib/retro_hex_chat/services/registered_channel.ex`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain changes that ALL user stories depend on — Membership, Modes, Policy, and Handler context

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation

- [X] T003 [P] Write unit tests for Membership extended roles (:owner, :half_operator), rank/1, owners/1, half_operators/1, outranks?/3 in `apps/retro_hex_chat/test/retro_hex_chat/channels/membership_test.exs`
- [X] T004 [P] Write unit tests for Modes new flags (:no_external, :secret, :private, :strip_colors, :registered_only, :no_knock), join_throttle field, +s/+p mutual exclusivity validation, new predicate functions, and to_string/1 with new flags in `apps/retro_hex_chat/test/retro_hex_chat/channels/modes_test.exs`
- [X] T005 [P] Write unit tests for Policy new functions: can_kick?/3 (rank-based), can_ban?/2 (operator+ only), can_set_mode?/3 (per-flag permissions: +q owner-only, +h/+o operator+, +v half-op+, channel flags operator+), updated can_speak?/3 for +n mode, updated can_join? for +R and +j in `apps/retro_hex_chat/test/retro_hex_chat/channels/policy_test.exs`

### Implementation for Foundation

- [X] T006 [P] Extend Membership module: add :owner and :half_operator to role type, add rank/1 (owner=4, operator=3, half_operator=2, voiced=1, regular=0), add owners/1, half_operators/1, outranks?/3 functions with @spec in `apps/retro_hex_chat/lib/retro_hex_chat/channels/membership.ex`
- [X] T007 [P] Extend Modes module: add join_throttle field to struct, add 6 new flag atoms to @channel_flags map (n→:no_external, s→:secret, p→:private, c→:strip_colors, R→:registered_only, K→:no_knock), add +j parameterized mode parsing (count:seconds format), add +s/+p mutual exclusivity validation in apply_changes/3, add 7 new predicate functions (no_external?/1, secret?/1, private?/1, strip_colors?/1, registered_only?/1, no_knock?/1, has_join_throttle?/1), update to_string/1 for new flags in `apps/retro_hex_chat/lib/retro_hex_chat/channels/modes.ex`
- [X] T008 Extend Policy module: add can_kick?/3 (actor rank > target rank, actor >= half_operator), add can_ban?/2 (actor rank >= operator), add can_set_mode?/3 (per-flag permission: +q requires owner, +h/+o requires operator+, +v requires half_operator+, channel flags require operator+), update can_speak?/3 to check +n mode (non-member → error "Cannot send to channel (no external messages)"), update can_join? to accept identified parameter for +R check and join_timestamps/throttle params for +j check in `apps/retro_hex_chat/lib/retro_hex_chat/channels/policy.ex`
- [X] T009 [P] Update Handler context type: add half_operator_in field to @type context in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex`

**Checkpoint**: Foundation ready — Membership, Modes, Policy, and Handler context support all new roles, modes, and permission checks. All foundation tests green.

---

## Phase 3: User Story 1 — Extended User Hierarchy (Priority: P1) — MVP

**Goal**: 5-tier role hierarchy (owner > operator > half-op > voice > regular) with rank-based permission enforcement in kick/ban/mode operations and nicklist display with ~@%+ prefixes.

**Independent Test**: Create a channel → first joiner is owner (~) → assign roles +q/+h → verify nicklist shows 5 groups → verify half-ops cannot kick operators → verify operators cannot kick owners.

### Tests for User Story 1

- [X] T010 [P] [US1] Write integration tests for Server hierarchy: first joiner gets :owner, set_mode +q/+h/+o/+v, kick rank enforcement (half-op can't kick operator, operator can't kick owner), ban rank enforcement, mode permission enforcement (half-op can only +v, operator can't +q), apply_user_modes with +q/+h in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`
- [X] T011 [P] [US1] Write unit tests for Nicklist component with 5 groups (owners ~, operators @, half-operators %, voiced +, regular), alphabetical sorting within groups, correct CSS classes (nick-owner, nick-halfop) in `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/nicklist_test.exs`

### Implementation for User Story 1

- [X] T012 [US1] Update Server: change determine_join_role/2 to return :owner for first joiner of unregistered channels, extend apply_user_modes/3 to handle +q/-q and +h/-h user mode flags (consuming next param as target nickname), update set_mode/4 to use Policy.can_set_mode?/3 for per-flag permission checks instead of simple operator? check, update kick/4 to use Policy.can_kick?/3 for rank-based enforcement, update ban/4 to use Policy.can_ban?/2, update state_to_map/1 to include owners and half_operators lists in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T013 [US1] Update CommandDispatch: modify channels_where_operator/1 to include channels where user is :owner (check both state.operators and state.owners), add channels_where_half_operator/1 function, add half_operator_in to context map built in dispatch_command/5 in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`
- [X] T014 [US1] Update Mode handler: change require_operator/2 to accept both operator_in and half_operator_in, allow half-ops to execute only +v/-v modes (reject other modes with "Insufficient privileges to set channel modes") in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mode.ex`
- [X] T015 [US1] Update Kick handler: change require_operator/2 to accept half_operator_in in addition to operator_in, allowing half-ops to use /kick (actual rank validation happens in Server.kick/4) in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/kick.ex`
- [X] T016 [US1] Update Nicklist component: add owners (~) and half-operators (%) groups to template and group_users/1 function, add CSS classes nick-owner and nick-halfop, update group order to owners/operators/half_operators/voiced/regular with correct prefixes (~, @, %, +, none) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex`
- [X] T017 [US1] Update ChannelState PubSub handler: add apply_mode_to_users/3 clauses for "+q"/"-q" (set/unset :owner) and "+h"/"-h" (set/unset :half_operator) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`
- [X] T018 [US1] Add CSS rules for nick-owner and nick-halfop classes in the appropriate CSS file under `apps/retro_hex_chat_web/assets/css/`

**Checkpoint**: User Story 1 complete — 5-tier hierarchy works end-to-end. First joiner is owner. All rank-based permission checks enforced. Nicklist displays 5 groups with correct prefixes.

---

## Phase 4: User Story 2 — Protection Modes +n, +s, +p (Priority: P2)

**Goal**: No external messages (+n), secret channels (+s hidden from /list and /whois), private channels (+p shown as "Prv" in /list for non-members). +s and +p mutually exclusive.

**Independent Test**: Set +n → non-member message blocked. Set +s → channel invisible in /list and /whois. Set +p → channel shows as "Prv" in /list. Set +s then +p → rejected.

### Tests for User Story 2

- [X] T019 [P] [US2] Write integration tests for Server +n mode: non-member message blocked with "Cannot send to channel (no external messages)", member message succeeds, system messages not blocked in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`
- [X] T020 [P] [US2] Write tests for ChannelListLive filtering: +s channel excluded from list for non-members, +p channel shown as "Prv" for non-members and normally for members, +s/+p mutual exclusivity in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_live_test.exs`

### Implementation for User Story 2

- [X] T021 [US2] Update Server send_message/4: add +n (no_external) check — if mode is set and sender is not a member, return {:error, "Cannot send to channel (no external messages)"} in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T022 [US2] Update ChannelListLive: modify list_active_channels/0 to accept viewer_channels parameter, query each channel's modes via Server.get_state/1, filter out :secret channels for non-members, show :private channels as %{name: "Prv", topic: nil} for non-members, pass viewer_channels from session in mount/3 in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex`
- [X] T023 [US2] Update Whois helper: modify get_user_channels/1 to accept requester_channels as second parameter, filter out channels with :secret mode unless requester is also a member, update call site in gather_whois_data/4 in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/whois.ex`

**Checkpoint**: User Story 2 complete — +n blocks external messages, +s hides from /list and /whois, +p shows as "Prv". Mutual exclusivity enforced.

---

## Phase 5: User Story 3 — Knock System (Priority: P2)

**Goal**: /knock command lets non-members request access to invite-only (+i) channels. Operators see knock notifications. +K mode disables knock. Rate limited to 1 per 60s per channel.

**Independent Test**: Set channel +i → non-member /knock → operators see notification → /invite → user joins. Set +K → knock rejected.

### Tests for User Story 3

- [X] T024 [P] [US3] Write unit tests for Knock command handler: validate args, channel not +i error, +K disabled error, already member error, banned error, success returns :ui_action in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/knock_test.exs`
- [X] T025 [P] [US3] Write integration tests for Server knock/3: validates +i required, +K blocks, banned user blocked, member blocked, success broadcasts {:knock, payload} via PubSub in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`

### Implementation for User Story 3

- [X] T026 [US3] Add knock/3 function to Server: validate channel is +i (invite_only?), not +K (no_knock?), user not banned, user not already member, then broadcast {:knock, %{nickname, channel, message}} to "channel:#{name}" PubSub topic in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T027 [US3] Create Knock command handler implementing Handler behaviour: parse args as [channel_name | rest], validate channel starts with #, return {:ok, :ui_action, :knock_channel, %{channel: channel, message: message}} in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/knock.ex`
- [X] T028 [US3] Register "knock" command in command registry in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`
- [X] T029 [US3] Add :knock_channel UI action handler in core: call Server.knock/3, on success display "Knock sent to #{channel}", on error display error message, track knock_timestamps in socket assigns for 60-second rate limiting per channel in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/core.ex`
- [X] T030 [US3] Add knock PubSub handler: handle {:knock, payload} in channel_state.ex, display system message "* #{nick} has knocked on #{channel} (#{msg})" only if current user is :owner or :operator in the channel (check channel_users assigns) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`

**Checkpoint**: User Story 3 complete — /knock command works end-to-end. Operators see notifications. +K disables knock. Rate limiting enforced.

---

## Phase 6: User Story 4 — Strip Colors (+c) and Registered-Only (+R) (Priority: P3)

**Goal**: +c strips all formatting codes from messages/actions server-side before persist/broadcast. +R blocks unregistered users from joining (existing members grandfathered).

**Independent Test**: Set +c → send colored message → arrives stripped. Set +R → unregistered join blocked → registered join succeeds.

### Tests for User Story 4

- [X] T031 [P] [US4] Write integration tests for Server +c mode: message with color codes arrives stripped, /me action with color codes arrives stripped, formatting codes (bold \x02, italic \x1D, underline \x1F, color \x03, reverse \x16, reset \x0F) all removed in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`
- [X] T032 [P] [US4] Write integration tests for Server +R mode: unregistered user join blocked with "You must be registered to join this channel", registered user join succeeds, existing unregistered members stay when +R is set in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`

### Implementation for User Story 4

- [X] T033 [US4] Update Server send_message/4: when :strip_colors mode is active, call Formatter.strip/1 on content before persisting to DB and broadcasting via PubSub in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T034 [US4] Update Server join flow: accept identified keyword option (default: false), pass to Policy.can_join? for +R check — if :registered_only mode active and identified is false, return {:error, "You must be registered to join this channel"} in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T035 [US4] Update join call sites in web layer: pass identified: session.identified when calling Server.join/4 from channel helpers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex`

**Checkpoint**: User Story 4 complete — +c strips all formatting server-side. +R blocks unregistered joins while grandfathering existing members.

---

## Phase 7: User Story 5 — Join Throttle (+j) (Priority: P3)

**Goal**: +j count:seconds limits join rate per channel. Excess joins rejected. Operators bypass throttle.

**Independent Test**: Set +j 5:10 → 5 joins succeed → 6th blocked → wait 10s → joins succeed again. Operator join always succeeds.

### Tests for User Story 5

- [X] T036 [P] [US5] Write integration tests for Server +j mode: joins within limit succeed, join exceeding limit blocked with "Channel join throttle active, please try again shortly", operator bypass, window expiration resets counter, invalid +j params rejected in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`

### Implementation for User Story 5

- [X] T037 [US5] Update Server: add join_timestamps field to state (default: []), implement join throttle check in join flow — filter timestamps within window, count, reject if at/above limit (operators bypass), append current timestamp on successful join, update init_state to include join_timestamps in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- [X] T038 [US5] Update persistence: load mode_join_throttle from registered_channels table in Queries.load_persisted_state/1, save join_throttle to mode_join_throttle column when persisting channel modes in `apps/retro_hex_chat/lib/retro_hex_chat/channels/queries.ex`

**Checkpoint**: User Story 5 complete — +j throttle works. Operators bypass. Settings persist for registered channels.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help system, mode persistence, and final validation

- [X] T039 [P] Add help topics for all new modes and /knock command: +q (Owner), +h (Half-Operator), +n (No External Messages), +s (Secret), +p (Private), +c (Strip Colors), +R (Registered Only), +j (Join Throttle), +K (No Knock), /knock command — each with syntax, description, examples, and See Also cross-references in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/channel_modes.ex`
- [X] T040 [P] Update channel modes overview help topic to include all new modes in the mode reference table in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/channel_modes.ex`
- [X] T041 Verify all new modes persist for registered channels: set modes on registered channel → restart channel process (stop/start) → verify modes restored correctly, including join_throttle parameter in `apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs`
- [X] T042 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — migration and schema can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — Modes needs struct ready, Policy needs Membership
- **Phase 3 (US1 Hierarchy)**: Depends on Phase 2 — Server needs Membership/Policy/Modes
- **Phase 4 (US2 Protection)**: Depends on Phase 2 — uses Modes predicates and Policy
- **Phase 5 (US3 Knock)**: Depends on Phase 2 — uses Modes predicates; independent of US1/US2
- **Phase 6 (US4 Strip/Registered)**: Depends on Phase 2 — uses Modes predicates and Server
- **Phase 7 (US5 Throttle)**: Depends on Phase 1 (migration) + Phase 2 — uses Modes and Server
- **Phase 8 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1 Hierarchy)**: Foundation only — no cross-story deps. **MVP target.**
- **US2 (P2 Protection)**: Foundation only — independent of US1
- **US3 (P2 Knock)**: Foundation only — independent of US1/US2
- **US4 (P3 Strip/Registered)**: Foundation only — independent of other stories
- **US5 (P3 Throttle)**: Foundation + Phase 1 migration — independent of other stories

### Within Each User Story

- Tests written FIRST — must FAIL before implementation
- Domain layer before web layer
- Server changes before command handler changes
- Command handlers before PubSub handlers

### Parallel Opportunities

- **Phase 2**: T003, T004, T005 tests run in parallel; T006, T007, T009 implementation in parallel
- **Phase 3-7**: After Phase 2 completes, US1-US5 can be worked on in parallel
- **Within each story**: Test tasks marked [P] run in parallel
- **Phase 8**: T039 and T040 help topics run in parallel

---

## Parallel Example: Phase 2 Foundation

```bash
# Tests (all [P] — different files):
T003: Membership tests (membership_test.exs)
T004: Modes tests (modes_test.exs)
T005: Policy tests (policy_test.exs)

# Implementation (T006, T007, T009 are [P] — different files):
T006: Membership module (membership.ex)
T007: Modes module (modes.ex)
T009: Handler context (handler.ex)
# T008 (Policy) depends on T006/T007 patterns — run after
```

## Parallel Example: User Stories (after Phase 2)

```bash
# All 5 user stories can proceed in parallel since they touch different concerns:
US1: Server hierarchy + Nicklist + CommandDispatch
US2: Server +n + ChannelListLive + Whois
US3: Server knock + Knock handler + PubSub
US4: Server +c/+R + channel helpers
US5: Server +j + Queries persistence
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Migration
2. Complete Phase 2: Foundation (Membership, Modes, Policy)
3. Complete Phase 3: User Story 1 (Hierarchy)
4. **STOP and VALIDATE**: 5-tier hierarchy works, nicklist shows all groups, permissions enforced
5. Run CI pipeline

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. + US1 → Hierarchy MVP (rank enforcement, nicklist, +q/+h modes)
3. + US2 → Protection modes (+n, +s, +p with /list and /whois filtering)
4. + US3 → Knock system (/knock command, +K disable, rate limiting)
5. + US4 → Strip colors (+c) and registered-only (+R)
6. + US5 → Join throttle (+j count:seconds)
7. Phase 8 → Help topics, persistence verification, CI validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution Principle IV: TDD mandatory — tests written and failing before implementation
- All new public functions MUST have @spec (Principle VI)
- Help topics mandatory for all new features (Principle XI)
- The +n mode only blocks user-originated messages from non-members, not system messages
- The +c mode strips server-side via Formatter.strip/1 before DB persist
- The +R mode passes identified flag as parameter (preserves bounded context separation)
