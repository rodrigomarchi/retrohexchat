# Feature Specification: Miscellaneous Polish

**Feature Branch**: `022-misc-polish`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Miscellaneous / Polish for RetroHexChat — 13 usability improvements covering double-click actions, copy support, nick alignment, help references, quit messages, away auto-reply, paste safety, character counter, emoji support, and timestamp configuration."

## Clarifications

### Session 2026-02-13

- Q: Should there be a hard maximum number of lines for multi-line paste beyond which "Send All" is disabled? → A: Hard cap at 100 lines — "Send All" disabled beyond this; dialog suggests using a pastebin.
- Q: When sending multiple lines from a paste, should there be a delay between messages to avoid triggering flood protection? → A: 300ms delay between lines — standard IRC pacing, avoids flood triggers.
- Q: When the user reaches 1000 characters in the input, should the input stop accepting characters (hard cap) or allow typing past the limit? → A: Hard cap — input stops accepting characters at 1000.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Nick Column Alignment (Priority: P1)

All nicknames in the chat area are rendered in a fixed-width column so that message text always starts at the same horizontal position regardless of nick length. This dramatically improves readability in busy channels.

**Why this priority**: Readability is the single highest-impact polish item. Every message in every channel benefits from aligned nicks. Currently nicks are inline `<span>` elements with no fixed width — short and long nicks cause message text to start at different positions.

**Independent Test**: Send messages from nicks of varying length (1–16 chars) and verify all message bodies start at the same horizontal offset.

**Acceptance Scenarios**:

1. **Given** a channel with messages from "Al" and "VeryLongNickname", **When** both messages render, **Then** the message body text starts at the same horizontal position for both.
2. **Given** the maximum nick length is 16 characters, **When** a 16-character nick sends a message, **Then** the nick column accommodates it without overflow or truncation.
3. **Given** an action message (`/me waves`), **When** it renders, **Then** it uses the full-width layout (no nick column) since actions display as `* Nick waves`.
4. **Given** a notice message, **When** it renders, **Then** it also uses the full-width layout since notices display as `-Nick- message`.
5. **Given** the chat area is resized, **When** the nick column is present, **Then** the message text area adjusts while the nick column width remains fixed.

---

### User Story 2 — Double-Click Actions (Priority: P1)

Double-clicking interactive elements in the chat UI performs intuitive actions: nicklist nicks open PM windows, channel names in chat join those channels, and URLs open in new tabs.

**Why this priority**: Double-click is the most intuitive interaction pattern for power users. It reduces friction for the three most common "I want to interact with this" actions.

**Independent Test**: Double-click a nickname in the nicklist and verify a PM tab opens for that user.

**Acceptance Scenarios**:

1. **Given** a user is viewing a channel, **When** they double-click a nickname in the nicklist, **Then** a PM query window (tab) opens for that nickname.
2. **Given** a message contains a channel name (e.g., "#general"), **When** the user double-clicks it, **Then** they join that channel (or switch to it if already joined).
3. **Given** a message contains a URL, **When** the user double-clicks it, **Then** the URL opens in a new browser tab.
4. **Given** a user double-clicks a nickname that is offline (e.g., from a /whowas result in the status tab), **When** the double-click fires, **Then** a system message "User is offline" is shown instead of opening a PM.

---

### User Story 3 — Right-Click Copy (Priority: P1)

Users can select text in the chat area and copy it to the clipboard using right-click context menu or Ctrl+C keyboard shortcut.

**Why this priority**: Copy is a fundamental text interaction. Without it, users cannot share or save chat content — a critical gap for any text-based application.

**Independent Test**: Select text in the chat area, press Ctrl+C, and verify clipboard contains the selected text.

**Acceptance Scenarios**:

1. **Given** a user has selected text in the chat area, **When** they press Ctrl+C, **Then** the selected text is copied to the clipboard as plain text.
2. **Given** a user has selected text in the chat area, **When** they right-click, **Then** a context menu with "Copy" appears.
3. **Given** a user clicks "Copy" in the context menu, **When** the copy executes, **Then** the selected text is copied to the clipboard.
4. **Given** no text is selected in the chat area, **When** the user right-clicks, **Then** the context menu shows "Copy" in a disabled/grayed-out state.
5. **Given** the selected text contains formatting (bold, colors), **When** copied, **Then** the clipboard contains plain text only (no IRC formatting codes).

---

### User Story 4 — Character Counter (Priority: P2)

A real-time character counter near the input box shows the current character count and maximum allowed, changing color as the user approaches the limit.

