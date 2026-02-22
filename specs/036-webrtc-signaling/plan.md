# Implementation Plan: WebRTC Signaling

**Branch**: `036-webrtc-signaling` | **Date**: 2026-02-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/036-webrtc-signaling/spec.md`

## Summary

Establish WebRTC peer-to-peer connections between browsers by implementing: (1) a self-hosted STUN/TURN server extracted from `elixir-webrtc/rel` into the umbrella domain app, (2) PubSub-based signaling relay in P2PSessionLive for SDP offer/answer and ICE candidate exchange, (3) browser-native RTCPeerConnection management via webrtc.js/webrtc_hook.js following the hook=wiring/lib=logic pattern, (4) connection state UI with retry logic. Zero external service dependencies.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend)
**Primary Dependencies**: Phoenix 1.8+, LiveView 1.0+, ex_stun ~> 0.1 (NEW), retro design system
**Storage**: PostgreSQL 16+ (existing `p2p_sessions` table — no new migrations)
**Testing**: ExUnit (Elixir), Vitest + jsdom (JS), mocked RTCPeerConnection
**Target Platform**: Web (all modern browsers with WebRTC support)
**Project Type**: Umbrella (retro_hex_chat domain + retro_hex_chat_web)
**Performance Goals**: P2P connection within 5s (LAN) / 10s (NAT), signaling relay <200ms overhead
**Constraints**: Zero external STUN/TURN services, self-hosted only, UDP port 3478
**Scale/Scope**: 1-to-1 P2P sessions, single server deployment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Elixir & Phoenix Exclusive Stack | PASS | Elixir backend, LiveView for reactive UI, browser-native WebRTC (no JS frameworks) |
| II. Umbrella with Bounded Contexts | PASS | TURN server modules go in `RetroHexChat.P2P.Turn.*` within domain app. Web layer stays thin. |
| III. OTP Process Architecture | PASS | TURN server has its own supervision tree: ListenerSupervisor → N Listener Tasks, DynamicSupervisor → AllocationHandler GenServers, Registry for lookup |
| IV. TDD (non-negotiable) | PASS | Unit tests for TURN auth/credentials, integration tests for signaling relay, Vitest for webrtc.js/hook |
| V. Contracts and Behaviours | PASS | `SignalingRateLimit` behaviour defined. TURN auth is a well-defined contract. |
| VI. Static Analysis from Day One | PASS | @spec on all public functions, Credo/Dialyxir/ESLint/Prettier enforced |
| VII. Lean LiveViews | PASS | LiveView only relays signals via PubSub, delegates state transitions to P2P context. PubSub topic `p2p:#{token}` already exists. |
| VIII. retro Design Fidelity | PASS | Connection state UI uses retro components (status bar, labels) |
| IX. Hot/Cold Data Separation | PASS | All signaling data is ephemeral (GenServer/PubSub). Only session status persisted to DB. |
| X. Scalable Architecture | PASS | TURN server is process-per-allocation, signaling is PubSub-based. Both scale naturally. |
| XI. Help Documentation | DEFERRED | Help topics deferred to separate pass per spec scope |

**Gate result: PASS** (XI deferred is acknowledged in spec scope)

## Project Structure

### Documentation (this feature)

```text
specs/036-webrtc-signaling/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: TURN server research, signaling architecture
├── data-model.md        # Phase 1: Ephemeral entities, config schema
├── quickstart.md        # Phase 1: Development testing guide
├── contracts/
│   ├── elixir-contracts.md  # TURN, signaling, LiveView event contracts
│   └── js-contracts.md      # webrtc.js and webrtc_hook.js API
├── checklists/
│   └── requirements.md      # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/p2p/
│   ├── p2p.ex                          # Add ice_servers/1, validate_signal/1
│   ├── service.ex                      # Add start_signaling/1 orchestration
│   ├── session_server.ex               # Existing — no changes needed
│   ├── signaling_rate_limit.ex         # NEW — behaviour definition
│   └── turn/                           # NEW — extracted from rel
│       ├── supervisor.ex               # TURN server supervision tree
│       ├── listener_supervisor.ex      # N listener Tasks
│       ├── listener.ex                 # UDP STUN/TURN packet processor
│       ├── allocation_handler.ex       # GenServer per TURN allocation
│       ├── auth.ex                     # Credential generation + verification
│       ├── monitor.ex                  # Socket cleanup
│       ├── utils.ex                    # Error responses, lifetime helpers
│       ├── config.ex                   # NEW — config struct replacing Application.fetch_env!
│       └── attributes/                 # 10 STUN/TURN attribute codecs
│           ├── additional_address_family.ex
│           ├── channel_number.ex
│           ├── data.ex
│           ├── even_port.ex
│           ├── lifetime.ex
│           ├── requested_address_family.ex
│           ├── requested_transport.ex
│           ├── reservation_token.ex
│           ├── xor_peer_address.ex
│           └── xor_relayed_address.ex
├── test/retro_hex_chat/p2p/
│   ├── turn/
│   │   ├── auth_test.exs               # NEW — credential gen/verify
│   │   └── config_test.exs             # NEW — config validation
│   └── signaling_rate_limit_test.exs   # NEW — behaviour compliance
└── mix.exs                              # Add {:ex_stun, "~> 0.1"}

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/p2p_session_live.ex        # MODIFY — add signaling event handlers
│   └── components/p2p_lobby.ex         # MODIFY — add connection state UI
├── assets/
│   ├── js/
│   │   ├── hooks/webrtc_hook.js        # NEW — LiveView wiring for WebRTC
│   │   ├── lib/webrtc.js               # NEW — RTCPeerConnection pure logic
│   │   └── app.js                      # MODIFY — register WebRTCHook
│   ├── css/
│   │   └── p2p-lobby.css               # MODIFY — connection state indicator styles
│   └── test/
│       ├── lib/webrtc.test.js          # NEW — Vitest tests
│       └── hooks/webrtc_hook.test.js   # NEW — Vitest tests

config/
├── config.exs                          # MODIFY — add TURN compile-time config
├── runtime.exs                         # MODIFY — add TURN runtime config
└── test.exs                            # MODIFY — TURN test overrides
```

