# Feature Specification: Perform / Auto-Commands

**Feature Branch**: `009-perform-auto-commands`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Perform / Auto-commands for RetroHexChat — auto-execute commands on connect, auto-join channels, auto-reconnect with exponential backoff"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Perform Commands on Connect (Priority: P1)

A user configures a list of slash commands that the system automatically executes in order every time they connect. Commands include NickServ identification (`/ns identify`), channel joins (`/join #channel`), away messages, and any other valid slash command. On each connection, the user sees system messages confirming each command as it executes (e.g., "* Performing: /join #elixir..."). Commands execute sequentially with a brief pause between each to allow server responses.

Users manage their perform list via the `/perform` command:
- `/perform` — lists all current perform commands
- `/perform add <command>` — appends a command to the list
- `/perform remove <number>` — removes command at position N
- `/perform clear` — removes all perform commands
- `/perform move <from> <to>` — reorders a command

Perform commands persist across sessions for registered users (loaded after NickServ identification). Guest users can add perform commands for their current session only.

**Why this priority**: This is the core value proposition. Without auto-execute on connect, no other part of this feature matters. The `/perform` command provides immediate usability without requiring a dialog UI.

**Independent Test**: Can be fully tested by adding perform commands via `/perform add`, reconnecting, and verifying they execute automatically. Delivers immediate time savings on every connection.

**Acceptance Scenarios**:

1. **Given** a registered user with perform commands `/ns identify pass` and `/join #elixir`, **When** they connect and identify with NickServ, **Then** the system executes each command sequentially with system messages "* Performing: /ns identify ****..." and "* Performing: /join #elixir..." and the user ends up identified and in #elixir.
2. **Given** a user with a perform command `/join #secret mykey`, **When** they connect and the channel rejects the key, **Then** the system shows an error message for that command and continues executing remaining commands.
3. **Given** a user with a perform command `/ns identify wrongpassword`, **When** they connect, **Then** NickServ identification fails, an error is shown, but remaining perform commands still execute.
4. **Given** a guest user, **When** they add perform commands via `/perform add /join #help`, **Then** the commands execute on their current connection but do not persist if they disconnect and reconnect.
5. **Given** a registered user with perform commands, **When** they connect and type `/perform`, **Then** they see a numbered list of all their commands with passwords masked as `****`.

---

### User Story 2 - Perform Dialog (Priority: P2)

Users can open a Perform dialog from the menu bar (Tools > Perform) or via Alt+P keyboard shortcut. The dialog provides a visual interface to manage perform commands:

- A listbox showing all commands in execution order (passwords masked as `****`)
- "Add" button opens a sub-dialog with a text input for the command
- "Edit" button opens a sub-dialog with the selected command pre-filled (passwords shown in the edit field for editing)
- "Remove" button deletes the selected command
- "Move Up" / "Move Down" buttons reorder commands
- An "Enable on connect" checkbox (checked by default) to globally toggle perform execution
- Changes take effect immediately (no separate save action needed)

The dialog follows 98.css styling consistent with other dialogs (Address Book, Highlight, Ignore List).

**Why this priority**: While `/perform` provides CLI management, most users expect a graphical interface. This dialog makes the feature accessible to users who prefer point-and-click over commands.

**Independent Test**: Can be tested by opening the dialog, adding/editing/removing/reordering commands, and verifying the list updates correctly. Does not require actually connecting to verify execution (that is US1).

**Acceptance Scenarios**:

1. **Given** a user on the chat screen, **When** they press Alt+P or click Tools > Perform, **Then** the Perform dialog opens showing their current command list.
2. **Given** an open Perform dialog, **When** the user clicks "Add" and enters `/join #newchannel`, **Then** the command appears at the bottom of the list.
3. **Given** a Perform dialog with commands, **When** the user selects a command containing `/ns identify secret123` , **Then** the listbox displays it as `/ns identify ****`.
4. **Given** a Perform dialog with commands, **When** the user clicks "Edit" on a masked command, **Then** the edit sub-dialog shows the full unmasked command for editing.
5. **Given** a Perform dialog with 3 commands and the second selected, **When** the user clicks "Move Up", **Then** the second command becomes first, and the previously first becomes second.
6. **Given** a Perform dialog with "Enable on connect" unchecked, **When** the user connects, **Then** no perform commands execute.

---

### User Story 3 - Auto-Join Channel List (Priority: P3)

Users can configure a dedicated auto-join channel list, separate from the general perform commands, for the common case of always joining the same channels. The auto-join list provides a simpler interface specifically for channels:

