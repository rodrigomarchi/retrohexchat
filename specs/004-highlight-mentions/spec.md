# Feature Specification: Highlight / Mentions

**Feature Branch**: `004-highlight-mentions`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Highlight / Mentions for RetroHexChat — own-nick highlighting, custom highlight words with per-word colors, notification sound, treebar/switchbar flash, configuration dialog."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Own-Nick Highlighting (Priority: P1)

A connected user receives messages in any channel. When another user sends a message containing the recipient's nickname as a whole word, that message line is rendered with a distinct highlight background color. This happens automatically with no configuration — the user's own nickname is always a highlight word. The user's own messages never trigger self-highlights.

**Why this priority**: This is the core value of the feature. Every IRC client since the 1990s highlights the user's own nick. Without this, the feature has no foundation.

**Independent Test**: Can be fully tested by connecting two users to the same channel, having one mention the other's nick, and verifying the message renders with highlight styling. Delivers immediate value — users can spot when they're mentioned.

**Acceptance Scenarios**:

1. **Given** user "Alice" is connected and viewing #elixir, **When** another user sends "hey Alice, check this out", **Then** the entire message line is rendered with the default highlight background color.
2. **Given** user "Alice" is connected to #elixir, **When** Alice sends a message containing "Alice", **Then** the message is NOT highlighted (no self-highlight).
3. **Given** user "Alice" is connected, **When** another user sends "Ali is great", **Then** the message is NOT highlighted (whole-word matching only — "Ali" does not match "Alice").
4. **Given** user "Alice" is connected, **When** another user sends "hey ALICE", **Then** the message IS highlighted (case-insensitive matching).
5. **Given** a message contains the user's nick inside a URL (e.g., "https://example.com/Alice/profile"), **Then** the message is NOT highlighted.
6. **Given** a system message contains the user's nick (e.g., "Alice has joined #elixir"), **Then** the system message is NOT highlighted.

---

### User Story 2 - Non-Active Channel Flash (Priority: P2)

When a highlight occurs in a channel that is not the user's currently active/focused channel, the treebar entry and switchbar tab for that channel flash to draw attention. This ensures the user notices mentions even when reading a different channel.

**Why this priority**: Highlighting in the active channel is useful, but the real urgency is knowing about mentions in channels you're not looking at. This is the second-most impactful behavior after visual highlighting itself.

**Independent Test**: Can be tested by connecting a user to two channels, making one active, triggering a highlight in the other, and verifying the inactive channel's treebar/switchbar entry flashes.

**Acceptance Scenarios**:

1. **Given** user "Alice" has joined #elixir and #general, and #elixir is the active channel, **When** another user mentions "Alice" in #general, **Then** the treebar entry and switchbar tab for #general flash visually.
2. **Given** user "Alice" is viewing #elixir (active), **When** another user mentions "Alice" in #elixir, **Then** the treebar/switchbar for #elixir do NOT flash (it's already active and visible).
3. **Given** a channel's treebar entry is flashing, **When** the user switches to that channel, **Then** the flashing stops immediately.

---

### User Story 3 - Notification Sound (Priority: P3)

When a highlight is triggered (own nick or custom word), a notification sound plays to alert the user audibly. This complements the visual highlighting and flashing.

**Why this priority**: Sound is an important secondary alert mechanism, but visual highlighting alone (US1 + US2) delivers substantial value without it. Sound enhances but is not essential.

**Independent Test**: Can be tested by triggering a highlight and verifying a sound plays. Verify sound does NOT play for non-highlighted messages.

**Acceptance Scenarios**:

1. **Given** a highlight is triggered in any channel, **When** the message is received, **Then** a notification sound plays once.
2. **Given** a highlight is triggered but the user has muted notifications for that channel, **When** the message is received, **Then** no sound plays (but the message text is still visually highlighted).
3. **Given** multiple highlights arrive in rapid succession, **When** messages are received, **Then** sounds should not overlap excessively (a brief cooldown or single sound per batch is acceptable).

---

### User Story 4 - Custom Highlight Words (Priority: P4)