**Why this priority**: Prevents the frustrating experience of composing a long message only to have it rejected at send time. Provides continuous feedback during composition.

**Independent Test**: Type in the input box and verify a counter updates in real-time showing current/max characters.

**Acceptance Scenarios**:

1. **Given** the input box is empty, **When** the user views the input area, **Then** a counter displays "0/1000".
2. **Given** the user types characters, **When** the count changes, **Then** the counter updates in real-time (on each keystroke).
3. **Given** the character count exceeds 450, **When** the counter updates, **Then** it changes color to yellow/warning.
4. **Given** the character count exceeds 900, **When** the counter updates, **Then** it changes color to red.
5. **Given** the user types Unicode characters (emoji, CJK, etc.), **When** the counter updates, **Then** it counts characters (not bytes), matching the server-side validation.
6. **Given** the user sends the message, **When** the input clears, **Then** the counter resets to "0/1000".
7. **Given** the user has typed exactly 1000 characters, **When** they attempt to type more, **Then** the input box stops accepting characters (hard cap).

---

### User Story 5 — Multi-Line Paste Dialog (Priority: P2)

When a user pastes text containing multiple lines into the input box, a confirmation dialog appears before sending to prevent accidental flooding.

**Why this priority**: Accidental paste-flooding is a common and disruptive problem in chat applications. This is a safety feature that protects both the user and the channel.

**Independent Test**: Paste a 5-line text block into the input and verify a confirmation dialog appears before any messages are sent.

**Acceptance Scenarios**:

1. **Given** the user pastes text with 2+ lines, **When** the paste event fires, **Then** a confirmation dialog appears showing "You are about to send N lines."
2. **Given** the confirmation dialog is shown, **When** the user clicks "Send All", **Then** each line is sent as a separate message.
3. **Given** the confirmation dialog is shown, **When** the user clicks "Cancel", **Then** no messages are sent and the input remains empty.
4. **Given** the paste contains more than 50 lines, **When** the dialog appears, **Then** an additional warning emphasizes the flood risk (e.g., bold/red text: "Warning: This may cause flooding").
5. **Given** the user pastes single-line text, **When** the paste event fires, **Then** no dialog appears and the text is placed in the input normally.
6. **Given** the paste contains empty lines mixed with text, **When** lines are sent, **Then** empty lines are skipped (not sent as blank messages).
7. **Given** the paste contains more than 100 lines, **When** the dialog appears, **Then** "Send All" is disabled and the dialog suggests using a pastebin service.
8. **Given** the user confirms sending, **When** lines are dispatched, **Then** messages are sent with a 300ms delay between each line to avoid flooding.

---

### User Story 6 — Quit Message Broadcast (Priority: P2)

Users can provide a custom quit message that is broadcast to all shared channels when they disconnect. The quit message is configurable via the `/quit` command or user preferences.

**Why this priority**: Quit messages are a core IRC social feature. They let users communicate their departure reason to others.

**Independent Test**: User A is in a channel with User B. User A types `/quit Goodbye!` and disconnects. User B sees "* UserA has quit (Goodbye!)" in the channel.

**Acceptance Scenarios**:

1. **Given** a user types `/quit Goodbye everyone!`, **When** they disconnect, **Then** all users in shared channels see a quit message: "* Nick has quit (Goodbye everyone!)".
2. **Given** a user types `/quit` with no message, **When** they disconnect, **Then** the quit message uses the default: "Leaving".
3. **Given** a user configures a custom default quit message in preferences, **When** they quit without specifying a message, **Then** the configured default is used instead of "Leaving".
4. **Given** a user is in 3 channels, **When** they quit, **Then** the quit message appears in all 3 channels for all other members.
5. **Given** a user disconnects unexpectedly (browser close, network loss), **When** the server detects the disconnection, **Then** a quit message with the default reason is broadcast.

---

### User Story 7 — Away Auto-Reply (Priority: P2)

When a user is marked as away and someone sends them a private message, the system automatically sends a single reply with the away message. The auto-reply is sent only once per unique sender per away session to prevent spam.

**Why this priority**: Auto-reply is an IRC convention that improves communication. Without it, PM senders have no feedback that the recipient is away.

**Independent Test**: Set `/away Gone for lunch`, receive a PM from another user, and verify the sender sees the auto-reply exactly once.

**Acceptance Scenarios**:

1. **Given** User A is away with message "Gone for lunch", **When** User B sends a PM to User A, **Then** User B receives an auto-reply: "* UserA is away: Gone for lunch".
2. **Given** User B has already received an auto-reply from User A, **When** User B sends another PM, **Then** no additional auto-reply is sent.
3. **Given** User A is away, **When** User C (a different sender) sends a PM, **Then** User C receives the auto-reply (once per unique sender).
4. **Given** User A returns from away (`/away` to clear), **When** the away state clears, **Then** the replied-to sender tracking resets.
5. **Given** User A is away, **When** they receive a notice (not a PM), **Then** no auto-reply is sent (per IRC convention).
6. **Given** User A sets away again after returning, **When** User B (who previously received a reply) sends a PM, **Then** User B receives a new auto-reply (new away session).

---

### User Story 8 — Timestamp Format Configuration (Priority: P3)

Users can configure the timestamp format for chat messages from the Options Dialog. Available formats: [HH:MM] (default), [HH:MM:SS], [DD/MM HH:MM], or no timestamps.

**Why this priority**: Timestamp format is a personal preference. The infrastructure already exists in the Log Viewer's DisplayPreferences module — this extends it to the main chat area.

**Independent Test**: Change timestamp format in Options Dialog and verify chat messages immediately reflect the new format.

**Acceptance Scenarios**:

1. **Given** the default settings, **When** messages display in chat, **Then** timestamps show as `[HH:MM]`.
2. **Given** the user selects `[HH:MM:SS]` in Options, **When** messages display, **Then** timestamps include seconds.
3. **Given** the user selects `[DD/MM HH:MM]` in Options, **When** messages display, **Then** timestamps include the date.
4. **Given** the user selects "No timestamps", **When** messages display, **Then** no timestamp is shown.
5. **Given** a registered user changes the format, **When** they reconnect, **Then** the preference persists.
6. **Given** the user changes the format, **When** existing messages are visible, **Then** all visible messages update to the new format (stream reset).

---

### User Story 9 — Emoji Support (Priority: P3)

Unicode emojis render properly in chat messages. An optional emoji picker popup is accessible from a toolbar button, allowing users to browse and insert emojis by category.

**Why this priority**: Emoji are a modern communication expectation. While lower priority than core interaction polish, they add expressiveness to chat.

**Independent Test**: Type or paste a Unicode emoji in the input, send it, and verify it renders correctly in the chat area. Open the emoji picker, click an emoji, and verify it's inserted at the cursor position.

**Acceptance Scenarios**:

1. **Given** a user sends a message containing Unicode emojis (e.g., "Hello! :smiling_face:"), **When** the message renders, **Then** the emojis display correctly.
2. **Given** the emoji picker toolbar button is clicked, **When** the picker opens, **Then** it shows a grid of emojis organized by category (Smileys, People, Animals, Food, Travel, Activities, Objects, Symbols).
3. **Given** the emoji picker is open, **When** the user clicks an emoji, **Then** it is inserted at the current cursor position in the input box.
4. **Given** the emoji picker is open, **When** the user clicks outside it or presses Escape, **Then** the picker closes.
5. **Given** the emoji picker is open, **When** the user types in a search field, **Then** emojis are filtered by name/keyword.
6. **Given** a message with emojis is displayed, **When** the user copies the text, **Then** emojis are preserved as Unicode characters.

---

### User Story 10 — About Dialog Enhancement (Priority: P3)

The Help > About dialog is enhanced to show a proper Windows 98-style about box with application name, version, credits, and a retro-style logo.

**Why this priority**: The About dialog already exists but is minimal. A polished about box adds professional feel and is a quick win.

**Independent Test**: Open Help > About and verify the dialog shows version, credits, and a retro-style visual element.

**Acceptance Scenarios**:

1. **Given** the user opens Help > About, **When** the dialog renders, **Then** it displays "RetroHexChat" as the application name.
2. **Given** the About dialog is open, **When** viewing credits, **Then** it shows "Built with Elixir, Phoenix LiveView, and 98.css" and the version number.
3. **Given** the About dialog is open, **When** viewing the logo area, **Then** a pixelated retro-style logo or ASCII art is displayed.
4. **Given** the About dialog is open, **When** the user clicks "OK", **Then** the dialog closes.

---

### User Story 11 — Help Menu Quick Access (Priority: P3)

The Help menu includes direct access items for "IRC Commands" and "Keyboard Shortcuts" that open the existing help system pre-navigated to those sections.

**Why this priority**: The help system already has comprehensive command and shortcut documentation. This adds discoverability by providing direct menu paths to the most-referenced content.

