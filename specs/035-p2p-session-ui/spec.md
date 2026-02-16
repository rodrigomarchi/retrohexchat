# Feature Specification: P2P Lobby & Session UI

**Feature Branch**: `035-p2p-session-ui`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "P2P Lobby & Session UI for RetroHexChat"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initiate a P2P Session via Slash Command (Priority: P1)

A registered user types `/p2p mario` in the chat input to request a peer-to-peer session with another online registered user. The system validates that "mario" exists and is online, creates a P2P session, and delivers the invitation through two channels: (1) a message in the **private chat (PM) between the two users** containing the lobby link, visible to both the initiator and the peer, and (2) a **toast notification** to the peer for immediate attention. The PM message is the primary invitation channel — it provides context within the conversation and persists in the chat history. The toast notification is a secondary alert with action buttons: Aceitar (accept — navigates to the lobby), Recusar (reject — closes the session with reason "rejected" and notifies the initiator in the PM), and Ignorar (dismiss — notification disappears, session expires after 5 minutes). Clicking the lobby link in the PM or clicking Aceitar in the toast both navigate to `/p2p/:token`.

**Why this priority**: Without a way to create sessions, no other P2P UI functionality is reachable. This is the entry point for the entire feature.

**Independent Test**: Can be fully tested by typing `/p2p <nick>` and verifying the invitation message appears in the PM between both users and a toast notification appears for the peer. Delivers the ability to create and respond to P2P invitations.

**Acceptance Scenarios**:

1. **Given** a registered user "rodrigo" in a channel, **When** they type `/p2p mario` and "mario" is online and registered, **Then** a message with the lobby link appears in the private chat between rodrigo and mario (visible to both), and mario also receives a toast notification with Aceitar/Recusar/Ignorar buttons.
2. **Given** a registered user, **When** they type `/p2p` without a nickname, **Then** they see an error message with usage syntax.
3. **Given** a registered user, **When** they type `/p2p ghost` and "ghost" is not online or not registered, **Then** they see an appropriate error message.
4. **Given** mario receives the toast notification, **When** mario clicks Recusar, **Then** the session is closed with reason "rejected" and a message "mario recusou o convite P2P" appears in the private chat between rodrigo and mario.
5. **Given** mario receives the toast notification, **When** mario clicks Ignorar, **Then** the notification is dismissed and the session expires after 5 minutes of inactivity.
6. **Given** mario receives the invitation, **When** mario clicks the lobby link in the PM or clicks Aceitar in the toast, **Then** mario is navigated to the P2P lobby at `/p2p/:token`.
7. **Given** mario is offline or has the PM tab closed, **When** mario later opens the PM with rodrigo, **Then** the invitation message with the lobby link is visible in the chat history (subject to session expiration).

---

### User Story 2 - P2P Lobby with Peer Presence and Ephemeral Chat (Priority: P2)

Both peers navigate to `/p2p/:token` and enter the lobby. The lobby is a dedicated page styled as a Windows 98 window showing both peers' names, online/offline presence indicators, and an ephemeral chat area. Peers can exchange messages in real-time within the lobby. These messages are not persisted to the database — they exist only in the session process memory. The lobby also displays system messages for events like peer joining, peer leaving, and session status changes.

**Why this priority**: The lobby is the core meeting space where peers interact before initiating any P2P action. Without it, peers have no shared context.

**Independent Test**: Can be tested by having two users navigate to the same `/p2p/:token` URL and verifying they see each other's names, presence indicators update in real-time, and chat messages are exchanged instantly.

**Acceptance Scenarios**:

1. **Given** a valid session token, **When** both the creator and peer navigate to `/p2p/:token`, **Then** both see a Windows 98-style lobby window with each other's nicknames and green "online" presence indicators.
2. **Given** both peers are in the lobby, **When** rodrigo types a message in the lobby chat, **Then** mario sees the message appear immediately, and vice versa.
3. **Given** both peers are in the lobby, **When** rodrigo refreshes the page, **Then** previous chat messages are gone (ephemeral — not persisted).
4. **Given** a valid session in pending state, **When** only one peer has joined the lobby, **Then** the other peer's presence indicator shows "offline/awaiting" and a system message indicates the peer has not yet arrived.
5. **Given** a user who is neither creator nor peer, **When** they navigate to `/p2p/:token`, **Then** they receive a 404 error page.
6. **Given** an expired or invalid token, **When** a user navigates to `/p2p/:token`, **Then** they are redirected to the main chat with an error message.

---

### User Story 3 - Bilateral Consent Action Requests (Priority: P3)