Users can configure a list of custom words that trigger highlighting in addition to their own nickname. Each word uses whole-word, case-insensitive matching. When a message contains any custom highlight word, it is highlighted just like a nick mention.

**Why this priority**: Custom words extend the feature's utility beyond nick mentions, letting users track topics of interest. Requires US1 as foundation.

**Independent Test**: Can be tested by adding "phoenix" to the highlight list, sending a message containing "phoenix" in a channel, and verifying it highlights. Delivers value for users who want to track specific topics.

**Acceptance Scenarios**:

1. **Given** user has added "phoenix" to their highlight words, **When** someone sends "I love phoenix framework", **Then** the message is highlighted with the default highlight color.
2. **Given** user has added "deploy" with a custom red background, **When** someone sends "we need to deploy now", **Then** the message is highlighted with the red background.
3. **Given** user has "phoenix" and "deploy" in their list, **When** a message contains both words, **Then** the highest-priority color wins (own nick > custom words in list order).
4. **Given** no custom words configured (default state), **When** any non-nick-mention message is received, **Then** no highlight occurs (only own nick triggers highlights by default).
5. **Given** user has added "go", **When** someone sends "let's go!", **Then** the message IS highlighted ("go" is a whole word match).
6. **Given** user has added "go", **When** someone sends "going forward", **Then** the message is NOT highlighted ("go" does not match "going" — whole-word only).

---

### User Story 5 - Highlight Configuration Dialog (Priority: P5)

Users can open a Highlight configuration dialog to manage their custom highlight words. The dialog allows adding, editing, and removing highlight words, setting per-word custom colors, and previewing the highlight appearance. The dialog follows the retro aesthetic using retro design system.

**Why this priority**: Configuration UI is needed for US4 but the underlying highlight engine (US1) works independently. This is the delivery mechanism for customization.

**Independent Test**: Can be tested by opening the dialog, adding/editing/removing words, and verifying the changes persist and take effect in the chat. For registered users, verify persistence across sessions.

**Acceptance Scenarios**:

1. **Given** the user is connected, **When** they open the Highlight configuration dialog, **Then** they see their current highlight word list (empty by default, own nick is shown as always-on and non-removable).
2. **Given** the dialog is open, **When** the user adds a new word "liveview", **Then** it appears in the list and immediately takes effect for new messages.
3. **Given** the dialog is open and "phoenix" is in the list, **When** the user sets a custom background color (blue) for "phoenix", **Then** messages matching "phoenix" use the blue background.
4. **Given** the dialog is open and "deploy" is in the list, **When** the user removes "deploy", **Then** it is removed from the list and no longer triggers highlights.
5. **Given** a registered user configures highlight words, **When** they disconnect and reconnect (after identifying with NickServ), **Then** their highlight word list and custom colors are restored.
6. **Given** a guest user configures highlight words, **When** they remain connected, **Then** highlight words work for the duration of the session (no persistence across sessions for guests).

---

### Edge Cases

