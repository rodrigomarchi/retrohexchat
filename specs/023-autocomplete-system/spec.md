# Feature Specification: Autocomplete System

**Feature Branch**: `023-autocomplete-system`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Autocomplete System for RetroHexChat — unified command, nickname, and channel autocomplete with fuzzy search, categories, recent commands, and context-aware argument completion."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enhanced Command Autocomplete with Fuzzy Search and Categories (Priority: P1)

A user types `/` in the chat input. The existing command palette dropdown appears, now organized by category (Básicos, Canal, Usuário, Configuração, Avançado). As they type `/jo`, the list filters using fuzzy matching to show `/join` and `/autojoin`. Their 5 most recently used commands appear in a "Recentes" section at the top of the dropdown. They select `/join` with Tab or Enter — the input fills with `/join ` (with trailing space) and the dropdown closes.

**Why this priority**: Commands are the most common autocomplete target and the command palette already exists. Enhancing it with fuzzy search, categories, and recents delivers the highest incremental value with the least effort since it builds directly on existing infrastructure.

**Independent Test**: Can be fully tested by typing `/` in the chat input and verifying that the dropdown shows categorized commands with fuzzy filtering and recent commands tracking, delivering a dramatically improved command discovery experience.

**Acceptance Scenarios**:

1. **Given** a user is in any window (channel or Status), **When** they type `/`, **Then** the command palette appears showing all commands organized by category with a "Recentes" section at the top (empty if no commands used yet).
2. **Given** the command palette is open, **When** the user types `/jo`, **Then** the list filters to show commands matching "jo" using fuzzy search (e.g., `/join`, `/autojoin`), highlighting matched characters.
3. **Given** the command palette is open with filtered results, **When** the user presses Tab or Enter on a highlighted command, **Then** the input is filled with `/commandname ` (with trailing space) and the dropdown closes.
4. **Given** the user has previously used `/join`, `/msg`, and `/nick`, **When** they open the command palette by typing `/`, **Then** their most recently used commands appear in a "Recentes" section at the top (up to 5 commands).
5. **Given** the command palette is open, **When** the user presses Escape or deletes the `/` character, **Then** the dropdown closes.
6. **Given** the command palette is open, **When** the user navigates with ↑/↓ arrow keys, **Then** the selection moves through the list and the selected item is visually highlighted.

---

### User Story 2 - Nick Autocomplete with @ Trigger and Tab Cycling (Priority: P2)

A user in a busy channel wants to mention someone. They type `@ma` — a dropdown appears showing matching nicknames with their status (Online/Away) and chat color. They press Tab or Enter to confirm `@Mario`. Alternatively, at the start of a message they type `Mar` and press Tab — it completes to `Mario: ` with a colon (IRC convention for addressing). In the middle of a sentence, Tab completes to `Mario ` without the colon. Pressing Tab again cycles to the next matching nickname.

**Why this priority**: Nick completion is the second most frequent autocomplete need in IRC. The existing Tab completion is primitive (single-match only, no dropdown, no cycling). This brings it to parity with classic mIRC behavior and adds the modern @ trigger with a visual dropdown.

**Independent Test**: Can be fully tested by joining a channel with multiple users and typing `@` followed by partial text to verify the dropdown appears, or by typing a partial nick and pressing Tab to verify cycling behavior.

**Acceptance Scenarios**:

1. **Given** a user is in a channel with other users, **When** they type `@ma`, **Then** a dropdown appears showing nicknames matching "ma" with status icons (Online/Away) and nick colors.
2. **Given** the nick dropdown is open, **When** the user presses Tab or Enter on a highlighted nick, **Then** `@NickName` is inserted at the cursor position and the dropdown closes.
3. **Given** a user is at the start of an empty input, **When** they type `Mar` and press Tab, **Then** the input becomes `Mario: ` (with colon and space — IRC addressing convention).
4. **Given** a user is in the middle of a sentence (e.g., "hey "), **When** they type `Mar` and press Tab, **Then** the input becomes `hey Mario ` (without colon).
5. **Given** multiple nicks match (e.g., `Mario`, `Marcelo`), **When** the user presses Tab repeatedly, **Then** it cycles through matching nicks in alphabetical order.
6. **Given** the nick dropdown is open, **When** a user in the channel changes their nick, **Then** the dropdown updates to reflect the new nick in real-time.
7. **Given** a user is in the Status window (not in any channel), **When** they type `@`, **Then** no nick dropdown appears (nick autocomplete is channel-only).
8. **Given** the nick dropdown is showing results, **When** the user's own nick would match, **Then** it is not shown as the first suggestion (deprioritized to the end of the list).

---

### User Story 3 - Context-Aware Argument Completion (Priority: P3)

After selecting a command that takes specific argument types, the autocomplete system offers contextual suggestions. For example, after typing `/join #`, a dropdown shows available channels with user counts. After typing `/msg `, a dropdown shows available nicks. After typing `/kick `, a dropdown shows nicks in the current channel.

**Why this priority**: Argument completion significantly reduces errors (wrong channel names, misspelled nicks) and makes commands more discoverable. It builds on Stories 1 and 2 — command autocomplete plus nick/channel data sources.

