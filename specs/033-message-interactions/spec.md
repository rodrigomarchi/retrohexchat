# Feature Specification: Quote/Reply & Message Edit/Delete

**Feature Branch**: `033-message-interactions`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "Quote/Reply & Message Edit/Delete for RetroHexChat"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reply to a Message (Priority: P1)

A user sees a message in the chat and wants to respond specifically to it, making the connection clear to everyone. They right-click the message and select "Responder" from the context menu, or hover over the message and click the reply button (↩ icon) that appears at the right edge of the message row on mouse hover. A compose bar appears above the input area showing "Respondendo a [author] — [truncated message, max 100 chars] ✕". The user types their response and presses Enter. The message appears in the chat with a visual reply block: a compact quoted section (indented, with a left border in the author's nick color) showing the original author and message text, followed by the reply content below. All users in the channel see the same visual format. Clicking the quoted block scrolls to the original message and highlights it with a 2-second yellow background fade animation. If the original message is not in the currently loaded stream (scrolled past the pagination boundary), the scroll-to action is silently ignored (no error shown).

This feature applies identically to private messages (PMs). When replying in a PM conversation, the same compose bar, visual reply block, and scroll-to behavior apply.

**Why this priority**: Replying is the most impactful feature — it transforms a flat message stream into threaded-style conversations, reducing confusion in active channels. Every modern chat considers this essential.

**Independent Test**: Can be fully tested by sending messages and replying to them in a channel. Delivers immediate value by linking related messages visually.

**Acceptance Scenarios**:

1. **Given** a channel with messages, **When** a user right-clicks a message and selects "Responder", **Then** a reply compose bar appears above the input showing the original author and a preview of the message content truncated to 100 characters with ellipsis.
2. **Given** the reply compose bar is active, **When** the user types a response and presses Enter, **Then** the message is sent with a visual reply block (indented quote with left border) linking it to the original message.
3. **Given** a reply message is displayed, **When** any user clicks the quoted block, **Then** the view scrolls to the original message and highlights it with a 2-second yellow background fade.
4. **Given** the reply compose bar is active, **When** the user clicks the "✕" dismiss button or presses Escape, **Then** the compose bar disappears and the input returns to normal send mode.
5. **Given** the original message has been deleted, **When** a reply to it is displayed, **Then** the quoted block shows "Respondendo a [mensagem removida]".
6. **Given** a message with content longer than 100 characters, **When** it is quoted in a reply compose bar or reply block, **Then** the text is truncated at 100 characters with "..." appended.
7. **Given** the user is in reply mode, **When** they switch to a different channel or PM tab, **Then** the reply mode is cancelled and the compose bar is dismissed.
8. **Given** a reply to another reply (nested), **When** displayed, **Then** only the immediate parent is quoted (no nested quote blocks — flat display).
9. **Given** a system, service, error, or action type message, **When** the user attempts to reply, **Then** the reply is allowed (all visible message types are replyable).
10. **Given** a reply message is displayed and the original message is beyond the loaded pagination boundary, **When** the user clicks the quoted block, **Then** nothing happens (scroll-to is silently ignored).

---

### User Story 2 - Edit Own Message (Priority: P2)

A user sends a message with a typo and wants to correct it. With the input field empty, they press the ↑ (arrow up) key. The system checks that (a) the user's last message is the most recent message in the channel, and (b) the message was sent within the last 5 minutes. If both conditions are met, the input fills with their last message text (preserving any mIRC format codes), and the message in the chat gets a dashed border in the highlight color indicating edit mode. The user corrects the text and presses Enter. The message updates in place for all viewers with a small "(editado)" tag appended. Hovering over "(editado)" shows a tooltip with the edit timestamp in "HH:MM DD/MM/YYYY" format (UTC). Pressing Escape instead of Enter cancels the edit, clears the input, and removes the edit indicator. If the edit is submitted with empty content, it is treated as a delete request (confirmation dialog appears).

This feature applies identically to private messages (PMs). When editing in a PM conversation, the same ↑ trigger, visual indicators, and time constraints apply.

**Why this priority**: Message editing is the second most requested feature after replies. Correcting typos is a basic quality-of-life improvement that every chat user expects.

**Independent Test**: Can be tested by sending a message, pressing ↑ to enter edit mode, modifying the text, and confirming the update appears for all connected users.

**Acceptance Scenarios**:

1. **Given** a user has sent at least one message, the input is empty, their last message is the most recent in the channel, and it was sent within 5 minutes, **When** they press ↑, **Then** the input fills with their last sent message text (including format codes) and the message in the chat shows a dashed border edit-mode indicator.
2. **Given** the user is in edit mode, **When** they modify the text and press Enter, **Then** the message is updated in place for all viewers and an "(editado)" tag is displayed.
3. **Given** the user is in edit mode, **When** they press Escape, **Then** the edit is cancelled, the input clears, and the edit indicator is removed from the message.
4. **Given** a user sent a message more than 5 minutes ago, **When** they press ↑ with empty input, **Then** normal command history navigation occurs (edit mode is NOT triggered).
5. **Given** a user is already in edit mode when the 5-minute window expires, **When** they press Enter within 2 additional minutes (grace period), **Then** the edit is accepted.
6. **Given** a user is in edit mode and the grace period (2 minutes after window expiry) has also passed, **When** they press Enter, **Then** the edit is rejected with a system error message: "Tempo para edição expirou."
7. **Given** an edited message, **When** any user hovers over the "(editado)" tag, **Then** a tooltip shows the edit timestamp in "HH:MM DD/MM/YYYY" format (UTC).
8. **Given** the input field contains typed text, **When** the user presses ↑, **Then** normal command history navigation occurs (edit mode is NOT triggered).
9. **Given** the user edits a message to have empty content, **When** they press Enter, **Then** the system opens the delete confirmation dialog instead of submitting an empty edit.
10. **Given** the user has no messages in the channel or there are no messages at all, **When** they press ↑ with empty input, **Then** normal command history navigation occurs.
11. **Given** the user's last message was an action (/me) type, **When** they press ↑ with empty input, **Then** edit mode is triggered for the action message (all user message types are editable).
12. **Given** the user is in edit mode, **When** a content validation error occurs (e.g., exceeds 1000 chars), **Then** the system shows an error message and the user remains in edit mode.
13. **Given** the user has two browser tabs open, **When** they enter edit mode in one tab, **Then** the other tab is unaffected (edit mode is per-session, not synchronized across tabs).

---

### User Story 3 - Delete Own Message (Priority: P3)

A user accidentally sends a message to the wrong channel. They right-click the message and select "Apagar mensagem" from the context menu. A confirmation dialog appears: "Apagar esta mensagem?" with "Confirmar" and "Cancelar" buttons. After confirming, the message is replaced with "[mensagem removida]" in the system message color (--system-messages-color), preserving the timestamp and removing the author nick. Deletion is only available within 5 minutes of sending and only for the user's own messages. Delete does NOT have a grace period (unlike edit) — once the 5-minute window closes, deletion is no longer possible.

This feature applies identically to private messages (PMs).

**Why this priority**: While less frequent than edits, deletion is important for recovering from mistakes. It has lower priority because the edit feature already covers the most common case (typo correction).

**Independent Test**: Can be tested by sending a message, right-clicking it, selecting delete, confirming, and verifying it shows as removed for all connected users.

**Acceptance Scenarios**:

1. **Given** a user's own message sent within the last 5 minutes, **When** they right-click it and select "Apagar mensagem", **Then** a confirmation dialog appears with "Confirmar" and "Cancelar" buttons.
2. **Given** the delete confirmation dialog is open, **When** the user clicks "Confirmar", **Then** the message is replaced with "[mensagem removida]" in system message color for all viewers, showing the timestamp but no author nick.
3. **Given** the delete confirmation dialog is open, **When** the user clicks "Cancelar" or presses Escape, **Then** the dialog closes and the message remains unchanged.
4. **Given** a message sent more than 5 minutes ago, **When** the user right-clicks it, **Then** the "Apagar mensagem" option is disabled with a muted appearance.
5. **Given** a message from another user, **When** the user views the context menu, **Then** the "Responder" item is shown but "Apagar mensagem" is not shown.
6. **Given** a deleted message that had replies referencing it, **When** the reply is displayed, **Then** the quoted block shows "Respondendo a [mensagem removida]".
7. **Given** a delete confirmation dialog is already open, **When** the user right-clicks another message and selects "Apagar mensagem", **Then** the first dialog is replaced by the new one (only one delete dialog at a time).
8. **Given** the context menu is open and the 5-minute window expires while it's visible, **When** the user clicks "Apagar mensagem", **Then** the system shows an error message "Tempo para exclusão expirou." instead of the confirmation dialog.

---

### Edge Cases

- **Reply to deleted message**: The quoted block in the reply shows "Respondendo a [mensagem removida]" instead of the original content. The snapshot is preserved in the reply_to_preview field so the reply remains meaningful in context.
- **Edit a message that has replies**: The reply_to_preview in existing replies is updated in the database and broadcast to all viewers via PubSub, so quotes always reflect the latest version of the parent message.
- **↑ key with other users' messages after**: The ↑ shortcut for edit only triggers if the user's last message is also the last message in the channel AND was sent within 5 minutes. If either condition fails, ↑ does normal history navigation.
- **Rapid successive edits**: Edits are debounced with a 3-second server-side cooldown after each successful edit. Attempts within the cooldown return an error: "Aguarde alguns segundos antes de editar novamente."
- **Long message truncation in reply preview**: Reply compose bar and reply blocks truncate the quoted text to a maximum of 100 characters with "..." appended.
- **Guest users**: Guests can reply to any message, and can edit/delete their own messages within the time window. Guest identity is tracked by LiveView session — if the guest disconnects and reconnects, they receive a new session and can no longer edit/delete messages from the previous session.
- **Edit while 5-minute window expires**: If the user entered edit mode before the window expired, a grace period of 2 additional minutes is granted. After the grace period, the edit is rejected.
- **Modal conflict (reply + edit)**: If the user is in reply mode and presses ↑ to trigger edit mode, the reply mode is cancelled first, then edit mode is entered. If the user is in edit mode and triggers reply, the edit mode is cancelled first (with the edit discarded), then reply mode is entered.
- **Backward compatibility**: Existing messages (sent before this feature) have nil values for all new fields. They render normally — no reply block, no "(editado)" tag, no deleted state. All nil fields are treated as "not applicable."
- **Pending message edit**: If a user presses ↑ immediately after sending and the message is still in pending state (optimistic UI, not yet confirmed), the edit mode is not triggered. The ↑ key only activates edit mode for confirmed messages (those with a server-assigned ID).
- **Connection loss during edit/reply**: If the connection is lost while in edit or reply mode, the mode state is preserved in the client. On reconnection, if the mode is still active but the message is no longer editable (time expired), the system automatically exits the mode and shows an error toast.
- **Editing messages with format codes**: Edit mode preserves mIRC format codes. The raw content (with codes) is loaded into the input. The formatting toolbar state is not changed by entering edit mode.
- **ON DELETE SET NULL**: If a message row is hard-deleted by a database administrator, any reply_to_id references become NULL, and those replies display "Respondendo a [mensagem removida]" — same as soft-delete behavior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow any user to reply to any visible message (including system, service, error, action, and notice types) via context menu ("Responder") or hover reply button. The existing disabled "Quote/Reply" context menu item MUST be renamed to "Responder" and enabled.
- **FR-002**: System MUST display a reply compose bar above the input area showing the original author, message preview truncated to 100 characters with "...", and a dismiss button ("✕"). The compose bar MUST also be dismissable via Escape key.
- **FR-003**: System MUST render reply messages with a visual quoted block: indented content with a left border in the original author's nick color, showing the original author name and truncated preview.
- **FR-004**: System MUST scroll to and highlight the original message (2-second yellow background fade) when a user clicks the quoted block in a reply. If the original message is outside the loaded pagination window, the click is silently ignored.
- **FR-005**: System MUST allow users to edit their own messages by pressing ↑ when: (a) the input is empty, (b) their last message is the most recent in the channel, and (c) the message was sent within the last 5 minutes (≤ 300 seconds, inclusive).
- **FR-006**: System MUST display a dashed border in the highlight color on the message being edited.
- **FR-007**: System MUST update the message in place for all viewers and append an "(editado)" tag after a successful edit.
- **FR-008**: System MUST show the edit timestamp in a tooltip with format "HH:MM DD/MM/YYYY" (UTC) when hovering over the "(editado)" tag. The tooltip MUST be accessible via keyboard focus (tabindex on the tag).
- **FR-009**: System MUST allow users to cancel an edit by pressing Escape, restoring the input to its previous state and removing the edit indicator.
- **FR-010**: System MUST enforce a 5-minute (≤ 300 seconds, inclusive) time window for editing messages, validated on the server side.
- **FR-011**: System MUST grant a grace period of 2 additional minutes for edits already in progress when the 5-minute window expires. After the grace period, the edit MUST be rejected with error message "Tempo para edição expirou."
- **FR-012**: System MUST allow users to delete their own messages via context menu ("Apagar mensagem") within a 5-minute window. Delete has NO grace period — once the window closes, the option is disabled.
- **FR-013**: System MUST show a confirmation dialog ("Apagar esta mensagem?" with "Confirmar" / "Cancelar") before deleting a message. Only one delete dialog can be open at a time.
- **FR-014**: System MUST replace deleted messages with "[mensagem removida]" in the system message color (--system-messages-color) for all viewers, showing the timestamp but removing the author nick display.
- **FR-015**: System MUST perform soft-deletes — the message record remains in the database with a deleted_at timestamp for audit purposes.
- **FR-016**: System MUST NOT allow users to edit or delete other users' messages. For guest users, ownership is determined by LiveView session identity — a new session cannot modify messages from a previous session.
- **FR-017**: System MUST enforce the 5-minute time limit on the server side, not just the client side.
- **FR-018**: System MUST preserve reply context when a message is edited (if the edited message was a reply, the reply reference is kept).
- **FR-019**: System MUST NOT trigger edit mode when the input field contains text — the ↑ key performs normal history navigation in that case.
- **FR-020**: System MUST treat messages edited to empty content as deletion requests (opening the delete confirmation dialog).
- **FR-021**: System MUST enforce a 3-second server-side cooldown between successive edits of the same message. Attempts within the cooldown MUST return error "Aguarde alguns segundos antes de editar novamente."
- **FR-022**: System MUST update reply_to_preview in existing replies when the original message is edited, and broadcast the updated preview to all viewers via PubSub.
- **FR-023**: System MUST show "Respondendo a [mensagem removida]" in replies whose original message has been deleted (or whose reply_to_id reference is NULL due to hard deletion).
- **FR-024**: System MUST cancel reply mode when the user switches to a different channel or PM tab.
- **FR-025**: System MUST resolve modal conflicts: entering edit mode cancels reply mode, and entering reply mode cancels edit mode (discarding unsaved edit).
- **FR-026**: All reply, edit, and delete features MUST apply identically to private messages (PMs), using the same time windows, UI components, and PubSub patterns.
- **FR-027**: The hover reply button (↩ icon) MUST appear at the right edge of the message row on mouse hover, positioned absolutely. On touch devices (no hover), the context menu "Responder" item is the only reply trigger.
- **FR-028**: Reply compose bar dismiss button and "(editado)" tag MUST be keyboard-accessible (focusable via Tab, activatable via Enter/Space).
- **FR-029**: Deleted messages ("[mensagem removida]") and reply quote blocks MUST use semantic HTML with appropriate ARIA attributes for screen reader compatibility.
- **FR-030**: Existing messages (sent before this feature is deployed) MUST render normally — nil values for new fields are treated as "not applicable" (no reply block, no edit tag, no deleted state).

### Key Entities

- **Message**: Extended with reply reference (link to parent message), edit status (edited flag, edit timestamp), and deletion status (soft-delete flag, deletion timestamp). Core entity that already exists with id, channel_name, author_nickname, content, type, and inserted_at.
- **Reply Reference**: A relationship from a reply message to its parent message, storing the parent message ID and a denormalized snapshot of the parent's author and content (max 100 chars). The snapshot is updated when the parent is edited (FR-022). When the parent is deleted or the reference is NULL, the display shows "[mensagem removida]".
- **PrivateMessage**: Extended with the same five new fields as Message, enabling identical reply/edit/delete behavior in PM conversations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can reply to any message with at most 2 interactions (right-click + menu item, or single hover-button click) and see the reply with its quoted block rendered in the chat stream.
- **SC-002**: Users can edit their last message by pressing ↑, modifying text, and pressing Enter — the update appears for all connected viewers via PubSub broadcast.
- **SC-003**: Users can delete their own message with confirmation and all connected viewers see "[mensagem removida]" via PubSub broadcast.
- **SC-004**: The 5-minute edit/delete window is enforced server-side — attempts after the window fail 100% of the time regardless of client manipulation.
- **SC-005**: Clicking a reply's quoted block scrolls to and highlights the original message (if within loaded pagination window).
- **SC-006**: Reply, edit, and delete features work identically for both guest (session-based identity) and registered users, verified by E2E tests covering both user types.

## Assumptions

- The existing message context menu (`:message` type in `chat_context_menu.ex`) has a disabled "Quote/Reply" item that will be renamed to "Responder" and enabled.
- The 5-minute edit/delete window is a fixed system constant (300 seconds), not a user-configurable setting.
- Soft-deleted messages remain in the database indefinitely (no automatic purging).
- Edit history is not stored — only the latest version of a message is kept, along with the edited_at timestamp. This is a deliberate product decision to keep the data model simple; edit history may be reconsidered in a future feature.
- Channel operators have no special edit/delete privileges over other users' messages (this may be added in a future feature).
- The hover reply button follows existing hover-interaction patterns in the UI (similar to nick hover card timing).
- The reply_to_preview is denormalized for efficient rendering (no JOINs needed). It is actively updated when the parent message is edited (FR-022), not a static snapshot. When the parent is deleted, it shows "[mensagem removida]".
- The database migration adds nullable columns with no default values. For existing message tables with large row counts, the migration is lightweight (no table rewrite — Postgres adds nullable columns without rewriting rows).
- Edit and delete operations share the existing message send rate limit. The 3-second edit debounce (FR-021) provides additional protection against edit spam.
