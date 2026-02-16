# Feature Specification: P2P Foundation

**Feature Branch**: `034-p2p-foundation`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "P2P Foundation for RetroHexChat — domain infrastructure for peer-to-peer sessions"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a P2P Session (Priority: P1)

A registered user initiates a peer-to-peer session with another registered user. The system validates both participants, creates a session record, starts a background process to manage the session lifecycle, and notifies the target user. Both users receive a unique session URL they can navigate to.

**Why this priority**: Without session creation, no P2P feature can exist. This is the foundational entry point for all P2P interactions (file transfer, audio/video calls).

**Independent Test**: Can be fully tested by calling the session creation function with two valid user IDs and verifying a session record exists in the database, a background process is running, and the target user receives a notification.

**Acceptance Scenarios**:

1. **Given** two registered users (Alice and Bob) with no active P2P session between them, **When** Alice creates a P2P session targeting Bob, **Then** a session record is created with status "pending", a background process starts managing the session, a unique token is generated, and Bob receives a notification with the session URL.
2. **Given** Alice has created a pending session with Bob, **When** Alice tries to create another session with Bob, **Then** the system rejects the request with an error indicating an active session already exists.
3. **Given** Alice is a registered user, **When** Alice tries to create a P2P session with a guest user, **Then** the system rejects the request with an error indicating both participants must be registered.
4. **Given** Alice is a registered user, **When** Alice tries to create a P2P session with herself, **Then** the system rejects the request.
5. **Given** Alice has blocked Bob (or Bob has blocked Alice), **When** either tries to create a P2P session with the other, **Then** the system rejects the request without revealing that a block exists — the error message is generic (e.g., "session cannot be created").

---

### User Story 2 - Session Lifecycle Management (Priority: P1)

Once a session is created, it progresses through a defined state machine: pending (awaiting peer), lobby (both peers present), connecting (handshake in progress), active (P2P connection established), and terminal states (closed, expired, failed). Each state has timeout rules that automatically expire inactive sessions.

**Why this priority**: The state machine is inseparable from session creation — without lifecycle management, sessions would remain in limbo forever. Co-equal priority with creation.

**Independent Test**: Can be fully tested by creating a session, simulating peer joins and state transitions, and verifying the session progresses through each state correctly with proper timeout behavior.

**Acceptance Scenarios**:

1. **Given** a session in "pending" status, **When** 5 minutes elapse without the peer joining, **Then** the session transitions to "expired" and the background process stops.
2. **Given** a session in "pending" status, **When** both peers join the session, **Then** the status transitions to "lobby".
3. **Given** a session in "lobby" status with both peers present, **When** 10 minutes of inactivity elapse, **Then** both peers receive a warning that the session will expire in 5 minutes.
4. **Given** a session in "lobby" status, **When** 15 minutes of total inactivity elapse, **Then** the session transitions to "expired" and the background process stops.
5. **Given** a session in "lobby" status, **When** any peer sends a message or takes an action, **Then** the inactivity timer resets.
6. **Given** a session in any active state, **When** either peer requests to close the session, **Then** the session transitions to "closed" with a recorded reason and timestamp, the background process stops, and the database record is updated.
7. **Given** a session in "lobby" status, **When** both peers agree on an action, **Then** the session transitions to "connecting".
8. **Given** a session in "connecting" status, **When** 30 seconds elapse without a successful connection, **Then** the session transitions to "failed".

---

### User Story 3 - Authorization and Policy Enforcement (Priority: P2)

The system enforces authorization rules for all P2P operations: only registered users can participate, both parties must be valid (not blocked/ignored), and session tokens must be cryptographically verified before granting access.

**Why this priority**: Security is critical but depends on the session infrastructure existing first. Authorization rules gate every P2P operation.

**Independent Test**: Can be fully tested by attempting various unauthorized operations (guest access, blocked users, expired tokens) and verifying each is rejected with appropriate errors.

**Acceptance Scenarios**:

1. **Given** a valid session token, **When** a user who is neither the creator nor the peer attempts to access the session, **Then** access is denied.
2. **Given** a session token that has expired (older than 24 hours), **When** a user attempts to verify it, **Then** verification fails with an expiration error.
3. **Given** a guest user, **When** they attempt any P2P operation (create or join), **Then** the operation is rejected.
4. **Given** a valid session, **When** the creator or peer accesses it with a valid token, **Then** access is granted and session data is returned.

---

### User Story 4 - Stale Session Cleanup (Priority: P3)

A periodic background task identifies and cleans up sessions that have become stale — sessions stuck in non-terminal states whose background processes are no longer running, or sessions that exceeded their maximum lifetime.

**Why this priority**: Cleanup prevents database bloat and resource leaks but is not needed for basic session functionality.

**Independent Test**: Can be fully tested by creating sessions in various stale states (pending with expired timeout, lobby with no running process) and running the cleanup task to verify they are properly transitioned to terminal states.

**Acceptance Scenarios**:

1. **Given** a session in "pending" status whose background process is not running and the pending timeout has elapsed, **When** the cleanup task runs, **Then** the session is updated to "expired" in the database.
2. **Given** a session in "lobby" status whose background process is not running, **When** the cleanup task runs, **Then** the session is updated to "expired" in the database.
3. **Given** a session in "active" status that is still being managed by a running background process, **When** the cleanup task runs, **Then** the session is left unchanged.
4. **Given** a session already in a terminal state ("closed", "expired", "failed"), **When** the cleanup task runs, **Then** the session is not modified.

---

### Edge Cases

