# Feature Specification: Ignore System

**Feature Branch**: `006-ignore-system`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Ignore System for RetroHexChat — local, client-side filtering of unwanted user messages with granular type control and temporary ignore timers."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ignore and Unignore a User (Priority: P1)

A user is being harassed or spammed by another user. They type `/ignore SpamBot42` and immediately stop seeing any user-authored content from SpamBot42 — channel messages, private messages, and actions all disappear from their view. A system message confirms: `* SpamBot42 is now ignored`. The ignored user receives no indication they are being ignored. The user can later type `/unignore SpamBot42` to remove the ignore. Typing `/ignore` with no arguments shows the current ignore list.

**Why this priority**: Core feature — without basic ignore/unignore functionality, the entire feature has no value. This is the minimum viable product.

**Independent Test**: Can be fully tested by connecting two users, having one ignore the other, and verifying that messages from the ignored user are no longer displayed to the ignoring user.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they type `/ignore SpamBot42`, **Then** a system message `* SpamBot42 is now ignored` appears and all subsequent channel messages, PMs, and actions from SpamBot42 are hidden from the user's view.
2. **Given** a user has ignored SpamBot42, **When** SpamBot42 sends a channel message, **Then** the message does not appear in the ignoring user's chat area, but other users still see it.
3. **Given** a user has ignored SpamBot42, **When** SpamBot42 sends a PM to the ignoring user, **Then** the PM does not appear in the ignoring user's view.
4. **Given** a user has ignored SpamBot42, **When** they type `/unignore SpamBot42`, **Then** a system message `* SpamBot42 is no longer ignored` appears and subsequent messages from SpamBot42 become visible again.
5. **Given** a user has ignored SpamBot42, **When** SpamBot42 joins or parts a channel, **Then** the join/part system message is still visible to the ignoring user (system messages are not filtered).
6. **Given** a connected user, **When** they type `/ignore` with no arguments, **Then** the system displays their current ignore list.

---

### User Story 2 - Ignore by Type (Priority: P2)

A user wants finer control over what they filter. They can specify an ignore type: `/ignore AnnoyingGuy pms` ignores only private messages from AnnoyingGuy while still showing their channel messages. Available types are: `all` (default), `messages`, `pms`, `invites`, `actions`.

**Why this priority**: Adds granularity that makes the feature more practical — users may want to see someone's channel messages but block their PMs. Builds on P1 foundation.

**Independent Test**: Can be tested by ignoring a user with a specific type, then verifying that only the specified message type is filtered while other types remain visible.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they type `/ignore AnnoyingGuy pms`, **Then** only PMs from AnnoyingGuy are hidden; channel messages and actions from AnnoyingGuy remain visible.
2. **Given** a connected user, **When** they type `/ignore AnnoyingGuy messages`, **Then** only channel messages from AnnoyingGuy are hidden; PMs and actions remain visible.
3. **Given** a connected user, **When** they type `/ignore AnnoyingGuy actions`, **Then** only `/me` actions from AnnoyingGuy are hidden; messages and PMs remain visible.
4. **Given** a connected user, **When** they type `/ignore AnnoyingGuy invites`, **Then** only channel invites from AnnoyingGuy are hidden.
5. **Given** a user has already ignored AnnoyingGuy with type `all`, **When** they type `/ignore AnnoyingGuy pms`, **Then** the ignore entry is updated to type `pms` and a system message confirms the change: `* AnnoyingGuy ignore updated to: pms`.

---

### User Story 3 - Temporary Ignore with Timer (Priority: P3)

A user wants to temporarily ignore someone. They type `/ignore LoudPerson all 5m` to ignore for 5 minutes. When the timer expires, a system message appears: `* LoudPerson is no longer ignored (timer expired)` and their messages become visible again. Supported time formats: `Nm` (minutes), `Nh` (hours), `Nd` (days).

**Why this priority**: Useful convenience feature but not essential — users can manually unignore. Adds polish to the ignore experience.