The lobby displays action buttons for available P2P activities: "Enviar Arquivo", "Chamada de Audio", and "Chamada de Video". When a peer clicks an action button, the other peer sees a request notification within the lobby (e.g., "rodrigo quer iniciar uma chamada de audio") with Accept and Reject buttons. Only when the second peer accepts does the system proceed — requesting browser permissions and initiating the action. If the browser does not support the required capability (e.g., `getUserMedia` for audio/video), the corresponding buttons are disabled with an explanatory tooltip. Browser capability detection runs asynchronously after mount and does not block the initial lobby render.

**Why this priority**: Bilateral consent is the core UX innovation over legacy DCC. It ensures both peers agree before any resource-intensive action begins.

**Independent Test**: Can be tested by having one peer click an action button and verifying the other peer sees the consent request with Accept/Reject options. Capability detection can be tested by simulating a browser without `getUserMedia`.

**Acceptance Scenarios**:

1. **Given** both peers are in the lobby, **When** rodrigo clicks "Chamada de Audio", **Then** mario sees "rodrigo quer iniciar uma chamada de audio" with Accept and Reject buttons.
2. **Given** mario sees an action request, **When** mario clicks Accept, **Then** the system requests microphone permission from both browsers. Once both grant permission, the session transitions to "connecting" state and the lobby displays an "Aguardando conexao..." placeholder (handoff point for future WebRTC feature).
3. **Given** mario sees an action request, **When** mario clicks Reject, **Then** the request is cancelled and rodrigo sees "mario recusou a chamada de audio".
4. **Given** the browser does not support `getUserMedia`, **When** the lobby loads, **Then** the "Chamada de Audio" and "Chamada de Video" buttons are disabled with a tooltip explaining incompatibility.
5. **Given** the browser supports no WebRTC capabilities at all, **When** the lobby loads, **Then** all action buttons are disabled with a message explaining browser incompatibility.
6. **Given** both peers click different action buttons simultaneously, **When** both requests arrive, **Then** the first request takes priority and the second is queued.
7. **Given** mario accepts a call request, **When** the browser prompts for microphone access and mario denies permission, **Then** a friendly error is shown with a retry option and the call does not proceed.

---

### User Story 4 - Close Session and Cleanup (Priority: P4)

Either peer can end the P2P session by clicking "Encerrar Sessao" in the lobby. The session is also closed automatically when a peer closes their browser tab or navigates away. The remaining peer is notified and redirected to the main chat with a system message "Sessao P2P encerrada". The session is marked as closed in the database with the appropriate reason.

**Why this priority**: Graceful session teardown prevents orphaned sessions and ensures a clean user experience when leaving.

**Independent Test**: Can be tested by having one peer click the close button and verifying the other peer is redirected with a notification.

**Acceptance Scenarios**:

1. **Given** both peers are in the lobby, **When** rodrigo clicks "Encerrar Sessao", **Then** both peers are redirected to the main chat, the session is closed in the database, and both see a system message "Sessao P2P encerrada".
2. **Given** both peers are in the lobby, **When** rodrigo closes the browser tab, **Then** mario sees a notification that rodrigo left, and the session is closed after a brief grace period.
3. **Given** both peers are in the lobby, **When** rodrigo navigates to a different URL, **Then** the `beforeunload` event and server-side `terminate/2` callback trigger session cleanup.
4. **Given** a session is in the lobby state, **When** both peers are idle for 15 minutes, **Then** the session expires and both peers are redirected with a timeout message.

---

### User Story 5 - Slash Commands for Specific Actions (Priority: P5)

Users can use `/call <nick>` and `/sendfile <nick>` as shortcuts that create a P2P session and immediately request the specific action type. The `/call` command creates a session of type "audio_call" and `/sendfile` creates a session of type "file_transfer". These commands follow the same invitation flow as `/p2p` but pre-select the action type, so when both peers are in the lobby the action request is automatically presented.

**Why this priority**: Convenience shortcuts that build on the core P2P flow. Not essential for MVP but improve discoverability and workflow.

**Independent Test**: Can be tested by typing `/call mario` and verifying a session is created with the audio_call type and the action request is auto-presented in the lobby.

**Acceptance Scenarios**:

1. **Given** a registered user, **When** they type `/call mario`, **Then** a P2P session is created with session_type "audio_call", a message appears in the PM between the two users specifying it's for an audio call with the lobby link, and mario receives a toast notification.
2. **Given** a registered user, **When** they type `/sendfile mario`, **Then** a P2P session is created with session_type "file_transfer", a message appears in the PM between the two users specifying it's for a file transfer with the lobby link, and mario receives a toast notification.
3. **Given** mario accepts a `/call` invitation, **When** both peers are in the lobby, **Then** the audio call action request is automatically presented to mario for bilateral consent.

