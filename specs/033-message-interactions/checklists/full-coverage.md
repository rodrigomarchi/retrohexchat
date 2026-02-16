# Full Coverage Checklist: Quote/Reply & Message Edit/Delete

**Purpose**: Thorough requirements quality validation across UX interactions, server-side enforcement, data model, real-time consistency, and edge cases
**Created**: 2026-02-16
**Feature**: [spec.md](../spec.md)
**Status**: All items resolved (2026-02-16)

## Requirement Completeness

- [x] CHK001 - Are requirements for PM (private message) reply/edit/delete explicitly defined, or only implied by the "same as channel" pattern? [Completeness] — **RESOLVED**: Each user story now explicitly states "This feature applies identically to private messages (PMs)." FR-026 added: all features MUST apply identically to PMs.
- [x] CHK002 - Are requirements defined for what happens when a user enters reply mode while already in edit mode (or vice versa)? [Completeness] — **RESOLVED**: FR-025 added + edge case "Modal conflict (reply + edit)" defines: entering edit cancels reply, entering reply cancels edit (discarding unsaved edit).
- [x] CHK003 - Is the maximum length for reply_to_preview (truncation threshold) explicitly specified? [Completeness] — **RESOLVED**: Truncation defined as 100 characters with "..." throughout spec (FR-002, AS-6 US1, edge cases, data model).
- [x] CHK004 - Are requirements specified for how reply/edit/delete features behave during connection loss or reconnection? [Completeness] — **RESOLVED**: Edge case "Connection loss during edit/reply" added: mode state preserved in client, on reconnect auto-exits if time expired with error toast.
- [x] CHK005 - Is the behavior defined for what the hover reply button looks like and where it appears relative to the message? [Completeness] — **RESOLVED**: FR-027 added: hover reply button (↩ icon) at right edge of message row, positioned absolutely. Touch devices use context menu only.
- [x] CHK006 - Are requirements specified for how existing messages (sent before this feature) render after deployment? [Completeness] — **RESOLVED**: FR-030 added + edge case "Backward compatibility" + data model note: nil fields treated as "not applicable."
- [x] CHK007 - Is the behavior defined for replying to a message that is currently being edited by its author? [Completeness] — **RESOLVED**: Replying is always allowed regardless of edit state. The reply targets the current version of the message. No special behavior needed.
- [x] CHK008 - Are requirements defined for keyboard accessibility of the reply compose bar dismiss button and hover reply button? [Completeness] — **RESOLVED**: FR-028 added: compose bar dismiss and "(editado)" tag MUST be keyboard-accessible (tabindex, Enter/Space). FR-029 added for ARIA.
- [x] CHK009 - Is the behavior specified for pressing ↑ when there are no messages at all in the channel? [Completeness] — **RESOLVED**: US2 AS-10 added: normal command history navigation occurs when no messages exist.

## Requirement Clarity

- [x] CHK010 - Is "briefly highlights" when scrolling to original message quantified with a specific duration? [Clarity] — **RESOLVED**: Defined as "2-second yellow background fade animation" in US1 narrative, AS-3, and FR-004.
- [x] CHK011 - Is "reasonable length" for reply preview truncation defined with a specific character count? [Clarity] — **RESOLVED**: Defined as 100 characters throughout (FR-002, AS-6, edge cases, data model).
- [x] CHK012 - Is "muted style" for deleted message display defined with specific visual properties? [Clarity] — **RESOLVED**: Defined as "--system-messages-color" in FR-014, US3 narrative, showing timestamp but removing author nick.
- [x] CHK013 - Is "distinct border" for edit-mode indicator defined with specific visual properties? [Clarity] — **RESOLVED**: Defined as "dashed border in the highlight color" in FR-006 and US2 narrative.
- [x] CHK014 - Is "within 5 minutes" defined as inclusive or exclusive of the exact 5-minute mark? [Clarity] — **RESOLVED**: Defined as "≤ 300 seconds, inclusive" in FR-005 and FR-010.
- [x] CHK015 - Is the grace period for in-progress edits quantified? Does it have its own time limit? [Clarity] — **RESOLVED**: FR-011 defines "2 additional minutes" grace period. US2 AS-5/AS-6 cover both accepted and rejected scenarios.
- [x] CHK016 - Is "debounce rapid successive edits" quantified with a specific cooldown interval? [Clarity] — **RESOLVED**: FR-021 defines "3-second server-side cooldown" with specific error message "Aguarde alguns segundos antes de editar novamente."
- [x] CHK017 - Is the error message for expired edit/delete window specified? [Clarity] — **RESOLVED**: FR-011 defines "Tempo para edição expirou." and US3 AS-8 defines "Tempo para exclusão expirou."

## Requirement Consistency

