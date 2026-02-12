# Feature Specification: User Information

**Feature Branch**: `016-user-information`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "User Information for RetroHexChat — expanded /whois output (User Central), /whowas command, /bio command, idle time tracking, shared channels display."

## Clarifications

### Session 2026-02-12

- Q: Should /whois output remain as text in the chat stream or become a windowed dialog? → A: Text output in chat stream (like current /whois), enhanced with new fields.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Expanded /whois Output (Priority: P1)

A user types `/whois Alice` and sees comprehensive information printed as text messages in the chat stream. Beyond the existing basic info (nickname, channels, away status), the output now includes: channels the querying user shares with Alice, Alice's online time for the current session, her idle time (e.g., "idle for 15 minutes"), whether she is registered with NickServ, her away message (if set), and her profile bio (if set). The `/whois` command can also be triggered by double-clicking a nickname in the nicklist.

**Why this priority**: The /whois command already exists but is minimal. Expanding its output delivers the most visible user value and serves as the display surface for all other user stories (bio, idle time, etc.). Without this, the other features have nowhere to be shown.

**Independent Test**: Type `/whois <nickname>` for an online user and verify the chat stream shows shared channels, online time, idle time, registration status, away message, and bio. Double-click a nickname in the nicklist and verify the same output appears.

**Acceptance Scenarios**:

1. **Given** a user is connected and Alice is online, **When** the user types `/whois Alice`, **Then** the chat stream shows Alice's nickname, shared channels, online time, idle time, registration status, and away message (if set) as formatted text messages.
2. **Given** a user is in a channel with Alice visible in the nicklist, **When** the user double-clicks Alice's nickname, **Then** the same /whois output appears in the chat stream.
3. **Given** a user types `/whois` on themselves, **When** the output is displayed, **Then** it shows their own profile information including their bio and all relevant fields.
4. **Given** Alice has been idle for 15 minutes, **When** the user views Alice's /whois, **Then** the idle time line shows "idle for 15 minutes".
5. **Given** Alice is registered with NickServ, **When** the user views Alice's /whois, **Then** the registration status shows "Registered".
6. **Given** Alice has no bio set, **When** the user views Alice's /whois, **Then** no bio line is displayed (no empty field).

---

### User Story 2 - Idle Time Tracking (Priority: P2)

The system tracks how long each connected user has been idle (time since their last activity). Idle time resets on any user activity: sending channel messages, private messages, or commands. The idle time is displayed in the /whois output.

**Why this priority**: Idle time is essential context shown in /whois output. Without tracking it, the expanded /whois would be missing a key piece of information that users expect from IRC clients.

**Independent Test**: Connect a user, wait without sending any messages, then query `/whois` on that user from another session and verify idle time reflects the elapsed time. Send a message and verify idle time resets to zero.

**Acceptance Scenarios**:

1. **Given** a user has been connected for 10 minutes without any activity, **When** another user types `/whois` on them, **Then** the idle time shows approximately "10 minutes".
2. **Given** a user has been idle for 5 minutes, **When** they send a channel message, **Then** their idle time resets to 0.
3. **Given** a user has been idle for 5 minutes, **When** they send a private message, **Then** their idle time resets to 0.
4. **Given** a user has been idle for 5 minutes, **When** they execute any command (e.g., `/away`, `/join`), **Then** their idle time resets to 0.

---

### User Story 3 - User Bio / Profile (Priority: P3)

Users can set a short text bio (maximum 200 characters) that appears in their /whois output. Bios are set via the `/bio` command. Bios persist across sessions for registered users. Guest users can set a bio that lasts for the current session only.

**Why this priority**: The bio adds personality and identity to the chat experience. It depends on the expanded /whois output (US1) to be displayed but can be implemented and tested independently.

**Independent Test**: Set a bio with `/bio Elixir enthusiast`, then have another user `/whois` you and verify the bio appears. Disconnect, reconnect, identify, and verify the bio persists.

**Acceptance Scenarios**:

1. **Given** a user is connected, **When** they type `/bio Elixir enthusiast from Brazil`, **Then** a confirmation message is shown and the bio is saved.
2. **Given** a user has set a bio, **When** another user types `/whois` on them, **Then** the bio appears in the /whois output.
3. **Given** a user has no bio set, **When** another user types `/whois` on them, **Then** the bio line is not displayed.
4. **Given** a user types `/bio` with text longer than 200 characters, **When** the bio is saved, **Then** it is truncated to 200 characters and a warning is shown to the user.
5. **Given** a registered user has a bio, **When** they disconnect and reconnect and identify with NickServ, **Then** the bio is restored.
6. **Given** a user types `/bio` with no arguments, **When** the command is processed, **Then** the current bio is displayed, or a message says no bio is set.
7. **Given** a user wants to clear their bio, **When** they type `/bio clear`, **Then** the bio is removed and a confirmation is shown.

---

### User Story 4 - /whowas Command (Priority: P4)

Users can look up information about recently disconnected users via `/whowas <nickname>`. The system caches disconnection information (last seen time, channels at disconnect, quit message) for a limited time (1 hour) after a user disconnects. Output is displayed as text in the chat stream.

**Why this priority**: /whowas adds value for users who just missed someone but is less frequently used than the core /whois features. It requires a separate caching system for disconnected user data.

**Independent Test**: Connect as Bob, join some channels, disconnect. From another user, type `/whowas Bob` within 1 hour and verify last seen time, channels, and quit message are shown. Wait beyond 1 hour and verify the data has expired.

**Acceptance Scenarios**:

1. **Given** Bob was online in #elixir and #lobby and disconnected 10 minutes ago with quit message "See you tomorrow!", **When** a user types `/whowas Bob`, **Then** the output shows "Bob was last seen 10 minutes ago, was in channels #elixir and #lobby, quit with message: See you tomorrow!".
2. **Given** Bob has never been online (or data has expired), **When** a user types `/whowas Bob`, **Then** the output shows "No whowas information available for Bob".
3. **Given** Bob disconnected 61 minutes ago, **When** a user types `/whowas Bob`, **Then** the cached data has expired and the output shows "No whowas information available for Bob".
4. **Given** a user types `/whowas` with no arguments, **When** the command is processed, **Then** a usage message is shown: "Usage: /whowas <nickname>".

---

### Edge Cases

- **Duplicate nicknames in /whowas cache**: If a user connects, disconnects, connects again, and disconnects again, only the most recent disconnection data is retained.
- **Self /whois**: `/whois <own nickname>` works and shows the user's own full profile including bio.
- **Bio with special characters**: Bios containing IRC formatting codes (bold, color, etc.) are stored and displayed with formatting preserved.
- **Idle time precision**: Idle time is displayed in human-friendly format: "less than a minute", "2 minutes", "1 hour 30 minutes", etc.
- **Online time**: Tracked from the moment the user's chat session begins, displayed as duration in the /whois output.
- **Whowas cache memory**: The cache does not grow unbounded; entries expire after 1 hour and the cache has a maximum size (1000 entries) to prevent memory issues.
- **Bio length enforcement**: Maximum 200 Unicode graphemes, not bytes. Truncation occurs at the grapheme boundary.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display expanded /whois information as text messages in the chat stream showing: nickname, shared channels with the querying user, online time, idle time, registration status, away message (if set), and bio (if set).
- **FR-002**: System MUST allow triggering /whois by double-clicking a nickname in the nicklist (outputs text to chat stream, same as typing the command).
- **FR-003**: System MUST track idle time per connected user, resetting on any activity (channel messages, private messages, commands).
- **FR-004**: System MUST display idle time in human-friendly format (e.g., "idle for 15 minutes").
- **FR-005**: System MUST allow users to set a bio via `/bio <text>` command (maximum 200 characters).
- **FR-006**: System MUST truncate bios exceeding 200 characters and show a warning to the user.
- **FR-007**: System MUST allow users to view their current bio via `/bio` (no arguments).
- **FR-008**: System MUST allow users to clear their bio via `/bio clear`.
- **FR-009**: System MUST persist bios across sessions for registered users (loaded on NickServ identification).
- **FR-010**: System MUST NOT display the bio line in /whois output when no bio is set.
- **FR-011**: System MUST cache disconnection information (/whowas data) including: last seen time, channels at disconnect, and quit message.
- **FR-012**: System MUST expire /whowas cache entries after 1 hour.
- **FR-013**: System MUST limit the /whowas cache to a maximum of 1000 entries to prevent unbounded memory growth.
- **FR-014**: System MUST display /whowas information as text in the chat stream including last seen time, channels, and quit message when available.
- **FR-015**: System MUST show "No whowas information available for <nickname>" when no cached data exists.
- **FR-016**: System MUST display online time (session duration) in the /whois output.
- **FR-017**: System MUST display NickServ registration status in the /whois output.
- **FR-018**: System MUST support `/whois` on oneself, showing the user's own full profile.

### Key Entities

- **User Profile**: Represents a user's self-set information — primarily their bio text (max 200 characters). Belongs to a registered nickname. Created/updated by the user, displayed in /whois output.
- **Whowas Entry**: Cached record of a recently disconnected user — nickname, last seen timestamp, list of channels at disconnect, quit message. Expires after 1 hour. Maximum 1000 entries cached.
- **Idle Tracker**: Per-user timer tracking time since last activity. Resets on any message or command sent. Used to display idle time in /whois.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can view comprehensive information about any online user (shared channels, idle time, online time, registration status, bio) in under 2 seconds via `/whois` or double-click.
- **SC-002**: Users can set, view, and clear their bio in a single command each, with immediate effect visible in subsequent /whois queries.
- **SC-003**: Idle time displayed in /whois reflects actual user inactivity with less than 30 seconds of drift.
- **SC-004**: Users can look up recently disconnected users via `/whowas` and see accurate last-seen information for up to 1 hour after disconnection.
- **SC-005**: 100% of /whowas cache entries are automatically cleaned up after 1 hour, with no manual intervention required.
- **SC-006**: Bio persistence works correctly — registered users who disconnect and reconnect retain their bio after NickServ identification.

## Assumptions

- The existing `/whois` command handler will be enhanced in place. Output remains as text messages in the chat stream (not a windowed dialog).
- Online time is tracked from the moment the user's chat session begins, not from NickServ identification.
- The /whowas cache is in-memory only; it does not survive application restarts (acceptable for ephemeral "recently seen" data).
- Idle time is tracked at the session level (per connection), not persisted to the database.
- Double-clicking a nickname in the nicklist triggers the `/whois` command for that user (text output in chat stream).
- Bio maximum length of 200 characters refers to Unicode graphemes, not bytes.

## Scope

### In Scope

- Expanded /whois text output with shared channels, online time, idle time, registration status, bio
- `/whowas` command with time-limited cache of disconnected user data
- `/bio` command (set, view, clear) and bio persistence for registered users
- Idle time tracking per connected user
- Double-click nicklist to trigger /whois
- Help documentation for new commands and features

### Out of Scope

- Profile pictures or avatars
- Detailed activity history or logs
- User blocking (separate feature)
- Extended whowas history beyond 1 hour
- Profile edit dialog (bio is set via `/bio` command; a dialog may be added in a future iteration)
- Windowed /whois dialog (output is text in chat stream)
