# Feature Specification: Smart Input & Command Help

**Feature Branch**: `024-smart-input-command-help`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Smart Input & Command Help for RetroHexChat — inline command syntax tooltip with parameter highlighting, contextual placeholder text, input vertical expansion, enhanced history navigation, and persistent history."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Command Syntax Tooltip (Priority: P1)

A user types a command (either manually or by selecting from the autocomplete dropdown) and immediately sees an inline syntax tooltip above the input field. The tooltip shows the command's syntax with parameter placeholders (e.g., `/mode <#canal> <+/-modos> [nick]`). As the user types arguments, the tooltip highlights the next expected parameter in bold. For commands with enumerated options (like `/mode`), available sub-options are listed below the syntax line with brief descriptions. The tooltip includes a contextual status line showing what the user has entered so far and what comes next. Users can dismiss the tooltip with Escape. The tooltip respects the user's configured detail level: Beginner (full descriptions and examples), Expert (syntax line only), or Off (disabled).

**Why this priority**: This is the core innovation of the feature — bridging the gap between the existing autocomplete (which helps users *find* commands) and actually *using* them correctly. Without syntax guidance, users must memorize parameters or repeatedly consult `/help`. This directly addresses the primary problem statement.

**Independent Test**: Can be fully tested by typing any recognized command (e.g., `/mode`, `/kick`, `/join`) and verifying the tooltip appears with correct syntax, parameter highlighting updates as arguments are typed, and dismissal via Escape works.

**Acceptance Scenarios**:

1. **Given** a user in a channel, **When** they type `/mode` followed by a space, **Then** a syntax tooltip appears above the input showing `/mode <#canal> <+/-modos> [nick]` with `<#canal>` highlighted as the next expected parameter.
2. **Given** a user who selected `/kick` from the autocomplete dropdown, **When** the autocomplete closes and the command is inserted, **Then** the syntax tooltip appears immediately showing `/kick <nick> [razão]`.
3. **Given** a user typing `/mode #general +o`, **When** they have typed up to `+o`, **Then** the tooltip highlights `[nick]` as the next expected parameter and shows a contextual note: "Você está definindo: +o (operador). Próximo: nickname do usuário."
4. **Given** a user with the autocomplete dropdown currently open, **When** they are browsing command suggestions, **Then** the syntax tooltip does NOT appear (it waits until a command is selected or autocomplete is dismissed).
5. **Given** a user typing a regular message (not starting with `/`), **When** they type any text, **Then** no syntax tooltip appears.
6. **Given** a user who presses Escape while the tooltip is visible, **When** the key is pressed, **Then** the tooltip is dismissed and does not reappear until the next command is typed.
7. **Given** a user with detail level set to "Expert", **When** they type a command, **Then** only the syntax line is shown (no descriptions, no examples, no sub-option details).
8. **Given** a user with detail level set to "Off", **When** they type a command, **Then** no tooltip appears at all.
9. **Given** a user typing an unknown command (e.g., `/xyzabc`), **When** the command is not recognized, **Then** no tooltip appears.

---

### User Story 2 - Contextual Input Placeholder (Priority: P2)

The chat input field displays dynamic placeholder text that changes based on the current context. In a channel, the placeholder reads "Mensagem para #channel-name — / para comandos". In a private message, it reads "Mensagem para NickName — / para comandos". In the Status window, it reads "Digite um comando — / para lista". The placeholder updates immediately when the user switches between channels, PMs, or the Status window.

**Why this priority**: Placeholder text is a low-effort, high-impact enhancement that provides constant contextual orientation. It helps users understand where they are and reminds them that commands are available. It requires minimal code and provides immediate visual polish.

**Independent Test**: Can be fully tested by switching between different channels, PM conversations, and the Status window and verifying the placeholder text changes immediately and accurately.

**Acceptance Scenarios**:

1. **Given** a user in channel #general, **When** the input field is empty, **Then** the placeholder reads "Mensagem para #general — / para comandos".
2. **Given** a user in a PM with Mario, **When** the input field is empty, **Then** the placeholder reads "Mensagem para Mario — / para comandos".
3. **Given** a user in the Status window, **When** the input field is empty, **Then** the placeholder reads "Digite um comando — / para lista".
4. **Given** a user switching from #general to a PM with Mario, **When** the switch happens, **Then** the placeholder updates immediately (no visible delay).
5. **Given** a user who starts typing in the input, **When** text is present, **Then** the placeholder is hidden (standard browser behavior).

---

### User Story 3 - Input Vertical Expansion (Priority: P3)

When a user types or pastes text that exceeds one line, the input field grows vertically to accommodate the content, up to a maximum of 5 visible lines. Beyond 5 lines, a scrollbar appears within the input. The expansion compresses the chat messages area above (the messages area shrinks to make room) rather than pushing content off-screen. The existing character counter continues to update normally during expansion. When text is deleted back to a single line, the input shrinks back to its original height.

**Why this priority**: Multi-line input expansion is a quality-of-life feature that makes composing longer messages more comfortable. It's independent of command help and history but rounds out the "smart input" experience. It has moderate complexity due to layout considerations.

**Independent Test**: Can be fully tested by typing or pasting multi-line text and verifying the input grows, scrollbar appears after 5 lines, chat area compresses, and input shrinks when text is deleted.

**Acceptance Scenarios**:

1. **Given** a user typing a message, **When** the text wraps to a second line, **Then** the input field grows vertically to show both lines.
2. **Given** a user with 5 lines of text in the input, **When** they add a 6th line, **Then** the input does NOT grow further and a vertical scrollbar appears inside the input.
3. **Given** an expanded input (3 lines visible), **When** the user deletes text back to a single line, **Then** the input shrinks back to its original single-line height.
4. **Given** an expanded input, **When** the input grows, **Then** the chat messages area above compresses proportionally (messages remain visible, no content is pushed off-screen).
5. **Given** an expanded input, **When** the character counter is visible, **Then** the counter updates correctly and remains properly positioned.

---

### User Story 4 - Enhanced History Navigation (Priority: P4)

Users can navigate their command/message history using Ctrl+Up and Ctrl+Down while preserving any text currently being composed. When Ctrl+Up is pressed, the current input text is saved as a draft, and the previous history entry replaces it. Ctrl+Down moves forward through history, and when the user reaches the end, the saved draft is restored. Regular Up/Down in an empty input continues to work as before (existing behavior preserved). Pressing Ctrl+R opens an inline reverse search field — the user types a search term and the most recent matching history entry is shown. History persists across page reloads via local storage, retaining the last 100 entries. Sensitive commands (`/identify`, `/nickserv`, and any command containing password arguments) are excluded from history persistence.

**Why this priority**: Enhanced history is a power-user feature that adds significant convenience but is not essential for basic usability. It builds on the existing Up/Down history already implemented. The draft preservation (Ctrl+Up/Down) and reverse search (Ctrl+R) are both familiar patterns from terminal emulators and IRC clients.

**Independent Test**: Can be fully tested by typing a partial message, pressing Ctrl+Up to browse history (verifying the draft is saved), pressing Ctrl+Down to return to the draft, using Ctrl+R to search, reloading the page to verify persistence, and checking that sensitive commands are excluded.

**Acceptance Scenarios**:

1. **Given** a user who has typed "hello wor" in the input, **When** they press Ctrl+Up, **Then** "hello wor" is saved as a draft and the most recent history entry replaces it in the input.
2. **Given** a user browsing history (after Ctrl+Up), **When** they press Ctrl+Down past the newest entry, **Then** the saved draft "hello wor" is restored in the input.
3. **Given** an empty input field, **When** the user presses Up arrow, **Then** the existing history navigation behavior is preserved (backward through history as currently implemented).
4. **Given** a user pressing Ctrl+R, **When** the reverse search activates, **Then** an inline search field appears (within or near the input area) with a prompt like "Search history:".
5. **Given** a user typing "join" in the Ctrl+R search field, **When** a match exists in history, **Then** the most recent history entry containing "join" is displayed in the input.
6. **Given** a user typing a search term in Ctrl+R, **When** no match is found, **Then** an inline "No match" indicator is shown.
7. **Given** a user who has sent 5 messages and reloads the page, **When** the page loads, **Then** their previous 5 history entries are available via Ctrl+Up navigation.
8. **Given** a user who sent `/identify mypassword`, **When** history is persisted to local storage, **Then** that entry is NOT stored (sensitive command filtered out).
9. **Given** a user whose local storage is full, **When** new history entries are added, **Then** the oldest entries are dropped to make room (no errors shown to user).
10. **Given** history with 100 entries, **When** a 101st entry is added, **Then** the oldest entry is removed and the new one is stored.

---

### Edge Cases

- **Tooltip vs. Autocomplete overlap**: The syntax tooltip MUST NOT appear while the autocomplete dropdown is open. The tooltip appears only after autocomplete closes (either by selection or dismissal).
- **Unknown commands**: If the user types a command not in the registry, no tooltip appears. No error is shown — the tooltip simply stays hidden.
- **Rapid channel switching**: Placeholder text must update on every channel switch, even if the user switches rapidly. There must be no stale placeholder from a previous context.
- **Input expansion layout stability**: Growing the input must not cause the chat scroll position to jump. Messages should remain anchored at the bottom as the input area expands.
- **History with formatting codes**: History entries containing IRC formatting codes (bold, color, etc.) should be stored and recalled correctly without losing formatting.
- **Ctrl+R conflict**: If the user has custom key bindings that conflict with Ctrl+R, the custom binding takes precedence (existing key binding system already handles this).
- **Empty history**: Ctrl+Up with no history does nothing. Ctrl+R with no history shows "No match" immediately.
- **localStorage unavailable**: If localStorage is unavailable (e.g., private browsing in some browsers), history works normally for the current session but does not persist. No error is shown.
- **Tooltip positioning**: The tooltip must not extend beyond the visible viewport. If the input is near the top of the screen, the tooltip should still be visible.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display an inline syntax tooltip above the input when a recognized command is typed or selected from autocomplete.
- **FR-002**: System MUST highlight the next expected parameter in the syntax tooltip as the user types arguments.
- **FR-003**: System MUST show sub-option descriptions for commands that have enumerated options (e.g., channel modes for `/mode`).
- **FR-004**: System MUST display a contextual status line in the tooltip showing what has been entered and what comes next.
- **FR-005**: System MUST allow the tooltip to be dismissed with the Escape key.
- **FR-006**: System MUST NOT show the tooltip while the autocomplete dropdown is open.
- **FR-007**: System MUST NOT show the tooltip for unrecognized commands or regular messages.
- **FR-008**: System MUST support three tooltip detail levels: Beginner (full descriptions, examples, sub-options), Expert (syntax line only), Off (disabled).
- **FR-009**: System MUST store the tooltip detail level as a user preference (persisted for registered users, in-memory for guests).
- **FR-010**: System MUST display contextual placeholder text in the input based on the active context: channel name, PM recipient, or Status window.
- **FR-011**: System MUST update placeholder text immediately on context switch with no visible delay.
- **FR-012**: System MUST expand the input field vertically as text wraps, up to a maximum of 5 visible lines.
- **FR-013**: System MUST show a vertical scrollbar within the input when content exceeds 5 lines.
- **FR-014**: System MUST compress the chat messages area above when the input expands (not push content off-screen).
- **FR-015**: System MUST shrink the input back to original height when text is deleted to a single line.
- **FR-016**: System MUST support Ctrl+Up/Ctrl+Down for history navigation that preserves the current draft.
- **FR-017**: System MUST save the current input text as a draft when Ctrl+Up is first pressed, and restore it when Ctrl+Down returns past the newest entry.
- **FR-018**: System MUST preserve existing Up/Down arrow history behavior for empty input fields.
- **FR-019**: System MUST provide Ctrl+R reverse history search with an inline search interface.
- **FR-020**: System MUST show "No match" when Ctrl+R search finds no results.
- **FR-021**: System MUST persist command history across page reloads, retaining the last 100 entries.
- **FR-022**: System MUST NOT persist sensitive commands (`/identify`, `/nickserv`, and commands containing password-like arguments) in stored history.
- **FR-023**: System MUST handle localStorage being full by dropping the oldest history entries gracefully.
- **FR-024**: System MUST provide corresponding help topics for all new features (command syntax tooltip, smart input, enhanced history).