**Independent Test**: Can be tested by setting a short timer (e.g., 1 minute), verifying the ignore is active, then verifying it auto-expires and the system message appears.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they type `/ignore LoudPerson all 5m`, **Then** LoudPerson is ignored and a system message shows `* LoudPerson is now ignored (expires in 5 minutes)`.
2. **Given** a user has a timed ignore on LoudPerson (5 minutes), **When** 5 minutes elapse, **Then** a system message `* LoudPerson is no longer ignored (timer expired)` appears and messages from LoudPerson become visible again.
3. **Given** a user has a timed ignore on LoudPerson, **When** they type `/unignore LoudPerson` before the timer expires, **Then** the ignore is removed immediately and the timer is cancelled.
4. **Given** a user has a permanent ignore on someone, **When** they type `/ignore someone all 10m`, **Then** the ignore is updated to a timed ignore (10 minutes) and the previous permanent ignore is replaced.

---

### User Story 4 - Ignore List Management Dialog (Priority: P4)

Users can view and manage their ignore list through a dialog window accessible from the menu bar. The dialog shows all currently ignored users with their nickname, ignore type, and expiration status (permanent or countdown). Users can add new ignores and remove existing ones via buttons.

**Why this priority**: Provides a visual alternative to commands. Important for discoverability but the command-based workflow (P1-P3) is fully functional without it.

**Independent Test**: Can be tested by opening the dialog, verifying it shows current ignores, adding a new ignore via the dialog, and removing one.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they open the Ignore List dialog from the menu, **Then** a 98.css-styled dialog appears showing all current ignores in a list with columns: Nickname, Type, Expires.
2. **Given** the dialog is open and the user has ignored 3 users, **When** they view the list, **Then** all 3 entries appear with correct nicknames, types, and expiration info.
3. **Given** the dialog is open, **When** the user clicks "Add" and enters a nickname, **Then** a new ignore entry is created with type `all` and permanent duration by default.
4. **Given** the dialog is open with entries, **When** the user selects an entry and clicks "Remove", **Then** the ignore is removed and the list updates.
5. **Given** a timed ignore is active, **When** the user views the dialog, **Then** the Expires column shows the remaining time (e.g., "3m 22s remaining") or "Permanent" for permanent ignores.

---

### User Story 5 - Ignore List Persistence (Priority: P5)

Registered users who have identified with NickServ have their ignore list saved and restored across sessions. Guest users keep their ignore list only for the current session.

**Why this priority**: Important for registered users but the feature works for a single session without persistence. Builds on the persistence pattern already established by notify list and highlight words.

**Independent Test**: Can be tested by identifying with NickServ, adding ignores, disconnecting, reconnecting and re-identifying, then verifying the ignore list is restored.

**Acceptance Scenarios**:

1. **Given** a registered user who has identified with NickServ and added ignores, **When** they disconnect and reconnect, **Then** after re-identifying with NickServ their ignore list is restored.
2. **Given** a guest user who has added ignores, **When** they disconnect and reconnect, **Then** their ignore list starts empty.
3. **Given** a registered user with saved ignores including a timed ignore, **When** they reconnect, **Then** timed ignores that would have expired during disconnection are not restored; only unexpired ignores are restored with adjusted remaining time.

---

### Edge Cases

