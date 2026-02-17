# Feature Specification: P2P Security, Help & Polish

**Feature Branch**: `039-p2p-security-help-polish`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "P2P Security, Help & Polish for RetroHexChat — TURN credentials, privacy mode, rate limiting, help documentation, ignore/ban integration"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - TURN Credential Generation (Priority: P1)

A user behind a symmetric NAT attempts a P2P connection (session, file transfer, or call). During the ICE gathering phase, only relay candidates succeed. The system generates short-lived TURN credentials (1-hour TTL, HMAC-SHA1 per RFC 5766) and includes them in the ICE server configuration sent to the browser. The TURN server authenticates these credentials and relays WebRTC traffic. The connection succeeds despite the restrictive NAT.

**Why this priority**: Without TURN support, approximately 30% of users behind symmetric NATs cannot establish P2P connections at all. This is the highest-impact improvement — it directly unblocks a significant portion of the user base.

**Independent Test**: Can be tested by configuring a TURN server and verifying that ICE server configuration includes valid short-lived credentials with correct HMAC-SHA1 signatures.

**Acceptance Scenarios**:

1. **Given** a TURN server is configured in application settings, **When** a P2P session is initiated, **Then** the ICE server configuration sent to the browser includes TURN credentials with a username containing the expiry timestamp and a credential computed via HMAC-SHA1.
2. **Given** a TURN server is configured, **When** credentials are generated, **Then** they expire after 1 hour (3600 seconds from generation time).
3. **Given** no TURN server is configured in application settings, **When** a P2P session is initiated, **Then** only STUN servers appear in the ICE configuration and the system operates normally without TURN.
4. **Given** TURN credentials were generated, **When** inspecting client-side JavaScript, **Then** the shared secret is never present — only the computed username and credential are visible.

---

### User Story 2 - P2P Rate Limiting (Priority: P1)

A malicious or misbehaving user attempts to abuse the P2P system by rapidly creating sessions, sending excessive invites, or flooding signaling messages. The system enforces server-side rate limits: 5 session creations per 10 minutes, 10 invites per 30 minutes, and 100 signaling messages per minute. Excess requests are rejected with a user-friendly message (sessions/invites) or silently dropped (signaling).

**Why this priority**: Rate limiting is a security-critical feature. Without it, a single user can degrade the experience for everyone by spamming session creation and signaling messages. Tied for P1 with TURN credentials because it protects system integrity.

**Independent Test**: Can be tested by attempting to exceed each rate limit threshold and verifying rejection behavior.

**Acceptance Scenarios**:

1. **Given** a user has created 5 P2P sessions in the last 10 minutes, **When** they attempt to create a 6th session, **Then** the system rejects the request with the message "Você criou muitas sessões. Tente novamente em X minutos" where X is the remaining wait time.
2. **Given** a user has sent 10 P2P invites in the last 30 minutes, **When** they attempt to send an 11th invite, **Then** the system rejects the request with an appropriate rate limit message.
3. **Given** a user has sent 100 signaling messages in the last minute, **When** they send additional signaling messages, **Then** excess messages are silently dropped without notifying the sender.
4. **Given** a user hit the session creation rate limit, **When** the time window expires, **Then** they can create sessions again normally.

---

### User Story 3 - TURN-Only Privacy Mode (Priority: P2)

A privacy-conscious user wants to prevent their real IP address from being exposed to peers during P2P connections. They enable "Modo privado (TURN-only)" either via a checkbox in the P2P lobby or through user preferences (p2p_settings.turn_only). When enabled, the WebRTC connection uses relay-only ICE transport policy, forcing all traffic through the TURN server. The user accepts higher latency in exchange for IP privacy.

**Why this priority**: Privacy mode depends on TURN infrastructure (P1) being in place. It provides significant value for privacy-conscious users but is an opt-in enhancement rather than a core blocker.

**Independent Test**: Can be tested by enabling privacy mode and verifying that the WebRTC connection configuration uses relay-only ICE transport policy.

**Acceptance Scenarios**:

1. **Given** a user has enabled TURN-only privacy mode, **When** a P2P connection is initiated, **Then** the WebRTC configuration forces relay-only transport and no direct peer connections are attempted.
2. **Given** a user has enabled privacy mode but no TURN server is configured, **When** they attempt a P2P connection, **Then** a warning message explains that privacy mode requires a TURN server, and the connection falls back to direct mode.
3. **Given** privacy mode is disabled (the default), **When** a P2P connection is initiated, **Then** both direct and relay ICE candidates are used normally.
4. **Given** a user is in the P2P lobby, **When** they check the "Modo privado (TURN-only)" checkbox, **Then** the preference is saved and applies to all subsequent P2P connections in that session and future sessions.
5. **Given** a user enables privacy mode in user preferences, **When** they enter the P2P lobby, **Then** the checkbox is pre-checked reflecting their saved preference.