- Each entry has a channel name and an optional key (for +k channels)
- Channels are joined in list order after perform commands complete
- Management via `/autojoin` command:
  - `/autojoin` — lists all auto-join channels
  - `/autojoin add #channel [key]` — adds a channel
  - `/autojoin remove #channel` — removes a channel
  - `/autojoin clear` — removes all auto-join channels
- An "Auto-Join" tab in the Perform dialog shows the channel list with Add/Edit/Remove buttons
- Auto-join entries persist for registered users

Auto-join channels execute after all perform commands complete, so NickServ identification (from perform) happens before channel joins that may require it.

**Why this priority**: While `/join` in perform achieves the same result, a dedicated auto-join list is more intuitive and mirrors mIRC's separation of concerns. It also simplifies the common case.

**Independent Test**: Can be tested by adding channels to the auto-join list, connecting, and verifying they are joined automatically. Works independently of perform commands.

**Acceptance Scenarios**:

1. **Given** a user with auto-join channels `#elixir` and `#phoenix`, **When** they connect, **Then** the system joins both channels in order with messages "* Auto-joining #elixir..." and "* Auto-joining #phoenix...".
2. **Given** a user with auto-join entry `#secret` with key `mykey`, **When** they connect, **Then** the system joins `#secret` with the provided key.
3. **Given** a user with both perform commands and auto-join channels, **When** they connect, **Then** perform commands execute first (e.g., NickServ identify), followed by auto-join channels.
4. **Given** the Perform dialog open on the "Auto-Join" tab, **When** the user clicks "Add" and enters `#newchan`, **Then** the channel appears in the auto-join list.

---

### User Story 4 - Auto-Reconnect (Priority: P4)

When the user's connection drops unexpectedly (server restart, network interruption), the system automatically attempts to reconnect with exponential backoff:

- Initial delay: 1 second
- Each subsequent attempt doubles the delay: 1s, 2s, 4s, 8s, 16s, 30s
- Maximum delay capped at 30 seconds
- Maximum 10 attempts before giving up

During reconnection, the user sees a status overlay:
- "Connection lost. Reconnecting in Xs..." with a countdown timer
- A "Cancel" button to stop reconnection and return to the connect screen
- Attempt counter: "Attempt 3 of 10"

Auto-reconnect does NOT trigger when:
- The user intentionally disconnects via `/quit`
- The user navigates away from the chat page
- The user closes the browser tab

After all attempts are exhausted, the system shows "Reconnection failed after 10 attempts" and a "Return to Connect" button.

**Why this priority**: Auto-reconnect is a convenience feature that enhances connection resilience. It is independent of perform — even without perform commands, reconnecting saves the user from manually re-entering their nickname.

**Independent Test**: Can be tested by simulating a connection drop (e.g., killing the server process) and verifying the reconnection overlay appears with countdown, attempts, and cancel functionality. Works without any perform commands configured.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** the server connection drops unexpectedly, **Then** the system shows "Connection lost. Reconnecting in 1s..." with a countdown and "Cancel" button.
2. **Given** a reconnecting user on attempt 3, **When** the connection is restored, **Then** the user is reconnected with their previous nickname and sees "Reconnected successfully".
3. **Given** a reconnecting user, **When** they click "Cancel", **Then** reconnection stops and they are returned to the connect screen.
4. **Given** a reconnecting user, **When** 10 attempts are exhausted without success, **Then** the system shows "Reconnection failed after 10 attempts" with a "Return to Connect" button.
5. **Given** a connected user, **When** they type `/quit`, **Then** auto-reconnect does NOT trigger and they are returned to the connect screen normally.

---

### User Story 5 - Session Restoration on Reconnect (Priority: P5)

When auto-reconnect succeeds, the system restores the user's previous session state:

1. Reconnect with the same nickname
2. Re-execute perform commands (if enabled)
3. Rejoin all channels the user was in before disconnection (preserving the channel list from the dropped session)
4. Restore the active channel/PM tab the user was viewing

The system saves minimal session state (nickname, channel list, active tab) to enable restoration. System messages inform the user of the restoration progress: "* Restoring session...", "* Rejoining #elixir...", "* Session restored".

If the nickname is taken during the disconnection window (another user connected with it), the system informs the user and returns them to the connect screen to choose a new nickname.

**Why this priority**: Session restoration completes the reconnection experience. Without it, auto-reconnect only saves the user from re-entering their nickname. With it, the user's full environment is seamlessly restored.

**Independent Test**: Can be tested by joining multiple channels, simulating a connection drop, allowing auto-reconnect to succeed, and verifying all channels are rejoined and the active tab is restored.

**Acceptance Scenarios**:

