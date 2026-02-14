# Feature Specification: Keyboard Shortcuts & Chat Search

**Feature Branch**: `025-shortcuts-chat-search`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Keyboard Shortcuts & Chat Search for RetroHexChat — centralized shortcut system, cheatsheet dialog, navigation shortcuts, customizable keybindings, enhanced search with highlighting, result navigation, and advanced filters."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keyboard Shortcut Cheatsheet Dialog (Priority: P1)

A user wants to discover what keyboard shortcuts are available. They press Ctrl+Shift+/ to open a cheatsheet — a read-only 98.css-styled dialog that lists all shortcuts organized by category (Navigation, Chat, Formatting, System). The dialog shows both default bindings and any user-customized bindings. Closing the dialog returns focus to the chat input.

**Why this priority**: Discoverability is the #1 barrier to keyboard-driven usage. Without knowing what's available, no other keyboard feature delivers value. This also provides the foundation (shortcut registry) that all other stories depend on.

**Independent Test**: Can be fully tested by opening the cheatsheet dialog, verifying all categories and shortcuts render correctly, and closing it. Delivers immediate value as a reference for existing shortcuts.

**Acceptance Scenarios**:

1. **Given** a user in a chat channel, **When** they press Ctrl+Shift+/, **Then** a 98.css-styled modal dialog opens listing all keyboard shortcuts organized by category.
2. **Given** the cheatsheet dialog is open, **When** the user presses Escape or clicks the X button, **Then** the dialog closes and focus returns to the chat input.
3. **Given** a registered user has customized a shortcut binding, **When** they open the cheatsheet, **Then** the customized binding is shown instead of the default.
4. **Given** the cheatsheet dialog is open, **When** the user tries to type or edit content, **Then** no text input is possible — the dialog is read-only.

---

### User Story 2 - Search Highlighting & Result Navigation (Priority: P2)

A user is looking for a specific message in chat. They press Ctrl+Shift+F to open the search bar. As they type, all matching occurrences in the visible chat are highlighted with a yellow background. A counter shows "3 of 17" (current position out of total matches). They press the Down arrow or "Find Next" button to jump to the next match — the chat scrolls to center the match and the counter updates. Pressing Escape closes the search and removes all highlights.

**Why this priority**: Search highlighting transforms the existing search from "find and list" into visual in-context search — the most requested pattern in chat applications. Builds on the existing search bar component.

**Independent Test**: Can be tested by opening search, typing a term, verifying highlights appear in the chat area, navigating between results, and confirming highlights clear on close.

**Acceptance Scenarios**:

1. **Given** a chat with messages containing "terraform", **When** the user opens search and types "terraform", **Then** all visible occurrences are highlighted with a yellow background and the counter shows "1 of N".
2. **Given** search is active with results, **When** the user clicks "Find Next" or presses Down arrow in the search bar, **Then** the chat scrolls to the next match, the match is visually distinguished as the "current" match, and the counter increments.
3. **Given** search is active with results, **When** the user clicks "Find Prev" or presses Up arrow in the search bar, **Then** the chat scrolls to the previous match and the counter decrements (wrapping from 1 to N).
4. **Given** search is active, **When** the user presses Escape or clicks the close button, **Then** the search bar closes and all highlights are removed from the chat.
5. **Given** the search bar was previously closed with a search term, **When** the user reopens search in the same session, **Then** the previous search term is pre-filled.

---

### User Story 3 - Global Shortcut Dispatcher (Priority: P3)

A user presses a keyboard shortcut (e.g., Ctrl+Shift+O for Options) from anywhere in the application — not just when the chat input is focused. The system intercepts the keypress, looks up the action from the shortcut registry, and dispatches the appropriate event to the LiveView. This replaces the current approach where shortcuts only work when specific elements are focused.

**Why this priority**: Without a global dispatcher, shortcuts are fragmented across individual hooks. Centralizing dispatch is the architectural prerequisite for navigation shortcuts and ensures consistent behavior regardless of focus.

**Independent Test**: Can be tested by focusing different elements (treebar, nicklist, chat area) and verifying that registered shortcuts still trigger their actions.

**Acceptance Scenarios**:

1. **Given** focus is on the nicklist (not the chat input), **When** the user presses Ctrl+Shift+F, **Then** the search bar opens.
2. **Given** the user is typing in the chat input, **When** they press Ctrl+Shift+O, **Then** the Options dialog opens (the shortcut is not typed into the input).
3. **Given** the user presses a shortcut that is not registered, **When** the key event fires, **Then** the default browser behavior is preserved (the shortcut is not swallowed).
4. **Given** a registered user has rebound "toggle_search" to Ctrl+Shift+Q, **When** they press Ctrl+Shift+Q, **Then** the search bar opens (and Ctrl+Shift+F no longer triggers search).

---

### User Story 4 - Window Navigation Shortcuts (Priority: P4)

A user has multiple channels and PMs open. They press Ctrl+Shift+] to switch to the next window (channel or PM) in the treebar order, or Ctrl+Shift+[ for the previous window. They can also press Ctrl+Shift+1 through Ctrl+Shift+9 to jump directly to the Nth window. The treebar visually updates to reflect the new active window.

**Why this priority**: Window navigation is the most frequently used keyboard action in IRC clients. However, it depends on the global dispatcher (P3) and the shortcut registry (P1).

**Independent Test**: Can be tested by joining multiple channels, pressing navigation shortcuts, and verifying the active channel changes correctly.

**Acceptance Scenarios**:

1. **Given** a user has channels #general (1st), #dev (2nd), #random (3rd) and #dev is active, **When** they press Ctrl+Shift+], **Then** #random becomes active and the treebar highlights it.
2. **Given** #general is the first window and is active, **When** the user presses Ctrl+Shift+[, **Then** the last window becomes active (wraps around).
3. **Given** a user has 3 windows open, **When** they press Ctrl+Shift+2, **Then** the 2nd window becomes active.
4. **Given** a user has 3 windows open, **When** they press Ctrl+Shift+7, **Then** nothing happens (fewer than 7 windows).
5. **Given** the Status window is in the list, **When** the user navigates to it via shortcuts, **Then** the Status view renders correctly.

---

### User Story 5 - Search Filters (Priority: P5)

A user needs to narrow search results. They toggle checkboxes in the search bar: "Case sensitive" makes the search respect letter casing. "Regex" enables regular expression patterns (e.g., `error|warn` matches both). "My mentions" filters to only messages containing the user's nickname. Invalid regex shows an inline error message rather than crashing.

**Why this priority**: Filters enhance search precision but are additive — basic search (P2) must work first.

**Independent Test**: Can be tested by searching with each filter individually and in combination, including the invalid regex error case.

**Acceptance Scenarios**:

1. **Given** messages contain "Error" and "error", **When** the user searches "error" with case-sensitive enabled, **Then** only lowercase "error" matches are highlighted.
2. **Given** the regex filter is enabled, **When** the user types `error|warn`, **Then** both "error" and "warn" occurrences are highlighted.
3. **Given** the regex filter is enabled, **When** the user types `[invalid`, **Then** an inline error message appears (e.g., "Invalid regex") and no search is performed.
4. **Given** the "My mentions" filter is active and the user's nick is "alice", **When** searching for "deploy", **Then** only messages containing both "deploy" and "alice" are highlighted.
5. **Given** no filters are active, **When** the user enables "Case sensitive" mid-search, **Then** results update immediately to reflect the filter.

---

### User Story 6 - Search in History (Priority: P6)

A user toggles the "Search history" checkbox to extend the search beyond currently loaded messages into the database. Results from history appear below current messages with a visual separator indicating they are historical. The search counter reflects the total across both loaded and historical results.

**Why this priority**: History search requires database queries and pagination — more complex than in-memory search. It's the least critical search enhancement for daily use.

**Independent Test**: Can be tested by sending messages, scrolling past them (so they unload), then toggling "Search history" and verifying database results appear.

**Acceptance Scenarios**:

1. **Given** the chat has 50 visible messages and 500 in the database, **When** the user enables "Search history" and searches "deploy", **Then** the counter shows total matches across both visible and historical messages.
2. **Given** "Search history" is enabled with results, **When** the user navigates to a historical result, **Then** the chat loads and scrolls to show that message in context.
3. **Given** "Search history" is disabled, **When** the user searches, **Then** only currently loaded/visible messages are searched (no database query).

---

### Edge Cases

- **Shortcut during text input**: Shortcuts using Ctrl+Shift+Key fire even when the chat input is focused. Single-key and unmodified shortcuts do NOT fire during text input.
- **Browser shortcut conflicts**: The system never overrides essential browser shortcuts. Only web-safe Ctrl+Shift+Key combinations are used for custom actions. See "Browser Safety" in Requirements.
- **Window count < shortcut number**: Ctrl+Shift+N where N > window count silently does nothing.
- **Empty search**: Searching with an empty string clears all highlights and resets the counter.
- **Very long messages**: Search highlighting handles messages that span multiple lines or contain HTML entities.
- **Debounced search input**: Search executes after a 300ms debounce to prevent UI freezing with rapid typing.
- **Concurrent search and navigation**: If a user navigates to a different channel while search is active, the search state resets for the new channel.

## Requirements *(mandatory)*

### Functional Requirements

#### Shortcut Registry & Cheatsheet
- **FR-001**: System MUST maintain a centralized registry of all keyboard shortcuts, including action name, default binding, current binding, and category.
- **FR-002**: System MUST provide a read-only cheatsheet dialog accessible via Ctrl+Shift+/ that displays all shortcuts grouped by category (Navigation, Chat, Formatting, System).
- **FR-003**: The cheatsheet MUST reflect the user's current custom bindings (if any), not just defaults.
- **FR-004**: The cheatsheet dialog MUST be closable via Escape key or X button.

#### Global Shortcut Dispatch
- **FR-005**: System MUST have a global keyboard event listener that intercepts registered shortcuts regardless of which UI element has focus.
- **FR-006**: When a registered shortcut is pressed, the system MUST dispatch the corresponding action to the server (LiveView).
- **FR-007**: When an unregistered key combination is pressed, the system MUST let the event propagate to default browser behavior.
- **FR-008**: Shortcuts MUST NOT fire during text input in form fields, EXCEPT for shortcuts using Ctrl+Shift modifier combinations which always fire.
- **FR-008a**: The global dispatcher MUST use standard event bubbling: focused-element handlers (e.g., text formatting in the chat input) fire first and may stop propagation. The global dispatcher only catches events not already handled by per-element hooks. This preserves existing formatting shortcuts (Ctrl+Shift+B/Y/U/D/V/X) when the chat input is focused.

#### Window Navigation
- **FR-009**: System MUST support "next window" (Ctrl+Shift+]) and "previous window" (Ctrl+Shift+[) shortcuts that cycle through open channels and PMs in treebar order.
- **FR-010**: System MUST support direct window access via Ctrl+Shift+1 through Ctrl+Shift+9 for the first 9 windows.
- **FR-011**: Window navigation MUST wrap around (next from last goes to first, previous from first goes to last).
- **FR-012**: Pressing Ctrl+Shift+N where N exceeds the window count MUST do nothing.

#### Search Enhancement
- **FR-013**: When search is active, all matching text in message body content MUST be highlighted with a yellow background. Nicknames, timestamps, and system messages are excluded from search matching and highlighting.
- **FR-014**: The currently active match MUST be visually distinguished from other matches (e.g., brighter highlight or outline).
- **FR-015**: System MUST support navigating between matches using Up/Down arrows in the search bar and Find Prev/Find Next buttons.
- **FR-016**: The counter MUST display the current match position and total count in "X of Y" format.
- **FR-017**: Navigation MUST wrap around (going past the last result returns to the first).
- **FR-018**: System MUST remember the last search term when the search bar is reopened in the same session.
- **FR-019**: All highlights MUST be removed when search is closed.

#### Search Filters
- **FR-020**: System MUST provide a "Case sensitive" toggle that switches between case-insensitive (default) and case-sensitive matching.
- **FR-021**: System MUST provide a "Regex" toggle that interprets the search term as a regular expression.
- **FR-022**: System MUST display an inline error message when an invalid regex is entered (not crash or throw).
- **FR-023**: System MUST provide a "My mentions" toggle that restricts results to messages containing the current user's nickname.
- **FR-024**: Filter changes MUST immediately update search results without requiring re-submission.

#### History Search
- **FR-025**: System MUST provide a "Search history" toggle that extends search to database-stored messages beyond the currently loaded set.
- **FR-026**: Historical results MUST be visually distinguishable from in-memory results.
- **FR-027**: Navigating to a historical result MUST load that message and its surrounding context into the chat view.

#### Custom Keybindings
- **FR-028**: Registered users MUST be able to rebind shortcuts in the Options dialog (existing Key Bindings panel).
- **FR-029**: The system MUST detect and warn about binding conflicts when a user attempts to assign a key combination already in use.
- **FR-030**: Custom bindings MUST NOT allow single-key assignments (would break typing).
- **FR-031**: Custom bindings MUST persist across sessions for registered users.
- **FR-032**: A "Reset to Defaults" option MUST restore all shortcuts to their original bindings.

### Browser Safety (Non-Negotiable)

The following key combinations are RESERVED and MUST NOT be overridden by the application:

- **Ctrl+key** (single modifier): Ctrl+T, Ctrl+W, Ctrl+N, Ctrl+L, Ctrl+H, Ctrl+J, Ctrl+D, Ctrl+R, Ctrl+O, Ctrl+S, Ctrl+P, Ctrl+F, Ctrl+G, Ctrl+E, Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z, Ctrl+Tab, Ctrl+Shift+Tab
- **DevTools & browser UI**: Ctrl+Shift+I, Ctrl+Shift+J, Ctrl+Shift+C, Ctrl+Shift+N, Ctrl+Shift+T, Ctrl+Shift+W, Ctrl+Shift+K, Ctrl+Shift+R, Ctrl+Shift+P, Ctrl+Shift+M, Ctrl+Shift+Delete
- **Alt+letter**: Blocked entirely (produces special characters on macOS, opens menus on Linux/Windows)
- **Function keys**: F1 (browser help), F3 (browser find), F5 (browser refresh), F6 (address bar), F11 (fullscreen), F12 (DevTools)

**Safe patterns used by this feature**: Ctrl+Shift+/ (cheatsheet), Ctrl+Shift+[ and ] (navigation), Ctrl+Shift+1..9 (window select), and the existing Ctrl+Shift+Letter bindings.

### Key Entities

- **Shortcut Registry Entry**: Action identifier, default key binding, current key binding, category, display label, description.
- **Search State**: Query string, filter flags (case-sensitive, regex, my-mentions, history), result list, current index, total count.
- **Custom Binding**: User reference, action identifier, key combination (key + modifiers), persisted as JSON in user preferences.

## Clarifications

### Session 2026-02-13

- Q: How should the global shortcut dispatcher coexist with existing per-element hooks (e.g., formatting shortcuts in autocomplete_hook)? → A: Standard bubble-up pattern — focused-element handlers fire first and may stop propagation; global dispatcher only catches unhandled events.
- Q: What text regions within a chat message should search highlighting apply to? → A: Message body text only — nicknames, timestamps, and system messages are excluded from search matching and highlighting.

## Assumptions

- The existing `KeyBindings` module and Options dialog Key Bindings panel provide the foundation for custom keybinding management — they will be extended, not replaced.
- The existing `search_bar.ex` component and `search_events.ex` handler will be enhanced with highlighting and filters rather than rebuilt from scratch.
- Search highlighting will be implemented client-side via a JavaScript hook that wraps matching text in highlight elements, since modifying the LiveView stream retroactively is not feasible.
- The "Ctrl+Shift+Key" pattern is the project's established convention for web-safe shortcuts and will be used for all new bindings.
- Guest users can use all shortcuts with default bindings but cannot persist custom bindings.
- The treebar order (Status first, then channels sorted alphabetically, then PMs sorted alphabetically) defines the window order for navigation shortcuts.
- Database history search will reuse the existing `Search.search_messages/3` function with pagination.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can discover all available shortcuts within 2 seconds by pressing a single shortcut to open the cheatsheet.
- **SC-002**: Users can switch between any two open channels/PMs using only the keyboard in under 1 second.
- **SC-003**: Search results are highlighted in the chat within 500ms of the user stopping typing (after debounce).
- **SC-004**: Users can navigate to any search match (forward or backward) with a single keypress.
- **SC-005**: All keyboard shortcuts work regardless of which UI element currently has focus.
- **SC-006**: Zero browser shortcut conflicts — no application shortcut overrides any standard browser shortcut.
- **SC-007**: Invalid regex input displays an error message instead of causing any application error.
- **SC-008**: Custom keybindings persist correctly across page reloads and new sessions for registered users.