**Independent Test**: Click Help > IRC Commands and verify the help dialog opens showing the commands listing. Click Help > Keyboard Shortcuts and verify it opens to the shortcuts topic.

**Acceptance Scenarios**:

1. **Given** the user clicks Help > IRC Commands, **When** the help dialog opens, **Then** it navigates directly to a commands overview/index.
2. **Given** the user clicks Help > Keyboard Shortcuts, **When** the help dialog opens, **Then** it navigates directly to the "Keyboard Shortcuts" topic.
3. **Given** the help dialog is opened via these menu items, **When** the user browses, **Then** all normal help navigation (Contents, Index, Search tabs) is available.

---

### Edge Cases

- **Double-click on offline user in /whowas**: Show "User is offline" system message instead of opening PM.
- **Right-click copy with no selection**: "Copy" menu item appears disabled/grayed out.
- **Paste > 50 lines**: Multi-line paste dialog shows an additional strong flood warning.
- **Paste > 100 lines**: Hard cap — "Send All" disabled, dialog suggests pastebin alternative.
- **Paste send pacing**: Messages sent with 300ms delay between lines to avoid triggering flood protection.
- **Unicode in character counter**: Counter counts characters (String.length), not bytes, matching the server-side 1000-character limit.
- **Character counter hard cap**: Input stops accepting characters at 1000 — no server-side rejection needed for overlength messages.
- **16-character nicks in column**: The nick column must accommodate the maximum 16-character nick without overflow.
- **Emoji picker dismissal**: Clicking outside or pressing Escape closes the picker.
- **Away auto-reply to notices**: Must NOT auto-reply (IRC convention).
- **Away auto-reply spam prevention**: Exactly one reply per unique sender per away session.
- **Multi-line paste without confirmation**: Must NEVER send lines without user confirmation.
- **Empty lines in paste**: Skipped when sending (no blank messages).
- **Quit message length**: Enforce a reasonable maximum (200 characters) to prevent abuse.
- **Concurrent quit/disconnect**: If user quits during a network interruption, server uses last known quit message.

## Requirements *(mandatory)*

### Functional Requirements

**Nick Column Alignment**:
- **FR-001**: System MUST render chat nicknames in a fixed-width column that accommodates up to 16 characters.
- **FR-002**: System MUST align all message body text to the same horizontal start position regardless of nickname length.
- **FR-003**: System MUST use monospace rendering for the nick column.
- **FR-004**: Action messages (`/me`) and notices MUST use full-width layout without the nick column.

**Double-Click Actions**:
- **FR-005**: System MUST open a PM query tab when a user double-clicks a nickname in the nicklist.
- **FR-006**: System MUST join (or switch to) a channel when a user double-clicks a channel name in chat text.
- **FR-007**: URLs in chat text MUST be clickable and open in a new browser tab (already implemented via `<a target="_blank">` from URLDetector).
- **FR-008**: System MUST show a "User is offline" message when double-clicking an offline user reference.

**Right-Click Copy**:
- **FR-009**: System MUST support Ctrl+C to copy selected text from the chat area.
- **FR-010**: System MUST display a right-click context menu with a "Copy" option when text is selected.
- **FR-011**: System MUST disable the "Copy" option when no text is selected.
- **FR-012**: System MUST copy as plain text only (no IRC formatting codes).

**Character Counter**:
- **FR-013**: System MUST display a real-time character counter near the input box showing "current/1000".
- **FR-014**: Counter MUST update on every keystroke.
- **FR-015**: Counter MUST change color at defined thresholds (yellow at >450, red at >900).
- **FR-016**: Counter MUST count characters (not bytes) to match server-side validation.
- **FR-016a**: Input box MUST enforce a hard cap at 1000 characters — no further typing accepted once the limit is reached.

**Multi-Line Paste Dialog**:
- **FR-017**: System MUST intercept paste events containing 2+ lines and show a confirmation dialog.
- **FR-018**: Dialog MUST display the number of lines to be sent.
- **FR-019**: Dialog MUST offer "Send All" and "Cancel" options.
- **FR-020**: Pasting >50 lines MUST show an additional flood warning.
- **FR-020a**: Pasting >100 lines MUST disable "Send All" and suggest using a pastebin service instead.
- **FR-021**: Empty lines MUST be skipped when sending.
- **FR-021a**: When sending confirmed lines, system MUST pace messages with a 300ms delay between each line.

