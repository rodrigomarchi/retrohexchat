# Tasks: P2P Security, Help & Polish

**Input**: Design documents from `/specs/039-p2p-security-help-polish/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD is mandated by Constitution Principle IV. Test tasks are included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuration changes and ETS table initialization shared across user stories

- [x] T001 Update TURN credentials lifetime from 86_400 to 3_600 (1 hour) in `apps/retro_hex_chat/config/config.exs`
- [x] T002 Add `p2p_session_rate_limit: {5, 600_000}` config key in `apps/retro_hex_chat/config/config.exs`
- [x] T003 Add test-friendly rate limit overrides (small windows) in `apps/retro_hex_chat/config/test.exs`
- [x] T004 Initialize `:p2p_rate_limits` ETS table in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/rate_limit_table.ex` (Agent in supervision tree)

**Checkpoint**: Configuration and ETS infrastructure ready for rate limiting modules

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core modules that multiple user stories depend on

**⚠️ CRITICAL**: US2 (rate limiting) and US3 (privacy mode) both depend on the ETS table from Phase 1

- [x] T005 Add `turn_configured?/0` function to `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` — checks if TURN server is configured in application env (returns boolean). Used by US1 (conditional STUN-only) and US3 (privacy mode warning).

**Checkpoint**: Foundation ready — user story implementation can begin

---

## Phase 3: User Story 1 — TURN Credential Configuration (Priority: P1) 🎯 MVP

**Goal**: Ensure TURN credentials use 1-hour TTL and system gracefully falls back to STUN-only when TURN is not configured

**Independent Test**: Verify `P2P.ice_servers/1` returns credentials with correct TTL; verify `turn_configured?/0` correctly detects TURN availability

### Tests for User Story 1

- [x] T006 [P] [US1] Write unit test for `turn_configured?/0` returning true/false based on app config in `apps/retro_hex_chat/test/retro_hex_chat/p2p/p2p_test.exs`
- [x] T007 [P] [US1] Write unit test verifying `ice_servers/1` credentials have TTL matching `turn_credentials_lifetime` config (3600s) in `apps/retro_hex_chat/test/retro_hex_chat/p2p/p2p_test.exs`

### Implementation for User Story 1

- [x] T008 [US1] Verify existing `P2P.ice_servers/1` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` returns correct credential format with updated 3600s TTL — add conditional logic to return STUN-only config when TURN is not configured (currently always returns TURN URLs). Ensure shared secret is never in the returned payload.

**Checkpoint**: TURN credentials work with 1h TTL; graceful STUN-only fallback when TURN unconfigured

---

## Phase 4: User Story 2 — P2P Rate Limiting (Priority: P1)

**Goal**: Enforce server-side rate limits on session creation (5/10min) and signaling messages (100/min)

**Independent Test**: Exceed rate limit thresholds and verify rejection (session creation) or silent drop (signaling)

### Tests for User Story 2

- [x] T009 [P] [US2] Write unit tests for `RateLimiter.check_session_rate/1` in `apps/retro_hex_chat/test/retro_hex_chat/p2p/rate_limiter_test.exs` — test: allows up to 5 requests in 10min window, rejects 6th with `{:error, {:rate_limited, remaining_seconds}}`, resets after window expires, returns correct remaining seconds
- [x] T010 [P] [US2] Write unit tests for `SignalingRateLimit.ETS.check_signal_rate/2` in `apps/retro_hex_chat/test/retro_hex_chat/p2p/signaling_rate_limit/ets_test.exs` — test: allows up to 100 signals/min, returns `{:error, :rate_limited}` on 101st, resets after window expires

### Implementation for User Story 2

- [x] T011 [P] [US2] Create `RetroHexChat.P2P.RateLimiter` module in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/rate_limiter.ex` — ETS sliding-window counter with `init_table/0`, `check_session_rate/1` (reads `p2p_session_rate_limit` config), `reset/1`. Key pattern: `{:session_create, user_id}`, value: `{key, count, window_start_ms}`
- [x] T012 [P] [US2] Create `RetroHexChat.P2P.SignalingRateLimit.ETS` module in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit/ets.ex` — implements `@behaviour RetroHexChat.P2P.SignalingRateLimit`, `check_signal_rate/2` using ETS sliding-window (100/min). Key pattern: `{:signal, user_id}`
- [x] T013 [US2] Wire rate limit into `P2P.Service.create_session/3` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — add `RateLimiter.check_session_rate(creator_id)` as first step in `with` chain, before `Policy.can_create?/2`. Map `{:error, {:rate_limited, remaining}}` to Portuguese error message "Você criou muitas sessões. Tente novamente em X minutos"
- [x] T014 [US2] Update `signaling_rate_limiter` config default from `Noop` to `RetroHexChat.P2P.SignalingRateLimit.ETS` in `apps/retro_hex_chat/config/config.exs` (keep `Noop` in test.exs unless test explicitly needs ETS)
- [x] T015 [US2] Write integration test verifying session creation rate limit error flows through to LiveView in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs`