**Structure Decision**: Follows existing umbrella architecture. TURN server modules extracted into `RetroHexChat.P2P.Turn.*` namespace within the domain app. A new `Turn.Config` struct replaces all `Application.fetch_env!(:rel, ...)` calls from the original `rel` source, providing a clean configuration boundary.

## Implementation Phases

### Phase A: TURN Server Extraction (Foundation)

**Goal**: Self-hosted STUN/TURN server running in the BEAM VM.

1. Add `{:ex_stun, "~> 0.1"}` dependency
2. Create `Turn.Config` struct — centralizes all TURN config, replaces `Application.fetch_env!`
3. Extract 10 attribute modules (as-is, namespace change only)
4. Extract `Turn.Monitor` (as-is)
5. Extract `Turn.Auth` — adapt to use `Turn.Config` instead of env reads
6. Extract `Turn.Utils` — adapt config reads
7. Extract `Turn.AllocationHandler` — adapt compile-time config
8. Extract `Turn.Listener` — adapt config reads, most complex module
9. Extract `Turn.ListenerSupervisor` — accept config via args
10. Create `Turn.Supervisor` — starts the tree as child of Application
11. Add to Application supervision tree
12. Add config to `config.exs`, `runtime.exs`, `test.exs`
13. Tests: Auth credential generation/verification, Config validation

### Phase B: Signaling Relay (Core)

**Goal**: Server relays SDP/ICE between peers via PubSub.

1. Add `validate_signal/1` to P2P context facade
2. Add `ice_servers/1` to P2P context — calls `Turn.Auth.generate_credentials/1`
3. Add `handle_event("p2p_signal")` to P2PSessionLive — validate + broadcast
4. Add `handle_info(%{event: "p2p_signal"})` to P2PSessionLive — forward to peer
5. Modify action acceptance flow: on `connecting` transition, push `p2p_start_offer` to creator and `p2p_start_answer` to peer with ICE config
6. Add `handle_event("p2p_connected")` — transition session to `:active`
7. Add `handle_event("p2p_failed")` — log failure reason
8. Tests: Signal validation, relay integration, state transitions

### Phase C: WebRTC JS (Client)

**Goal**: Browser-native RTCPeerConnection with offer/answer/ICE flow.

1. Create `webrtc.js` lib — all RTCPeerConnection logic
2. Create `webrtc_hook.js` hook — wiring to LiveView events
3. Register `WebRTCHook` in `app.js`
4. Add `phx-hook="WebRTCHook"` to P2P lobby template
5. Implement retry logic in hook (3 attempts, 2s/4s/8s backoff)
6. Implement disconnected grace period (5s before treating as failed)
7. Tests: Vitest for webrtc.js (mocked RTCPeerConnection), webrtc_hook.js

### Phase D: Connection State UI

**Goal**: Visual feedback during WebRTC handshake.

1. Add `webrtc_state` assign to P2PSessionLive (default: nil)
2. Add `handle_event("p2p_state_change")` — update assign
3. Add connection state indicator component to P2P lobby
4. Style with retro design system (status bar / label)
5. Add retry progress indicator ("Tentativa 2 de 3...")
6. Add "Try again" button on permanent failure (creates new session)
7. CSS: connection state styles in `p2p-lobby.css`

### Phase E: Rate Limit Contract + Validation

**Goal**: Clean integration point for future rate limiting.

1. Create `SignalingRateLimit` behaviour module
2. Add optional rate limit check in signaling relay (configurable, noop by default)
3. Tests: Behaviour compliance, noop implementation

## Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| `rel` extraction breaks with `ex_stun` API changes | High | Pin `ex_stun ~> 0.1` exactly matching `rel`'s dependency |
| TURN server UDP port conflicts in test env | Medium | Use random ports in test config, tag TURN tests as integration |
| `rel` code has undocumented edge cases | Medium | Keep extracted code close to original; run rel's own test suite if available |
| RTCPeerConnection mocking is fragile in Vitest | Low | Use well-defined mock class with standard WebRTC API surface |
| TURN server needs public IP in production | Low | `Config` module includes `guess_external_ip/1` utility from `rel`'s runtime.exs |
