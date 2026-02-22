# Feature Specification: Channel Invite System

**Feature Branch**: `010-channel-invite-system`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Invite System for RetroHexChat — /invite command for operators to invite users to invite-only (+i) channels, with notification dialog and auto-join preference."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Operator Invites User to Invite-Only Channel (Priority: P1)

An operator in an invite-only channel (#private, mode +i) wants to bring in a colleague. The operator types `/invite Alice #private`. The system validates that the operator has permission and that the channel is invite-only, then delivers a notification to Alice. The operator sees a confirmation message: `* Inviting Alice to #private`.

**Why this priority**: This is the core feature — without the ability to send invites, the entire system has no value. Invite-only channels are currently dead-ends since no one can enter them once +i is set.

**Independent Test**: Can be fully tested by having an operator send `/invite` and verifying the confirmation message appears. Delivers immediate value by enabling the fundamental invite workflow.

**Acceptance Scenarios**:

1. **Given** an operator is in channel #private which has mode +i set, **When** they type `/invite Alice #private`, **Then** the operator sees `* Inviting Alice to #private` as a system message.
2. **Given** an operator is in channel #private which has mode +i set, **When** they type `/invite Alice` (without specifying a channel), **Then** the system uses the operator's currently active channel as the target.
3. **Given** the operator's active channel is #private (mode +i), **When** they type `/invite Alice`, **Then** the invite is sent for #private.

---

### User Story 2 - Invited User Receives Notification and Joins (Priority: P1)

Alice is connected to the server (in any channel or no channel). She receives a real-time notification that an operator has invited her to #private. A retro-style dialog popup appears with the message: "OperatorNick has invited you to join #private" and two buttons: "Join" and "Ignore". If Alice clicks "Join", she is automatically joined to #private. If she clicks "Ignore", the invitation is dismissed and the dialog closes.

**Why this priority**: Equally critical as Story 1 — the invite is useless without the recipient being able to act on it. Together with Story 1, this forms the complete minimum viable feature.

**Independent Test**: Can be tested by sending an invite and verifying the recipient sees the dialog, can click Join to enter the channel, or click Ignore to dismiss it.

**Acceptance Scenarios**:

1. **Given** Alice is connected and an operator invites her to #private, **When** the invite is delivered, **Then** Alice sees a retro-style dialog with the operator's name, the channel name, and "Join" / "Ignore" buttons.
2. **Given** Alice sees the invite dialog for #private, **When** she clicks "Join", **Then** she is joined to #private and the dialog closes.
3. **Given** Alice sees the invite dialog for #private, **When** she clicks "Ignore", **Then** the dialog closes and she remains where she is.
4. **Given** Alice receives an invite, **When** the invite dialog is displayed, **Then** it does not block the rest of the chat interface — Alice can continue chatting behind the dialog.

---

### User Story 3 - Invite Expiration (Priority: P2)

Invites are time-limited. If Alice does not respond to an invite within 5 minutes, the invite expires. After expiration, clicking "Join" on a stale dialog (if still open) does not grant access. If Alice tries to `/join #private` after the invite expires, the channel still rejects her (since it is +i and the invite is no longer valid).

**Why this priority**: Important for security — without expiration, a one-time invite would grant permanent access, which undermines the purpose of invite-only channels. However, the core flow (Story 1 + 2) works without expiration as a first iteration.

**Independent Test**: Can be tested by sending an invite, waiting for the timeout period, and verifying that the invite no longer grants access to the channel.

**Acceptance Scenarios**:

1. **Given** Alice received an invite to #private 5 minutes ago and has not responded, **When** she clicks "Join" on the dialog, **Then** the system shows an error: "This invitation has expired" and she is not joined.
2. **Given** Alice received an invite to #private 5 minutes ago, **When** she tries `/join #private`, **Then** the join is rejected with the standard invite-only error.
3. **Given** Alice received an invite to #private 3 minutes ago (still valid), **When** she clicks "Join", **Then** she is joined to #private successfully.

---

### User Story 4 - Auto-Join on Invite Preference (Priority: P3)

A user can enable an "Auto-join on invite" preference. When enabled, receiving an invite skips the dialog entirely — the user is immediately joined to the invited channel. A system message notifies them: `* You have been invited to #private by OperatorNick (auto-joined)`. This preference is disabled by default for security.

**Why this priority**: A convenience feature for power users who trust the operators of their server. Not essential for the core invite flow, but improves UX for users who receive frequent invites.

**Independent Test**: Can be tested by enabling the preference, receiving an invite, and verifying the user is auto-joined without a dialog appearing.

**Acceptance Scenarios**:

1. **Given** Alice has "Auto-join on invite" enabled, **When** an operator invites her to #private, **Then** she is immediately joined to #private without any dialog.
2. **Given** Alice has "Auto-join on invite" enabled, **When** she is auto-joined to #private, **Then** she sees a system message: `* You have been invited to #private by OperatorNick (auto-joined)`.
3. **Given** Alice has NOT enabled "Auto-join on invite" (default), **When** an operator invites her to #private, **Then** she sees the standard invite dialog with "Join" / "Ignore" buttons.
4. **Given** Alice wants to change her auto-join preference, **When** she accesses her user preferences, **Then** she can toggle "Auto-join on invite" on or off.

---

### Edge Cases

- **Inviting a user already in the channel**: The operator sees an informational system message: `* Alice is already in #private` — not an error, just feedback.
- **Inviting a non-existent or offline user**: The operator sees: `* User 'Alice' not found`.
- **Non-operator tries to invite**: The user sees: `* You are not a channel operator`.
- **Inviting to a non-invite-only channel**: The operator sees: `* #general is not invite-only — anyone can join`.
- **Channel mode changes during pending invite**: If #private has its +i mode removed while Alice has a pending invite, the invite becomes irrelevant — Alice can join freely. The pending invite dialog (if still open) should still work (clicking "Join" joins her), but the invite is no longer necessary.
- **Multiple pending invites to the same channel**: If Alice receives a second invite to #private while one is already pending, the existing invite timer resets (extends the expiration). Only one dialog is shown at a time for the same channel.
- **Multiple invites to different channels**: Alice can have pending invites to multiple channels simultaneously. Each appears as a separate retro-style dialog, stacked with a slight offset (cascading windows effect), so all are visible and independently actionable.
- **Operator leaves channel after sending invite**: The invite remains valid — it was authorized at send time.
- **Invited user disconnects and reconnects**: Pending invites are lost on disconnect. The invite was an ephemeral, real-time notification.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `/invite` command with syntax `/invite <nickname> [#channel]`.
- **FR-002**: The `/invite` command MUST only be executable by channel operators who are current members of the target channel (having +o status alone is not sufficient — the operator must be in the channel).
- **FR-003**: The `/invite` command MUST only work on channels with invite-only mode (+i) enabled.
- **FR-004**: When an invite is sent, the system MUST deliver a real-time notification to the invited user, regardless of which channel or conversation they are currently viewing.
- **FR-005**: The invite notification MUST be displayed as a retro-style dialog popup with the inviter's nickname, the channel name, and "Join" / "Ignore" action buttons.
- **FR-006**: When the invited user clicks "Join", the system MUST join them to the target channel immediately.
- **FR-007**: When the invited user clicks "Ignore", the system MUST dismiss the dialog with no further action.
- **FR-008**: The operator who sends the invite MUST see a confirmation system message: `* Inviting <nickname> to <channel>`.
- **FR-009**: Invites MUST expire after 5 minutes. After expiration, the invite no longer grants access to the channel.
- **FR-010**: If the invited user attempts to act on an expired invite (clicking "Join" on a stale dialog), the system MUST show an error message indicating the invitation has expired.
- **FR-011**: Users MUST be able to enable an "Auto-join on invite" preference that skips the dialog and automatically joins the user to the invited channel.
- **FR-012**: The "Auto-join on invite" preference MUST be disabled by default.
- **FR-013**: When auto-join is enabled and an invite is received, the system MUST display a system message confirming the auto-join: `* You have been invited to <channel> by <operator> (auto-joined)`.
- **FR-014**: If the target channel is not invite-only, the system MUST reject the invite command with a message indicating the channel is open.
- **FR-015**: If the invited user is already in the channel, the system MUST show an informational message to the operator rather than an error.
- **FR-016**: If the invited user does not exist or is not connected, the system MUST inform the operator that the user was not found.
- **FR-017**: If a non-operator attempts to use `/invite`, the system MUST reject the command with a permission error.
- **FR-018**: If no channel is specified in the command, the system MUST use the operator's currently active channel as the target.
- **FR-019**: Pending invites MUST be ephemeral (in-memory only) — they are lost if the invited user disconnects.
- **FR-020**: If a second invite is sent to the same user for the same channel while one is pending, the system MUST reset the expiration timer rather than creating a duplicate.

### Key Entities

- **Invite**: An ephemeral record representing a pending channel invitation. Key attributes: inviter nickname, invitee nickname, target channel name, creation timestamp, expiration time. Invites exist only in memory and are not persisted to the database.
- **Auto-Join Preference**: A per-user setting indicating whether the user wants to automatically join channels when invited, without seeing a confirmation dialog. Stored as part of the user's session preferences.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can invite a user to an invite-only channel and the invited user can join within 5 seconds of receiving the notification.
- **SC-002**: 100% of invite attempts by non-operators are rejected with a clear permission error.
- **SC-003**: 100% of invite attempts on non-invite-only channels are rejected with a clear informational message.
- **SC-004**: Expired invites (after 5 minutes) are never honored — 100% rejection rate for stale invites.
- **SC-005**: Users with "Auto-join on invite" enabled are joined to the channel within 2 seconds of the invite being sent, with no dialog displayed.
- **SC-006**: The invite dialog does not block the user's chat interface — users can continue reading and sending messages while the dialog is visible.
- **SC-007**: All edge cases (user already in channel, user not found, non-operator, non-invite-only channel) produce clear, distinct feedback messages within 1 second.

## Clarifications

### Session 2026-02-12

- Q: How should multiple simultaneous invite dialogs be presented? → A: Stack simultaneously — all invite dialogs appear at once, slightly offset like cascading retro windows.
- Q: Must the operator be a current member of the channel to send an invite? → A: Yes — the operator must be currently in the channel, not just have +o status from a previous session.

## Assumptions

- The invite system is **ephemeral and in-memory only**. No database tables are needed. Invites are not persisted across server restarts or user reconnections. This matches the real-time, session-based nature of IRC invitations.
- The "Auto-join on invite" preference is stored in the user's in-memory Session (for guests) and can optionally be persisted to the database for registered users. The initial implementation uses in-memory Session only.
- The invite dialog follows the same 2000s-era pattern as existing dialogs in the application (PerformDialog, ChannelCentralDialog, etc.).
- The `/invite` command follows the same Handler behaviour pattern as all other commands in the system.
- Channel operators include the channel owner and any users with +o status in the channel.
- Invite exceptions list (+I mode) and the /knock command are explicitly **out of scope** for this feature.
