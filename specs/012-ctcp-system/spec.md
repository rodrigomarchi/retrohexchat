# Feature Specification: CTCP (Client-to-Client Protocol)

**Feature Branch**: `012-ctcp-system`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "CTCP (Client-to-Client Protocol) for RetroHexChat — simulated CTCP commands (PING, VERSION, TIME, FINGER) for querying user information and measuring latency."

## Clarifications

### Session 2026-02-12

- Q: CTCP TIME — server UTC vs browser local time? → A: Server UTC time (server-side `DateTime.utc_now()`, no browser JS hooks needed)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send CTCP PING and Measure Latency (Priority: P1)

A user wants to measure the round-trip latency to another connected user. They type `/ctcp Alice ping`. The system sends a CTCP PING request to Alice's client, which automatically echoes the ping back with a timestamp. The sender sees a system message: `* CTCP PING reply from Alice: 45ms`. Alice sees a brief system message: `* CTCP PING request from Bob`. The entire exchange happens automatically — Alice does not need to take any action.

If the user sends `/ctcp Alice ping` and Alice is not online, the sender sees: `* User 'Alice' not found`. If Alice has disabled CTCP responses, the sender sees `* No CTCP reply from Alice (timed out)` after 10 seconds.

Self-CTCP is allowed: `/ctcp MyNick ping` returns an instant `0ms` response.

**Why this priority**: PING is the most commonly used CTCP command in IRC culture and provides the core request/reply mechanism that all other CTCP types build upon. It validates the entire round-trip message flow.

**Independent Test**: Can be fully tested by two connected users exchanging CTCP PING requests and verifying the latency display. Delivers immediate value by enabling users to measure connection responsiveness.

**Acceptance Scenarios**:

1. **Given** two connected users (Bob and Alice), **When** Bob types `/ctcp Alice ping`, **Then** Alice's client automatically replies, and Bob sees `* CTCP PING reply from Alice: <N>ms` where N is the round-trip time in milliseconds.
2. **Given** a connected user Bob, **When** Bob types `/ctcp OfflineUser ping`, **Then** Bob sees `* User 'OfflineUser' not found`.
3. **Given** two connected users where Alice has disabled CTCP responses, **When** Bob types `/ctcp Alice ping`, **Then** Bob sees `* No CTCP reply from Alice (timed out)` after 10 seconds.
4. **Given** a connected user Bob, **When** Bob types `/ctcp Bob ping`, **Then** Bob sees `* CTCP PING reply from Bob: 0ms` (self-ping returns instantly).
5. **Given** two connected users, **When** Bob sends `/ctcp Alice ping`, **Then** Alice sees `* CTCP PING request from Bob` as a system message.

---

### User Story 2 - Query VERSION, TIME, and FINGER (Priority: P1)

A user wants to query information about another user's client. They type `/ctcp Alice version` and see: `* CTCP VERSION reply from Alice: RetroHexChat v1.0`. They try `/ctcp Alice time` and see the server's UTC time: `* CTCP TIME reply from Alice: 2026-02-12 10:30:00 UTC`. They type `/ctcp Alice finger` and see Alice's profile text: `* CTCP FINGER reply from Alice: Alice - idle 5 minutes`.

Each CTCP type returns a different kind of information:
- **VERSION**: The client name and version string (default: "RetroHexChat v1.0").
- **TIME**: The server's current UTC date and time.
- **FINGER**: A configurable profile text (default: shows nickname and idle time since last message).

An invalid CTCP type shows an error: `/ctcp Alice unknown` results in `* Unknown CTCP type: unknown. Valid types: ping, version, time, finger`.

**Why this priority**: VERSION, TIME, and FINGER complete the standard CTCP command set. They reuse the same request/reply infrastructure as PING and are essential for feature parity with IRC expectations.

**Independent Test**: Can be tested by sending each CTCP type to an online user and verifying the correct reply format is displayed.

**Acceptance Scenarios**:

1. **Given** two connected users, **When** Bob types `/ctcp Alice version`, **Then** Bob sees `* CTCP VERSION reply from Alice: RetroHexChat v1.0` (or Alice's custom version string).
2. **Given** two connected users, **When** Bob types `/ctcp Alice time`, **Then** Bob sees `* CTCP TIME reply from Alice: <server UTC time>`.
3. **Given** two connected users, **When** Bob types `/ctcp Alice finger`, **Then** Bob sees `* CTCP FINGER reply from Alice: <Alice's finger text or default>`.
4. **Given** a connected user, **When** they type `/ctcp Alice unknown`, **Then** they see `* Unknown CTCP type: unknown. Valid types: ping, version, time, finger`.
5. **Given** two connected users, **When** Bob sends any CTCP request, **Then** Alice sees `* CTCP <TYPE> request from Bob` as a system message.

---

### User Story 3 - Customize CTCP Reply Settings (Priority: P2)

A user wants to customize what their CTCP replies contain, or disable CTCP responses entirely for privacy. They access a CTCP settings dialog (via the Tools menu or a command) where they can:

- **Enable/Disable CTCP responses**: A toggle to stop responding to all CTCP requests. When disabled, senders will see a timeout message.
- **Custom VERSION string**: Override the default "RetroHexChat v1.0" with a custom string (e.g., "MyCustomClient v2.0").
- **Custom FINGER text**: Override the default idle-time text with a custom profile message (e.g., "Alice - Elixir developer from Brazil").

Settings are persisted for registered (identified) users. Guest users can modify settings for their current session only.

The dialog follows the retro aesthetic consistent with other RetroHexChat dialogs.

**Why this priority**: Customization adds personality and privacy control but is not needed for the core CTCP functionality to work. Users can use CTCP with defaults before configuring custom replies.

**Independent Test**: Can be tested by opening the CTCP settings dialog, modifying reply strings, and verifying that subsequent CTCP replies reflect the customized values.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they open the CTCP settings dialog, **Then** they see toggles and text fields for configuring CTCP responses.
2. **Given** a user who has set a custom VERSION string "MyCoolClient v3.0", **When** another user sends `/ctcp <nick> version`, **Then** the reply shows "MyCoolClient v3.0".
3. **Given** a user who has disabled CTCP responses, **When** another user sends any CTCP request, **Then** no reply is sent and the sender sees a timeout message after 10 seconds.
4. **Given** a registered user who customizes CTCP settings, **When** they reconnect and identify, **Then** their custom settings are restored.
5. **Given** a guest user who customizes CTCP settings, **When** they disconnect, **Then** the settings are lost (session-only).

---

### Edge Cases

- **User not found**: Sending a CTCP request to a non-existent or offline user shows `* User '<target>' not found`.
- **CTCP to self**: `/ctcp <own-nick> <type>` works and returns an immediate response (useful for testing). PING shows 0ms; other types show the user's own configured values.
- **CTCP responses disabled**: When the target has disabled CTCP, the sender waits up to 10 seconds then sees a timeout message. No error is shown to the target.
- **Rate limiting**: A user cannot send more than 3 CTCP requests to the same target within a 30-second window. Exceeding this shows `* CTCP rate limit reached for <target>. Please wait before sending another request.`
- **Empty or missing arguments**: `/ctcp` with no arguments shows usage syntax. `/ctcp Alice` with no type shows usage syntax.
- **CTCP type case insensitivity**: `/ctcp Alice PING`, `/ctcp Alice ping`, and `/ctcp Alice Ping` all work identically.
- **Target disconnects during pending request**: If the target disconnects after a CTCP request is sent but before a reply arrives, the sender sees the timeout message after 10 seconds.
- **Very long custom strings**: Custom VERSION and FINGER strings are truncated to 200 characters maximum.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `/ctcp` command with syntax `/ctcp <target> <type>` supporting four CTCP types: `ping`, `version`, `time`, `finger`.
- **FR-002**: System MUST send CTCP requests as private messages between sender and target only — no channel visibility.
- **FR-003**: System MUST automatically generate replies to incoming CTCP requests without user intervention (unless CTCP is disabled).
- **FR-004**: CTCP PING MUST measure round-trip time between request and reply and display the result in milliseconds.
- **FR-005**: CTCP VERSION MUST return the client's version string (default: "RetroHexChat v1.0", customizable per user).
- **FR-006**: CTCP TIME MUST return the server's current UTC date and time.
- **FR-007**: CTCP FINGER MUST return the target user's configured profile text, or a default showing their nickname and idle time.
- **FR-008**: System MUST display incoming CTCP requests to the target as a system message: `* CTCP <TYPE> request from <sender>`.
- **FR-009**: System MUST display CTCP replies to the sender as a system message: `* CTCP <TYPE> reply from <target>: <value>`.
- **FR-010**: System MUST show `* User '<target>' not found` when the target is offline or does not exist.
- **FR-011**: System MUST implement a 10-second timeout for CTCP replies. If no reply is received, the sender sees `* No CTCP reply from <target> (timed out)`.
- **FR-012**: System MUST support self-CTCP (sending CTCP to own nickname) with immediate response and 0ms for PING.
- **FR-013**: System MUST rate-limit CTCP requests to a maximum of 3 requests per target per 30-second window. Exceeding this limit shows an informative message.
- **FR-014**: System MUST treat CTCP type names as case-insensitive.
- **FR-015**: CTCP exchanges MUST NOT create PM windows, treebar entries, notification sounds, or highlights.
- **FR-016**: CTCP replies MUST NOT trigger further automatic responses (prevents infinite loops).
- **FR-017**: System MUST provide a CTCP settings dialog accessible from the Tools menu for customizing responses.
- **FR-018**: System MUST allow users to enable or disable all CTCP responses via the settings dialog.
- **FR-019**: System MUST allow users to set a custom VERSION string (max 200 characters) via the settings dialog.
- **FR-020**: System MUST allow users to set a custom FINGER text (max 200 characters) via the settings dialog.
- **FR-021**: System MUST persist CTCP settings for registered (identified) users across sessions.
- **FR-022**: System MUST show usage syntax when `/ctcp` is invoked without sufficient arguments.
- **FR-023**: System MUST show an error listing valid types when an unknown CTCP type is specified.

### Key Entities

- **CTCP Request**: A message from sender to target specifying a CTCP type (ping, version, time, finger). Includes a timestamp for PING latency measurement.
- **CTCP Reply**: An automatic response from target to sender containing the requested information. Includes the original timestamp for PING round-trip calculation.
- **CTCP Settings**: Per-user configuration containing: responses enabled (boolean, default true), custom version string (string, default "RetroHexChat v1.0"), custom finger text (string, default null — uses auto-generated text).
- **CTCP Rate Limiter**: Per-sender-target pair tracker that enforces the 3-requests-per-30-seconds limit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can send a CTCP PING and see a latency measurement within 1 second (for online targets with CTCP enabled).
- **SC-002**: All four CTCP types (PING, VERSION, TIME, FINGER) return correctly formatted replies 100% of the time for online users with CTCP enabled.
- **SC-003**: CTCP timeout fires within 10-11 seconds when the target has disabled CTCP responses.
- **SC-004**: Rate limiting correctly blocks the 4th CTCP request to the same target within a 30-second window.
- **SC-005**: Custom CTCP reply strings (VERSION, FINGER) are reflected in replies within the same session after being changed.
- **SC-006**: Registered users' CTCP settings persist across disconnects and reconnects after identification.
- **SC-007**: Zero PM windows or treebar entries are created as a result of any CTCP exchange.
- **SC-008**: Self-CTCP (any type) returns immediately without waiting for timeout.

## Scope

### In Scope

- `/ctcp` command supporting PING, VERSION, TIME, FINGER
- Automatic, invisible CTCP reply handling
- CTCP reply customization (VERSION string, FINGER text, enable/disable toggle)
- CTCP settings dialog with retro aesthetic
- CTCP settings persistence for registered users
- Rate limiting (3 requests per target per 30 seconds)
- 10-second reply timeout
- Self-CTCP support

### Out of Scope

- CTCP flood protection beyond basic rate limiting (that is Cat N)
- Custom CTCP types beyond the four standard ones (ping, version, time, finger)
- CTCP ACTION (already implemented as `/me`)
- CTCP over real IRC protocol (RetroHexChat is web-only, CTCP is simulated)
- Notification sounds or highlights for CTCP events

## Assumptions

- All connected users are reachable via the same messaging infrastructure used for notices and PMs.
- "Idle time" for FINGER default text is calculated as time since the user's last sent message.
- The CTCP settings dialog is a new dialog opened from the Tools menu, following the same retro pattern as existing dialogs (Highlight Words, Ignore List, etc.).
- CTCP requests and replies use the same user-to-user messaging channel (not the channel broadcast system).
- The VERSION default string ("RetroHexChat v1.0") uses the application's current version if available.
- TIME returns the server's UTC time (simpler, consistent, no browser JS hooks needed).

## Dependencies

- Existing user-to-user PubSub messaging (`user:#{nickname}` topic) for request/reply delivery.
- Existing online user detection (via #lobby membership check).
- Existing Session struct for storing per-user CTCP settings in memory.
- Existing persistence patterns (Ecto schemas, registered_nicks FK) for storing CTCP settings.
- Existing retro dialog component patterns for the settings UI.
- Existing command Handler behaviour for the `/ctcp` command.