1. **Given** a user in channels `#elixir`, `#phoenix`, and `#lobby` with `#phoenix` active, **When** they reconnect after a connection drop, **Then** all three channels are rejoined and `#phoenix` is the active tab.
2. **Given** a registered user with perform commands, **When** they reconnect, **Then** perform commands execute first, then channels from the previous session are rejoined (deduplicating any channels already joined by perform/auto-join).
3. **Given** a user who was disconnected and whose nickname was taken by another user, **When** auto-reconnect succeeds, **Then** the system detects the nickname conflict, shows "Your nickname is no longer available", and returns the user to the connect screen.
4. **Given** a user who had open PM conversations, **When** they reconnect, **Then** PM tabs are not auto-restored (PMs are ephemeral; only channels are restored).

---

### Edge Cases

- **Perform command references a non-existent channel**: The `/join` fails with "No such channel" error; system continues with next command.
- **Circular perform reference**: `/perform add /perform add /join #foo` — the `/perform` command itself is disallowed in perform lists to prevent recursion.
- **Disallowed perform commands**: `/quit`, `/perform`, `/autojoin`, and `/disconnect` are not allowed in perform lists. Adding them shows an error.
- **Empty perform list**: On connect, no perform commands execute; only auto-join channels (if any) and the default #lobby join proceed normally.
- **Duplicate auto-join channels**: Adding a channel that already exists in the auto-join list shows "Channel already in auto-join list".
- **Very long perform list**: Maximum 50 perform commands and 20 auto-join channels to prevent abuse.
- **Connection drops during perform execution**: If the connection drops while perform commands are running, the partial execution is abandoned; on next reconnect, perform starts from the beginning.
- **NickServ identify timeout during reconnect**: The 60-second identify timer still applies; if the user's perform has `/ns identify` it should fire before the timer expires.
- **Auto-reconnect during server maintenance**: If the server rejects all connections (e.g., maintenance mode), each attempt fails and the backoff progresses; after 10 attempts the user is informed.
- **Multiple rapid disconnections**: If a user reconnects and immediately disconnects again, the reconnection state resets and a new backoff sequence begins.
- **Password changes**: If a user changes their NickServ password, their saved `/ns identify oldpass` in perform will fail. The error is shown but execution continues.
- **Channel key changes**: If a channel's key changes, the saved auto-join key fails; the error is shown and the channel is skipped.

## Requirements *(mandatory)*

### Functional Requirements

#### Perform Commands
- **FR-001**: System MUST allow users to maintain an ordered list of slash commands (the "perform list") that execute automatically on each connection.
- **FR-002**: System MUST execute perform commands sequentially, in the user's configured order, with a brief delay between commands to allow server processing.
- **FR-003**: System MUST show a system message for each perform command as it executes, with passwords masked (e.g., "* Performing: /ns identify ****...").
- **FR-004**: System MUST continue executing remaining perform commands if any individual command fails, showing the error and proceeding to the next.
- **FR-005**: System MUST provide a `/perform` command with subcommands: `add`, `remove`, `move`, `clear`, and bare (list).
- **FR-006**: System MUST disallow adding `/quit`, `/perform`, `/autojoin`, and `/disconnect` to the perform list, showing an error message explaining why.
- **FR-007**: System MUST enforce a maximum of 50 perform commands per user.
- **FR-008**: System MUST mask passwords in any command output or display — any argument following "identify" in `/ns identify` or `/msg NickServ identify` commands MUST be shown as `****`.

#### Perform Dialog
- **FR-009**: System MUST provide a Perform dialog accessible via Alt+P shortcut and Tools > Perform menu item.
- **FR-010**: The Perform dialog MUST display the command list in a listbox with passwords masked, and provide Add, Edit, Remove, Move Up, and Move Down buttons.
- **FR-011**: The Perform dialog MUST include an "Enable on connect" checkbox that globally toggles whether perform commands execute on connection.
- **FR-012**: The Edit sub-dialog MUST show the full unmasked command to allow password editing.
- **FR-013**: Changes in the Perform dialog MUST take effect immediately without a separate save action.

#### Auto-Join
- **FR-014**: System MUST allow users to maintain a separate ordered list of channels to auto-join on connection.
- **FR-015**: Auto-join channels MUST be joined after all perform commands complete, to ensure NickServ identification (from perform) happens first.
- **FR-016**: Each auto-join entry MUST support an optional channel key for +k channels.
- **FR-017**: System MUST provide an `/autojoin` command with subcommands: `add`, `remove`, `clear`, and bare (list).
- **FR-018**: System MUST enforce a maximum of 20 auto-join channels per user.
- **FR-019**: The Perform dialog MUST include an "Auto-Join" tab for managing the auto-join channel list with Add, Edit, and Remove buttons.
- **FR-020**: System MUST prevent duplicate channels in the auto-join list.

