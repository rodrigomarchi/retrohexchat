# Feature Specification: Visual Feedback & Unread Indicators

**Feature Branch**: `030-visual-feedback-unread`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Visual Feedback & Unread Indicators for RetroHexChat"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Treebar Unread Indicators (Priority: P1)

As a user with multiple channels open, I want to see which channels have unread messages, mentions, or are muted so I can prioritize where to look first without switching to each channel.

The treebar displays 6 visual states for each channel/PM entry:
- **Normal**: Default appearance — no unread activity.
- **Unread**: Bold text — new user messages arrived since last visit.
- **Highlight**: Red dot badge — the user's nickname was mentioned.
- **Active**: Selected background — the channel the user is currently viewing.
- **Muted**: Grayed-out text, no badges — the user has silenced this channel.
- **Disconnected**: Lightning icon with gray text — channel connection lost.

A numeric badge shows the count of unread user messages (e.g., "3"). Counts above 99 display as "99+". When the user switches to a channel, its unread state and count reset to zero. System messages (joins, parts, quits, mode changes) do not increment the unread count — only user-authored messages and highlights do.

**Why this priority**: Unread indicators are the single most impactful visual feedback feature — they help users navigate multi-channel conversations efficiently and are visible at all times.

**Independent Test**: Can be tested by joining 3+ channels, sending messages from another user in non-active channels, and verifying bold text / numeric badges / red dots appear correctly in the treebar.

**Acceptance Scenarios**:

1. **Given** a user is in #general and #random, **When** a user message arrives in #random, **Then** #random shows bold text and a "1" badge in the treebar.
2. **Given** #random has 5 unread messages, **When** the user switches to #random, **Then** the badge disappears and text returns to normal weight.
3. **Given** a user message in #random mentions the current user's nick, **When** the treebar updates, **Then** #random shows a red dot badge in addition to the numeric badge.
4. **Given** a system message (user join) arrives in #random, **When** the treebar updates, **Then** the unread count does NOT increment.
5. **Given** #random is muted, **When** messages arrive in #random, **Then** #random remains grayed out with no badges.
6. **Given** #random has 100+ unread messages, **When** the treebar displays the count, **Then** it shows "99+".
7. **Given** the user is disconnected from #random, **When** the treebar renders, **Then** #random shows a lightning icon with gray text.

---

### User Story 2 - Kick Notification Dialog (Priority: P2)

As a user who is kicked from a channel, I want to see a clear dialog telling me who kicked me, from which channel, and why, so I understand what happened and can decide my next action.

When the user is kicked from a channel, a modal dialog appears with the message: "Você foi expulso de #canal por AdminNick: motivo". The dialog has an OK button the user must click to dismiss — it does not auto-dismiss. If the user is kicked from multiple channels simultaneously, the dialogs queue and display one at a time.

**Why this priority**: Being kicked is a disruptive event that currently provides no clear notification, leaving users confused about what happened.

**Independent Test**: Can be tested by having an operator kick a user from a channel and verifying the dialog appears with correct information.

**Acceptance Scenarios**:

1. **Given** a user is in #general, **When** an operator kicks them with reason "spam", **Then** a dialog appears: "Você foi expulso de #general por OperatorNick: spam" with an OK button.
2. **Given** the kick dialog is open, **When** the user clicks OK, **Then** the dialog closes and the channel is removed from the treebar.
3. **Given** the user is kicked from #general and #random simultaneously, **When** the first dialog is dismissed, **Then** the second dialog appears.
4. **Given** the kick had no reason provided, **When** the dialog appears, **Then** it shows: "Você foi expulso de #canal por AdminNick" (no trailing colon or empty reason).

---

### User Story 3 - Copy & Settings Confirmation Toasts (Priority: P3)

As a user who copies text or saves settings, I want brief visual confirmation so I know the action succeeded.

When the user copies text from the chat (via context menu, keyboard shortcut, or selection), a toast notification appears at the bottom-right: "Copiado!" and fades after 2 seconds. When the user saves settings (clicks OK/Apply in Options), a toast appears: "Configurações salvas" and fades after 2 seconds. These toasts reuse the existing toast component from the Contextual Tips feature (Category Z2). A maximum of 3 toasts may be visible at once — additional toasts queue until a slot opens.

**Why this priority**: Copy and save operations are frequent micro-interactions that benefit from subtle confirmation, but the feature is low-risk and builds on existing infrastructure.

**Independent Test**: Can be tested by copying text and verifying the "Copiado!" toast appears, and by saving settings and verifying the "Configurações salvas" toast appears.

**Acceptance Scenarios**:

1. **Given** the user selects text in the chat, **When** they copy (Ctrl+C or context menu), **Then** a "Copiado!" toast appears at the bottom-right and fades after 2 seconds.
2. **Given** the user is in Options, **When** they click OK or Apply, **Then** a "Configurações salvas" toast appears and fades after 2 seconds.
3. **Given** 3 toasts are already visible, **When** a 4th toast is triggered, **Then** it queues and appears when a slot opens.
4. **Given** a toast is visible, **When** 2 seconds elapse, **Then** the toast fades out and is removed.