**Independent Test**: Can be fully tested by selecting `/join` from the command palette and typing `#` to verify channel suggestions appear, or by selecting `/msg` and verifying nick suggestions appear.

**Acceptance Scenarios**:

1. **Given** the user has typed `/join ` (with trailing space), **When** they type `#`, **Then** a dropdown shows available channels matching the partial name, with user counts and a checkmark for already-joined channels.
2. **Given** the user has typed `/msg `, **When** they type a partial nick, **Then** a dropdown shows matching nicknames from across all joined channels.
3. **Given** the user has typed `/kick ` in a channel, **When** they type a partial nick, **Then** a dropdown shows matching nicknames from the current channel only.
4. **Given** channel suggestions are showing, **When** the user selects a channel, **Then** the channel name is inserted after the command and the dropdown closes.
5. **Given** the user has typed `/join #de`, **Then** channels the user has already joined appear first in the results with a visual indicator (checkmark).

---

### User Story 4 - Channel Autocomplete with # Trigger (Priority: P4)

A user types `#de` anywhere in their message. A dropdown appears showing matching channels: #dev (5 users, joined), #design (3 users), #debian (12 users). Channels the user has already joined appear first with a checkmark. Selecting a channel inserts the full channel name.

**Why this priority**: Channel autocomplete in free-form messages is useful but less frequently needed than command and nick autocomplete. It shares the same dropdown infrastructure and channel data source as argument completion.

**Independent Test**: Can be fully tested by typing `#` followed by partial text in the chat input and verifying the channel dropdown appears with matching channels, user counts, and joined indicators.

**Acceptance Scenarios**:

1. **Given** a user is in any window, **When** they type `#de`, **Then** a dropdown appears showing channels matching "de" with user counts.
2. **Given** channel results are showing, **When** joined channels exist in results, **Then** they appear first with a checkmark indicator.
3. **Given** channel results are showing, **When** the user selects a channel with Tab or Enter, **Then** the full channel name (e.g., `#design`) is inserted at the cursor position.
4. **Given** channels exist with secret mode (+s), **When** the user is not a member of those channels, **Then** secret channels do not appear in autocomplete results.
5. **Given** no channels match the typed text, **When** the dropdown would show results, **Then** a "No results" message is displayed instead.

---

### Edge Cases

- **Empty results**: When no commands, nicks, or channels match the typed text, the dropdown shows a styled "No results" message rather than disappearing.
- **Status window context**: In the Status window, only command autocomplete is active — nick and channel autocomplete do not trigger since there is no channel context.
- **Trigger deletion**: If the user deletes back past the trigger character (`/`, `@`, `#`), the dropdown closes immediately.
- **Scrollable dropdown**: When the results list exceeds the maximum visible height, the dropdown becomes scrollable with a scrollbar.
- **Real-time nick updates**: If a user changes their nick while the dropdown is open, the dropdown updates to reflect the change.
- **Multiple triggers in one message**: Each trigger (`/`, `@`, `#`) operates independently based on cursor position — e.g., `/msg @nick check #channel` can have autocomplete for each segment.
- **Viewport boundaries**: The dropdown repositions if it would extend beyond the visible viewport area.
- **No self-suggestion priority**: The current user's own nickname is never shown as the first suggestion in nick autocomplete — it is deprioritized to the end of the list.
- **No message sending**: Autocomplete only assists with input composition — it never sends messages, joins channels, or performs any server action.
- **Focus preservation**: The dropdown never steals focus from the input field — all keyboard interaction (↑/↓, Tab, Enter, Esc) is handled while the input retains focus.
- **Secret channel filtering**: Channels with mode +s (secret) are hidden from autocomplete results for users who are not members.
- **Word boundary requirement**: The `@` and `#` triggers only activate when preceded by whitespace or at the start of input — typing `email@user` or `issue#123` mid-word does not trigger autocomplete.

## Clarifications

### Session 2026-02-13