**Quit Message**:
- **FR-022**: System MUST broadcast a quit message to all shared channels when a user disconnects.
- **FR-023**: `/quit [message]` MUST use the provided message, defaulting to "Leaving".
- **FR-024**: System MUST support a configurable default quit message in user preferences.
- **FR-025**: Quit messages MUST be limited to 200 characters.

**Away Auto-Reply**:
- **FR-026**: System MUST automatically reply to PMs when the user is away, including the away message.
- **FR-027**: System MUST send at most one auto-reply per unique sender per away session.
- **FR-028**: System MUST NOT auto-reply to notices.
- **FR-029**: System MUST reset the replied-to tracking when the user returns from away.

**Timestamp Format**:
- **FR-030**: System MUST support 4 timestamp formats: `[HH:MM]`, `[HH:MM:SS]`, `[DD/MM HH:MM]`, and none.
- **FR-031**: Format selection MUST be available in the Options Dialog.
- **FR-032**: Changing the format MUST immediately update all visible messages.
- **FR-033**: Format preference MUST persist for registered users.

**Emoji Support**:
- **FR-034**: System MUST render Unicode emojis correctly in chat messages.
- **FR-035**: System MUST provide an emoji picker accessible from a toolbar button.
- **FR-036**: Emoji picker MUST organize emojis by category with a search function.
- **FR-037**: Clicking an emoji MUST insert it at the current cursor position.
- **FR-038**: Emoji picker MUST be dismissable via Escape key or clicking outside.

**About Dialog Enhancement**:
- **FR-039**: About dialog MUST display application name, version number, and credits.
- **FR-040**: About dialog MUST include a retro-style logo or ASCII art.

**Help Menu Quick Access**:
- **FR-041**: Help menu MUST include "IRC Commands" item that opens help to the commands section.
- **FR-042**: Help menu MUST include "Keyboard Shortcuts" item that opens help to the shortcuts topic.

### Already Implemented (Excluded from Scope)

- **Finger Reply**: The CTCP system (feature 012) already provides `finger_text` configuration via `CtcpSettings` and `CtcpSettingsDialog`. No additional work needed.

### Key Entities

- **AwayReplyTracker**: In-memory set of nicknames that have already received an auto-reply during the current away session. Stored in socket assigns, reset when away is cleared.
- **UserPreferences** (extension): Add `quit_message` (default quit text) and `timestamp_format` fields to the existing preferences schema.
- **EmojiData**: Static dataset of Unicode emojis organized by category with names and keywords for search.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All message bodies in the chat area start at the same horizontal position regardless of sender nickname length (1–16 characters).
- **SC-002**: Double-click on nicklist nick opens a PM tab within 1 interaction (no additional clicks needed).
- **SC-003**: Users can copy selected chat text to clipboard using Ctrl+C or right-click > Copy in a single action.
- **SC-004**: Character counter is visible and updates in real-time as the user types, with color changes at warning thresholds.
- **SC-005**: Multi-line paste (2+ lines) always shows a confirmation dialog before any messages are sent.
- **SC-006**: Quit messages are visible to all users in shared channels within 1 second of disconnection.
- **SC-007**: Away auto-reply sends exactly one response per unique PM sender per away session — no duplicates, no misses.
- **SC-008**: Timestamp format changes in Options take effect immediately on all visible messages without page reload.
- **SC-009**: Emoji picker shows at least 200 commonly used emojis across 8 categories with functional search.
- **SC-010**: All 12 new features (excluding already-implemented Finger Reply) pass their acceptance scenarios with zero regressions in existing functionality.

## Assumptions

- The nick column width is fixed at 16 characters (matching the server's maximum nick length) rather than dynamically adjusting to the longest visible nick. This provides consistent layout across all views.
- The character counter maximum is 1000, matching the existing `@max_content_length` in `Chat.Policy`.
- The emoji dataset is a curated static list bundled with the application (not fetched from an external API).
- The About dialog version number is hardcoded (following the existing pattern of "RetroHexChat v1.0").
- Quit message broadcast reuses the existing PubSub channel topics.
- Timestamp format configuration extends the existing UserPreferences schema (feature 021) rather than creating a new persistence mechanism.
- The right-click copy context menu is implemented via browser-native clipboard API since LiveView cannot directly access the clipboard.
- Multi-line paste detection and dialog are handled client-side with the actual message sending delegated to server-side events.
- Finger Reply is considered already implemented via the CTCP system (feature 012) and excluded from this feature's scope. The original 13 items become 12 new items.