- What happens when the user's nickname changes (via /nick)? Highlighting must update to the new nickname immediately.
- What happens when a highlight word is a substring of the user's nick (e.g., word "Ali" and nick "Alice")? Both are evaluated independently with whole-word matching — "Ali" matches "Ali" but not "Alice".
- What happens when the highlight word list is very long (e.g., 50+ words)? Performance must remain acceptable — matching should complete within the message rendering pipeline without visible delay.
- What happens when a message contains formatting codes (bold, color) around the highlighted word? Matching should work on the plain text content, ignoring formatting codes.
- What happens when a channel has muted notifications? Sound and flash are suppressed, but visual text highlighting still applies.
- What happens when the same word appears multiple times in a message? The message is highlighted once (line-level highlight, not per-word inline highlight).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST highlight the entire message line when it contains the user's own nickname as a whole word (case-insensitive), applying a default highlight background color.
- **FR-002**: System MUST NOT highlight messages sent by the user themselves (no self-highlight).
- **FR-003**: System MUST use whole-word matching only — partial word matches do not trigger highlights.
- **FR-004**: System MUST perform case-insensitive matching for all highlight words.
- **FR-005**: System MUST NOT highlight words that appear inside URLs within a message.
- **FR-006**: System MUST NOT highlight system messages (join/part/quit/mode/kick/etc.).
- **FR-007**: System MUST flash the treebar entry and switchbar tab for a channel when a highlight occurs and that channel is not the user's currently active channel.
- **FR-008**: System MUST stop flashing a channel's treebar/switchbar entry when the user switches to that channel.
- **FR-009**: System MUST play a notification sound when a highlight is triggered.
- **FR-010**: System MUST suppress sound and flash (but not visual text highlighting) for channels where the user has muted notifications.
- **FR-011**: System MUST allow users to add custom highlight words beyond their own nickname.
- **FR-012**: System MUST allow users to set an optional custom background color for each highlight word.
- **FR-013**: When a message matches multiple highlight words, the system MUST apply the highest-priority color: own nickname highlight takes precedence over custom words; among custom words, the first match in list order wins.
- **FR-014**: System MUST provide a configuration dialog (retro aesthetic) for managing the highlight word list (add, edit, remove) and per-word colors.
- **FR-015**: System MUST persist highlight word configuration across sessions for registered users (loaded upon NickServ identification).
- **FR-016**: System MUST support highlight words for the duration of the session for guest users (no persistence).
- **FR-017**: System MUST update own-nick highlighting immediately when the user changes their nickname.
- **FR-018**: Highlight processing MUST be purely local — no information about a user's highlight words is transmitted to other users or the server-side channel state.
- **FR-019**: System MUST match highlight words against the plain text content of a message, ignoring any formatting codes (bold, color, etc.).
- **FR-020**: The default highlight word list MUST be empty (only the user's own nickname is highlighted by default, with no additional configuration needed).

### Key Entities

- **Highlight Word**: A user-configured word or phrase to watch for. Attributes: word text, optional custom background color, position/order in the list.
- **Highlight Match**: A transient result of evaluating a message against the user's highlight word list. Determines whether to highlight, which color to use, and whether to trigger sound/flash.
- **Highlight Settings**: Per-user configuration including the list of highlight words with their colors and the default highlight color. Persisted for registered users, in-memory for guests.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify messages mentioning their nickname within 1 second of the message appearing, due to the distinct visual highlight.
- **SC-002**: Users notice mentions in non-active channels within 3 seconds, due to treebar/switchbar flashing and notification sound.
- **SC-003**: Custom highlight words can be configured in under 30 seconds (add a word, optionally set a color, save).
- **SC-004**: Highlight matching introduces no perceptible delay to message rendering (message appears as fast as non-highlighted messages).
- **SC-005**: Registered users' highlight configuration survives disconnection and reconnection without data loss.
- **SC-006**: 100% of highlight activity is invisible to other users — no side effects, broadcasts, or state leaks.

## Assumptions

- The notification sound will be a single, short audio file bundled with the application (no user-customizable sounds in this scope).
- "Muted notifications" refers to an existing or future per-channel mute toggle — if not yet implemented, sound/flash suppression for muted channels is deferred until the mute feature exists, but the highlight engine supports the concept.
- The default highlight background color is a bright yellow (consistent with mIRC conventions) — can be adjusted during implementation.
- The color picker for custom highlight word colors reuses the existing 16-color IRC palette already available in the application (from the text formatting feature).
- Highlight matching applies to the message body only, not to sender nicknames displayed in the message prefix.
- The configuration dialog is accessible via a menu item or keyboard shortcut (specific trigger to be determined during planning).
- "List order" for priority means the order in which words appear in the user's highlight word list, top to bottom.

## Scope

### In Scope

- Own-nick highlighting (on by default, no setup required)
- Custom highlight word list with per-word optional colors
- Notification sound on highlight
- Treebar and switchbar flash on highlight in non-active channels
- Highlight configuration dialog (retro aesthetic)
- Persistence for registered users, session-only for guests
- Whole-word, case-insensitive matching
- URL exclusion and system message exclusion

### Out of Scope

- Regex patterns for highlight matching
- Highlight logging or history
- User-customizable notification sounds
- Per-channel highlight word lists (highlight words apply globally across all channels)
- Inline per-word highlighting within a message (the entire message line is highlighted, not individual words)