- **Self-ignore**: User types `/ignore OwnNick` — system responds with `* You cannot ignore yourself` and no ignore entry is created.
- **Duplicate ignore**: User ignores the same nickname twice — the existing entry is updated with the new type/duration rather than creating a duplicate.
- **Unignore non-ignored user**: User types `/unignore SomeUser` when SomeUser is not ignored — system responds with `* SomeUser is not in your ignore list`.
- **Ignored user quoted by non-ignored user**: If a non-ignored user quotes text from an ignored user, the quoted text remains visible (filtering is per-sender, not per-content).
- **System messages from ignored users**: Joins, parts, kicks, nick changes, and other server/system messages from ignored users remain visible to maintain channel context.
- **Case sensitivity**: Nickname matching for ignore is case-insensitive (`/ignore spambot42` matches messages from `SpamBot42`).
- **Nick rename tracking**: If an ignored user changes their nickname, the ignore follows the new nickname (tracked via the existing nick rename broadcast system).
- **Invalid timer format**: User types `/ignore User all xyz` — system responds with `* Invalid duration format. Use: 5m, 2h, 1d`.
- **Zero or negative timer**: User types `/ignore User all 0m` — system responds with `* Duration must be greater than zero`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to ignore other users by nickname via the `/ignore` command.
- **FR-002**: System MUST allow users to remove ignores via the `/unignore` command.
- **FR-003**: System MUST support five ignore types: `all` (default), `messages` (channel messages), `pms` (private messages), `invites` (channel invites), `actions` (`/me` actions).
- **FR-004**: System MUST filter ignored content locally on the receiving user's client — the ignored user receives no notification or indication.
- **FR-005**: System MUST NOT filter system/server messages (joins, parts, kicks, mode changes, nick changes) from ignored users.
- **FR-006**: System MUST support temporary ignores with configurable duration using `Nm` (minutes), `Nh` (hours), `Nd` (days) format.
- **FR-007**: System MUST automatically remove expired timed ignores and display a system message when they expire.
- **FR-008**: System MUST reject self-ignore attempts with a friendly error message.
- **FR-009**: System MUST update existing ignore entries when the same nickname is ignored again (no duplicates).
- **FR-010**: System MUST display the current ignore list when `/ignore` is typed with no arguments.
- **FR-011**: System MUST provide an Ignore List management dialog accessible from the menu bar.
- **FR-012**: System MUST persist ignore lists for registered users (identified via NickServ) across sessions.
- **FR-013**: System MUST match nicknames case-insensitively for ignore operations.
- **FR-014**: System MUST track nick renames and apply ignores to the renamed nickname.
- **FR-015**: System MUST validate timer format and reject invalid or zero/negative durations.
- **FR-016**: System MUST display confirmation system messages for ignore add, update, remove, and expiry events.
- **FR-017**: System MUST restore only unexpired timed ignores on session reconnect, with adjusted remaining time.

### Key Entities

- **IgnoreEntry**: Represents a single ignore rule — target nickname, ignore type (all/messages/pms/invites/actions), expiration (permanent or timestamp), creation time.
- **IgnoreList**: Collection of IgnoreEntry items belonging to a user session — supports CRUD operations, lookup by nickname, and timer management.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can ignore an unwanted user in under 5 seconds by typing a single command.
- **SC-002**: Ignored user's filtered content (matching the ignore type) is not displayed to the ignoring user with 100% reliability.
- **SC-003**: System messages (joins, parts, kicks) from ignored users remain visible with 100% reliability.
- **SC-004**: Timed ignores expire within 1 second of the specified duration and produce a visible system message.
- **SC-005**: Registered users' ignore lists are fully restored after reconnection and re-identification.
- **SC-006**: The Ignore List dialog accurately displays all current ignores with correct type and expiration information.
- **SC-007**: All ignore operations provide immediate visual feedback via system messages.
- **SC-008**: Nick renames of ignored users are tracked without requiring manual re-ignore.

## Assumptions

- **A-001**: The ignore system operates entirely client-side (in the LiveView process) — ignored messages are still delivered by the server but filtered before display. This follows the IRC convention where ignore is a client feature.
- **A-002**: Timer precision is at the minute level for display purposes, though internal tracking uses seconds.
- **A-003**: The persistence model follows the existing pattern used by notify list and highlight words (database table + NickServ identify trigger for loading).
- **A-004**: Maximum ignore list size is 100 entries per user — a reasonable limit to prevent abuse.
- **A-005**: The Ignore List dialog is a modal 98.css window consistent with other dialogs (Address Book, Highlight, etc.).
- **A-006**: The context menu on nicknames in the nicklist and chat area will include an "Ignore" option for quick access.

## Scope

### In Scope

- `/ignore` and `/unignore` commands with full argument parsing
- Per-type ignore filtering (all, messages, pms, invites, actions)
- Temporary ignore with timer (minutes, hours, days)
- Ignore List management dialog (view, add, remove)
- Persistence for registered users via NickServ identify
- Nick rename tracking for ignored users
- Help documentation topics

### Out of Scope

- Wildcard/pattern-based ignoring (hostmasks) — reserved for future enhancement
- Automatic flood-based ignoring — separate feature (rate limiting category)
- Ignore management within Address Book Control tab — separate feature (Address Book enhancement)
- Ignore-on-invite (auto-declining invites) — invites are filtered but no auto-decline response is sent
