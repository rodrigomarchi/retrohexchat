# Tasks: P2P Foundation

**Input**: Design documents from `/specs/034-p2p-foundation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/p2p-api.md

**Tests**: Included — Constitution IV mandates TDD (tests written before implementation).

**Organization**: Tasks grouped by user story. US1 and US2 are both P1 but separated: US1 covers session creation, US2 covers the full state machine lifecycle.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Create the P2P bounded context directory structure and database migration

- [x] T001 Create P2P module directory structure under `apps/retro_hex_chat/lib/retro_hex_chat/p2p/` and `apps/retro_hex_chat/lib/retro_hex_chat/p2p/schema/` and test directories `apps/retro_hex_chat/test/retro_hex_chat/p2p/` and `apps/retro_hex_chat/test/retro_hex_chat/p2p/schema/`
- [x] T002 Create `p2p_sessions` migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_p2p_sessions.exs` — table with token (string 64, unique), creator_id (FK registered_nicks, cascade), peer_id (FK registered_nicks, cascade), status (string 20, default "pending"), session_type (string 20, default "generic"), metadata (map, default %{}), closed_at (utc_datetime_usec nullable), closed_reason (string 100 nullable), timestamps(utc_datetime_usec). Create indexes: unique on token, btree on creator_id, peer_id, status, and composite on (creator_id, peer_id, status) for duplicate check. Run `mix ecto.migrate`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema, queries, token, registry, and supervisor — core infrastructure that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

### Schema

- [x] T003 Write Session schema changeset tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/schema/session_test.exs` — test valid changeset, required fields (token, creator_id, peer_id, status, session_type), status enum validation (pending/lobby/connecting/active/closed/expired/failed), session_type enum validation (generic/file_transfer/audio_call/video_call), token max length 64, closed_reason max length 100, status_changeset for transitions (require closed_at and closed_reason for terminal states). Tag: `@tag :unit`
- [x] T004 Implement Session schema in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/schema/session.ex` — Ecto schema matching migration, changeset/2 for creation, status_changeset/2 for state transitions with terminal-state validations per data-model.md. Follow existing Message schema pattern (use `@type t`, `@status_values`, `@session_type_values`)

### Queries

- [x] T005 Write Queries tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/queries_test.exs` — test insert_session/1 (valid and invalid), get_session_by_token/1 (found and not found), get_session/1, update_status/3 (valid transition and terminal state), active_session_exists?/2 (bidirectional: A→B and B→A both detected, terminal sessions ignored), list_stale_sessions/1 (returns non-terminal sessions older than threshold), expire_session/1. Tag: `@tag :integration`
- [x] T006 Implement Queries in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/queries.ex` — insert_session/1, get_session_by_token/1, get_session/1, update_status/3, active_session_exists?/2 (bidirectional WHERE clause per research R3), list_stale_sessions/1, expire_session/1. Follow Chat.Queries pattern (import Ecto.Query, alias Repo)

### Session Token

- [x] T007 [P] Write SessionToken tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_token_test.exs` — test sign/3 returns non-empty string, verify/1 returns {:ok, data} with correct creator_id/peer_id/session_id, verify/1 returns {:error, :expired} for old token, verify/1 returns {:error, :invalid} for tampered token, round-trip sign→verify. Tag: `@tag :unit`
- [x] T008 [P] Implement SessionToken in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/session_token.ex` — sign/3 using Phoenix.Token.sign with salt "p2p_session" and data %{creator_id, peer_id, session_id}, verify/1 using Phoenix.Token.verify with max_age 86_400 (24h). Get secret_key_base from Application.get_env(:retro_hex_chat, :p2p_token_secret) per research R2. Add config entry in config files

### OTP Infrastructure

