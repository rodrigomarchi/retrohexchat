# Feature Specification: Special Messages

**Feature Branch**: `020-special-messages`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Special Messages for RetroHexChat — MOTD, channel welcome messages, wallops, and global announcements"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Message of the Day (MOTD) on Connect (Priority: P1)

A user connects to RetroHexChat. In the Status Window, they see a bordered, visually distinctive system message: the Message of the Day. The MOTD contains server rules, announcements, and useful information set by an administrator. It is displayed automatically once upon connection and can be re-read at any time using the `/motd` command.

An administrator sets or updates the MOTD using the `/setmotd` command. The MOTD persists across server restarts and is shown to all future connections. Clearing the MOTD with `/clearmotd` means new connections see no MOTD (not an error).

**Why this priority**: MOTD is the most fundamental server communication tool — it provides orientation for every connecting user and is present in virtually every IRC implementation. It delivers value to every single user on every connection.

**Independent Test**: Can be fully tested by setting a MOTD, connecting a user, and verifying the MOTD appears in the Status Window. Value is delivered immediately: users see server information on connect.

**Acceptance Scenarios**:

1. **Given** an administrator has set a MOTD, **When** a user connects to the server, **Then** the MOTD is displayed in the Status Window as a bordered, distinctive system message.
2. **Given** no MOTD has been set, **When** a user connects to the server, **Then** no MOTD is displayed and the connection proceeds normally.
3. **Given** a connected user, **When** they type `/motd`, **Then** the current MOTD is displayed in the Status Window (or a message indicating no MOTD is set).
4. **Given** an administrator, **When** they type `/setmotd <text>`, **Then** the MOTD is updated and all future connections see the new text.
5. **Given** an administrator, **When** they type `/clearmotd`, **Then** the MOTD is removed and future connections see no MOTD.
6. **Given** a non-administrator user, **When** they type `/setmotd` or `/clearmotd`, **Then** they receive a permission denied error.

---

### User Story 2 - Channel Welcome Message (Priority: P2)

A channel operator or founder sets a welcome message for their channel using the `/setwelcome` command. When any user subsequently joins that channel, they see the welcome message immediately after the join notification — as a system message visible only to the joining user. The welcome message is not shown to the user who set it (they already know the content).

**Why this priority**: Channel welcome messages provide immediate value to channel communities, giving newcomers context and guidance. This is the second-most impactful communication tool because it targets the moment users need orientation most — when they first enter a channel.

**Independent Test**: Can be fully tested by setting a welcome message on a channel, having another user join, and verifying they see the message. Tests the complete flow from operator configuration to newcomer experience.

**Acceptance Scenarios**:

1. **Given** a channel with a welcome message set, **When** a user joins the channel, **Then** they see the welcome message as a system message immediately after the join notification.
2. **Given** a channel with a welcome message, **When** the user who set the welcome message joins the channel, **Then** they do NOT see the welcome message.
3. **Given** a user is a channel owner or operator, **When** they type `/setwelcome <message>`, **Then** the welcome message is saved for that channel.
4. **Given** a user is a channel owner or operator, **When** they type `/clearwelcome`, **Then** the welcome message is removed from that channel.
5. **Given** a regular (non-operator) user, **When** they type `/setwelcome`, **Then** they receive a permission denied error.
6. **Given** a channel with no welcome message set, **When** a user joins, **Then** no welcome message is displayed and the join proceeds normally.
7. **Given** a user who already joined a channel during this session and the channel has a welcome message, **When** they part and rejoin the same channel within the same session, **Then** the welcome message is NOT shown again.

---

### User Story 3 - Wallops (Operator Broadcast) (Priority: P3)

A server operator needs to notify all other operators about an urgent matter. They type `/wallops <message>`. All users who have opted into wallops notifications (by enabling the `+w` user mode via `/umode +w`) see the wallops message in their Status Window, formatted as `[Wallops] SenderNick: <message>`.

**Why this priority**: Wallops provides essential operator-to-operator communication for server coordination. While it serves a narrower audience than MOTD or welcome messages, it fills a critical gap for operational communication.

**Independent Test**: Can be fully tested by having an operator send a wallops, verifying it reaches users with +w mode enabled, and confirming it does not reach users without +w mode.

**Acceptance Scenarios**:

