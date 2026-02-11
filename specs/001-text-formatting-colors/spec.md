# Feature Specification: Text Formatting & Colors

**Feature Branch**: `001-text-formatting-colors`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Text Formatting & Colors for RetroHexChat — mIRC-compatible inline formatting (bold, italic, underline, strikethrough, reverse, colors, reset), formatting toolbar, and per-user strip-codes preference."

## Clarifications

### Session 2026-02-11

- Q: How should the color picker in the formatting toolbar behave? → A: Dropdown grid — a single "Color" button that opens a 4x4 popup grid of 16 color swatches below it.
- Q: Should the system impose a maximum number of format codes per message? → A: Soft limit (128) — strip excess format codes beyond 128 at display time, preserving text content.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inline Text Formatting via Keyboard Shortcuts (Priority: P1)

A user chatting in a channel wants to emphasize a word. They position their cursor in the input box, press Ctrl+B, type the word, and press Ctrl+B again. The message is sent containing mIRC format control codes. All other users in the channel see that word rendered in **bold**. The same pattern applies: Ctrl+I for italic, Ctrl+U for underline, Ctrl+R for reverse video (swaps foreground/background colors), and Ctrl+O to reset all active formatting back to plain text. Strikethrough uses the mIRC control code 0x1E.

Format codes are stored verbatim in the message content. Rendering happens at display time: the chat display parses control codes and wraps text segments with appropriate visual styles.

**Why this priority**: This is the core feature — without parsing and rendering format codes, nothing else (toolbar, strip option) has value. It's also required for interoperability with any future IRC bridging.

**Independent Test**: Can be fully tested by typing a message with Ctrl+B wrapped text, sending it, and verifying the recipient sees bold text in the chat area.

**Acceptance Scenarios**:

1. **Given** a user is typing in the input box, **When** they press Ctrl+B, type "hello", press Ctrl+B, and send, **Then** all users in the channel see "hello" rendered in bold.
2. **Given** a user sends a message containing Ctrl+I around "world", **When** other users receive the message, **Then** "world" appears in italic.
3. **Given** a user presses Ctrl+U, types "important", presses Ctrl+U, **When** the message is displayed, **Then** "important" appears underlined.
4. **Given** a user presses Ctrl+R, types "reversed", presses Ctrl+R, **When** displayed, **Then** foreground and background colors are swapped for "reversed".
5. **Given** a message has multiple active formats (bold + italic), **When** the user presses Ctrl+O, **Then** all formatting resets to plain text from that point forward.
6. **Given** a user sends a message with strikethrough code (0x1E) around "deleted", **When** displayed, **Then** "deleted" appears with a line through it.
7. **Given** a message is stored in the database, **Then** the content field contains the raw mIRC control codes verbatim.

---

### User Story 2 - Color Codes (Priority: P1)

A user wants to add color to their text. They press Ctrl+K in the input box, then type a foreground color number (0–15). The subsequent text renders in that color. Optionally, they can specify a background color by typing Ctrl+K followed by `foreground,background` (e.g., `4,1` for red text on black background). A bare Ctrl+K with no number following resets color to default. The 16 standard mIRC colors are:

| Code | Color       | Hex       |
|------|-------------|-----------|
| 0    | White       | #FFFFFF   |
| 1    | Black       | #000000   |
| 2    | Navy        | #00007F   |
| 3    | Green       | #009300   |
| 4    | Red         | #FF0000   |
| 5    | Brown       | #7F0000   |
| 6    | Purple      | #9C009C   |
| 7    | Orange      | #FC7F00   |
| 8    | Yellow      | #FFFF00   |
| 9    | Light Green | #00FC00   |
| 10   | Teal        | #009393   |
| 11   | Cyan        | #00FFFF   |
| 12   | Blue        | #0000FC   |
| 13   | Pink        | #FF00FF   |
| 14   | Grey        | #7F7F7F   |
| 15   | Light Grey  | #D2D2D2   |

**Why this priority**: Colors are equally fundamental to mIRC identity as bold/italic. They're part of the same parsing engine and should be implemented together.

**Independent Test**: Can be tested by sending a message with Ctrl+K + color number and verifying the text renders in the correct color.

**Acceptance Scenarios**:

