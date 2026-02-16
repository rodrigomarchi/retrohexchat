# Tasks: WebRTC Signaling

**Input**: Design documents from `/specs/036-webrtc-signaling/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — TDD is a non-negotiable constitution principle (IV).

**Organization**: Tasks grouped by user story. US1 and US3 are both P1 (co-dependent for a working connection). US2 and US4 are P2. US5 is P3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Add dependency and TURN server configuration

- [x] T001 Add `{:ex_stun, "~> 0.1"}` to `apps/retro_hex_chat/mix.exs` dependencies
- [x] T002 Add TURN compile-time config to `config/config.exs` (turn_realm, turn_credentials_lifetime, turn_nonce_lifetime, turn_default_allocation_lifetime, turn_max_allocation_lifetime, turn_permission_lifetime, turn_channel_lifetime)
- [x] T003 [P] Add TURN runtime config to `config/runtime.exs` (turn_listen_ip, turn_listen_port, turn_relay_ip, turn_relay_port_range, turn_listener_count, turn_auth_secret, turn_nonce_secret)
- [x] T004 [P] Add TURN test overrides to `config/test.exs` (random port, disabled listener, test secrets)

---

## Phase 2: Foundational — TURN Server Extraction (Blocking)

**Purpose**: Self-hosted STUN/TURN server running in the BEAM VM. Extracted from `elixir-webrtc/rel`.

**⚠️ CRITICAL**: US1 and US3 depend on this phase being complete.

### Tests (write first, ensure they fail)

- [x] T005 [P] Write `Turn.Config` validation tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/turn/config_test.exs` — valid config, missing keys, invalid types
- [x] T006 [P] Write `Turn.Auth` credential tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/turn/auth_test.exs` — generate_credentials/1 returns valid structure, authenticate/2 accepts valid credentials, rejects expired

### Implementation

- [x] T007 Create `Turn.Config` struct module in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/config.ex` — centralizes all TURN config, replaces `Application.fetch_env!` reads, includes `from_application_env/0` and `guess_external_ip/1`
- [x] T008 Extract 10 STUN/TURN attribute codec modules (as-is, namespace change `Rel.Attribute.*` → `RetroHexChat.P2P.Turn.Attributes.*`) in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/attributes/` — additional_address_family.ex, channel_number.ex, data.ex, even_port.ex, lifetime.ex, requested_address_family.ex, requested_transport.ex, reservation_token.ex, xor_peer_address.ex, xor_relayed_address.ex
- [x] T009 Extract `Turn.Monitor` (as-is, namespace change) in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/monitor.ex`
- [x] T010 Extract `Turn.Auth` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/auth.ex` — adapt to use `Turn.Config` instead of env reads, expose `generate_credentials/1`
- [x] T011 Extract `Turn.Utils` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/utils.ex` — adapt config reads to use `Turn.Config`
- [x] T012 Extract `Turn.AllocationHandler` GenServer in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/allocation_handler.ex` — adapt compile-time config to use `Turn.Config`
- [x] T013 Extract `Turn.Listener` Task in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/listener.ex` — adapt config reads, UDP recv_loop on STUN/TURN port
- [x] T014 Extract `Turn.ListenerSupervisor` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/listener_supervisor.ex` — accept config via `start_link/1` args
- [x] T015 Create `Turn.Supervisor` in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/supervisor.ex` — starts ListenerSupervisor + DynamicSupervisor (AllocationSupervisor) + Registry
- [x] T016 Add `Turn.Supervisor` to Application supervision tree in `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`

**Checkpoint**: TURN server compiles and starts with `mix phx.server`. Auth tests pass. Config tests pass.

---

## Phase 3: User Story 1 — Successful P2P Connection Establishment (Priority: P1) 🎯 MVP

**Goal**: Two peers exchange SDP offer/answer + ICE candidates through the server relay and establish a direct RTCPeerConnection.

**Independent Test**: Two authenticated users accept an action in the lobby → connection established → session becomes active.

**Depends on**: Phase 2 (TURN server for ICE servers), US3 (ICE server config sent to browsers).

**Note**: US1 and US3 are tightly coupled (both P1). US3 provides the ICE servers that US1's signaling flow requires.

### Tests (write first)

- [x] T017 [P] [US1] Write `P2P.validate_signal/1` unit tests in `apps/retro_hex_chat/test/retro_hex_chat/p2p/p2p_test.exs` — valid offer/answer/ice-candidate, invalid type, missing sdp, missing candidate
- [x] T018 [P] [US1] Write `webrtc.js` Vitest tests in `apps/retro_hex_chat_web/assets/test/lib/webrtc.test.js` — createPeerConnection, createOffer, createAnswer, handleAnswer, addIceCandidate, close, event callbacks (mocked RTCPeerConnection)
- [x] T019 [P] [US1] Write `webrtc_hook.js` Vitest tests in `apps/retro_hex_chat_web/assets/test/hooks/webrtc_hook.test.js` — p2p_start_offer flow, p2p_start_answer flow, p2p_signal dispatch, p2p_connected push, cleanup on destroyed

