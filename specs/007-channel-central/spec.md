# Feature Specification: Channel Central Dialog

**Feature Branch**: `007-channel-central`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Channel Central Dialog — visual hub for channel administration with info, topic, modes, bans, ban exceptions (+e), and invite exceptions (+I)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Read-Only Channel Central (Priority: P1)

Any channel member can open the Channel Central dialog to view comprehensive information about a channel. The dialog displays the channel name, creation date, member count, current topic (including who set it and when), all active modes, and the ban list. Non-operators see everything in a read-only state with no editable controls visible.

**Why this priority**: The read-only view is the foundation for all other stories. It delivers immediate value by giving users a single place to see all channel information at a glance, replacing the need for multiple slash commands.

**Independent Test**: Can be fully tested by opening Channel Central as a non-operator and verifying all sections display correct, read-only information.

**Acceptance Scenarios**:

1. **Given** a user is a member of a channel, **When** they double-click the channel name in the treebar, **Then** the Channel Central dialog opens showing the channel's info, topic, modes, and ban list in read-only form.
2. **Given** a user is a member of a channel, **When** they right-click the channel name in the treebar and select "Channel Central", **Then** the dialog opens with the same information.
3. **Given** the Channel Central dialog is open, **When** the user views the Info section, **Then** they see the channel name, creation date, and current member count.
4. **Given** the Channel Central dialog is open, **When** the user views the Topic section, **Then** they see the current topic text, who set it, and when it was set.
5. **Given** a non-operator opens Channel Central, **When** they view the Modes section, **Then** all mode checkboxes are visible but disabled (grayed out), showing the current state.
6. **Given** a non-operator opens Channel Central, **When** they view the Bans section, **Then** the ban list is visible but no "Add Ban" or "Remove Ban" buttons are shown.
7. **Given** a user is NOT a member of the channel, **When** they attempt to open Channel Central, **Then** the action is rejected with an appropriate message.
8. **Given** Channel Central is open, **When** the user clicks the close button or presses Escape, **Then** the dialog closes.

---

### User Story 2 — Operator Topic Editing (Priority: P2)

Channel operators can edit the topic directly from the Channel Central dialog. The Topic section shows an editable text field pre-filled with the current topic and a "Set Topic" button. Clicking the button applies the new topic to the channel.

**Why this priority**: Topic editing is the most commonly needed operator action and demonstrates the dialog's value as a management tool beyond just viewing information.

**Independent Test**: Can be tested by opening Channel Central as an operator, changing the topic text, clicking "Set Topic", and verifying the channel's topic updates.

**Acceptance Scenarios**:

1. **Given** an operator opens Channel Central, **When** they view the Topic section, **Then** they see an editable text field with the current topic and a "Set Topic" button.
2. **Given** an operator types a new topic and clicks "Set Topic", **When** the action completes, **Then** the channel's topic is updated and all members see the change.
3. **Given** an operator clears the topic field and clicks "Set Topic", **When** the action completes, **Then** the channel's topic is cleared.
4. **Given** a non-operator opens Channel Central, **When** they view the Topic section, **Then** no editable text field or "Set Topic" button is shown — only the read-only topic display.

---

### User Story 3 — Operator Mode Toggles (Priority: P3)

Channel operators can toggle channel modes from the Modes section of Channel Central. Each mode is presented as a labeled checkbox. Key (+k) has an adjacent password field, Limit (+l) has a number input. Changes take effect when the operator clicks "Apply".

**Why this priority**: Mode management is the second most common operator task. The checkbox UI makes it far more discoverable and less error-prone than memorizing `/mode` syntax.

**Independent Test**: Can be tested by opening Channel Central as an operator, toggling a mode checkbox, clicking "Apply", and verifying the mode change takes effect on the channel.

**Acceptance Scenarios**:

1. **Given** an operator opens Channel Central, **When** they view the Modes section, **Then** they see labeled checkboxes for: Moderated (+m), Invite Only (+i), Topic Lock (+t), Key (+k) with a password field, and Limit (+l) with a number input.
2. **Given** an operator checks "Moderated" and clicks "Apply", **When** the action completes, **Then** the channel mode +m is set.
3. **Given** an operator unchecks "Invite Only" and clicks "Apply", **When** the action completes, **Then** the channel mode -i is applied.
4. **Given** an operator checks "Key", enters "secret" in the password field, and clicks "Apply", **When** the action completes, **Then** the channel key is set.
5. **Given** an operator checks "Key" but leaves the password field empty and clicks "Apply", **When** the action completes, **Then** a validation error is displayed and the mode is not changed.
6. **Given** an operator checks "Limit", enters 50 in the number field, and clicks "Apply", **When** the action completes, **Then** the channel user limit is set to 50.
7. **Given** a non-operator opens Channel Central, **When** they view the Modes section, **Then** all checkboxes are disabled and no "Apply" button is shown.

---

### User Story 4 — Operator Ban Management (Priority: P4)

Channel operators can view and manage the ban list from the Bans section. The list shows each banned user along with who set the ban and when. Operators can add new bans and remove existing ones.

**Why this priority**: Ban management completes the core administration surface. While bans can already be managed via `/ban` and context menus, having them in the dialog provides a comprehensive overview.

**Independent Test**: Can be tested by opening Channel Central as an operator, adding a ban via the "Add Ban" button, verifying it appears in the list, then removing it and verifying it disappears.

**Acceptance Scenarios**:

1. **Given** an operator opens Channel Central for a channel with bans, **When** they view the Bans section, **Then** they see a list showing each banned nickname, who set the ban, and when.
2. **Given** an operator clicks "Add Ban", **When** a sub-dialog appears, **Then** they can enter a nickname and confirm to add the ban.
3. **Given** an operator selects a ban in the list and clicks "Remove Ban", **When** the action completes, **Then** the ban is removed from the channel and disappears from the list.
4. **Given** a channel has no bans, **When** the operator views the Bans section, **Then** the list is empty with appropriate placeholder text.
5. **Given** a non-operator opens Channel Central, **When** they view the Bans section, **Then** the ban list is visible but no "Add Ban" or "Remove Ban" buttons are shown.

---

### User Story 5 — Ban Exceptions (+e) (Priority: P5)

The Channel Central dialog includes a Ban Exceptions section showing users who are exempt from bans. Operators can add and remove ban exceptions. When a user matches both a ban and a ban exception, the exception takes precedence and the user is allowed to join.

**Why this priority**: Ban exceptions are a standard IRC feature that adds nuance to ban management. They enable operators to broadly ban patterns while whitelisting specific trusted users.

**Independent Test**: Can be tested by adding a ban exception for a user, banning that user, and verifying they can still join the channel.

**Acceptance Scenarios**:

1. **Given** an operator opens Channel Central, **When** they view the Ban Exceptions section, **Then** they see a list of current ban exceptions (or empty placeholder if none exist).
2. **Given** an operator clicks "Add Exception" in the Ban Exceptions section, **When** they enter a nickname and confirm, **Then** the exception is added to the list.
3. **Given** an operator selects an exception and clicks "Remove Exception", **When** the action completes, **Then** the exception is removed.
4. **Given** a user is banned but also has a ban exception, **When** the user attempts to join the channel, **Then** the exception overrides the ban and the user is allowed to join.
5. **Given** a non-operator opens Channel Central, **When** they view the Ban Exceptions section, **Then** the list is visible but no add/remove controls are shown.

---

### User Story 6 — Invite Exceptions (+I) (Priority: P6)

The Channel Central dialog includes an Invite Exceptions section showing users who can bypass invite-only mode. Operators can add and remove invite exceptions. When a channel is +i (invite-only), users on the invite exception list can join without an explicit invite.

**Why this priority**: Invite exceptions provide a persistent "VIP list" for invite-only channels, avoiding the need for operators to manually invite frequent visitors each time.

**Independent Test**: Can be tested by setting a channel to invite-only, adding a user to the invite exception list, and verifying that user can join without being invited.

**Acceptance Scenarios**:

1. **Given** an operator opens Channel Central, **When** they view the Invite Exceptions section, **Then** they see a list of current invite exceptions (or empty placeholder if none exist).
2. **Given** an operator clicks "Add Exception" in the Invite Exceptions section, **When** they enter a nickname and confirm, **Then** the exception is added to the list.
3. **Given** an operator selects an exception and clicks "Remove Exception", **When** the action completes, **Then** the exception is removed.
4. **Given** a channel is set to +i (invite-only) and a user is on the invite exception list, **When** the user attempts to join, **Then** they are allowed in without an explicit invite.
5. **Given** a channel is set to +i and a user is NOT on the invite exception list and has no invite, **When** the user attempts to join, **Then** they are rejected as before.
6. **Given** a non-operator opens Channel Central, **When** they view the Invite Exceptions section, **Then** the list is visible but no add/remove controls are shown.

---

### User Story 7 — Real-Time Updates (Priority: P7)

The Channel Central dialog reflects changes made by other users or via slash commands in real time. If another operator changes a mode, edits the topic, or modifies the ban list while the dialog is open, the dialog updates immediately without requiring the user to close and reopen it.

**Why this priority**: Real-time updates prevent stale data from causing confusion or conflicting changes. This is important for correctness but builds on top of all other stories.

**Independent Test**: Can be tested by having two operators open: one changes a mode via `/mode`, and the other's Channel Central dialog updates to reflect the change.

**Acceptance Scenarios**:

1. **Given** Channel Central is open, **When** another operator changes the topic via `/topic`, **Then** the Topic section updates to show the new topic, who set it, and when.
2. **Given** Channel Central is open, **When** another operator toggles a mode via `/mode`, **Then** the Modes section updates to reflect the new mode state.
3. **Given** Channel Central is open, **When** another operator bans a user via `/ban`, **Then** the Bans section updates to include the new ban.
4. **Given** Channel Central is open, **When** another operator removes a ban, **Then** the ban disappears from the Bans list.
5. **Given** Channel Central is open, **When** the viewing user's operator status is revoked, **Then** the dialog switches from the operator view to the read-only view (editable controls are removed).

---

### Edge Cases

- Opening Channel Central for a channel the user has already parted should be rejected.
- If the channel is destroyed (all members leave an unregistered channel) while the dialog is open, the dialog should close with a notification.
- Setting +l (limit) to 0 or a negative number should show a validation error.
- Setting +l to a value lower than the current member count should be allowed (existing members stay, new joins are blocked).
- Multiple operators editing the topic simultaneously: last write wins, dialog reflects the final state.
- Adding a ban exception for a user who is not currently banned should succeed (preemptive exception).
- Adding an invite exception when the channel is not currently +i should succeed (preemptive exception).
- Removing the last item from any exception list should leave the list cleanly empty.
- The dialog should be accessible via keyboard navigation (Tab between sections, Enter to activate buttons).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Channel Central dialog accessible by double-clicking a channel name in the treebar.
- **FR-002**: System MUST provide a Channel Central dialog accessible via right-click context menu on the channel name in the treebar.
- **FR-003**: System MUST display an Info section showing: channel name, creation date, and current member count.
- **FR-004**: System MUST display a Topic section showing: current topic text, who set it, and when it was set.
- **FR-005**: System MUST display a Modes section with labeled checkboxes for all supported modes: Moderated (+m), Invite Only (+i), Topic Lock (+t), Key (+k), and Limit (+l).
- **FR-006**: Key (+k) MUST have an adjacent password/text field for the key value. Limit (+l) MUST have an adjacent number input for the limit value.
- **FR-007**: System MUST display a Bans section listing all active bans with: banned nickname, who set the ban, and when.
- **FR-008**: System MUST display a Ban Exceptions section listing all +e entries.
- **FR-009**: System MUST display an Invite Exceptions section listing all +I entries.
- **FR-010**: Operators MUST see editable controls: topic text field with "Set Topic" button, enabled mode checkboxes with "Apply" button, "Add Ban"/"Remove Ban" buttons, "Add Exception"/"Remove Exception" buttons for both exception lists.
- **FR-011**: Non-operators MUST see a fully read-only view with no editable controls — disabled checkboxes, no buttons for editing topic or managing lists.
- **FR-012**: System MUST reject opening Channel Central for a channel the user is not a member of.
- **FR-013**: System MUST validate mode inputs: empty key field for +k shows an error, non-positive limit for +l shows an error.
- **FR-014**: System MUST update the dialog in real time when channel state changes (topic, modes, bans, exceptions) are made by other users or via slash commands.
- **FR-015**: System MUST switch the dialog from operator view to read-only view if the user's operator status is revoked while the dialog is open.
- **FR-016**: Ban exceptions (+e) MUST override matching bans — a user with a ban exception can join despite matching a ban.
- **FR-017**: Invite exceptions (+I) MUST allow listed users to bypass invite-only (+i) mode without an explicit invite.
- **FR-018**: System MUST close the Channel Central dialog when the user presses Escape or clicks the close button.
- **FR-019**: System MUST persist ban exceptions and invite exceptions for registered channels (same pattern as ban persistence).
- **FR-020**: System MUST provide help documentation for the Channel Central dialog, accessible via F1 and the Help menu.

