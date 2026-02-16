# Research: WebRTC Signaling (036)

**Date**: 2026-02-16

## R1: Self-Hosted STUN/TURN Server

### Decision

Extract core modules from [`elixir-webrtc/rel`](https://github.com/elixir-webrtc/rel) into the `retro_hex_chat` domain app under `RetroHexChat.P2P.Turn.*` namespace. Add `{:ex_stun, "~> 0.1"}` as the only new dependency.

### Rationale

- `rel` is NOT a hex library — it's a standalone OTP application with its own Bandit HTTP server, Prometheus metrics, and env-var-based config.
- It cannot be added as a dependency without conflicts (port 4000, own Application module).
- However, its core TURN server logic is clean and compact: **16 modules, ~1,323 LOC**.
- Extracting modules lets us embed the TURN server directly in the BEAM VM, satisfying FR-005 (zero external services).
- `ex_stun` (hex.pm, v0.2.0) provides STUN message codec — the only external dependency needed.

### Alternatives Considered

| Alternative | Rejected Because |
|---|---|
| `rel` as git dependency | Conflicts with Phoenix (port 4000, own Application). Would need a fork. |
| `rel` as Docker sidecar | Not "same BEAM VM" — violates self-hosted premise. |
| ProcessOne `stun` (Erlang) | Erlang-first API, ejabberd-oriented, harder to embed idiomatically. |
| MongooseICE | Last updated 2017, UDP-only, stale. |
| Build from scratch | ~600 LOC of non-trivial TURN relay logic with edge cases already handled in `rel`. |

### Extraction Plan

**Skip entirely (2 modules):**
- `Rel.AuthProvider` (71 LOC) — REST endpoint on Bandit. We generate credentials in Phoenix.
- `Rel.App` as OTP Application — we create our own supervisor.

**Take as-is (11 modules, ~303 LOC):**
- `Rel.Monitor` (15 LOC) — socket cleanup helper
- 10 attribute modules in `Rel.Attribute.*` (~280 LOC total) — pure data codecs

**Modify for embedding (5 modules, ~1,020 LOC):**
- `Rel.Listener` (335 LOC) — replace `Application.fetch_env!(:rel, ...)` with config struct
- `Rel.ListenerSupervisor` (25 LOC) — accept config via `start_link/1` args
- `Rel.AllocationHandler` (421 LOC) — replace compile-time config reads
- `Rel.Auth` (87 LOC) — replace env reads, expose `generate_credentials/1`
- `Rel.Utils` (152 LOC) — replace config reads

**New module:** `RetroHexChat.P2P.Turn.Supervisor` — child supervisor starting ListenerSupervisor + DynamicSupervisor + Registry.

### Configuration

| Key | Default | Where |
|---|---|---|
| `turn_listen_ip` | `{0,0,0,0}` | runtime.exs |
| `turn_listen_port` | `3478` | runtime.exs |
| `turn_relay_ip` | auto-detect | runtime.exs |
| `turn_relay_port_range` | `{49152, 65535}` | runtime.exs |
| `turn_listener_count` | `System.schedulers_online()` | runtime.exs |
| `turn_realm` | `"retro-hex-chat"` | config.exs |
| `turn_auth_secret` | random 64 bytes | runtime.exs |
| `turn_nonce_secret` | random 64 bytes | runtime.exs |
| `turn_credentials_lifetime` | `86_400` (1 day) | config.exs |
| `turn_nonce_lifetime` | `3_600_000_000_000` ns (1h) | config.exs |
| `turn_allocation_lifetime` | `600` (10 min) | config.exs |
| `turn_max_allocation_lifetime` | `3_600` (1h) | config.exs |

---

## R2: Signaling Relay Architecture

### Decision

Use existing PubSub topic `p2p:#{token}` for signaling relay. LiveView handles `p2p_signal` events from both JS hooks and PubSub broadcasts. No GenServer changes needed — the signaling flow is stateless from the server's perspective.

### Rationale

The signaling relay is a simple broadcast: JS → pushEvent → LiveView handle_event → PubSub broadcast → peer LiveView handle_info → push_event → peer JS. The server never inspects SDP content. The GenServer only needs to know about state transitions (connecting → active), not individual signaling messages.

### Flow

```
Initiator Browser                Server (LiveView + PubSub)            Peer Browser
       |                                    |                                |
       |--- pushEvent("p2p_signal", offer)-->|                                |
       |                                    |-- PubSub.broadcast(p2p:token) ->|
       |                                    |                                |-- push_event("p2p_signal", offer)
       |                                    |                                |
       |                                    |<- pushEvent("p2p_signal", answer)|
       |<-- push_event("p2p_signal", answer)|                                |
       |                                    |                                |
       |--- pushEvent("p2p_signal", ice) -->|-- PubSub.broadcast ----------->|-- push_event("p2p_signal", ice)
       |<-- push_event("p2p_signal", ice) --|<- PubSub.broadcast ------------|-- pushEvent("p2p_signal", ice)
       |                                    |                                |
       |--- pushEvent("p2p_connected") ---->|-- transition(:active) -------->|
       |                                    |-- PubSub: p2p_status_changed ->|
```

---

## R3: WebRTC JS Architecture

### Decision

Follow existing hook=wiring/lib=logic pattern. Two new files: `webrtc.js` (lib) and `webrtc_hook.js` (hook).

### webrtc.js API Surface

```javascript
// Pure logic — no DOM, no LiveView, no side effects beyond RTCPeerConnection
export function createPeerConnection(iceServers) → RTCPeerConnection
export async function createOffer(pc) → { type, sdp }
export async function createAnswer(pc, offer) → { type, sdp }
export function handleAnswer(pc, answer) → void
export function addIceCandidate(pc, candidate) → void
export function close(pc) → void
export function onConnectionStateChange(pc, callback) → void
export function onIceCandidate(pc, callback) → void
export function onDataChannel(pc, callback) → void
```

### webrtc_hook.js Responsibilities

- Receive `p2p_start_offer` from server → call `createPeerConnection` + `createOffer`
- Receive `p2p_signal` from server → dispatch to `createAnswer` / `handleAnswer` / `addIceCandidate`
- Push local signals (offer/answer/ICE) to server via `pushEvent("p2p_signal", ...)`
- Push `p2p_connected` / `p2p_failed` to server on connection state changes
- Manage retry logic (3 attempts, 2s/4s/8s exponential backoff)
- Track disconnected grace period (5s before treating as failed)

---

## R4: Initiator Designation

### Decision

The session creator is always the offer initiator. When the action is accepted (status transitions to `connecting`), the server sends `p2p_start_offer` only to the creator. The peer waits for the offer to arrive via `p2p_signal`.

### Rationale

Prevents simultaneous offer creation. The creator role is already tracked in the SessionServer state and LiveView assigns (`role: :creator | :peer`).

---

## R5: ex_stun Version Compatibility

### Decision

Use `{:ex_stun, "~> 0.1"}` to match `rel`'s dependency pin. The 0.2.x series has API changes that would require updating the extracted modules.

### Rationale

The extracted `rel` code was written against `ex_stun ~> 0.1`. Upgrading to 0.2.x would require auditing all Message/Attribute API calls for breaking changes. Better to match and upgrade later if needed.