### Key Entities

- **Command Syntax Definition**: A structured description of a command's expected parameters — including parameter name, whether it is required or optional, parameter type (channel, nick, text, mode flags), and sub-option enumerations. One syntax definition per registered command.
- **Tooltip Detail Level**: A per-user preference with three possible values: Beginner, Expert, Off. Determines the verbosity of the command syntax tooltip.
- **History Entry**: A single line of user input stored in the history buffer. Has content (the text), a timestamp, and a sensitivity flag determining whether it can be persisted.
- **Draft**: A temporary holding area for the user's in-progress input text, saved when entering history navigation and restored when exiting. One draft per input session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see syntax guidance for any recognized command within 200 milliseconds of typing or selecting it.
- **SC-002**: Users can correctly use a new command on first attempt (without consulting `/help`) at least 80% of the time with the tooltip at Beginner level.
- **SC-003**: Placeholder text updates within 100 milliseconds of switching contexts (channel, PM, Status).
- **SC-004**: Input field accommodates up to 5 lines of text without requiring the user to scroll, improving multi-line message composition comfort.
- **SC-005**: Users can retrieve any of their last 100 commands within 5 keystrokes (Ctrl+Up or Ctrl+R + search term).
- **SC-006**: Command history survives page reloads with zero data loss (up to 100 entries).
- **SC-007**: No sensitive command arguments (passwords, NickServ credentials) are ever written to persistent storage.
- **SC-008**: All new features include corresponding help topics accessible via F1, Help menu, and `/help`.

## Assumptions

- The existing autocomplete system (023) provides a reliable signal for when autocomplete opens and closes, which the tooltip can use to coordinate visibility.
- The existing command registry and handler system already contains enough information (command name, handler module) to derive syntax definitions, or syntax definitions will be added alongside existing handler metadata.
- The current user preferences system (6 categories) can accommodate a new preference for tooltip detail level without schema changes (by adding to an existing category like "display" or creating a new one).
- The existing chat layout uses a flex or similar layout model where the input area can grow and the messages area can shrink proportionally.
- The existing `command_history` in LiveView state (50 items) coexists with the new client-side persistent history (100 items). The client-side history is the authoritative source for Ctrl+Up/Down navigation; the server-side history continues to serve existing Up/Down behavior.

## Scope

### In Scope

- Inline command syntax tooltip with parameter highlighting
- Tooltip activation on both autocomplete selection and manual command typing
- Mode helper for `/mode` (sub-option listing)
- Configurable tooltip detail level (Beginner/Expert/Off) as user preference
- Contextual placeholder text for channels, PMs, and Status window
- Input vertical expansion up to 5 lines with scrollbar
- Ctrl+Up/Ctrl+Down history navigation with draft preservation
- Ctrl+R reverse history search with inline UI
- localStorage-based history persistence (100 entries)
- Sensitive command filtering for history persistence
- Help topics for all new features

### Out of Scope

- Spell-checking or grammar suggestions
- Message drafts per channel (saving drafts when switching channels)
- Input themes or styling beyond 98.css
- Autocomplete improvements (already covered by feature 023)
- Command validation or error checking while typing (the tooltip is informational only)