### Implementation — Elixir

- [x] T020 [US1] Add `validate_signal/1` to P2P context facade in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` — validates signal type is offer/answer/ice-candidate, validates sdp or candidate presence
- [x] T021 [US1] Add `ice_servers/1` to P2P context facade in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` — calls `Turn.Auth.generate_credentials/1`, returns ICE server config list
- [x] T022 [US1] Add signaling event handlers to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — `handle_event("p2p_signal")` validates + broadcasts via PubSub, `handle_info(%{event: "p2p_signal"})` forwards to peer via `push_event`, `handle_event("p2p_connected")` transitions session to `:active`, `handle_event("p2p_failed")` logs failure
- [x] T023 [US1] Modify action acceptance flow in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — on `connecting` transition, push `p2p_start_offer` (with ICE config) to creator, push `p2p_start_answer` (with ICE config) to peer

### Implementation — JavaScript

- [x] T024 [P] [US1] Create `webrtc.js` pure logic module in `apps/retro_hex_chat_web/assets/js/lib/webrtc.js` — createPeerConnection, createOffer, createAnswer, handleAnswer, addIceCandidate, close, onConnectionStateChange, onIceCandidate, onDataChannel, RETRY_CONFIG export
- [x] T025 [US1] Create `webrtc_hook.js` LiveView hook in `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js` — handle p2p_start_offer/p2p_start_answer/p2p_signal server events, push p2p_signal/p2p_connected/p2p_failed to server, manage RTCPeerConnection lifecycle
- [x] T026 [US1] Register `WebRTCHook` in `apps/retro_hex_chat_web/assets/js/app.js`
- [x] T027 [US1] Add `phx-hook="WebRTCHook"` to P2P session template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`

**Checkpoint**: Two browsers can establish a WebRTC connection via the signaling relay. Session transitions to active.

---

## Phase 4: User Story 3 — Self-Hosted ICE Server Configuration (Priority: P1)

**Goal**: ICE server addresses and short-lived TURN credentials are provided to browsers. No external services contacted.

**Independent Test**: Verify ICE config is sent on connection start, TURN credentials are valid and short-lived, no external STUN/TURN requests.

**Note**: Largely implemented within Phase 2 (TURN server) and Phase 3 (ice_servers/1 in T021, ICE config sent in T023). This phase covers the integration test and any remaining gaps.

### Tests

- [x] T028 [US3] Write integration test verifying ICE server config is included in `p2p_start_offer` and `p2p_start_answer` push events in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_signaling_test.exs`

### Implementation

- [x] T029 [US3] Add `start_signaling/1` orchestration to `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — generates ICE config, returns role-specific payloads for creator/peer

**Checkpoint**: ICE server config with valid TURN credentials is sent to both browsers on connection start. No external service requests.

---

## Phase 5: User Story 2 — Automatic Retry on Connection Failure (Priority: P2)

**Goal**: Failed handshakes retry up to 3 times with exponential backoff (2s, 4s, 8s). Progress displayed. Terminal failure after 3 attempts.

**Independent Test**: Simulate handshake failure → verify retry behavior, progress messages, final failure state.

### Tests

- [x] T030 [P] [US2] Write Vitest tests for retry logic in `apps/retro_hex_chat_web/assets/test/hooks/webrtc_hook.test.js` — retry on "failed" state, exponential backoff delays, max 3 attempts, stop on success, disconnected 5s grace period
- [x] T031 [P] [US2] Write `handle_event("p2p_retry")` test in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_signaling_test.exs`

### Implementation

- [x] T032 [US2] Add retry logic to `webrtc_hook.js` in `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js` — on "failed" connectionState: close old pc, wait delay, create new connection, increment retryCount. On "disconnected": start 5s grace timer, clear on recovery. Push `p2p_retry` event with attempt number.
- [x] T033 [US2] Add `handle_event("p2p_retry")` to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — track retry attempt in assigns, broadcast retry status to peer
- [x] T034 [US2] On final failure (attempt 3 exhausted), push `p2p_failed` → LiveView transitions session to `:failed`, offer "Try again" button that creates new session with same peer in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`

**Checkpoint**: Connection failures trigger automatic retry with backoff. Progress messages shown. Permanent failure shows "Try again".

---

## Phase 6: User Story 4 — Connection State Visibility (Priority: P2)

**Goal**: Both users see real-time connection state: "Conectando...", "Conectado", "Reconectando...", "Falha na conexão".

**Independent Test**: Observe connection state indicator during each phase of signaling flow.

### Tests

- [x] T035 [P] [US4] Write Vitest test for `p2p_state_change` push in `apps/retro_hex_chat_web/assets/test/hooks/webrtc_hook.test.js`
- [x] T036 [P] [US4] Write LiveView test for `webrtc_state` assign rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_signaling_test.exs`

### Implementation