---

### Edge Cases

- **Unauthorized access**: A user who is neither creator nor peer navigates to `/p2p/:token` — system returns 404.
- **Expired token**: User navigates to a session with an expired or invalid token — redirected to main chat with error flash.
- **Guest access attempt**: A guest (non-registered) user attempts to access `/p2p/:token` — redirected with "registered users only" message.
- **Self-invite**: User types `/p2p <own_nick>` — system returns error "You cannot start a P2P session with yourself".
- **Duplicate session**: User tries to create a session with someone they already have an active session with — system returns error about existing active session.
- **Peer offline during lobby**: One peer disconnects while both are in the lobby — remaining peer sees a presence change and a system message. Session remains open for a grace period.
- **Simultaneous action requests**: Both peers click action buttons at nearly the same time — first request takes priority, second is queued until the first is resolved.
- **Permission denied**: Browser denies microphone/camera permission after bilateral consent — friendly error with retry option, session returns to lobby state.
- **File picker cancelled**: User cancels the file picker dialog — no error, lobby returns to normal state.
- **Session expires in lobby**: 15-minute inactivity timeout triggers while peers are in the lobby — both redirected with timeout message.
- **Blocked user**: User tries `/p2p` with someone who has blocked them (or vice versa) — generic error without revealing the block.
- **Rate limiting**: User creates too many sessions in a short period — rate limit error from existing P2P policy enforcement.
- **Action request timeout**: Peer doesn't respond to an action request within 60 seconds — request expires with "Pedido expirou", lobby returns to normal state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `/p2p <nickname>` command that creates a P2P session and delivers the invitation via private chat message and toast notification.
- **FR-002**: System MUST provide a `/call <nickname>` command that creates a P2P session with type "audio_call" and delivers the invitation via private chat message and toast notification.
- **FR-003**: System MUST provide a `/sendfile <nickname>` command that creates a P2P session with type "file_transfer" and delivers the invitation via private chat message and toast notification.
- **FR-004**: System MUST send the invitation as a **system-generated PM from the initiator** with a clickable lobby link in the private chat between initiator and peer. The message uses the existing PM infrastructure (authored as the initiator) but renders with invitation styling/card format. This message MUST be visible to both users in their shared PM history.
- **FR-005**: System MUST deliver a **toast notification** to the peer with three action buttons: Aceitar (accept — navigates to lobby), Recusar (reject — closes session), and Ignorar (dismiss — session expires naturally).
- **FR-006**: System MUST provide a dedicated lobby page at `/p2p/:token` accessible only to the session's creator and peer.
- **FR-007**: System MUST reject access to the lobby for guests, unauthorized users, and invalid/expired tokens.
- **FR-008**: System MUST display both peers' nicknames and real-time presence indicators (online/offline) in the lobby.
- **FR-009**: System MUST support ephemeral chat in the lobby — messages exchanged in real-time but not persisted to the database.
- **FR-010**: System MUST display three action buttons in the lobby: "Enviar Arquivo", "Chamada de Audio", and "Chamada de Video".
- **FR-011**: System MUST implement bilateral consent for all actions — the requesting peer's action MUST be explicitly accepted by the other peer before proceeding.
- **FR-012**: System MUST detect browser capabilities (WebRTC support, `getUserMedia`) asynchronously after lobby mount without blocking the initial render.
- **FR-013**: System MUST disable action buttons for unsupported browser capabilities and display explanatory tooltips.
- **FR-014**: System MUST request browser permissions (microphone, camera) only after bilateral consent is established.
- **FR-015**: System MUST handle session close via explicit user action ("Encerrar Sessao" button), browser tab close (`beforeunload`), and navigation away (`terminate/2` callback).
- **FR-016**: System MUST redirect the remaining peer to the main chat with a system message when the session is closed by any means.
- **FR-017**: System MUST notify the initiator when their invitation is rejected by sending a message in the private chat (PM) indicating the peer declined (e.g., "mario recusou o convite P2P").
- **FR-018**: System MUST handle permission denial gracefully with a user-friendly error and retry option, without proceeding with the action.
- **FR-019**: Command handlers MUST delegate all business logic to the P2P domain context — no business logic in handlers.
- **FR-020**: The P2PSessionLive MUST delegate all business logic to the P2P domain context — no business logic in the LiveView.
- **FR-021**: The lobby UI MUST follow 98.css Windows 98 aesthetic with dark theme support, consistent with the rest of the application.
- **FR-022**: The PM invitation message MUST clearly indicate the session type (generic P2P, audio call, or file transfer) and include the clickable lobby link.
- **FR-023**: Action requests MUST expire after 60 seconds if the peer does not respond. Upon expiry, the requesting peer sees "Pedido expirou" and the lobby returns to its normal state, allowing either peer to initiate a new request.