- What happens when the background process crashes mid-session? The supervisor restarts it, and the process recovers its state from the database (DB is authoritative).
- What happens when a session token is reused after the session has been closed? Token verification succeeds but session status check rejects access since the session is in a terminal state.
- What happens when both users try to create a P2P session with each other simultaneously? The duplicate-session check prevents the second creation — the pair is checked bidirectionally (A-B is the same as B-A).
- What happens when the target user is offline? The session is created in "pending" status and the notification is published to the user's topic. If the user comes online within the timeout window, they receive the notification; otherwise the session expires.
- What happens when the cleanup task finds a session whose background process stopped but the database record is still in a non-terminal state? The cleanup task updates the database record to "expired" without attempting to stop a non-existent process.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow registered users to create P2P sessions with other registered users.
- **FR-002**: System MUST reject P2P session creation when either participant is a guest (unregistered).
- **FR-003**: System MUST reject P2P session creation when a user targets themselves.
- **FR-004**: System MUST reject P2P session creation when an active (non-terminal) session already exists between the same pair of users, regardless of direction.
- **FR-005**: System MUST reject P2P session creation when either user has blocked/ignored the other, without revealing the block/ignore relationship to the blocked user.
- **FR-006**: System MUST generate a unique, cryptographically signed session token for each new session with a 24-hour expiration.
- **FR-007**: System MUST persist session records in the database with status, participants, token, timestamps, and closure details.
- **FR-008**: System MUST start a dedicated background process for each active session, registered by session token for lookup.
- **FR-009**: System MUST enforce a session state machine with exactly these states: pending, lobby, connecting, active, closed, expired, failed.
- **FR-010**: System MUST automatically expire sessions that exceed their state-specific timeouts: pending (5 minutes), lobby (15 minutes of inactivity), connecting (30 seconds).
- **FR-011**: System MUST send an inactivity warning to both peers after 10 minutes of lobby inactivity, indicating the session will expire in 5 minutes.
- **FR-012**: System MUST reset the lobby inactivity timer when any peer activity occurs.
- **FR-013**: System MUST notify the target user of a new P2P session invitation via the existing publish/subscribe system.
- **FR-014**: System MUST allow either peer to close an active session gracefully, recording the reason and timestamp.
- **FR-015**: System MUST verify session tokens before granting access, rejecting expired or tampered tokens.
- **FR-016**: System MUST ensure only the session creator and the designated peer can access a session.
- **FR-017**: System MUST recover session state from the database when a background process restarts after a crash.
- **FR-018**: System MUST provide a periodic cleanup mechanism to expire stale sessions whose background processes are no longer running.
- **FR-019**: System MUST update the database record when a session transitions to any terminal state (closed, expired, failed), including the closure timestamp and reason.
- **FR-020**: The P2P domain layer MUST NOT depend on web framework concerns — it must be a standalone domain module within the umbrella architecture.

### Key Entities

- **P2P Session**: Represents a peer-to-peer connection between two registered users. Key attributes: unique token, creator, peer, current status, session type, creation time, closure time, closure reason, and arbitrary metadata for extensibility.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A P2P session can be created, progress through all lifecycle states, and terminate in under 1 second of processing time (excluding deliberate timeout waits).
- **SC-002**: All authorization checks (guest rejection, self-session, duplicate detection, block enforcement) execute and return a result in under 100 milliseconds.
- **SC-003**: 100% of stale sessions (background process stopped, timeout exceeded) are identified and cleaned up within one cleanup cycle.
- **SC-004**: A crashed background process recovers its session state from the database and resumes management without data loss.
- **SC-005**: Session token generation and verification complete without errors for all valid inputs, and reject 100% of expired or tampered tokens.
- **SC-006**: The P2P domain module has zero compile-time dependencies on web framework modules, maintaining clean umbrella separation.
- **SC-007**: The lobby inactivity warning is delivered to both peers exactly once at the 10-minute mark, and session expiration occurs at the 15-minute mark.

## Scope

### In Scope

- P2P bounded context module scaffold (facade, service, policy, queries)
- p2p_sessions database schema and migration
- Session token generation and verification module
- Policy module with authorization rules (registered-only, no self-session, no duplicates, block/ignore enforcement)
- SessionServer background process with full state machine (pending, lobby, connecting, active, closed, expired, failed)
- Lobby inactivity warning at 10 minutes and expiration at 15 minutes
- Dynamic process supervisor and registry setup
- Service orchestration module coordinating creation, lifecycle, and teardown
- Database query module for session lookups and status updates
- Stale session cleanup task

### Out of Scope

- P2P LiveView UI and page components
- Command handlers (/p2p, /call, /sendfile)
- WebRTC signaling and media code
- File transfer protocol
- Audio/video media handling
- TURN/STUN server credentials and setup
- Rate limiting for P2P operations
- Help documentation topics

## Assumptions

- The existing ignore/ban system in the Accounts context exposes a function to check if one user has blocked another, usable from the P2P context without introducing a dependency on web concerns.
- The existing DynamicSupervisor + Registry + GenServer pattern used by ChannelServer is the architectural template for P2P session management.
- Phoenix.Token (already used for user authentication) is the mechanism for session token generation and verification.
- PubSub topics follow the existing convention "user:nickname" for user-directed notifications.
- The cleanup task runs as a periodic process (e.g., every minute) rather than requiring external scheduling.
- Session type (generic, file-transfer, audio-call) is stored as metadata but does not affect the core state machine — all session types share the same lifecycle.
- The "connecting" and "active" states are included in the state machine for completeness but their transition triggers (WebRTC handshake success) will be implemented in a subsequent signaling plan.

## Dependencies

- **Accounts context**: For user lookup (registered vs. guest) and block/ignore status checks.
- **PubSub**: For publishing session notifications to target users.
- **Phoenix.Token**: For cryptographic token generation and verification.
- **Ecto/PostgreSQL**: For session persistence.