- [x] T037 [US4] Add `webrtc_state` assign (default: nil) and `handle_event("p2p_state_change")` to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — update assign with state label
- [x] T038 [US4] Push `p2p_state_change` events from `webrtc_hook.js` on connectionState transitions in `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js`
- [x] T039 [US4] Add connection state indicator component to P2P lobby in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex` — show "Conectando...", "Conectado", "Reconectando..." (with attempt), "Falha na conexão" + "Try again" button
- [x] T040 [US4] Add connection state CSS styles to `apps/retro_hex_chat_web/assets/css/p2p-lobby.css` — indicator colors, retry progress, 98.css status bar style

**Checkpoint**: Connection state indicator visible and accurate during all connection phases.

---

## Phase 7: User Story 5 — Signaling Rate Limit Contract (Priority: P3)

**Goal**: Rate limit behaviour defined. Integration point ready for future enforcement.

**Independent Test**: Behaviour module compiles and defines expected callbacks.

### Tests

- [x] T041 [P] [US5] Write behaviour compliance test in `apps/retro_hex_chat/test/retro_hex_chat/p2p/signaling_rate_limit_test.exs` — verify callback definitions, test noop implementation

### Implementation

- [x] T042 [US5] Create `SignalingRateLimit` behaviour module in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit.ex` — define `@callback check_signal_rate(String.t(), integer()) :: :ok | {:error, :rate_limited}`, provide default noop implementation
- [x] T043 [US5] Add optional rate limit check in signaling relay in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` — configurable module, noop by default, called before broadcasting

**Checkpoint**: Rate limit behaviour defined and noop implementation wired into signaling relay.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [x] T044 Run quickstart.md validation — start server, test P2P flow end-to-end per `specs/036-webrtc-signaling/quickstart.md`
- [x] T045 Run full CI-equivalent validation pipeline (see CLAUDE.md "CI-Equivalent Validation") — all 8 checks must pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (TURN Extraction)**: Depends on Phase 1 — BLOCKS Phases 3, 4
- **Phase 3 (US1 — Signaling)**: Depends on Phase 2
- **Phase 4 (US3 — ICE Config)**: Depends on Phase 2. Most work already done in Phase 3 (T021, T023)
- **Phase 5 (US2 — Retry)**: Depends on Phase 3 (needs working signaling)
- **Phase 6 (US4 — State UI)**: Depends on Phase 3 (needs working signaling)
- **Phase 7 (US5 — Rate Limit)**: Depends on Phase 3 (integrates with signaling relay)
- **Phase 8 (Polish)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)** + **US3 (P1)**: Co-dependent, implemented in Phases 3-4. US3's ICE config is used by US1's signaling flow.
- **US2 (P2)**: Depends on US1. Extends the signaling flow with retry logic.
- **US4 (P2)**: Depends on US1. Adds UI layer on top of signaling events. Can be parallelized with US2.
- **US5 (P3)**: Depends on US1. Adds optional middleware to signaling relay. Can be parallelized with US2/US4.

### Within Each Phase

- Tests MUST be written and FAIL before implementation
- Elixir modules before JS modules (server provides events for client)
- Pure logic modules before wiring modules (webrtc.js before webrtc_hook.js)

### Parallel Opportunities

- **Phase 1**: T003 and T004 in parallel
- **Phase 2**: T005 and T006 in parallel (tests), T008 and T009 in parallel (attribute codecs + monitor)
- **Phase 3**: T017, T018, T019 in parallel (tests), T024 in parallel with Elixir tasks
- **Phase 5, 6, 7**: Can all start after Phase 3 completes. US2, US4, US5 are independent of each other.

---

## Parallel Example: After Phase 3 Completes

```
# These three phases can run in parallel:
Phase 5 (US2 — Retry):     T030-T034
Phase 6 (US4 — State UI):  T035-T040
Phase 7 (US5 — Rate Limit): T041-T043
```

---

## Implementation Strategy

### MVP First (US1 + US3 — Phases 1-4)

1. Complete Phase 1: Setup (dependency + config)
2. Complete Phase 2: TURN server extraction
3. Complete Phase 3: Signaling relay + WebRTC JS
4. Complete Phase 4: ICE config integration test
5. **STOP and VALIDATE**: Two browsers can establish a P2P connection

### Incremental Delivery

1. Phases 1-4 → Working P2P connection (MVP)
2. Phase 5 → Automatic retry on failure
3. Phase 6 → Visual connection state feedback
4. Phase 7 → Rate limit contract for future security
5. Phase 8 → Full validation

---

## Notes

- Total tasks: 45
- Per-story: US1=11, US2=5, US3=2, US4=6, US5=3, Setup=4, Foundation=12, Polish=2
- TURN extraction (Phase 2) is the largest phase — 12 tasks, ~1,323 LOC from `rel`
- US1 and US3 are tightly coupled (both P1) — US3's ICE servers are required by US1's signaling
- US2, US4, US5 can all run in parallel after US1 completes
- Suggested MVP scope: Phases 1-4 (US1 + US3)
- All tasks include exact file paths for immediate executability
