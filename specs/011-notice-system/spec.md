# Feature Specification: Notice System

**Feature Branch**: `011-notice-system`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Notices for RetroHexChat — lightweight notification-style messages with /notice command, distinct visual rendering, and configurable routing"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a Notice to a User (Priority: P1)

A user wants to quietly inform another user about something without opening a full PM conversation window. They type `/notice Alice hey, check #project when you have a moment`. Alice sees the notice displayed in her currently active window with distinctive formatting — a `-UserNick-` prefix (instead of the usual `<UserNick>` for regular messages) and a unique color that distinguishes it from normal chat. No PM window is created on either side. No notification sound is played. No treebar entry is added.

**Why this priority**: This is the core use case for notices. Without user-to-user notice delivery and distinct rendering, the feature has no value.

**Independent Test**: Can be fully tested by having two connected users exchange notices and verifying delivery, formatting, and that no PM windows or sounds are triggered.

**Acceptance Scenarios**:

1. **Given** user "Bob" is connected and user "Alice" is connected, **When** Bob types `/notice Alice hey, check #project`, **Then** Alice sees `-Bob- hey, check #project` in her active window with notice-specific styling, and no PM window is created for either user.
2. **Given** user "Bob" is connected, **When** Bob types `/notice Alice hey` and Alice is not connected, **Then** Bob sees an error message "User not found: Alice".
3. **Given** user "Bob" is connected, **When** Bob types `/notice` with no arguments, **Then** Bob sees a usage hint showing the correct syntax: `/notice <target> <message>`.
4. **Given** user "Bob" is connected, **When** Bob types `/notice Alice` with no message text, **Then** Bob sees an error indicating that a message is required.

---

### User Story 2 - Send a Notice to a Channel (Priority: P1)

A channel member wants to make a lightweight announcement to all members of a channel. They type `/notice #elixir Server maintenance in 30 minutes`. All members of `#elixir` see the notice in the channel window with the distinct notice formatting (`-UserNick-` prefix and notice color).

**Why this priority**: Channel notices are equally important to user notices — they enable announcements and service messages, which are a fundamental IRC message type.

**Independent Test**: Can be fully tested by having a user send a notice to a channel and verifying all members see it with correct formatting, while non-members are rejected.

**Acceptance Scenarios**:

1. **Given** user "Bob" is a member of `#elixir`, **When** Bob types `/notice #elixir Server maintenance in 30 minutes`, **Then** all members of `#elixir` see `-Bob- Server maintenance in 30 minutes` in the `#elixir` channel window with notice-specific styling.
2. **Given** user "Bob" is NOT a member of `#elixir`, **When** Bob types `/notice #elixir hello`, **Then** Bob sees an error message "You must be a member of #elixir to send notices there".
3. **Given** user "Bob" is a member of `#elixir` and the channel has 5 members, **When** Bob sends a channel notice, **Then** all 5 members (including Bob) see the notice in the `#elixir` window.

---

### User Story 3 - Notice Routing Preferences (Priority: P2)

A user wants to control where incoming notices appear. They can configure their notice routing preference to one of three options:

- **Active window** (default): Notices appear in whatever window/tab the user currently has focused.
- **Status window**: Notices appear in the Status tab. If no Status tab exists, the system falls back to the active window.
- **Sender's PM window**: Notices appear in the sender's PM window if one is already open. If no PM window exists for the sender, the system falls back to the active window. This option must NOT create a new PM window.

The user sets their preference using `/notice_routing <active|status|sender>`.

**Why this priority**: Routing is important for user experience but the feature works without it (using the default "active window" routing). This can be layered on after core notice delivery is working.

**Independent Test**: Can be fully tested by changing routing preference and verifying notices appear in the correct location for each routing mode.

**Acceptance Scenarios**:

1. **Given** user has routing set to "active" (default), **When** they receive a notice, **Then** the notice appears in their currently active window (channel or PM tab).
2. **Given** user has routing set to "status", **When** they receive a notice and the Status tab exists, **Then** the notice appears in the Status tab.
3. **Given** user has routing set to "status", **When** they receive a notice and no Status tab is open, **Then** the notice falls back to appearing in the active window.
4. **Given** user has routing set to "sender" and a PM window with the sender is already open, **When** they receive a notice from that sender, **Then** the notice appears in the sender's PM window.
5. **Given** user has routing set to "sender" and NO PM window with the sender exists, **When** they receive a notice, **Then** the notice falls back to appearing in the active window (no new PM window is created).
6. **Given** user types `/notice_routing` with no arguments, **Then** the system displays the current routing preference.
7. **Given** user types `/notice_routing invalid`, **Then** the system shows an error with valid options: `active`, `status`, `sender`.