---

### User Story 4 - Optimistic Message Send with Retry (Priority: P4)

As a user sending a message, I want to see my message appear instantly in the chat (before server confirmation) so the conversation feels responsive, and I want clear feedback if the send fails with the ability to retry.

When the user sends a message, it appears immediately in the chat with a subtle pending visual state (slightly faded or with a small indicator). Once the server confirms delivery, the pending state disappears and the message appears normal. If the send fails, a warning icon appears next to the message with a tooltip: "Falha ao enviar. Clique para reenviar". Clicking the icon retries the send. Failed messages remain visually distinct from successful messages even after scrolling. Each failed message has its own independent retry button.

**Why this priority**: Optimistic UI improves perceived performance significantly, but is the most complex user story involving message lifecycle management, so it is lower priority than simpler visual feedback.

**Independent Test**: Can be tested by sending a message and verifying it appears immediately with a pending state, then verifying the state clears on server confirmation.

**Acceptance Scenarios**:

1. **Given** the user types a message and presses Enter, **When** the message is submitted, **Then** it appears instantly in the chat with a subtle pending visual state.
2. **Given** a pending message, **When** the server confirms delivery, **Then** the pending visual state disappears and the message looks normal.
3. **Given** a pending message, **When** the server fails to deliver it, **Then** a warning icon appears with tooltip "Falha ao enviar. Clique para reenviar".
4. **Given** a failed message with a retry button, **When** the user clicks the retry icon, **Then** the message returns to pending state and is re-sent.
5. **Given** 3 messages fail to send, **When** the user views the chat, **Then** each failed message has its own independent retry button.
6. **Given** a failed message, **When** the user scrolls away and back, **Then** the failed state and retry button are still visible.

---

### User Story 5 - Channel Join Flash (Priority: P5)

As a user who just joined a new channel, I want the treebar entry to briefly flash (green highlight) so I have visual confirmation that the join succeeded and can easily locate the new channel.

When a channel is successfully joined, its treebar entry flashes with a green highlight for approximately 1 second before returning to normal (or active) state.

**Why this priority**: A minor polish feature — joining a channel already has functional confirmation (the channel appears in the treebar), but the flash adds a satisfying visual cue.

**Independent Test**: Can be tested by joining a channel via /join and verifying the treebar item flashes green briefly.

**Acceptance Scenarios**:

1. **Given** the user is connected, **When** they join #newchannel via /join, **Then** the #newchannel treebar entry flashes green for approximately 1 second.
2. **Given** the join flash is active, **When** 1 second elapses, **Then** the flash ends and the entry shows its normal (or active) state.

---

### Edge Cases

- What happens when the user rapidly switches between channels? Unread counts must update atomically — no race conditions that could show stale counts.
- What happens when a user is kicked while a kick dialog is already open? The new kick dialog queues behind the current one.
- What happens when the user copies text but the clipboard operation fails? No toast appears — only show "Copiado!" on confirmed clipboard write.
- What happens when there are more than 99 unread messages in a channel? The badge shows "99+".
- What happens when a muted channel receives a mention? The mention is tracked internally but no visual indicator is shown while the channel is muted. When the user unmutes, accumulated indicators appear.
- What happens when a failed message references a channel the user has since left? The retry button is disabled or removed with a tooltip explaining the channel is no longer available.
- What happens when the treebar is hidden (user toggled it off in Display settings)? Unread tracking continues in the background — when the treebar is re-shown, it reflects the current unread state.

## Requirements *(mandatory)*

### Functional Requirements

**Unread Indicators (Treebar)**

- **FR-001**: System MUST display bold text for treebar entries with unread user messages.
- **FR-002**: System MUST display a numeric badge showing the count of unread messages per channel.
- **FR-003**: System MUST display a red dot badge for channels where the user's nickname was mentioned.
- **FR-004**: System MUST display the active channel with a selected/highlighted background in the treebar.
- **FR-005**: System MUST display muted channels with grayed-out text and suppress all badges for muted channels.
- **FR-006**: System MUST display disconnected channels with a lightning icon and gray text.
- **FR-007**: System MUST reset the unread count and badges for a channel when the user switches to that channel.
- **FR-008**: System MUST NOT count system messages (joins, parts, quits, mode changes, topic changes) toward the unread count — only user-authored messages and highlights increment the count.
- **FR-009**: System MUST display "99+" when the unread count for a channel exceeds 99.
- **FR-010**: System MUST continue tracking unread state in the background when the treebar is hidden, and display the correct state when the treebar is re-shown.

**Kick Dialog**