---

### User Story 4 - Ignore/Ban Integration for P2P (Priority: P2)

A user who has blocked (ignored) another user should not receive P2P invitations from them. If a P2P session is active when one user blocks the other, the session is closed immediately. Banned users cannot initiate P2P sessions at all. The blocked user is not informed of the block reason — they see a generic "user unavailable" response.

**Why this priority**: Integrates existing ignore/ban infrastructure with the P2P system to maintain user safety and harassment prevention. Important for trust but the P2P system functions without it.

**Independent Test**: Can be tested by ignoring a user and verifying that P2P invites from them are silently rejected.

**Acceptance Scenarios**:

1. **Given** User A has ignored User B, **When** User B attempts to send a P2P invite to User A, **Then** the invite is silently rejected and User B sees a generic "user unavailable" message.
2. **Given** User A and User B are in an active P2P session, **When** User A blocks User B, **Then** the P2P session is closed immediately for both users.
3. **Given** a user is banned, **When** they attempt to create any P2P session, **Then** the request is rejected.
4. **Given** User A has ignored User B, **When** User B views their contact list, **Then** there is no indication that they have been blocked — User A simply appears unavailable for P2P.

---

### User Story 5 - P2P Help Documentation (Priority: P3)

A user accesses the help system (via the Help menu > Help Topics, or `/help`) and finds comprehensive documentation for all P2P features: sessions, file transfer, audio/video calls, and privacy settings. Each topic includes clear descriptions, usage instructions, command syntax, and "See Also" cross-references to related topics. The Keyboard Shortcuts topic is updated with any P2P-related shortcuts (browser-allowed shortcuts only).

**Why this priority**: Help documentation is a mandatory requirement per Constitution Principle XI but does not affect functionality. It completes the P2P feature set for release readiness.

**Independent Test**: Can be tested by navigating to each help topic and verifying that content is accurate, complete, and cross-referenced.

**Acceptance Scenarios**:

1. **Given** a user accesses the help system, **When** they search for "P2P" or navigate to the Features category, **Then** they find a "P2P Sessions" topic explaining session creation (/p2p command), the lobby system, bilateral consent, and session timeouts.
2. **Given** a user reads the "P2P Sessions" help topic, **When** they follow "See Also" links, **Then** they can navigate to "File Transfer", "Audio/Video Calls", and "Privacy Settings" topics.
3. **Given** a user accesses the "File Transfer" help topic, **When** they read it, **Then** they find instructions for using /sendfile, supported file types/sizes, and transfer progress information.
4. **Given** a user accesses the "Audio/Video Calls" help topic, **When** they read it, **Then** they find instructions for using /call, call controls (mute, camera toggle, screen share), and connection requirements.
5. **Given** a user accesses the "Privacy Settings" help topic, **When** they read it, **Then** they find an explanation of TURN-only privacy mode, what it does, and how to enable it.

---

### Edge Cases