---

### Edge Cases

- **Self-notice**: A user sends `/notice OwnNickname message` — the notice is delivered to their own active window (same as any other notice delivery).
- **Notice to service bots**: Notices from NickServ, ChanServ, or other service bots always display with notice formatting (`-ServiceNick-` prefix), regardless of the user's routing preference.
- **Notice during tab switch**: If a user switches tabs while a notice is in flight, the notice appears based on the active window at the time of delivery, not at the time of sending.
- **Empty channel notice**: If a channel has only the sender as a member, the notice is still delivered (to the sender only).
- **Rate limiting**: Notices are subject to the existing rate-limiting system. No special rate-limit rules are needed.
- **Ignored sender**: If the receiver has ignored the sender via the Ignore System, the notice is silently dropped — consistent with how regular messages from ignored users are handled.
- **Text formatting**: Notices support existing text formatting (bold, italic, colors, etc.) — they use the same rendering pipeline as regular messages.
- **Guest users**: Guest (unregistered) users can send and receive notices. Routing preference is stored in-memory in the Session struct and defaults to "active".

## Clarifications

### Session 2026-02-12

- Q: Should channel notices follow the sender's routing preference, or always appear in the channel window? → A: Channel notices always appear in the channel window for all members (including the sender). Routing preferences only apply to user-targeted notices.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support a `/notice <target> <message>` command where `<target>` is either a user nickname or a channel name (prefixed with `#`).
- **FR-002**: System MUST deliver user-targeted notices to the recipient via PubSub on the user's personal topic, without creating a PM conversation or treebar entry.
- **FR-003**: System MUST deliver channel-targeted notices to all channel members (including the sender) via the channel topic, with the notice always displayed in the channel window regardless of any member's routing preference.
- **FR-004**: System MUST render notices with distinct formatting: the author is displayed with `-AuthorNick-` delimiters (as opposed to `<AuthorNick>` for regular messages) and a distinct CSS color class.
- **FR-005**: System MUST reject notices sent to non-existent users with a "User not found" error shown to the sender.
- **FR-006**: System MUST reject notices sent to channels where the sender is not a member, with an appropriate error shown to the sender.
- **FR-007**: System MUST NOT create PM windows, query windows, or treebar entries when a notice is received.
- **FR-008**: System MUST NOT trigger notification sounds or highlight processing when a notice is received.
- **FR-009**: System MUST NOT send automatic replies to received notices (preventing infinite bot loops).
- **FR-010**: System MUST support a `/notice_routing <active|status|sender>` command to configure where incoming user-targeted notices are displayed. Channel notices are exempt from routing and always appear in the channel window.
- **FR-011**: System MUST persist the notice routing preference for registered users across sessions.
- **FR-012**: System MUST default the notice routing preference to "active" (current active window) for all users.
- **FR-013**: System MUST respect the Ignore System — notices from ignored users are silently dropped.
- **FR-014**: System MUST support existing text formatting (bold, italic, colors) within notice message content.
- **FR-015**: System MUST include help topics for `/notice` and `/notice_routing` commands, and a "Notices" feature topic.

### Key Entities

- **Notice**: A transient message (not persisted to the database) with a sender, target (user or channel), content, and timestamp. Notices are delivered in real-time and are not stored in message history.
- **Notice Routing Preference**: A per-user setting (`active` | `status` | `sender`) that controls where incoming notices are displayed. Stored in-memory for guests and persisted for registered users.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can send a notice to another user or channel and the recipient sees the notice within 1 second of sending.
- **SC-002**: Notices are visually distinguishable from regular messages at a glance — users can immediately identify a notice by its `-Nick-` prefix and distinct color.
- **SC-003**: No PM windows or treebar entries are created by notice delivery under any circumstance.
- **SC-004**: No notification sounds are triggered by notice delivery under any circumstance.
- **SC-005**: Users can change their notice routing preference and the change takes effect immediately for subsequent notices.
- **SC-006**: 100% of notices from ignored users are silently dropped without any indication to the sender.
- **SC-007**: The system correctly handles all three routing modes (active, status, sender) with proper fallback behavior when the preferred target is unavailable.