- **FR-011**: System MUST display a modal dialog when the user is kicked from a channel, showing the channel name, the kicking operator's nickname, and the kick reason.
- **FR-012**: The kick dialog MUST require the user to click OK to dismiss — it MUST NOT auto-dismiss.
- **FR-013**: System MUST queue kick dialogs when the user is kicked from multiple channels simultaneously, displaying them one at a time.
- **FR-014**: System MUST omit the reason portion of the kick message when no reason is provided.

**Copy & Settings Toasts**

- **FR-015**: System MUST display a "Copiado!" toast at the bottom-right when text is successfully copied to the clipboard.
- **FR-016**: System MUST display a "Configurações salvas" toast when settings are saved via OK or Apply.
- **FR-017**: Toasts MUST fade out after 2 seconds.
- **FR-018**: System MUST NOT display more than 3 toasts simultaneously — additional toasts MUST queue.

**Optimistic Message Send**

- **FR-019**: System MUST display the user's message immediately in the chat upon submission, before server confirmation.
- **FR-020**: System MUST show a subtle pending visual state (e.g., slightly faded appearance) for messages awaiting server confirmation.
- **FR-021**: System MUST remove the pending visual state once the server confirms successful delivery.
- **FR-022**: System MUST display a warning icon with tooltip "Falha ao enviar. Clique para reenviar" for messages that fail to send.
- **FR-023**: System MUST retry sending a failed message when the user clicks the retry icon.
- **FR-024**: Each failed message MUST have its own independent retry button.
- **FR-025**: Failed messages MUST remain visually distinct from successful messages, even after scrolling.

**Channel Join Flash**

- **FR-026**: System MUST briefly flash the treebar entry green (approximately 1 second) when a channel is successfully joined.

### Key Entities

- **Unread State**: Per-channel tracking of unread message count, highlight (mention) flag, and muted flag. Resets on channel switch. Stored in client session (not persisted to database).
- **Message Status**: Per-message lifecycle state: pending, confirmed, or failed. Used for optimistic UI rendering. Ephemeral (not persisted).
- **Kick Event**: Channel name, operator nickname, and optional reason. Triggers a queued dialog. Ephemeral.
- **Toast Notification**: Message text, duration, and queue position. Reuses the existing toast component from Category Z2. Ephemeral.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify which channels have unread messages within 1 second of looking at the treebar.
- **SC-002**: 100% of user-sent messages appear in the chat within 100 milliseconds of pressing Enter (optimistic display).
- **SC-003**: Failed messages show a retry option within 2 seconds of the failure, and retry succeeds on the next attempt when connectivity is restored.
- **SC-004**: Users acknowledge a kick event by clicking OK on every kick dialog — no kick events are silently lost.
- **SC-005**: Copy confirmation toast appears and fades within 2 seconds, providing clear visual feedback for 100% of successful copy operations.
- **SC-006**: Unread counts remain accurate when the user switches between channels rapidly (10+ switches in 5 seconds).
- **SC-007**: All 6 treebar visual states (normal, unread, highlight, active, muted, disconnected) are visually distinct and distinguishable from each other.
- **SC-008**: The system handles at least 20 simultaneous channels with independent unread tracking without visible performance degradation.

## Scope

### In Scope

- Optimistic message send with pending state, failure detection, and retry
- Channel join flash in treebar (green highlight, ~1 second)
- Kick dialog (98.css styled, queued, requires OK to dismiss)
- Copy confirmation toast ("Copiado!", 2 seconds, via Z2 toast component)
- Settings save confirmation toast ("Configurações salvas", 2 seconds, via Z2 toast component)
- 6 treebar visual states: normal, unread, highlight, active, muted, disconnected
- Unread message count badges (numeric, "99+" cap)
- Mention indicator (red dot badge)
- Unread state reset on channel switch

### Out of Scope

- Status bar enhancements (Category AB2)
- Loading states and spinners (Category AB2)
- Desktop/browser notifications (Category AC)
- Sound feedback for events (Category O)
- Unread count persistence across sessions (counts reset on reconnect)

## Assumptions

- The toast component from Category Z2 (Contextual Tips) is available and supports arbitrary message text, custom duration, and queue management.
- The treebar already renders channel entries — this feature adds visual state differentiation to existing entries.
- Muted channel state is already tracked via `muted_channels` MapSet in the session (from existing feature).
- Unread channels and highlight channels are already tracked via `unread_channels` and `highlight_channels` MapSets — this feature adds numeric counts and visual rendering.
- The kick event is already handled functionally (channel is removed) — this feature adds the user-facing dialog notification.
- Clipboard copy events can be detected reliably in the browser to trigger the confirmation toast.

## Dependencies

- **Category Z2 (Contextual Tips)**: Provides the reusable toast component for copy and settings confirmation toasts.
- **Existing treebar component**: The treebar already renders channel/PM entries — this feature layers visual states on top.
- **Existing mute/unread tracking**: `muted_channels`, `unread_channels`, and `highlight_channels` assigns already exist in ChatLive.