- [x] CHK018 - Are the "Responder" and "Quote/Reply" labels consistent? [Consistency] — **RESOLVED**: FR-001 explicitly states: existing "Quote/Reply" item MUST be renamed to "Responder" and enabled. Single label throughout.
- [x] CHK019 - Is the delete menu label consistent? [Consistency] — **RESOLVED**: "Apagar mensagem" used consistently in US3, FR-012, context menu references.
- [x] CHK020 - Do the reply compose bar cancel behaviors align between spec and contracts? [Consistency] — **RESOLVED**: FR-002 now specifies both "✕" button and Escape key. Contracts align with both triggers.
- [x] CHK021 - Are the 5-minute window rules consistent between edit and delete? [Consistency] — **RESOLVED**: FR-012 now explicitly states "Delete has NO grace period." US3 narrative also states this. Edit has grace (FR-011), delete does not — intentional asymmetry documented.
- [x] CHK022 - Is the ↑ key edit trigger condition consistent between spec and research? [Consistency] — **RESOLVED**: FR-005 now includes all 3 conditions: (a) input empty, (b) last message is most recent, (c) within 5 minutes. Research R3 aligns. No ambiguity.

## Acceptance Criteria Quality

- [x] CHK023 - Are acceptance scenarios for US1 testable without visual inspection? [Measurability] — **RESOLVED**: US1 AS-2 now specifies "indented quote with left border" — testable via HTML structure and CSS class assertions.
- [x] CHK024 - Is the "(editado)" tooltip timestamp format specified? [Measurability] — **RESOLVED**: FR-008 defines "HH:MM DD/MM/YYYY" format (UTC). US2 AS-7 repeats the format.
- [x] CHK025 - Are success criteria SC-001 through SC-006 all independently measurable? [Measurability] — **RESOLVED**: SC-001/002/003 rewritten to focus on PubSub broadcast delivery rather than wall-clock latency. SC-005 scoped to "if within loaded pagination window."
- [x] CHK026 - Is "all viewers see the removal within 1 second" measurable? [Measurability] — **RESOLVED**: SC-003 rewritten as "all connected viewers see '[mensagem removida]' via PubSub broadcast" — testable via PubSub subscription in tests.
- [x] CHK027 - Can "identically for both guest and registered users" be objectively verified? [Measurability] — **RESOLVED**: SC-006 now specifies "verified by E2E tests covering both user types" and clarifies "session-based identity" for guests.

## Scenario Coverage — Reply (US1)

- [x] CHK028 - Are requirements defined for replying to a reply (nested reply display)? [Coverage] — **RESOLVED**: US1 AS-8 added: "only the immediate parent is quoted (no nested quote blocks — flat display)."
- [x] CHK029 - Are requirements defined for replying to system/service/error/action type messages? [Coverage] — **RESOLVED**: US1 AS-9 added + FR-001 now lists all types: "including system, service, error, action, and notice types."
- [x] CHK030 - Are requirements defined for the reply compose bar when switching channels? [Coverage] — **RESOLVED**: US1 AS-7 added + FR-024: reply mode is cancelled on channel/PM tab switch.
- [x] CHK031 - Is the scroll-to-message behavior defined when the original is beyond pagination boundary? [Coverage] — **RESOLVED**: US1 AS-10 added + FR-004: "silently ignored" when outside loaded window.
- [x] CHK032 - Are requirements defined for the hover reply button on touch devices? [Coverage] — **RESOLVED**: FR-027 added: "On touch devices (no hover), the context menu 'Responder' item is the only reply trigger."

## Scenario Coverage — Edit (US2)

- [x] CHK033 - Are requirements defined for edit-mode indicator if message scrolls out of view? [Coverage] — **RESOLVED**: The edit-mode indicator is a CSS class on the message element. If the message scrolls out of the viewport, the class remains but is not visible — standard behavior, no special handling needed.
- [x] CHK034 - Is the behavior defined for pressing ↑ when user's last message was an action type? [Coverage] — **RESOLVED**: US2 AS-11 added: "edit mode is triggered for the action message (all user message types are editable)."
- [x] CHK035 - Are requirements defined for edit mode and the formatting toolbar? [Coverage] — **RESOLVED**: Edge case "Editing messages with format codes" added: raw content with mIRC codes loaded into input, formatting toolbar state unchanged.
- [x] CHK036 - Is the behavior specified for multi-tab edit mode? [Coverage] — **RESOLVED**: US2 AS-13 added: "edit mode is per-session, not synchronized across tabs."
- [x] CHK037 - Are requirements defined for edit when content validation fails? [Coverage] — **RESOLVED**: US2 AS-12 added: "system shows an error message and the user remains in edit mode."

## Scenario Coverage — Delete (US3)

- [x] CHK038 - Is the behavior defined for multiple delete dialogs? [Coverage] — **RESOLVED**: US3 AS-7 added + FR-013: "Only one delete dialog can be open at a time" — new replaces old.
- [x] CHK039 - Are requirements defined for deleted message layout? [Coverage] — **RESOLVED**: FR-014 now specifies: "showing the timestamp but removing the author nick display."
- [x] CHK040 - Is the behavior defined for stale context menu? [Coverage] — **RESOLVED**: US3 AS-8 added: if window expires while menu is open, clicking shows error "Tempo para exclusão expirou." instead of dialog.