**Checkpoint**: Session creation and signaling rate limits enforced server-side; Portuguese error messages displayed

---

## Phase 5: User Story 3 — TURN-Only Privacy Mode (Priority: P2)

**Goal**: Users can opt into relay-only WebRTC transport to hide their IP address from peers

**Independent Test**: Enable privacy mode, verify WebRTC config uses `iceTransportPolicy: "relay"`; disable it, verify `"all"` is used

### Tests for User Story 3

- [x] T016 [P] [US3] Write JS test for `createPeerConnection(iceServers, { turnOnly: true })` setting `iceTransportPolicy: "relay"` in `apps/retro_hex_chat_web/assets/test/lib/webrtc.test.js`
- [x] T017 [P] [US3] Write LiveView test for `toggle_privacy_mode` event persisting preference and `mount/3` reading it in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs`

### Implementation for User Story 3

- [x] T018 [P] [US3] Update `createPeerConnection` in `apps/retro_hex_chat_web/assets/js/lib/webrtc.js` — add second `options = {}` parameter; when `options.turnOnly` is truthy, set `config.iceTransportPolicy = "relay"`
- [x] T019 [P] [US3] Update `WebRTCHook` in `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js` — read `turn_only` from `p2p_start_offer`/`p2p_start_answer` event payload, pass `{ turnOnly: turnOnly }` to `createPeerConnection`
- [x] T020 [US3] Update `P2PSessionLive.mount/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — load user's `message_settings.p2p_settings.turn_only` preference (default `false`), assign as `:turn_only`
- [x] T021 [US3] Update `handle_info` for `p2p_status_changed` → `"connecting"` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — include `turn_only: socket.assigns.turn_only` in `p2p_start_offer`/`p2p_start_answer` push_event payloads. If `turn_only` is true but `P2P.turn_configured?()` is false, push warning system message and set `turn_only: false` in payload
- [x] T022 [US3] Add `handle_event("toggle_privacy_mode", ...)` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — persist `message_settings.p2p_settings.turn_only` to user_preferences via existing preference persistence mechanism, update socket assign
- [x] T023 [US3] Add "Modo privado (TURN-only)" checkbox to P2P lobby component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex` — 98.css styled checkbox, bound to `turn_only` assign, sends `toggle_privacy_mode` event on change. Show warning text if TURN not configured. Only visible when `turn_configured?` is true or preference is already enabled

**Checkpoint**: Privacy mode toggle works end-to-end; relay-only transport enforced when enabled

---

## Phase 6: User Story 4 — Ignore/Ban Integration for P2P (Priority: P2)

**Goal**: Blocked users cannot send P2P invites; active sessions close when block occurs

**Independent Test**: Ignore a user, verify P2P invite is rejected with generic message; block during active session, verify session closes

### Tests for User Story 4

- [x] T024 [P] [US4] Write unit test for `close_sessions_between/2` in `apps/retro_hex_chat/test/retro_hex_chat/p2p/service_test.exs` — test: finds and closes non-terminal sessions between two users with reason "user_blocked"
- [x] T025 [P] [US4] Write unit test verifying `Policy.can_create?/2` returns `"Usuário não disponível"` when users are mutually blocked in `apps/retro_hex_chat/test/retro_hex_chat/p2p/policy_test.exs`

### Implementation for User Story 4

- [x] T026 [US4] Update `check_no_block/2` error message in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/policy.ex` — change `"Session cannot be created"` to `"Usuário não disponível"`
- [x] T027 [US4] Add `active_sessions_between/2` query in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/queries.ex` — returns all non-terminal sessions where both users are participants (creator_id/peer_id in either direction)
- [x] T028 [US4] Add `close_sessions_between/2` function in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — uses `Queries.active_sessions_between/2`, iterates and closes each with `SessionServer.close/3` (reason: `"user_blocked"`)
- [x] T029 [US4] Add `close_sessions_between/2` delegate in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex`
- [x] T030 [US4] Wire `P2P.close_sessions_between/2` into ignore command handler — find the `/ignore` command handler module, add call after successful ignore list addition. Resolve both user IDs from nicknames before calling.

