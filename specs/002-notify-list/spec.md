# Feature Specification: Notify List (Buddy List)

**Feature Branch**: `002-notify-list`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Notify List (Buddy List) for RetroHexChat — persistent buddy list that alerts users to friends' presence changes, with a dedicated retro-style window."

## Clarifications

### Session 2026-02-11

- Q: Where should notify list notifications (online/offline) be delivered when the user has no active channel? → A: Notifications are delivered to a Status window (mIRC-style). This feature introduces a minimal Status window as a persistent, always-available system message area. The Status window receives all notify list events regardless of which channel or PM the user is viewing. A full channel/PM tab bar (as seen in mIRC's bottom tab strip) is a related future enhancement, not part of this feature.
- Q: What happens to the persisted notify list entry when a tracked buddy renames? → A: Auto-update the stored nickname to the new one. The entry tracks the person, not the original name. If Alice renames to Alice2, the entry now shows "Alice2" everywhere.
- Q: Is auto-whois a global toggle or per-entry? → A: Single global toggle for the entire notify list, not per-entry. Matches mIRC behavior.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manage Buddy List Entries (Priority: P1)

A user wants to keep track of specific people in chat. They open the Notify List window (via the toolbar or a `/notify` command) and add nicknames of friends they want to track. Each entry can include an optional personal note (e.g., "Works on Elixir projects"). The user can edit notes, remove entries, and see all their tracked buddies at a glance.

For registered users who have identified with NickServ, the notify list persists across sessions — when they reconnect and identify, their list is restored. For guests, the list lives only for the current session.

**Why this priority**: Without the ability to add and manage buddies, no other notify functionality can work. This is the foundation of the entire feature.

**Independent Test**: Can be fully tested by adding, editing, and removing entries from the notify list and verifying they appear correctly in the window. Delivers value as a personal address book even before online/offline notifications are implemented.

**Acceptance Scenarios**:

1. **Given** a connected user with the Notify List window open, **When** they add a nickname "Alice" with note "Elixir dev", **Then** a new entry appears in the list showing "Alice" with status "offline" (unknown), the note "Elixir dev", and "Last Seen: Never".
2. **Given** a user with "Alice" in their notify list, **When** they edit Alice's note to "Phoenix expert", **Then** the note updates immediately in the list.
3. **Given** a user with "Alice" in their notify list, **When** they remove Alice, **Then** Alice disappears from the list and no further notifications are generated for Alice.
4. **Given** a user who tries to add their own nickname, **When** they submit the add form, **Then** the system displays a friendly message: "You cannot add yourself to the notify list."
5. **Given** a user with 50 entries in the notify list, **When** they try to add a 51st, **Then** the system displays: "Notify list is full (maximum 50 entries)."
6. **Given** a registered user with a saved notify list, **When** they reconnect and identify with NickServ, **Then** their notify list is restored with all entries and notes.
7. **Given** a guest user with entries in the notify list, **When** they disconnect, **Then** the list is lost (no persistence).

---

### User Story 2 - Online/Offline Notifications (Priority: P2)

When a buddy on the notify list connects to the server, the user receives a system notification in the Status window: "* Alice is now online". When Alice disconnects, the user sees "* Alice has gone offline" in the Status window. Each notification type has a distinct visual style. The Notify List window updates the buddy's status icon in real time. The "Last Seen" column updates when a buddy goes offline.

If a buddy rapidly connects and disconnects (e.g., connection issues), notifications are debounced so the user does not get spammed.

**Why this priority**: Real-time presence notifications are the core value proposition of a notify list. Without them, it is just a static list of names.

**Independent Test**: Can be tested by having a tracked buddy connect and disconnect while the user is online, and verifying that system messages appear and the Notify List window reflects the status change.

**Acceptance Scenarios**:

1. **Given** a user tracking "Alice" in the notify list and Alice is offline, **When** Alice connects to the server, **Then** the user sees a system message "* Alice is now online" in the Status window, and Alice's status in the Notify List window changes to "online" (green icon).
2. **Given** a user tracking "Alice" and Alice is online, **When** Alice disconnects, **Then** the user sees "* Alice has gone offline" in the Status window, Alice's status changes to "offline" (grey icon), and "Last Seen" updates to the current timestamp.
3. **Given** a buddy who connects and disconnects 5 times within 10 seconds, **When** the debounce period elapses, **Then** the user sees at most one online and one offline notification (not 10 messages).
4. **Given** a user who removes "Alice" from the notify list while Alice is online, **When** the removal completes, **Then** no "Alice has gone offline" notification is generated.
5. **Given** a user who is tracking "Alice" and Alice changes her nickname to "Alice2", **When** the rename occurs, **Then** the notify list entry still tracks Alice under her new nickname and a system message indicates the rename.

---

### User Story 3 - Notify List Window (Priority: P3)

The Notify List window is a dedicated retro-style window (consistent with the MDI layout) showing all buddies in a sortable list with columns: Nickname, Status (online/offline icon), Notes, Last Seen. Online buddies appear at the top of the list by default. The window has toolbar buttons for Add, Remove, and Edit. Double-clicking an online buddy opens a private message conversation with them.

**Why this priority**: The window provides the visual interface for the feature. The underlying functionality (stories 1 and 2) can work via commands alone, but the window makes it accessible and matches the mIRC experience.

**Independent Test**: Can be tested by opening the window, verifying column layout, sorting behavior, and double-click to PM. Delivers value as the primary UI for managing and viewing the buddy list.

**Acceptance Scenarios**:

1. **Given** a user clicks the Notify List toolbar button (or uses the menu), **When** the window opens, **Then** it displays a retro-style window with columns: Nickname, Status, Notes, Last Seen.
2. **Given** a notify list with 3 online and 2 offline buddies, **When** the window renders, **Then** online buddies appear above offline buddies, each group sorted alphabetically.
3. **Given** the user double-clicks an online buddy "Alice", **When** the action fires, **Then** a PM conversation opens with Alice.
4. **Given** the user double-clicks an offline buddy "Bob", **When** the action fires, **Then** nothing happens (or a tooltip shows "Bob is offline").
5. **Given** the user clicks the "Add" toolbar button, **When** the add dialog appears, **Then** it has fields for Nickname (required) and Notes (optional).

---

### User Story 4 - Auto-Whois on Connect (Priority: P4)

As an optional feature, users can enable "auto-whois" for the notify list. When enabled and a buddy comes online, the system automatically fetches that buddy's whois information and displays it as a system message, so the user can see what channels the buddy is in and other details.

**Why this priority**: This is a convenience enhancement on top of the core notification system. Useful but not essential for the feature to deliver value.

**Independent Test**: Can be tested by enabling auto-whois, having a buddy connect, and verifying that whois information appears as a system message after the online notification.

**Acceptance Scenarios**:

1. **Given** a user with auto-whois enabled and "Alice" in the notify list, **When** Alice connects, **Then** the user sees "* Alice is now online" followed by Alice's whois information (channels, idle time, etc.) as system messages in the Status window.
2. **Given** a user with auto-whois disabled, **When** a buddy connects, **Then** only the standard online notification appears (no whois).
3. **Given** a user toggles auto-whois on, **When** a buddy who is already online reconnects, **Then** the whois is fetched and displayed.

---

### User Story 5 - Slash Commands for Notify List (Priority: P5)

Users can manage the notify list entirely via slash commands, consistent with the mIRC `/notify` command:

- `/notify add <nickname> [note]` — add a buddy with optional note
- `/notify remove <nickname>` — remove a buddy
- `/notify list` — display the current notify list in the active channel
- `/notify edit <nickname> <note>` — update a buddy's note
- `/notify` (no args) — open the Notify List window

**Why this priority**: Power users expect command-line management. This complements the GUI window and follows mIRC conventions.

**Independent Test**: Can be tested by executing each command variant and verifying the expected response or action.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they type `/notify add Alice Works on Elixir`, **Then** "Alice" is added to the list with note "Works on Elixir" and a confirmation message appears.
2. **Given** a user with "Alice" in the list, **When** they type `/notify remove Alice`, **Then** Alice is removed and a confirmation appears.
3. **Given** a user with entries, **When** they type `/notify list`, **Then** the current notify list is displayed as system messages in the active channel.
4. **Given** a connected user, **When** they type `/notify`, **Then** the Notify List window opens.

---

### Edge Cases

- **Nickname doesn't exist yet**: Adding a nickname that no one currently uses is allowed — they may connect in the future. The entry shows as "offline" with "Last Seen: Never".
- **Duplicate add**: Adding a nickname already in the list displays "Alice is already in your notify list."
- **Case sensitivity**: Nickname matching is case-insensitive (adding "alice" when "Alice" exists is a duplicate).
- **Buddy renames**: When a tracked buddy changes their nickname, the system automatically updates the stored nickname in the entry to the new name. The entry tracks the person, not the original name they were added under. A system message in the Status window informs the user (e.g., "* Your notify list buddy Alice is now known as Alice2").
- **Concurrent sessions**: If the same registered user connects from two sessions, the notify list is consistent across both (loaded from database on identify).
- **Registered user loses nick**: If a registered user who owns the notify list gets force-renamed (e.g., NickServ ghost), the in-memory list remains active for the session.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to add nicknames to their personal notify list with an optional text note (up to 200 characters).
- **FR-002**: System MUST allow users to remove nicknames from their notify list.
- **FR-003**: System MUST allow users to edit the note associated with a notify list entry.
- **FR-004**: System MUST enforce a maximum of 50 entries per notify list.
- **FR-005**: System MUST reject adding the user's own nickname to their notify list with a friendly message.
- **FR-006**: System MUST persist the notify list for registered users who have identified with NickServ, restoring it on subsequent sessions after identification.
- **FR-007**: System MUST maintain in-memory-only notify lists for guest users, discarded on disconnect.
- **FR-008**: System MUST detect when a tracked buddy connects and deliver a system notification ("* [nickname] is now online") to the Status window.
- **FR-009**: System MUST detect when a tracked buddy disconnects and deliver a system notification ("* [nickname] has gone offline") to the Status window.
- **FR-021**: System MUST provide a Status window — a persistent, always-available system message area that receives all notify list notifications, server messages, and other system events. The Status window is always present and cannot be closed.
- **FR-010**: System MUST debounce rapid connect/disconnect events for the same buddy, consolidating notifications within a 10-second window.
- **FR-011**: System MUST NOT generate an offline notification when a buddy is removed from the notify list while they are online.
- **FR-012**: System MUST display a Notify List window with columns: Nickname, Status (online/offline icon), Notes, Last Seen.
- **FR-013**: System MUST sort the Notify List window with online buddies above offline buddies, each group sorted alphabetically.
- **FR-014**: System MUST open a PM conversation when the user double-clicks an online buddy in the Notify List window.
- **FR-015**: System MUST provide a single global auto-whois toggle for the notify list that, when enabled, automatically displays whois information in the Status window for any buddy who comes online.
- **FR-016**: System MUST support `/notify` commands: add, remove, list, edit, and bare `/notify` to open the window.
- **FR-017**: System MUST track nickname changes for buddies and automatically update the stored nickname in the notify list entry to the new name (the entry tracks the person, not the original name).
- **FR-018**: System MUST update the "Last Seen" timestamp for a buddy when they go offline.
- **FR-019**: System MUST handle duplicate add attempts by displaying "Already in your notify list" message.
- **FR-020**: System MUST perform case-insensitive nickname matching for all notify list operations.

### Key Entities

- **Notify List Entry**: A single buddy tracking record belonging to one user. Attributes: owner nickname, tracked nickname, personal note, last seen timestamp.
- **Notify List**: The collection of all entries for a single user. Has a maximum capacity of 50 entries. Includes a global auto-whois toggle (on/off).
- **Presence Event**: An online/offline status change for any connected user, used to trigger notifications for users tracking that nickname.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a buddy and receive their first online notification within 5 seconds of the buddy connecting.
- **SC-002**: The Notify List window displays accurate real-time status for all tracked buddies, reflecting changes within 5 seconds.
- **SC-003**: Registered users retain their complete notify list across sessions — 100% of entries and notes restored after re-identification.
- **SC-004**: Rapid connect/disconnect sequences (5+ events in 10 seconds) produce at most 2 notifications (one online, one offline).
- **SC-005**: All notify list operations (add, remove, edit) complete and reflect in the UI within 2 seconds.
- **SC-006**: The feature supports up to 50 buddies per user without noticeable performance degradation in the Notify List window.
- **SC-007**: Users can manage their entire notify list via slash commands without ever opening the window, and vice versa.

## Assumptions

- The existing PubSub infrastructure and `"user:#{nickname}"` topic can be extended to support global presence events for notify list tracking.
- Nickname rename tracking leverages the existing `:nick_changed` broadcast that already propagates through channels.
- Sound notifications are referenced in the user description but sound file selection UI is explicitly out of scope. The feature will trigger sound events that can be handled by a future sound system; for now, visual notifications are the primary feedback mechanism.
- The Notify List window follows the same MDI (Multiple Document Interface) pattern used by the existing chat windows in the retro design system.
- Auto-whois reuses the existing whois data gathering logic already present in the `/whois` command handler.

## Out of Scope

- Address Book integration (Category C — separate feature).
- Sound file selection UI (Category O — separate feature).
- Notify list import/export.
- Group/category organization within the notify list.
- Blocking or ignoring users (separate feature from tracking).
- Full channel/PM tab bar with colored activity indicators (related future enhancement inspired by mIRC's bottom tab strip).