- **TURN server is down**: P2P connections may still work via direct connection for users not behind symmetric NATs. Users who require relay will see a connection failure with an appropriate error message.
- **TURN credentials expire during active session**: The session continues uninterrupted — credentials are only needed during the ICE negotiation phase, not for ongoing media relay.
- **Privacy mode enabled but no TURN server configured**: The system displays a warning explaining that privacy mode requires a TURN server and falls back to direct connection mode.
- **Rate limit hit during legitimate burst**: The user waits for the time window to reset. The rate limits (5 sessions/10min, 10 invites/30min, 100 signaling/min) are generous enough for normal usage patterns.
- **User blocks peer during active P2P session**: The session is closed immediately for both parties.
- **Guest users and P2P**: Guest (session-based) users cannot use P2P features — only registered users can initiate or accept P2P connections. This is consistent with existing P2P foundation behavior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST generate short-lived TURN credentials using HMAC-SHA1 per RFC 5766, with a 1-hour TTL, when a TURN server is configured.
- **FR-002**: System MUST include TURN server URLs and generated credentials in the ICE server configuration sent to clients during P2P session setup.
- **FR-003**: System MUST never expose the TURN shared secret to the client — only computed username (with expiry timestamp) and credential (HMAC-SHA1 hash) are transmitted.
- **FR-004**: System MUST operate normally without TURN when no TURN server is configured, using only STUN servers.
- **FR-005**: System MUST support application-level configuration for TURN server URL(s) and shared secret.
- **FR-006**: System MUST enforce a rate limit of 5 P2P session creations per user per 10-minute window.
- **FR-007**: System MUST enforce a rate limit of 10 P2P invites per user per 30-minute window.
- **FR-008**: System MUST enforce a rate limit of 100 signaling messages per user per 1-minute window, silently dropping excess messages.
- **FR-009**: System MUST display a user-friendly message in Portuguese when session creation or invite rate limits are hit, including the remaining wait time.
- **FR-010**: System MUST support a user preference (p2p_settings.turn_only) for TURN-only privacy mode, defaulting to disabled.
- **FR-011**: System MUST provide a "Modo privado (TURN-only)" checkbox in the P2P lobby UI that reflects and updates the user's privacy mode preference.
- **FR-012**: When privacy mode is enabled, system MUST configure WebRTC connections with relay-only ICE transport policy.
- **FR-013**: When privacy mode is enabled but no TURN server is configured, system MUST warn the user and fall back to direct connection mode.
- **FR-014**: System MUST prevent users who are ignored/blocked from sending P2P invitations to the blocking user, showing a generic "user unavailable" message to the blocked user.
- **FR-015**: System MUST immediately close active P2P sessions when one participant blocks the other.
- **FR-016**: System MUST prevent banned users from creating P2P sessions.
- **FR-017**: System MUST provide help topics for: P2P Sessions, File Transfer, Audio/Video Calls, and Privacy Settings.
- **FR-018**: System MUST update the existing Keyboard Shortcuts help topic with any P2P-related keyboard shortcuts (browser-allowed shortcuts only).
- **FR-019**: All help topics MUST include "See Also" cross-references to related topics.
- **FR-020**: All rate limiting MUST be enforced server-side; client-side enforcement alone is not acceptable.

### Key Entities

- **TURN Credentials**: Short-lived authentication token pair (username with embedded expiry, HMAC-SHA1 credential) used by WebRTC clients to authenticate with TURN relay servers. Generated server-side, never exposing the shared secret.
- **P2P Rate Limit**: Per-user counters tracking session creation, invite, and signaling message frequency within sliding time windows. Enforced via the existing RateLimit bounded context.
- **P2P Privacy Preference**: User setting (p2p_settings.turn_only) stored in user preferences that controls whether WebRTC connections use relay-only transport policy.
- **Help Topic**: Structured documentation entry within the HelpTopics module, containing title, category, content, and "See Also" cross-references.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users behind symmetric NATs can establish P2P connections when a TURN server is configured, increasing successful connection rate from ~70% to ~95%+ of connection attempts.
- **SC-002**: No user can create more than 5 P2P sessions in any 10-minute window, or send more than 10 invites in any 30-minute window.
- **SC-003**: Signaling message floods exceeding 100 messages per minute are silently contained without affecting legitimate users' connections.
- **SC-004**: Users with privacy mode enabled have their real IP address fully hidden from peers — all traffic routes through the relay server.
- **SC-005**: Blocked/ignored users cannot send P2P invitations and see no indication that they have been blocked — only a generic "unavailable" message.
- **SC-006**: All five P2P-related help topics are accessible through the help system, with accurate content and working cross-references.
- **SC-007**: TURN shared secret is never present in any client-facing response or JavaScript variable.

## Assumptions

- A TURN server (e.g., coturn) will be deployed separately — this feature only handles credential generation and configuration, not server deployment.
- The existing `user_preferences` table with JSONB columns can accommodate the new `p2p_settings` key without a database migration (consistent with previous preference additions).
- The existing RateLimit bounded context patterns (used for flood control) are suitable for P2P rate limiting without architectural changes.
- The F1 key reference in the original description refers to accessing help through the application's Help menu or `/help` command — keyboard shortcuts are limited to what browsers allow.
- The signaling rate limit of 100 messages/minute is sufficient for legitimate ICE trickle operations during WebRTC negotiation.

## Scope

### In Scope

- TurnCredentials module (RFC 5766 HMAC-SHA1 credential generation)
- TURN server application configuration (URLs, shared secret)
- TURN-only privacy mode user preference and lobby UI toggle
- Session creation rate limit (5/10min)
- Invite rate limit (10/30min)
- Signaling rate limit enforcement (100/min)
- 5 help topics: P2P Sessions, File Transfer, Audio/Video Calls, Privacy Settings, Keyboard Shortcuts update
- Ignore/ban integration for P2P (invite blocking, session termination)

### Out of Scope

- TURN server deployment and operations
- Certificate management
- DDoS protection beyond rate limiting
- Session recording or history persistence
- Admin controls for P2P
- Client-side-only rate limiting