1. **Given** a server operator, **When** they type `/wallops Server restart in 15 minutes`, **Then** the message is sent to all users who have `+w` mode enabled.
2. **Given** a user with `+w` mode enabled, **When** an operator sends a wallops, **Then** the user sees `[Wallops] OperatorNick: <message>` in their Status Window.
3. **Given** a user without `+w` mode enabled, **When** an operator sends a wallops, **Then** they do NOT see the wallops message.
4. **Given** a non-operator user, **When** they type `/wallops <message>`, **Then** they receive a permission denied error.
5. **Given** no users have `+w` mode enabled, **When** an operator sends a wallops, **Then** the command succeeds silently (no error, message sent to nobody).
6. **Given** a connected user, **When** they type `/umode +w`, **Then** they opt into receiving wallops notifications.
7. **Given** a user with `+w` mode enabled, **When** they type `/umode -w`, **Then** they opt out of wallops notifications.

---

### User Story 4 - Global Announcement (Priority: P4)

An administrator needs to reach every connected user urgently. They type `/announce <message>`. Every connected user sees a prominent, unmissable message in their currently active window, formatted as `[ANNOUNCEMENT] <message>` with distinctive styling (bold text, colored background). Global announcements bypass ignore lists and reach users regardless of their state (away, in moderated channels, etc.).

**Why this priority**: Global announcements are the nuclear option for server communication — used rarely but essential when needed. It ranks last because it requires the most privilege and has the narrowest use case (emergency/critical notices only), but its impact when used is the highest.

**Independent Test**: Can be fully tested by having an administrator send an announcement and verifying all connected users receive it in their active window with distinctive styling, including users with ignore lists and away status.

**Acceptance Scenarios**:

1. **Given** an administrator, **When** they type `/announce Server maintenance at 22:00 UTC`, **Then** the announcement is delivered to every connected user.
2. **Given** a connected user (in any state), **When** an administrator sends a global announcement, **Then** the user sees `[ANNOUNCEMENT] <message>` in their currently active window with bold text and colored background styling.
3. **Given** a user who has the sender on their ignore list, **When** an administrator sends a global announcement, **Then** the announcement is still displayed (bypasses ignore lists).
4. **Given** a non-administrator user, **When** they type `/announce <message>`, **Then** they receive a permission denied error.
5. **Given** a user who is away, **When** an administrator sends a global announcement, **Then** the announcement is still delivered and visible when they return.

---

### Edge Cases

- What happens when the MOTD text is very long (thousands of characters)? The MOTD is displayed in a scrollable container within the Status Window so users can read at their own pace without flooding the view.
- What happens when a channel welcome message contains special characters or formatting codes? The message is displayed as-is, preserving any text formatting supported by the chat system.
- What happens when an operator sends a wallops while they themselves have `+w` enabled? The operator also sees their own wallops message in their Status Window (consistent behavior).
- What happens when a user connects and the MOTD is updated while they are still reading it? The user sees the MOTD that was current at the time of their connection. They can use `/motd` to see the updated version.
- What happens when multiple administrators send announcements simultaneously? Each announcement is delivered independently; users see all announcements in chronological order.
- What happens when the `/setwelcome` message is empty? It is treated the same as `/clearwelcome` — the welcome message is cleared.

## Requirements *(mandatory)*

### Functional Requirements

**MOTD**:
- **FR-001**: System MUST allow administrators to set the MOTD text using the `/setmotd <text>` command.
- **FR-002**: System MUST allow administrators to clear the MOTD using the `/clearmotd` command.
- **FR-003**: System MUST display the current MOTD to users automatically upon connection, in the Status Window, with a bordered distinctive visual style.
- **FR-004**: System MUST provide the `/motd` command for any user to re-read the current MOTD at any time.
- **FR-005**: System MUST persist the MOTD across server restarts.
- **FR-006**: System MUST NOT display any MOTD message when no MOTD has been set (no error, no placeholder).
- **FR-007**: System MUST NOT block the connection flow while displaying the MOTD (display is informational only).

**Channel Welcome Messages**:
- **FR-008**: System MUST allow channel owners and operators to set a welcome message for their channel using `/setwelcome <message>`.
- **FR-009**: System MUST allow channel owners and operators to clear a channel's welcome message using `/clearwelcome`.
- **FR-010**: System MUST display the channel's welcome message to a user immediately after their join notification, as a system message visible only to the joining user.
- **FR-011**: System MUST NOT display the welcome message to the user who set it when they join the channel.
- **FR-012**: System MUST NOT display the welcome message on subsequent rejoins within the same session (only on first join per session).
- **FR-013**: System MUST persist channel welcome messages across server restarts.