- Q: Should `@` and `#` triggers require a word boundary (whitespace or start of input) before activating? → A: Yes — triggers only activate after whitespace or at input start (prevents false positives on `email@user`, `issue#123`).
- Q: Should the first item be pre-selected when a dropdown opens, or require ↓ first? → A: First item pre-selected — dropdown opens with the top result highlighted, ready for immediate Tab/Enter confirmation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide fuzzy matching for command search — matching characters need not be contiguous (e.g., "jo" matches "join" and "autojoin").
- **FR-002**: System MUST organize commands into categories (Básicos, Canal, Usuário, Configuração, Avançado) in the command palette dropdown.
- **FR-003**: System MUST track and display up to 5 most recently used commands per user in a "Recentes" section at the top of the command palette, persisted in localStorage.
- **FR-004**: System MUST provide nick autocomplete triggered by typing `@` followed by one or more characters, but only when the `@` appears at the start of input or after whitespace (word boundary requirement). The dropdown shows matching nicknames, their status (Online/Away), and nick color.
- **FR-005**: System MUST support IRC-style Tab completion for nicks — completing to `Nick: ` at the start of input and `Nick ` mid-sentence, with Tab cycling through multiple matches.
- **FR-006**: System MUST provide channel autocomplete triggered by typing `#` followed by one or more characters, but only when the `#` appears at the start of input or after whitespace (word boundary requirement). The dropdown shows matching channels with user counts and joined status.
- **FR-007**: System MUST provide context-aware argument completion — nick suggestions after `/msg`, `/kick`, `/query`, `/whois`, `/notice`, `/ctcp`; channel suggestions after `/join`, `/part`, `/topic`, `/mode`.
- **FR-008**: System MUST support keyboard navigation (↑/↓ arrows) and selection (Tab/Enter) in all autocomplete dropdowns, with Escape to dismiss. The first item MUST be pre-selected (highlighted) when the dropdown opens.
- **FR-009**: System MUST close the autocomplete dropdown when the user deletes back past the trigger character.
- **FR-010**: System MUST exclude secret channels (+s) from autocomplete results for users who are not members of those channels.
- **FR-011**: System MUST deprioritize the current user's own nickname in nick autocomplete results (shown last, not first).
- **FR-012**: System MUST update nick autocomplete results in real-time when users join, leave, or change their nicknames in the channel.
- **FR-013**: System MUST render all autocomplete dropdowns using retro styling consistent with the existing command palette appearance.
- **FR-014**: System MUST limit autocomplete to the chat input field only — dropdowns do not appear in dialog inputs.
- **FR-015**: System MUST display a "No results" message in the dropdown when no items match the current input.
- **FR-016**: System MUST reposition the dropdown if it would extend beyond the visible viewport area.
- **FR-017**: System MUST NOT send any messages, join channels, or perform server actions as a result of autocomplete interaction — it only assists with input composition.
- **FR-018**: System MUST NOT steal focus from the input field when displaying autocomplete dropdowns.

### Key Entities

- **Autocomplete Trigger**: A character (`/`, `@`, `#`) that activates a specific autocomplete mode based on context and cursor position.
- **Autocomplete Result**: A suggestion item containing display text, metadata (category, status, user count), and the text to insert upon selection.
- **Recent Command**: A record of a previously used command, stored per-user in localStorage with a timestamp, capped at 5 entries.
- **Command Category**: A grouping label for organizing commands in the palette (Básicos, Canal, Usuário, Configuração, Avançado).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can discover and select any command from the palette in under 3 keystrokes beyond the initial `/` trigger (via fuzzy search).
- **SC-002**: Nick autocomplete suggestions appear within 100ms of typing the trigger character, even in channels with 50+ users.
- **SC-003**: Tab-cycling through nick matches completes a full cycle without errors or duplicate entries.
- **SC-004**: 100% of secret channels (+s) are excluded from autocomplete results for non-member users.
- **SC-005**: All autocomplete interactions complete without sending any unintended messages or performing server-side actions.
- **SC-006**: The autocomplete dropdown remains fully functional when the browser window is resized or the viewport is small, repositioning as needed.
- **SC-007**: Recent commands persist across page reloads for the same user without requiring login.
- **SC-008**: Autocomplete works correctly across all three trigger types (`/`, `@`, `#`) within a single input line without interference.

## Assumptions

- **Command categories**: Commands will be mapped to categories based on their existing handler module locations and logical grouping. The categories (Básicos, Canal, Usuário, Configuração, Avançado) cover the full 45-command set.
- **Fuzzy matching algorithm**: A simple subsequence match (each typed character appears in order within the candidate) is sufficient — no need for a weighted scoring library. Results are ranked by match quality (consecutive matches weighted higher, prefix matches first).
- **Recent commands storage**: localStorage is the appropriate persistence mechanism for recent commands since it is per-browser, doesn't require server state, and works for both guest and registered users.
- **Nick data source for @ trigger**: The `@` trigger dropdown pulls nicknames from the current channel's user list (via Presence). For argument completion after `/msg`, nicks are drawn from all channels the user has joined.
- **Channel data source**: Channel autocomplete uses the existing channel listing mechanism, which already provides name and user count. The secret mode (+s) filter uses the existing `Channels.Modes.secret?/1` function.
- **Max dropdown items**: The dropdown shows up to 20 results at a time with scrolling, matching the existing command palette's scroll behavior.
- **Tab completion cycling**: Tab-cycling maintains its own ephemeral state (current match index and original partial text) that resets when the user types any other key or moves the cursor.

## Scope

### In Scope

- Fuzzy command search replacing prefix-only matching
- Command categories in the palette dropdown
- Recent commands tracking (up to 5, localStorage)
- Context-aware argument completion (nicks after /msg, channels after /join, channel nicks after /kick, etc.)
- Nick autocomplete with `@` trigger and visual dropdown
- IRC-style Tab-completion for nicks with cycling
- Channel autocomplete with `#` trigger
- Shared retro-styled dropdown UI across all autocomplete types
- Help documentation for the autocomplete feature

### Out of Scope

- Inline syntax hints after command selection (future Smart Input feature)
- Emoji autocomplete
- Custom or plugin-based autocomplete providers
- Autocomplete in dialog/modal inputs (chat input only)
- Server-side autocomplete indexing or search