#### Auto-Reconnect
- **FR-021**: System MUST automatically attempt to reconnect when the connection drops unexpectedly (not from `/quit` or intentional navigation).
- **FR-022**: Reconnection attempts MUST use exponential backoff starting at 1 second, doubling each attempt, capped at 30 seconds maximum delay.
- **FR-023**: System MUST stop reconnection after a maximum of 10 failed attempts and inform the user.
- **FR-024**: System MUST display a reconnection overlay showing: countdown timer, current attempt number, total attempts allowed, and a "Cancel" button.
- **FR-025**: The "Cancel" button MUST immediately stop reconnection and return the user to the connect screen.
- **FR-026**: Auto-reconnect MUST NOT trigger on intentional disconnection (`/quit`, navigating away, closing the tab).

#### Session Restoration
- **FR-027**: On successful reconnect, the system MUST restore the user's previous nickname.
- **FR-028**: On successful reconnect, the system MUST re-execute perform commands (if enabled) and then rejoin all channels the user was in before disconnection.
- **FR-029**: Channel rejoining MUST deduplicate — channels already joined by perform or auto-join commands MUST NOT be joined a second time.
- **FR-030**: If the user's nickname is taken when reconnecting, the system MUST inform the user and return them to the connect screen.
- **FR-031**: The system MUST save minimal reconnection state (nickname, channel list, active tab) to enable session restoration.

#### Persistence
- **FR-032**: Perform commands and auto-join channels MUST persist across sessions for registered users (loaded after NickServ identification).
- **FR-033**: Guest users' perform commands and auto-join channels MUST be available for their current session only (in-memory).
- **FR-034**: The "Enable on connect" preference MUST persist for registered users.

#### Help Documentation
- **FR-035**: System MUST include help topics for the `/perform` command, `/autojoin` command, and the Perform feature (dialog and auto-reconnect).
- **FR-036**: The keyboard shortcuts help topic MUST be updated to include Alt+P.

### Key Entities

- **PerformEntry**: A single command in the perform list. Attributes: position (execution order), command text (the full slash command). Belongs to a user's perform configuration. The enable/disable toggle is a list-level setting (not per-entry).
- **AutoJoinEntry**: A channel in the auto-join list. Attributes: position (join order), channel name, optional key (for +k channels). Belongs to a user's auto-join configuration.
- **ReconnectionState**: Temporary client-side state for reconnection. Attributes: previous nickname, list of channels the user was in, active channel/PM tab, attempt count, enabled flag.

## Assumptions

- **Single server**: There is only one server, so per-network perform lists are not needed.
- **No scripting**: Perform commands are simple slash commands with no conditionals, variables, or scripting logic.
- **Default #lobby still joins**: The system's default auto-join of #lobby continues to work alongside perform and auto-join. If #lobby is also in the auto-join list, it is deduplicated.
- **Execution timing**: Perform commands execute after the initial connection is established and #lobby is joined, but before the NickServ identify timer expires (within the 60-second window).
- **Password masking scope**: Only `/ns identify` and `/msg NickServ identify` patterns are masked. Other commands with sensitive data are the user's responsibility to manage.
- **PM tabs not restored**: Private message conversations are ephemeral and are not restored on reconnect; only channel memberships are restored.
- **Auto-reconnect default**: Auto-reconnect is enabled by default for all users. The Cancel button on the overlay serves as the per-disconnection escape hatch.
- **Perform execution for registered users**: For registered users, perform commands execute after NickServ identification completes (since the saved list loads from persistence). If the user has `/ns identify` as a perform command, it executes immediately on connect (before identification loads the full saved list from DB). The system uses the in-memory perform list if available, or loads from persistence after identification.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users with configured perform commands are fully set up (identified, channels joined) within 5 seconds of connecting, with zero manual commands needed.
- **SC-002**: 100% of perform commands execute in the configured order, with failures isolated to the individual command (no cascade failures).
- **SC-003**: Auto-reconnect restores a user's session (nickname + channels) within 35 seconds of an unexpected disconnection when the server is available.
- **SC-004**: Users can manage their perform list (add, edit, remove, reorder) through both the dialog and the `/perform` command with no data loss or inconsistency between the two interfaces.
- **SC-005**: Passwords in perform commands are never displayed in plain text in any user-facing output (dialog listbox, `/perform` list, system messages, help output).
- **SC-006**: Intentional disconnections (`/quit`) never trigger auto-reconnect (zero false positive reconnections).
