# Research: Quote/Reply & Message Edit/Delete

**Feature Branch**: `033-message-interactions`
**Date**: 2026-02-16

## R1: Message Schema Extension Strategy

**Decision**: Add `reply_to_id`, `reply_to_author`, `reply_to_preview`, `edited_at`, and `deleted_at` columns to the existing `messages` table via a new migration.

**Rationale**: The Message schema currently has no `updated_at` field (write-once model). Adding `edited_at` (nullable) and `deleted_at` (nullable) preserves the write-once default while supporting the new features. Reply reference fields (`reply_to_id` as a self-referential FK, `reply_to_author`, `reply_to_preview`) are stored denormalized for efficient rendering — no JOINs needed to display reply quotes. The snapshot approach (`reply_to_author` + `reply_to_preview`) means replies remain displayable even when the parent is deleted.

**Alternatives considered**:
- Separate `message_replies` join table: Rejected — adds JOIN complexity for every message render with no real benefit since a message can only reply to one parent.
- Storing only `reply_to_id` and loading parent dynamically: Rejected — requires extra queries and breaks when parent is deleted.

## R2: Private Message Reply/Edit/Delete

**Decision**: Apply the same schema extension pattern to `private_messages` table.

**Rationale**: Users expect consistent behavior between channel messages and PMs. The same `reply_to_id`, `reply_to_author`, `reply_to_preview`, `edited_at`, and `deleted_at` fields will be added to `private_messages`.

**Alternatives considered**:
- Channel-only feature: Rejected — inconsistent UX, users will expect parity.

## R3: Edit Mode Trigger (↑ Key)

**Decision**: The ↑ key triggers edit mode only when: (1) the input is empty, (2) the user's last message is the most recent message in the channel, (3) the message was sent within the last 5 minutes.

**Rationale**: This follows the Discord/Slack convention. The "most recent in channel" constraint prevents confusion when other users have posted after the user's message. The keyboard hook already classifies ↑ as `history_up` — we'll add a pre-check: if input is empty and conditions met, push `edit_last_message` event instead of `history_navigate`.

**Alternatives considered**:
- Always allow editing last own message regardless of position: Rejected per spec — ambiguity when others posted after.
- Separate keyboard shortcut (e.g., Ctrl+↑): Rejected — less discoverable than the standard ↑ convention.

## R4: Soft Delete Display

**Decision**: Deleted messages display as "[mensagem removida]" in the system message color (--system-messages-color), preserving the timestamp but removing the author nick. The message remains in the stream with content replaced client-side.

**Rationale**: Soft delete preserves message IDs (important for reply references) and audit trail. Displaying "[mensagem removida]" (vs hiding entirely) maintains conversation context for other users who may have seen the original. Using the existing system message color ensures visual consistency with other non-user content.

**Alternatives considered**:
- Complete removal from stream: Rejected — breaks reply context and confuses users who saw the original.
- Configurable per user (show/hide deleted): Considered but deferred to avoid scope creep.

## R5: PubSub Events for Edit/Delete

**Decision**: Broadcast two new events on existing channel/PM topics: `message_edited` and `message_deleted`.

**Rationale**: Reuses the existing PubSub topic structure (`"channel:#{name}"`, `"pm:#{sorted}"`) so all subscribers receive updates. Event payloads carry the message ID plus updated fields, allowing clients to update their streams in-place.

**Alternatives considered**:
- Reusing `new_message` event with a flag: Rejected — semantically different operations should have distinct events for clarity.

## R6: Server-Side Time Window Enforcement

**Decision**: The 5-minute window is enforced in `Chat.Policy` with a new `can_edit?/2` and `can_delete?/2` function that compares `DateTime.utc_now()` against `message.inserted_at`.

**Rationale**: Server-side enforcement is non-negotiable per spec. Policy module already handles `validate_content/1` and `check_rate_limit/2` — this is the natural home for authorization checks. The 5-minute window is defined as ≤ 300 seconds (inclusive). The grace period for in-progress edits grants 2 additional minutes (120 seconds) — the client sends `edit_started_at` timestamp, and if the user started editing within the original window, they have until 7 minutes total to submit. Delete has NO grace period.

**Alternatives considered**:
- GenServer-level enforcement in Channel Server: Rejected — Policy module is the established authorization boundary.
- No grace period: Rejected per spec requirement.
- Unbounded grace period: Rejected — must have a finite limit (2 minutes chosen as reasonable).

## R7: Reply Compose Bar Placement

**Decision**: The reply compose bar renders between the formatting toolbar and the input form, inside the `chat-input-area`.

**Rationale**: This matches the standard chat UI pattern (Discord, Slack, Telegram all show the reply bar directly above the input). The formatting toolbar is already above the input — the reply bar slots between them. A new component `ReplyComposeBar` will handle this.

**Alternatives considered**:
- Above the formatting toolbar: Rejected — too far from the input, less natural.
- Inside the input as a prefix: Rejected — conflicts with text editing.

## R8: Edit Debounce Strategy

**Decision**: Debounce rapid edits with a 3-second cooldown after each successful edit.

**Rationale**: Prevents spam while still allowing corrections. The cooldown is enforced server-side in `Chat.Policy` by comparing `edited_at` against the current time. 3 seconds is short enough to not frustrate legitimate use but long enough to prevent abuse.

**Alternatives considered**:
- No debounce (rate limit only): Rejected — existing rate limit is per-message, not per-edit.
- Longer cooldown (10s): Rejected — too frustrating for quick successive corrections.