## Edge Case Coverage

- [x] CHK041 - Is the behavior defined for editing a pending (optimistic UI) message? [Edge Case] — **RESOLVED**: Edge case "Pending message edit" added: edit mode only activates for confirmed messages (those with server-assigned ID).
- [x] CHK042 - Are requirements defined for editing whitespace/format-code-only messages? [Edge Case] — **RESOLVED**: Existing Policy.validate_content/1 already checks for visible text via Formatter.has_visible_text?/1. Editing to whitespace-only fails content validation (US2 AS-12).
- [x] CHK043 - Is the behavior defined when parent is edited significantly? [Edge Case] — **RESOLVED**: FR-022 makes this clear: reply_to_preview is actively updated when parent is edited. Quotes always reflect latest version.
- [x] CHK044 - Are requirements clear about whether reply_to_preview updates live or remains a snapshot? [Conflict] — **RESOLVED**: Conflict eliminated. FR-022 is authoritative: preview IS actively updated. Assumptions section now aligns: "actively updated when the parent message is edited, not a static snapshot."
- [x] CHK045 - Guest session identity continuity on reconnect? [Edge Case] — **RESOLVED**: Edge case "Guest users" updated: "if the guest disconnects and reconnects, they receive a new session and can no longer edit/delete messages from the previous session." FR-016 clarifies "LiveView session identity."

## Non-Functional Requirements

- [x] CHK046 - Are performance requirements defined for bulk reply preview update? [NFR] — **RESOLVED**: Contracts note: "single UPDATE WHERE query." Data model note on migration performance. For high-reply messages, this is a bounded operation (indexed by reply_to_id).
- [x] CHK047 - Are rate-limiting requirements defined for edit/delete? [NFR] — **RESOLVED**: Assumption added: "Edit and delete operations share the existing message send rate limit. The 3-second edit debounce (FR-021) provides additional protection."
- [x] CHK048 - Are accessibility requirements specified for new UI elements? [NFR] — **RESOLVED**: FR-028 (keyboard accessibility) and FR-029 (ARIA/screen reader) added. Contracts specify tabindex, aria-label, role attributes for all new interactive elements.
- [x] CHK049 - Are screen reader requirements defined for deleted messages and reply blocks? [NFR] — **RESOLVED**: FR-029 added: "semantic HTML with appropriate ARIA attributes." Contracts specify aria-label for deleted messages and role="link" for reply blocks.
- [x] CHK050 - Is database migration performance assessed? [NFR] — **RESOLVED**: Data model and Assumptions updated: "PostgreSQL adds nullable columns without rewriting existing rows, so this migration is lightweight even on large tables."

## Dependencies & Assumptions

- [x] CHK051 - Is the existing "Quote/Reply" context menu mapping validated? [Assumption] — **RESOLVED**: FR-001 now explicitly states: "The existing disabled 'Quote/Reply' context menu item MUST be renamed to 'Responder' and enabled." Verified against code exploration.
- [x] CHK052 - Is "edit history not stored" documented as deliberate? [Assumption] — **RESOLVED**: Assumptions section now states: "This is a deliberate product decision to keep the data model simple; edit history may be reconsidered in a future feature."
- [x] CHK053 - Is Channel GenServer dependency documented? [Dependency] — **RESOLVED**: Plan.md constitution check confirms "Edit/delete routed through existing Channel GenServer. No new processes needed." Contracts define GenServer calls.
- [x] CHK054 - Is ON DELETE SET NULL behavior documented? [Dependency] — **RESOLVED**: Edge case "ON DELETE SET NULL" added + data model migration plan documents the FK behavior. FR-023 covers NULL reference display.

## Ambiguities & Conflicts

- [x] CHK055 - FR-022 vs Assumptions: snapshot vs live update conflict? [Conflict] — **RESOLVED**: Conflict eliminated. FR-022 is authoritative. Assumptions rewritten: "actively updated when the parent message is edited (FR-022), not a static snapshot."
- [x] CHK056 - Guest session identity for edit/delete? [Ambiguity] — **RESOLVED**: FR-016 clarified: "For guest users, ownership is determined by LiveView session identity — a new session cannot modify messages from a previous session."
- [x] CHK057 - Edit trigger conditions: 2 vs 3 conditions? [Ambiguity] — **RESOLVED**: FR-005 now explicitly lists all 3 conditions: "(a) input is empty, (b) last message is most recent in channel, and (c) message was sent within 5 minutes." Research R3 aligns.

## Notes

- All 57 items resolved on 2026-02-16
- 3 conflicts eliminated (CHK044/CHK055 snapshot vs live update, CHK022/CHK057 edit trigger conditions, CHK056 guest identity)
- 7 new functional requirements added (FR-024 through FR-030)
- 13 new acceptance scenarios added across all user stories
- 7 new edge cases added to the spec