- [x] T009 [P] Implement Registry in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/registry.ex` — via_tuple/1, lookup/1, registry_name/0. Follow Channels.Registry pattern exactly. Registry name: `RetroHexChat.P2P.SessionRegistry`
- [x] T010 [P] Implement Supervisor in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/supervisor.ex` — DynamicSupervisor with start_link/1, child_spec/1, start_child/2, stop_child/2. Follow Channels.Supervisor pattern exactly
- [x] T011 Register P2P processes in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` — add `{Registry, keys: :unique, name: RetroHexChat.P2P.SessionRegistry}` and `RetroHexChat.P2P.Supervisor` to the children list (after existing channel entries). Do NOT add CleanupTask yet (Phase 6)

**Checkpoint**: Foundation ready — Schema, Queries, Token, Registry, Supervisor all operational. User story implementation can begin.

---

## Phase 3: User Story 1 — Create a P2P Session (Priority: P1)

**Goal**: A registered user can create a P2P session with another registered user. The system validates participants, persists a session record, starts a GenServer, generates a token, and notifies the peer via PubSub.

**Independent Test**: Call Service.create_session/3 with two valid user IDs → verify DB record exists with status "pending", GenServer running (Registry.lookup succeeds), token generated, PubSub notification sent to peer.

### Tests for US1

- [x] T012 [P] [US1] Write Policy.can_create? tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/policy_test.exs` — test: both registered users → :ok, creator is guest → {:error, _}, peer is guest → {:error, _}, self-session (same ID) → {:error, _}, active session exists between pair → {:error, _}, creator has ignored peer → {:error, _} (generic message, no block reveal), peer has ignored creator → {:error, _} (generic message), no active session → :ok. Tag: `@tag :integration`
- [x] T013 [P] [US1] Write Service.create_session tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/service_test.exs` — test: successful creation returns {:ok, %{session, token}}, session has status "pending", GenServer is running (Registry.lookup), PubSub notification sent to "user:#{peer_nick}" with event "p2p_invite", duplicate creation returns {:error, _}, invalid users return {:error, _}. Tag: `@tag :integration`

### Implementation for US1

- [x] T014 [US1] Implement Policy module in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/policy.ex` — can_create?/2 with `with` chain: check not self → check both registered (query registered_nicks) → check no active session (Queries.active_session_exists?/2) → check no block/ignore (query ignore_list_entries directly per research R4, checking both directions). Return :ok | {:error, String.t()} following Channels.Policy pattern. Generic error for block: "Session cannot be created"
- [x] T015 [US1] Implement basic SessionServer in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/session_server.ex` — GenServer with `use GenServer, restart: :transient`. start_link/1 takes token, registers via P2P.Registry.via_tuple(token). init/1 loads session from DB via Queries.get_session_by_token/1 — if terminal state return :ignore, otherwise set state with session data and start pending timeout (5 min via Process.send_after). Include get_state/1 public API for inspection. State struct: %{token, session, creator_joined: false, peer_joined: false, timers: %{}}. Implement handle_info for {:timeout, :pending_expiry} that expires session and stops GenServer
- [x] T016 [US1] Implement Service.create_session/3 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — orchestrate: Policy.can_create? → SessionToken.sign → Queries.insert_session → P2P.Supervisor.start_child(token) → PubSub.broadcast("user:#{peer_nick}", %{event: "p2p_invite", payload: ...}) → return {:ok, %{session, token}}. Follow Chat.Service pattern with `with` chain
- [x] T017 [US1] Implement Facade create_session/3 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` — delegate to Service.create_session/3. Also add get_session/1 and session_info/1 delegations

**Checkpoint**: Session creation works end-to-end. Can create sessions, reject invalid requests, GenServer starts in pending state, peer notified.

---

## Phase 4: User Story 2 — Session Lifecycle Management (Priority: P1)

**Goal**: Sessions progress through the full state machine (pending → lobby → connecting → active → terminal). Timeouts auto-expire sessions. Lobby inactivity warning at 10 min, expiry at 15 min. Either peer can close gracefully.

**Independent Test**: Create a session, simulate both peers joining (→ lobby), verify inactivity warning at 10 min, verify expiry at 15 min. Test close from either peer. Test connecting timeout at 30 sec.

### Tests for US2

- [x] T018 [P] [US2] Write SessionServer state machine tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_server_test.exs` — test: pending → lobby when both peers join, pending → expired on 5 min timeout, lobby inactivity warning broadcast at 10 min (test with shortened timer), lobby → expired on 15 min inactivity, lobby inactivity timer reset on activity, lobby → connecting on transition/2 call, connecting → failed on 30 sec timeout, connecting → active on transition/2 call, any state → closed on close/3, close updates DB with closed_at and closed_reason, GenServer stops after terminal state, crash recovery loads state from DB. Tag: `@tag :integration`
- [x] T019 [P] [US2] Write Service join_session and close_session tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/service_test.exs` (append to existing file) — test: join_session with valid token and user_id → :ok, join as non-participant → {:error, _}, join terminal session → {:error, _}, close_session → :ok with DB updated, PubSub "p2p_session_closed" event broadcast on "p2p:#{token}". Tag: `@tag :integration`

### Implementation for US2

