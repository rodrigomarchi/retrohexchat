# Feature Specification: WebRTC Signaling

**Feature Branch**: `036-webrtc-signaling`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "WebRTC Signaling — PubSub-based signal relay, self-hosted STUN/TURN via rel, browser-native RTCPeerConnection, connection state UI, automatic retry with exponential backoff"

## Clarifications

### Session 2026-02-16

- Q: Which RTCPeerConnection states trigger the retry cycle? → A: Only `"failed"` triggers retry; `"disconnected"` gets a 5-second grace period before being treated as failed.
- Q: What does "return to lobby" mean after permanent failure? → A: Close the failed session; offer a "Try again" button that creates a new session with the same peer. No backwards state transitions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Successful P2P Connection Establishment (Priority: P1)

After both peers agree on an action in the P2P lobby (e.g., file transfer or audio call), the system automatically establishes a direct peer-to-peer connection between their browsers. The initiator's browser creates an SDP offer and exchanges it with the peer through the server relay. ICE candidates are exchanged incrementally. Both users see a "Conectando..." indicator during the handshake. When the connection succeeds, both users see "Conectado" and the session transitions to active state.

**Why this priority**: This is the core value — without a successful WebRTC handshake, no P2P features (file transfer, calls) can work. Everything else depends on this.

**Independent Test**: Can be fully tested by having two authenticated users accept an action in the lobby and verifying that a peer-to-peer connection is established with correct state transitions displayed.

**Acceptance Scenarios**:

1. **Given** two users are in the P2P lobby and one accepts an action request, **When** the signaling flow completes, **Then** both users see "Conectado" and the session status becomes active.
2. **Given** the initiator's browser creates an SDP offer, **When** the server receives it, **Then** the server relays it to the peer without inspecting or modifying its content.
3. **Given** both browsers are discovering ICE candidates, **When** a candidate is found, **Then** it is sent incrementally (trickle ICE) to the peer via the server relay.
4. **Given** a successful WebRTC connection, **When** the connection state becomes "connected", **Then** the server is notified and updates the session to active state in both the process and the database.

---

### User Story 2 - Automatic Retry on Connection Failure (Priority: P2)

When the WebRTC handshake fails (e.g., due to NAT traversal issues), the system automatically retries up to 3 times with exponential backoff (2s, 4s, 8s delays). The user sees progress updates ("Tentativa 2 de 3..."). If all attempts fail, the session transitions to failed state and the user sees a clear error message with an option to return to the lobby.

**Why this priority**: Network conditions vary widely — automatic retry significantly improves connection success rate without user intervention.

**Independent Test**: Can be tested by simulating a handshake failure and verifying retry behavior, progress messages, and final failure state.

**Acceptance Scenarios**:

1. **Given** a WebRTC handshake fails on the first attempt, **When** the system retries, **Then** a new connection is created (not reusing the failed one) after a 2-second delay, and the user sees "Falha na conexão. Tentativa 2 de 3...".
2. **Given** the second retry also fails, **When** the system retries a third time, **Then** the delay is 4 seconds before the third attempt, and the user sees "Tentativa 3 de 3...".
3. **Given** all 3 attempts fail, **When** the final attempt completes, **Then** the session transitions to failed state (terminal), the user sees "Não foi possível estabelecer a conexão P2P", and a "Try again" button is presented that creates a new session with the same peer.
4. **Given** a retry is in progress, **When** the second attempt succeeds, **Then** the retry cycle stops and the session transitions to active normally.

---

### User Story 3 - Self-Hosted ICE Server Configuration (Priority: P1)

The application includes a self-hosted STUN/TURN server running within the same process. ICE server addresses and short-lived TURN credentials are provided to browsers during connection setup. No external public services are contacted. In development/LAN scenarios, direct host candidates work without any STUN. In production, the self-hosted server provides both STUN (for public IP discovery) and TURN (as relay fallback for restrictive NATs).

**Why this priority**: Equal to P1 because the signaling flow cannot produce a successful connection without ICE servers. Self-hosting is a non-negotiable project premise.

**Independent Test**: Can be tested by verifying that ICE server configuration is sent to browsers on connection start, that TURN credentials are valid and short-lived, and that no requests are made to external services.

**Acceptance Scenarios**:

1. **Given** a P2P connection is being initiated, **When** the server sends ICE configuration to the browser, **Then** the configuration points to the self-hosted STUN/TURN instance with valid credentials.
2. **Given** the application starts, **When** the STUN/TURN server process initializes, **Then** it listens on the configured ports within the same runtime.
3. **Given** TURN credentials are generated for a session, **When** the credential TTL expires, **Then** the credentials are no longer valid for new allocations.
4. **Given** a restrictive NAT environment, **When** direct and STUN-reflexive candidates fail, **Then** the TURN relay provides connectivity as a fallback.

---

### User Story 4 - Connection State Visibility (Priority: P2)

Both users see real-time connection state updates during the WebRTC handshake and throughout the session. States include: "Conectando..." (during handshake), "Conectado" (successful), "Reconectando..." (during retry), and "Falha na conexão" (on failure). The visual indicator appears in the session window.

**Why this priority**: Users need feedback about what's happening during the connection process, but this is display-only — the connection works even without the UI indicator.

**Independent Test**: Can be tested by observing the connection state indicator during each phase of the signaling flow.

**Acceptance Scenarios**:

1. **Given** the signaling flow has started, **When** the browser is creating an offer or exchanging ICE candidates, **Then** the user sees "Conectando...".
2. **Given** the connection state becomes "connected", **When** the UI updates, **Then** the user sees "Conectado".
3. **Given** a retry is in progress, **When** the system is between attempts, **Then** the user sees "Reconectando..." with the attempt number.
4. **Given** all retries have failed, **When** the session enters failed state, **Then** the user sees "Falha na conexão" with a "Try again" button that closes the session and creates a new one with the same peer.

---

### User Story 5 - Signaling Rate Limit Contract (Priority: P3)

A rate limit interface (contract/behaviour) is established for signaling messages. This defines the expected function signature and return types that a future rate limiter must implement. The contract is available for integration but enforcement is deferred to a separate security feature.

**Why this priority**: The contract is a preparatory step — it doesn't block P2P functionality but ensures the integration point is clean when enforcement is added later.

**Independent Test**: Can be tested by verifying the behaviour module compiles and defines the expected callbacks.

**Acceptance Scenarios**:

1. **Given** the rate limit behaviour is defined, **When** a module implements it, **Then** it must provide a function that accepts a session token and user identifier and returns either success or a rate-limited error.
2. **Given** the signaling relay processes a message, **When** a rate limiter is configured, **Then** the relay calls the rate limit check before broadcasting.

---

### Edge Cases

- **Peer disconnects during handshake**: If one peer's LiveView disconnects before the answer is received, the initiator's handshake times out after 30 seconds and enters the retry cycle.
- **Simultaneous offer creation**: The server designates the session creator as the initiator to prevent both peers from creating offers simultaneously.
- **LiveView reconnect mid-handshake**: If a peer's LiveView reconnects during an active handshake, the new mount triggers a fresh signaling negotiation from the beginning.
- **ICE gathering timeout**: Trickle ICE sends candidates as they are discovered; the system does not wait for all candidates before starting the handshake.
- **Browser lacks WebRTC support**: Detected by the existing capability check in the lobby; the signaling flow assumes WebRTC support is confirmed before starting.
- **Rapid signaling messages**: The rate limit interface is prepared; without enforcement, the server processes all messages but the contract is ready for throttling.
- **Transient disconnection**: If `connectionState` becomes `"disconnected"`, the system waits 5 seconds for self-recovery before treating it as `"failed"` and entering the retry cycle. This avoids unnecessary retries on brief network hiccups.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST relay SDP offers, SDP answers, and ICE candidates between peers via the server without inspecting, modifying, or storing their content.
- **FR-002**: System MUST designate the session creator as the offer initiator to prevent simultaneous offer creation.
- **FR-003**: System MUST send self-hosted ICE server configuration (STUN and TURN addresses with credentials) to browsers when initiating a connection.
- **FR-004**: System MUST generate short-lived TURN credentials per session with a configurable time-to-live (default: 1 hour).
- **FR-005**: System MUST run a STUN/TURN server within the same application runtime, requiring zero external service dependencies.
- **FR-006**: System MUST display connection state to both users: "Conectando...", "Conectado", "Reconectando...", "Falha na conexão".
- **FR-007**: System MUST automatically retry failed handshakes up to 3 times with exponential backoff (2s, 4s, 8s delays), creating a new connection on each attempt. Retry is triggered only when `connectionState` becomes `"failed"`. A `"disconnected"` state is given a 5-second grace period before being treated as failed.
- **FR-008**: System MUST transition the session to active state when the peer-to-peer connection is successfully established.
- **FR-009**: System MUST transition the session to failed state when all retry attempts are exhausted.
- **FR-010**: System MUST close the failed session and offer a "Try again" button that creates a new session with the same peer. No backwards state transitions (failed sessions are terminal).
- **FR-011**: System MUST define a rate limit interface (behaviour/contract) for signaling messages, accepting a session token and user identifier.
- **FR-012**: System MUST validate signaling message format server-side before relaying (message type must be one of: offer, answer, ice-candidate).
- **FR-013**: System MUST use trickle ICE — candidates are sent incrementally as discovered, not batched.
- **FR-014**: System MUST separate WebRTC connection logic (pure logic module) from LiveView wiring (hook module), following the existing hook=wiring/lib=logic pattern.