### Key Entities

- **P2P Session** (existing): Token-identified session connecting two peers. Has status (pending/lobby/connecting/active/closed/expired/failed), session type (generic/file_transfer/audio_call/video_call), creator and peer references, metadata, and timestamps.
- **Lobby Chat Message** (ephemeral): A message exchanged between peers in the lobby. Contains sender nickname, content, and timestamp. Lives only in session process memory — never persisted.
- **Action Request** (ephemeral): A request from one peer to perform an action (file transfer, audio call, video call). Contains requester, action type, and status (pending/accepted/rejected). Lives only in session process memory.
- **Invitation (dual-channel)**: Delivered through two channels: (1) a **PM message** in the private chat between initiator and peer, containing the lobby link and session type — persisted in chat history, and (2) a **toast notification** to the peer for immediate attention, with Aceitar/Recusar/Ignorar action buttons. Both reference the same session token.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can initiate a P2P session via `/p2p <nick>` and see a lobby link within 2 seconds of command execution.
- **SC-002**: Both peers can join the lobby and see each other's presence indicators update within 1 second of arrival.
- **SC-003**: Ephemeral chat messages in the lobby are delivered to the other peer within 500 milliseconds.
- **SC-004**: Action consent requests (accept/reject) are delivered and displayed to the other peer within 1 second.
- **SC-005**: Session cleanup (via close button, tab close, or navigation) completes within 3 seconds, with the remaining peer redirected and notified.
- **SC-006**: Browser capability detection completes within 2 seconds of lobby mount without blocking the initial render.
- **SC-007**: 100% of unauthorized access attempts (wrong user, guest, expired token) are rejected without exposing session details.
- **SC-008**: Invitation notifications are delivered to the peer within 1 second of session creation.

## Clarifications

### Session 2026-02-16

- Q: How should the PM invitation message be authored? → A: System-generated PM from the initiator — uses existing PM infrastructure, message appears as if the initiator sent it but with invitation styling/card format (clickable lobby link, session type indicator).
- Q: What should the lobby show after bilateral consent + permission grant, given WebRTC is out of scope? → A: Session transitions to "connecting" state and lobby shows an "Aguardando conexao..." placeholder, establishing the state machine boundary as a clean handoff point for the future WebRTC feature.
- Q: Should action requests (e.g., audio call) have their own timeout if the peer doesn't respond? → A: 60-second timeout. Request expires with "Pedido expirou" message and lobby returns to normal, allowing either peer to try again.

## Assumptions

- The existing P2P bounded context (feature 034) is fully functional: SessionServer, Service, Policy, SessionToken, Queries, CleanupTask, Registry, and Supervisor are all operational.
- The notification system (feature 032) supports delivering notifications with interactive action buttons (Aceitar/Recusar/Ignorar) — if not, the notification will include a clickable link instead and reject/ignore will be handled via separate UI.
- PubSub topics `"p2p:#{token}"` and `"user:#{nickname}"` are available for real-time communication.
- The existing rate limiting in P2P Policy (5 sessions/10 min) is sufficient and does not need changes.
- Browser capability detection uses standard Web APIs (`navigator.mediaDevices`, `RTCPeerConnection`) and does not require polyfills.
- The grace period for peer disconnection in the lobby is handled by the existing SessionServer timeout mechanism (15-minute lobby timeout).

## Scope

**In scope**:
- Router with `/p2p/:token` route in authenticated pipeline
- `P2PSessionLive` LiveView with mount, authentication, and PubSub subscription
- `/p2p`, `/call`, `/sendfile` command handlers following Handler behaviour
- Invitation delivery via dual channel: PM message with lobby link (persisted in chat) + toast notification with accept/reject/ignore actions
- Ephemeral lobby chat (in-process only, not persisted)
- 98.css lobby layout with Windows 98 aesthetic and dark theme
- Peer presence indicators (online/offline)
- Bilateral consent UI for action requests (request/accept/reject)
- Browser capability detection via JS hook (async, non-blocking)
- Browser permission requests (after bilateral consent only)
- Session close with redirect (explicit button, `beforeunload`, `terminate/2`)
- CSS files: `p2p-session.css`, `p2p-lobby.css`

**Out of scope**:
- WebRTC signaling (SDP offer/answer, ICE candidate exchange)
- File transfer protocol (chunked transfer, progress, integrity verification)
- Media streams (audio/video capture, codec negotiation, adaptive quality)
- TURN/STUN server credentials and configuration
- Help documentation (will be a separate feature)