- [x] T020 [US2] Extend SessionServer with full state machine in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/session_server.ex` — add join/2 (handle_call: mark creator/peer_joined, if both joined transition to lobby + cancel pending timer + start lobby_warning timer at 10 min + start lobby_expiry timer at 15 min + broadcast "p2p_peer_joined" + update DB status). Add close/3 (handle_call: transition to closed + update DB + broadcast "p2p_session_closed" + {:stop, :normal, ...}). Add activity/1 (handle_call: reset lobby timers). Add transition/2 (handle_call: validate transition per data-model valid transitions table, update DB, broadcast "p2p_status_changed", start connecting_timeout if → connecting). Implement handle_info for {:timeout, :lobby_warning} → broadcast "p2p_inactivity_warning" on "p2p:#{token}". Implement handle_info for {:timeout, :lobby_expiry} → expire session + stop. Implement handle_info for {:timeout, :connecting_timeout} → fail session + stop. Private helper: cancel_timer/2 to cancel existing Process.send_after refs
- [x] T021 [US2] Implement Service.join_session/2 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — verify token → load session → Policy.can_join? → SessionServer.join(token, user_id). Handle case where GenServer not running (session expired)
- [x] T022 [US2] Implement Service.close_session/3 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — verify token → SessionServer.close(token, user_id, reason). Handle case where GenServer not running (update DB directly)
- [x] T023 [US2] Add join_session/2, close_session/3, and transition_status/2 to Facade in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` — delegate to Service

**Checkpoint**: Full lifecycle works. Sessions transition through all states, timeouts expire sessions, lobby warning fires, either peer can close.

---

## Phase 5: User Story 3 — Authorization and Policy Enforcement (Priority: P2)

**Goal**: All P2P operations enforce authorization. Non-participants denied access. Expired tokens rejected. Guests rejected from all operations. Block/ignore opacity maintained.

**Independent Test**: Attempt to join as a non-participant → denied. Use expired token → rejected. Attempt as guest → rejected. Valid participant with valid token → allowed.

### Tests for US3

- [x] T024 [P] [US3] Write Policy.can_join? and can_close? tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/policy_test.exs` (append to existing file) — test: can_join? with creator → :ok, can_join? with peer → :ok, can_join? with third user → {:error, _}, can_join? on terminal session → {:error, _}, can_close? with participant → :ok, can_close? with non-participant → {:error, _}, can_close? on already-terminal session → {:error, _}. Tag: `@tag :integration`
- [x] T025 [P] [US3] Write authorization integration tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/service_test.exs` (append to existing file) — test: Service.join_session with expired token → {:error, _}, Service.join_session with non-participant user → {:error, _}, full flow with blocked user: create → {:error, _} with generic message, verify Service rejects guest user_id (no registered_nick record). Tag: `@tag :integration`

### Implementation for US3

- [x] T026 [US3] Implement Policy.can_join?/2 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/policy.ex` — check user_id matches creator_id or peer_id, check session status not terminal. Return :ok | {:error, String.t()}
- [x] T027 [US3] Implement Policy.can_close?/2 in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/policy.ex` — check user_id matches creator_id or peer_id, check session status not already terminal. Return :ok | {:error, String.t()}
- [x] T028 [US3] Add token verification to Service.join_session and Service.close_session in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — ensure SessionToken.verify/1 is called before any operation, reject expired/invalid tokens with descriptive error. Ensure Policy.can_join?/can_close? is called in the with chain

**Checkpoint**: Authorization fully enforced. Non-participants, expired tokens, guests, and blocked users all correctly rejected.

---

## Phase 6: User Story 4 — Stale Session Cleanup (Priority: P3)

**Goal**: A periodic background task detects and expires stale sessions whose GenServer processes are no longer running or whose timeouts have been exceeded.

**Independent Test**: Create sessions in various stale states (pending past timeout, lobby with no GenServer), run cleanup, verify they transition to "expired". Verify active sessions with running GenServer are untouched.

### Tests for US4