**Checkpoint**: Blocked users see "Usuário não disponível"; active sessions auto-close on block

---

## Phase 7: User Story 5 — P2P Help Documentation (Priority: P3)

**Goal**: 4 new help topics for P2P features with cross-references; keyboard shortcuts updated

**Independent Test**: Search for "P2P" in help system, verify all 4 topics appear with correct content and working "See Also" links

### Tests for User Story 5

- [x] T031 [P] [US5] Write unit tests verifying all 4 new help topic IDs exist, have correct category ("Features"), non-empty content, and valid `data-help-topic` cross-references in `apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs`

### Implementation for User Story 5

- [x] T032 [P] [US5] Add "P2P Sessions" help topic (`feature-p2p-sessions`) to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — cover: /p2p command syntax, lobby system, bilateral consent, session types (generic, file_transfer, audio_call, video_call), timeouts (pending 5min, lobby 15min, connecting 30s, action 60s). See Also: File Transfer, Audio/Video Calls, Privacy Settings
- [x] T033 [P] [US5] Add "File Transfer" help topic (`feature-file-transfer`) to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — cover: /sendfile command, drag-drop, supported file sizes (configurable max), blocked extensions, transfer progress, pause/resume, hash verification, retry. See Also: P2P Sessions
- [x] T034 [P] [US5] Add "Audio/Video Calls" help topic (`feature-audio-video-calls`) — Existing topics (feature-audio-call, feature-video-call) already covered this. Updated cross-references to include P2P Sessions and Privacy Settings
- [x] T035 [P] [US5] Add "Privacy Settings" help topic (`feature-privacy-settings`) to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — cover: TURN-only privacy mode explanation, how to enable (lobby checkbox or user preferences), latency tradeoff, what it protects (IP address). See Also: P2P Sessions, Audio/Video Calls
- [x] T036 [US5] Update Keyboard Shortcuts topic — No-op: no P2P-specific browser-compatible keyboard shortcuts exist
- [x] T037 [US5] Created new command help topics (`cmd-p2p`, `cmd-call`, `cmd-sendfile`) with cross-references to new feature topics in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/commands.ex`

**Checkpoint**: All 4 P2P help topics accessible via help system with accurate content and working cross-references

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [x] T038 Verify all new public functions have `@spec` annotations — check `rate_limiter.ex`, `signaling_rate_limit/ets.ex`, new functions in `p2p.ex`, `service.ex`, `queries.ex`
- [x] T039 Run full CI-equivalent validation pipeline per CLAUDE.md: compile first (`mix compile --warnings-as-errors`), then in parallel: `mix format --check-formatted`, `mix credo --strict`, `make lint.js`, `make lint.css`, `npm test --prefix apps/retro_hex_chat_web/assets`, `mix test --include e2e`, `mix dialyzer`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (ETS table must exist for `turn_configured?`)
- **US1 (Phase 3)**: Depends on Phase 1 (TTL config) + Phase 2 (`turn_configured?`)
- **US2 (Phase 4)**: Depends on Phase 1 (ETS table + rate limit config)
- **US3 (Phase 5)**: Depends on Phase 2 (`turn_configured?`) — can run in parallel with US1/US2
- **US4 (Phase 6)**: Depends on Phase 2 only — fully independent of US1/US2/US3
- **US5 (Phase 7)**: No code dependencies — can run in parallel with any user story (but benefits from US3 being done for Privacy Settings topic accuracy)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (TURN Config)**: Independent — only needs Phase 1+2
- **US2 (Rate Limiting)**: Independent — only needs Phase 1
- **US3 (Privacy Mode)**: Depends on US1 conceptually (TURN must exist for privacy mode to be useful) but code-independent
- **US4 (Ignore/Ban)**: Fully independent of all other stories
- **US5 (Help Docs)**: Fully independent — content can reference features from other stories

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Domain modules before web layer
- Elixir before JavaScript
- Core logic before UI integration

### Parallel Opportunities

- T001, T002, T003 (config changes) can run in parallel
- T006, T007 (US1 tests) can run in parallel
- T009, T010 (US2 tests) can run in parallel
- T011, T012 (US2 rate limiter modules) can run in parallel (different files)
- T016, T017 (US3 tests) can run in parallel
- T018, T019 (US3 JS changes) can run in parallel
- T024, T025 (US4 tests) can run in parallel
- T032, T033, T034, T035 (US5 help topics) can ALL run in parallel (same file but independent topic blocks)
- **US2, US3, US4, US5 can all proceed in parallel** after Phase 2 completes

---

## Parallel Example: User Story 2 (Rate Limiting)

```bash
# Launch tests in parallel:
Task: "T009 - Unit tests for RateLimiter in rate_limiter_test.exs"
Task: "T010 - Unit tests for SignalingRateLimit.ETS in ets_test.exs"