### Key Entities

- **Ban Exception (+e)**: A nickname exempted from ban matching for a specific channel. Attributes: nickname, channel, set by whom, when set.
- **Invite Exception (+I)**: A nickname allowed to bypass invite-only mode for a specific channel. Attributes: nickname, channel, set by whom, when set.
- **Channel Info**: Aggregated view of a channel's state — name, creation date, member count, topic (with metadata), modes, bans, ban exceptions, invite exceptions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Channel members can view all channel information (info, topic, modes, bans, exceptions) from a single dialog in under 2 seconds from opening.
- **SC-002**: Operators can change a channel mode through the dialog with fewer interactions than the equivalent slash command (checkbox + Apply vs. typing `/mode #channel +m`).
- **SC-003**: Non-operators see zero editable controls — no buttons, no enabled inputs, no text fields that accept input.
- **SC-004**: Changes made via slash commands are reflected in an open Channel Central dialog within 1 second.
- **SC-005**: All dialog sections (info, topic, modes, bans, ban exceptions, invite exceptions) are accessible without scrolling on a standard display, or via clear scrollable sections if content exceeds available space.
- **SC-006**: Ban exceptions correctly override bans in 100% of join attempts where both a ban and exception exist for the same user.
- **SC-007**: Invite exceptions correctly bypass invite-only in 100% of join attempts where the user is on the exception list.

## Assumptions

- Topic metadata (who set it, when) is not currently tracked in the server state. The implementation will need to extend the server state to store this metadata. The spec assumes this enrichment will be part of the feature work.
- Ban exception and invite exception lists are new concepts that will require new data structures in the server state and new database tables for persistence.
- The dialog follows the same 2000s-era aesthetic as all other dialogs in the application (using retro design system).
- The Channel Central dialog is modal (blocks interaction with the main chat window while open), consistent with other dialogs in the application.
- Keyboard shortcut for opening Channel Central will be determined during planning (e.g., Alt+C or similar, avoiding conflicts with existing shortcuts).
- The "creation date" in the Info section refers to when the channel's server process was started (already stored as `created_at` in server state), not a persistent historical date.

## Scope

### In Scope

- Channel Central dialog with all six sections (info, topic, modes, bans, ban exceptions, invite exceptions)
- Operator vs. non-operator views (editable vs. read-only)
- Real-time updates via PubSub
- Ban exceptions (+e) backend support and UI
- Invite exceptions (+I) backend support and UI
- Treebar double-click and context menu entry points
- Help documentation for the feature
- Persistence of ban exceptions and invite exceptions for registered channels

### Out of Scope

- Advanced channel modes not yet implemented (+s secret, +p private, +c no colors, +n no external messages) — these will appear as additional checkboxes once their backend support is added in a future feature
- Channel registration management (ChanServ operations)
- User access level management (ChanServ access lists)
- Batch operations (e.g., importing/exporting ban lists)