- [x] T029 [P] [US4] Write CleanupTask tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/cleanup_task_test.exs` — test: run_cleanup/0 expires stale pending sessions (inserted_at older than 5 min with no GenServer), run_cleanup/0 expires stale lobby sessions (no GenServer, updated_at older than 15 min), run_cleanup/0 leaves active sessions with running GenServer untouched, run_cleanup/0 ignores terminal sessions, run_cleanup/0 returns {:ok, count} with correct count, periodic scheduling works (GenServer sends :cleanup message to self). Tag: `@tag :integration`

### Implementation for US4

- [x] T030 [US4] Implement CleanupTask in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/cleanup_task.ex` — GenServer with `use GenServer`. start_link/1 with configurable interval (default 60_000ms). init/1 schedules first cleanup via Process.send_after. handle_info(:cleanup, state) runs cleanup logic then reschedules. run_cleanup/0 public API: query Queries.list_stale_sessions/1 → for each, check Registry.lookup — if GenServer not found, call Queries.expire_session/1, if found attempt SessionServer.get_state to verify. Return {:ok, count}. Add @cleanup_interval module attribute configurable via opts
- [x] T031 [US4] Register CleanupTask in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` — add `RetroHexChat.P2P.CleanupTask` to children list after P2P.Supervisor

**Checkpoint**: Stale sessions cleaned up automatically. No orphaned DB records or leaked processes.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, edge cases, and CI compliance

- [x] T032 [P] Add SessionServer crash recovery test in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_server_test.exs` (append) — test: kill GenServer process, verify supervisor restarts it, verify it recovers state from DB, verify timers are reset appropriately. Kill GenServer of terminal session, verify init returns :ignore. Tag: `@tag :integration`
- [x] T033 [P] Add bidirectional duplicate session edge case test in `apps/retro_hex_chat/test/retro_hex_chat/p2p/service_test.exs` (append) — test: Alice creates session with Bob (A→B), then Bob tries to create session with Alice (B→A) → rejected. Also test that after A→B session closes (terminal), B→A creation succeeds. Tag: `@tag :integration`
- [x] T034 Verify umbrella separation — run `mix xref graph --label compile-connected --sink RetroHexChatWeb` from `apps/retro_hex_chat/` and confirm zero results for P2P modules. Ensure no `alias RetroHexChatWeb.*` or `import RetroHexChatWeb.*` in any P2P module
- [x] T035 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — creates the core session creation flow
- **US2 (Phase 4)**: Depends on Phase 3 — extends SessionServer and Service with full lifecycle
- **US3 (Phase 5)**: Depends on Phase 3 — adds authorization to existing Service flows
- **US4 (Phase 6)**: Depends on Phase 2 — only needs Queries and Registry, independent of US1-US3
- **Polish (Phase 7)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only. Creates SessionServer (basic) and Service
- **US2 (P1)**: Depends on US1. Extends SessionServer with state machine, adds join/close to Service
- **US3 (P2)**: Depends on US1. Adds Policy.can_join?/can_close? and token verification to Service
- **US4 (P3)**: Independent of US1-US3. Only needs Foundational (Queries + Registry)

### Within Each User Story

- Tests MUST be written FIRST and FAIL before implementation (Constitution IV)
- Schema/Queries before Policy before Service
- Policy before Service (Service calls Policy)
- SessionServer before Service (Service calls SessionServer)

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T007 (SessionToken tests) + T009 (Registry) + T010 (Supervisor) can run in parallel
- T008 (SessionToken impl) can run parallel with T009, T010

**Phase 3 (US1)**:
- T012 (Policy tests) + T013 (Service tests) can be written in parallel

**Phase 4 (US2)**:
- T018 (SessionServer tests) + T019 (Service tests) can be written in parallel

**Phase 5 (US3)**:
- T024 (Policy tests) + T025 (auth integration tests) can be written in parallel

**Phase 7 (Polish)**:
- T032 (crash recovery test) + T033 (duplicate edge case test) can run in parallel

---

## Parallel Example: Phase 2 (Foundational)

```text
# Sequential first:
T003 → T004 (Schema test → Schema impl)
T005 → T006 (Queries test → Queries impl)

# Then parallel (all independent modules):
T007 + T009 + T010 (SessionToken test, Registry, Supervisor — different files)
T008 (SessionToken impl — after T007)

# Then:
T011 (Application.ex — after T009, T010)
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Schema, Queries, Token, Registry, Supervisor)
3. Complete Phase 3: US1 (Policy.can_create?, basic SessionServer, Service.create_session)
4. **STOP and VALIDATE**: Create a session via IEx, verify DB record + GenServer running + PubSub notification
5. This is a deployable MVP — sessions can be created and expire via timeout

### Incremental Delivery

1. Setup + Foundational → P2P infrastructure exists
2. US1 → Sessions can be created (MVP)
3. US2 → Full lifecycle with join, transitions, timeouts, warnings, close
4. US3 → All operations are authorization-gated
5. US4 → Stale sessions cleaned up automatically
6. Polish → CI-green, crash recovery verified, edge cases covered

---

## Notes

- All new code goes in `apps/retro_hex_chat/` (domain app) — zero web-layer code
- Follow existing patterns: Channels.Registry, Channels.Supervisor, Channels.Policy, Chat.Service, Chat.Queries
- PubSub topics: `"p2p:#{token}"` for session events, `"user:#{nickname}"` for invitations
- Tests use shortened timers (e.g., 50ms instead of 5 min) to avoid slow tests
- GenServer uses `restart: :transient` so it doesn't restart after normal termination
- DB is authoritative (Constitution IX) — GenServer is hot cache only