**Wallops**:
- **FR-014**: System MUST provide the `/wallops <message>` command for server operators to broadcast messages to users with `+w` mode.
- **FR-015**: System MUST provide the `/umode +w` and `/umode -w` commands for users to opt in/out of wallops notifications.
- **FR-016**: System MUST display wallops messages in the recipient's Status Window, formatted as `[Wallops] SenderNick: <message>`.
- **FR-017**: System MUST reject `/wallops` commands from non-operator users with a permission denied error.
- **FR-018**: System MUST succeed silently when a wallops is sent but no users have `+w` mode enabled.

**Global Announcements**:
- **FR-019**: System MUST provide the `/announce <message>` command for administrators to send global announcements.
- **FR-020**: System MUST deliver global announcements to every connected user in their currently active window.
- **FR-021**: System MUST display announcements with distinctive styling: bold text and a colored background, formatted as `[ANNOUNCEMENT] <message>`.
- **FR-022**: System MUST NOT allow global announcements to be blocked by ignore lists — they bypass all ignore and filtering mechanisms.
- **FR-023**: System MUST deliver announcements to users in all states, including away users and users in moderated channels.
- **FR-024**: System MUST reject `/announce` commands from non-administrator users with a permission denied error.

**Permissions**:
- **FR-025**: System MUST restrict `/setmotd`, `/clearmotd`, and `/announce` to administrator users only.
- **FR-026**: System MUST restrict `/wallops` to server operator users only.
- **FR-027**: System MUST restrict `/setwelcome` and `/clearwelcome` to channel owners and operators of the respective channel.

### Key Entities

- **MOTD**: The server-wide Message of the Day. A single text value (potentially multi-line) that persists across restarts. Only one MOTD exists at a time; setting a new one replaces the old.
- **Channel Welcome Message**: A per-channel greeting message. Each channel may have at most one welcome message. Associated with the channel name. Persists across restarts.
- **Wallops Message**: A transient operator-to-operator broadcast. Not persisted — delivered in real time to eligible recipients and not stored.
- **Global Announcement**: A transient server-wide broadcast from an administrator. Not persisted — delivered in real time to all connected users and not stored.
- **User Mode (+w)**: A per-user toggle indicating whether the user wants to receive wallops notifications. Stored in the user's session state. Defaults to off.

## Assumptions

- **Administrator role**: The system has a concept of "administrator" users. Based on the existing codebase, this will leverage NickServ identification combined with an admin designation (assumed to be configurable). If no admin system currently exists, one will need to be introduced as part of this feature — a simple list of admin nicknames in application configuration.
- **Server operator role**: Similar to administrator but for operational tasks. Assumed to be a configurable list of identified nicknames who have operator privileges. If `/oper` command exists, that mechanism will be used; otherwise a configuration-based approach similar to admin.
- **MOTD storage**: Assumed to be stored in the database for persistence across restarts.
- **Channel welcome message storage**: Assumed to be stored in the database, associated with the channel name.
- **Session tracking for welcome messages**: The system tracks which channels a user has already received a welcome message for during their current session, using in-memory state (socket assigns or session struct).
- **Multi-line MOTD**: The `/setmotd` command accepts the entire MOTD as a single command argument. For multi-line MOTDs, administrators can include newline characters or use multiple `/setmotd` calls that append (decision: single command replaces entirely, keeping it simple).
- **Active window for announcements**: "Active window" means whichever chat tab/channel the user currently has focused. The announcement is inserted into that window's message stream.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of connecting users see the MOTD (when set) in their Status Window within 1 second of connection completion.
- **SC-002**: Users can re-read the MOTD by typing `/motd` and see the result within 1 second.
- **SC-003**: 100% of users joining a channel with a welcome message see the greeting immediately after their join notification (within 1 second).
- **SC-004**: Welcome messages are displayed zero times to the user who set them when they join the same channel.
- **SC-005**: Wallops messages reach all users with `+w` mode enabled within 1 second of the operator sending the command.
- **SC-006**: Global announcements reach 100% of connected users regardless of ignore lists, away status, or channel moderation state.
- **SC-007**: All permission-restricted commands (`/setmotd`, `/clearmotd`, `/announce`, `/wallops`, `/setwelcome`, `/clearwelcome`) correctly reject unauthorized users with clear error messages 100% of the time.
- **SC-008**: MOTD and channel welcome messages persist correctly across server restarts with zero data loss.