### Key Entities

- **Signal Message**: A signaling payload relayed between peers. Contains a type (offer, answer, or ice-candidate) and associated data (SDP string or ICE candidate object). Ephemeral — never persisted.
- **ICE Server Configuration**: STUN/TURN server addresses and credentials sent to browsers. Includes server URLs, credential username, credential password, and TTL. Generated per session.
- **Connection State**: The current state of the WebRTC peer connection as observed by the browser. Values: new, connecting, connected, disconnected, failed, closed. Mapped to user-facing labels for display. `"disconnected"` has a 5-second grace period before being escalated to `"failed"`.
- **Retry Attempt**: Tracks the current retry count (1-3) and delay schedule. Reset on success. Drives the retry UI indicator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two users on the same network establish a direct P2P connection within 5 seconds of bilateral consent.
- **SC-002**: Two users behind different NATs establish a P2P connection (via TURN relay) within 10 seconds of bilateral consent.
- **SC-003**: Connection state transitions are visible to the user within 500ms of the underlying state change.
- **SC-004**: Failed connections retry automatically without user intervention, with at least 1 retry succeeding when the initial failure is transient.
- **SC-005**: Zero requests are made to external public STUN/TURN services during any connection flow.
- **SC-006**: TURN credentials expire after their configured TTL and cannot be reused for new allocations.
- **SC-007**: The signaling relay adds less than 200ms overhead to the SDP/ICE exchange round-trip time.

## Assumptions

- WebRTC browser support is confirmed by the existing capability check before signaling begins (no fallback needed for unsupported browsers).
- The `rel` Elixir library provides STUN and TURN functionality suitable for 1-to-1 P2P sessions. If `rel` does not meet requirements, an equivalent self-hosted Elixir library will be evaluated.
- TURN relay bandwidth is acceptable for 1-to-1 sessions; scaling for many concurrent TURN-relayed sessions is out of scope.
- The existing PubSub topic `p2p:#{token}` is sufficient for signaling message delivery with acceptable latency.
- Help documentation for this feature will be added in a separate pass and is explicitly out of scope for this specification.

## Scope

### In Scope

- PubSub signal relay for SDP offers, answers, and ICE candidates in P2PSessionLive
- webrtc.js pure logic module (RTCPeerConnection management, offer/answer/ICE flow)
- webrtc_hook.js LiveView hook (wiring between LiveView events and webrtc.js)
- Self-hosted STUN/TURN via `rel` library (dependency addition, supervisor configuration)
- TURN credential generation module
- ICE server configuration via application environment
- Connection state tracking UI in the session window
- Automatic retry with exponential backoff (3 attempts, 2s/4s/8s)
- Session state transition to active on successful connection
- Signaling rate limit interface (behaviour/contract definition only)
- Server-side signal message format validation
- JS tests for webrtc.js (Vitest, mocked RTCPeerConnection)
- JS tests for webrtc_hook.js (Vitest, LiveView event simulation)

### Out of Scope

- TURN server production deployment, scaling, or monitoring
- Rate limit enforcement implementation (deferred to security feature)
- File transfer protocol over DataChannel
- Audio/video media streams
- Help documentation (separate pass)
- TURN-only privacy mode (user preference for forcing relay)
- ICE candidate filtering or modification