# Launch implementations in parallel (different files):
Task: "T011 - Create RateLimiter module in rate_limiter.ex"
Task: "T012 - Create SignalingRateLimit.ETS module in ets.ex"

# Sequential (depends on T011):
Task: "T013 - Wire rate limit into Service.create_session"
Task: "T014 - Update config default"
Task: "T015 - Integration test for LiveView"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (config changes + ETS init)
2. Complete Phase 2: Foundational (`turn_configured?`)
3. Complete Phase 3: US1 — TURN credential TTL fix
4. Complete Phase 4: US2 — Rate limiting
5. **STOP and VALIDATE**: Both P1 stories functional, security hardening in place
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. US1 (TURN config) → Credential TTL corrected, STUN fallback works
3. US2 (Rate limiting) → Abuse prevention active → **Security MVP!**
4. US3 (Privacy mode) → Privacy-conscious users can hide IP
5. US4 (Ignore/ban) → Harassment prevention for P2P
6. US5 (Help docs) → Feature documentation complete → **Release ready!**
7. Polish → CI validation passes

---

## Notes

- TURN credential generation already works (features 034-036) — US1 is primarily a config change
- Session creation = invite in current architecture — single rate limit covers both FR-006 and FR-007
- Ban system is channel-level; P2P "ban" is enforced via registration requirement + ignore list
- No database migrations needed — all state is ETS (ephemeral) or JSONB (existing column)
- [P] tasks = different files, no dependencies
- Constitution Principle IV requires TDD — test tasks are mandatory