1. **Given** a user presses Ctrl+K, types "4", then types "red text", **When** displayed, **Then** "red text" appears in red (#FF0000).
2. **Given** a user types Ctrl+K, "4,1", then "red on black", **When** displayed, **Then** the text has red foreground and black background.
3. **Given** a user types Ctrl+K with no number after it, **When** displayed, **Then** color resets to the default text color.
4. **Given** a user uses color code "04" (zero-padded), **When** displayed, **Then** it renders the same as color code "4" (red).
5. **Given** color codes are combined with formatting (e.g., bold + red), **When** displayed, **Then** both bold and red styling are applied simultaneously.

---

### User Story 3 - Formatting Toolbar (Priority: P2)

For users who find keyboard shortcuts difficult, a visual formatting toolbar sits above the input box. It contains buttons for Bold (B), Italic (I), Underline (U), and a Color button. Clicking a formatting button inserts the appropriate mIRC control code character at the current cursor position in the input box. The Color button opens a dropdown popup displaying a 4x4 grid of the 16 standard mIRC color swatches; clicking a swatch inserts the Ctrl+K + color number code at the cursor position and closes the dropdown. Clicking outside the dropdown or pressing Escape dismisses it without inserting a code. The toolbar must not steal focus from the input box or displace the cursor.

**Why this priority**: The toolbar is an accessibility enhancement. The core formatting works via keyboard shortcuts (P1); the toolbar makes it discoverable and easier to use.

**Independent Test**: Can be tested by clicking the Bold button, verifying the control code appears in the input, sending the message, and confirming it renders bold.

**Acceptance Scenarios**:

1. **Given** the user has the cursor at position 5 in the input box, **When** they click the Bold button on the toolbar, **Then** a bold control code (0x02) is inserted at position 5 and the cursor remains in the input box at position 6.
2. **Given** the user clicks the Color button, **When** the dropdown opens, **Then** a 4x4 grid of 16 color swatches is displayed below the button.
3. **Given** the color dropdown is open and the user clicks color 4 (Red), **When** the code is inserted, **Then** the input contains the Ctrl+K + "4" sequence at the cursor position and the dropdown closes.
4. **Given** the color dropdown is open, **When** the user clicks outside the dropdown or presses Escape, **Then** the dropdown closes without inserting any code.
5. **Given** the user clicks a toolbar button, **Then** the input box retains focus and the cursor position advances by the length of the inserted code.
6. **Given** the toolbar is visible, **Then** it does not overlap or push down the chat message area in a way that hides messages.

---

### User Story 4 - Strip Formatting Codes Preference (Priority: P3)

A user who prefers clean, unformatted text enables the "Strip formatting codes" option. When enabled, all incoming messages have their mIRC format control codes removed before display, showing only the plain text content. This is a per-user runtime preference stored in the session (not persisted to the database). Messages are still stored with their original format codes; stripping happens only at display time.

**Why this priority**: This is a user preference that enhances the experience for users who dislike formatting, but the core feature (rendering formatted text) must work first.

**Independent Test**: Can be tested by enabling the strip option, receiving a formatted message, and verifying it appears as plain text without any formatting.

**Acceptance Scenarios**:

1. **Given** the user has "Strip formatting codes" enabled, **When** they receive a message containing bold codes, **Then** the message displays as plain text without bold styling.
2. **Given** the user has "Strip formatting codes" enabled, **When** they receive a message with color codes, **Then** the message displays in the default text color with no color changes.
3. **Given** the user disables "Strip formatting codes", **When** they receive the next formatted message, **Then** it displays with full formatting applied.
4. **Given** the user has "Strip formatting codes" enabled, **When** they send a message with format codes, **Then** the message is stored with format codes intact (stripping only affects display of incoming messages).

---

### Edge Cases

- **Malformed color codes**: Ctrl+K followed by non-numeric text (e.g., "Ctrl+K abc") renders the Ctrl+K as invisible and displays "abc" as plain text.
- **Nested/overlapping formats**: Bold inside italic (or vice versa) applies both styles simultaneously. Closing one format does not close the other.
- **Unclosed format codes**: If a user opens bold but never closes it, the bold applies to the rest of the message and resets at message boundary.
- **Messages with only format codes**: If after stripping all format codes the message contains no visible text (only whitespace or empty), the message is not sent. The user sees an error or the send is silently ignored.
- **Pasted external mIRC text**: Text pasted from other IRC clients containing mIRC format codes renders correctly, as the codes are standard Unicode control characters.
- **Color code edge cases**: Color numbers outside 0–15 are treated as plain text. Color code "16" is interpreted as color 1 followed by literal "6".
- **Format codes in system/service/error messages**: System-generated messages (joins, parts, mode changes) are not subject to user formatting — they render with their own fixed styles.
- **Private messages**: Format codes work identically in private messages as in channel messages.
- **Excessive format codes**: Messages with more than 128 format codes have excess codes stripped at display time; visible text content is preserved.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST parse mIRC format control codes in message content: bold (0x02), italic (0x1D), underline (0x1F), strikethrough (0x1E), reverse (0x16), color (0x03), and reset (0x0F).
- **FR-002**: System MUST render parsed format codes as visual styles in the chat message display area (bold as CSS font-weight bold, italic as font-style italic, underline as text-decoration underline, strikethrough as text-decoration line-through, reverse as swapped foreground/background colors).
- **FR-003**: System MUST support the 16 standard mIRC color codes (0–15) for foreground color, and optionally background color using the `foreground,background` syntax after the color control code (0x03).
- **FR-004**: System MUST store format control codes verbatim in the message content field — no transformation or stripping on write.
- **FR-005**: System MUST insert the correct mIRC control code character at the current cursor position when the user presses the corresponding keyboard shortcut (Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+R, Ctrl+K, Ctrl+O) in the input box.
- **FR-006**: System MUST provide a formatting toolbar above the input box with buttons for Bold, Italic, Underline, and a Color button that opens a dropdown 4x4 grid of the 16 mIRC color swatches.
- **FR-007**: Clicking a formatting toolbar button MUST insert the corresponding control code at the current cursor position without stealing focus from the input box.
- **FR-008**: System MUST provide a per-user "Strip formatting codes" toggle that, when enabled, removes all format control codes from incoming messages before display, showing plain text only.
- **FR-009**: The strip-codes preference MUST be a runtime session setting (not persisted to the database).
- **FR-010**: System MUST NOT send messages that contain only format codes and no visible text content.
- **FR-011**: System MUST reset all active formatting at message boundaries — format state does not carry over between messages.
- **FR-012**: Format code parsing and rendering MUST work identically for channel messages and private messages.
- **FR-013**: System-generated messages (type: system, service, error) MUST NOT have their content parsed for user format codes.
- **FR-014**: Malformed color codes (Ctrl+K followed by non-numeric characters) MUST degrade gracefully — display subsequent text as plain text without crashing.
- **FR-015**: The formatting toolbar MUST be styled consistently with the Windows 98 aesthetic using 98.css conventions (raised panel, small icon-like buttons).
- **FR-016**: System MUST enforce a soft limit of 128 format codes per message — if a message contains more than 128 format control codes, excess codes beyond the 128th are stripped at display time while preserving the visible text content.

### Key Entities

- **Format Code**: A Unicode control character (0x02, 0x03, 0x0F, 0x16, 0x1D, 0x1E, 0x1F) embedded inline in message content that signals a style change.
- **Color Specification**: A numeric value 0–15 (optionally zero-padded to two digits) following a color control code (0x03), optionally followed by a comma and a second number for background color.
- **Strip Preference**: A boolean per-user session flag that controls whether format codes are rendered visually or stripped before display.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can send and receive messages with bold, italic, underline, strikethrough, reverse, and color formatting, with the correct visual style applied on every recipient's screen.
- **SC-002**: All 16 standard mIRC colors render correctly as foreground colors, and all 16 render correctly as background colors when specified.
- **SC-003**: Formatting toolbar buttons insert codes without disrupting cursor position or input focus, verifiable by typing, clicking a button, and continuing to type seamlessly.
- **SC-004**: The strip-formatting toggle removes all visual formatting from incoming messages within the same session, without affecting other users' display or the stored message content.
- **SC-005**: Messages composed entirely of format codes (no visible text) are rejected before sending, preventing empty-looking messages in the chat.
- **SC-006**: Pasted text containing mIRC format codes from external sources renders with correct formatting, matching the behavior of the same codes typed via keyboard shortcuts.

## Assumptions

- The 16-color mIRC palette is sufficient; extended 99-color palettes or hex color support are out of scope (belongs in a future Options Dialog feature).
- Channel-level forced color stripping (channel mode +c) is out of scope and belongs in a separate channel modes feature.
- The strip-codes preference does not need database persistence — it resets on reconnect, which is acceptable for a session-level setting.
- Format codes in nicknames are not supported — nicknames remain plain text with hash-based colors.
- The formatting toolbar is always visible when the chat input is visible; there is no option to hide it.
