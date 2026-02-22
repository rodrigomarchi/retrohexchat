# Feature Specification: Context Menus

**Feature Branch**: `026-context-menus`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Context Menus for RetroHexChat — comprehensive right-click menus for chat area elements (nicks, URLs, channels, messages) and extended treebar menu"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nick Context Menu in Chat Area (Priority: P1)

A user right-clicks on a nickname displayed in the chat message area. A retro-styled context menu appears at the cursor position with actions relevant to that user: Private Message, Whois, Copy Nick, a separator, then Ignore, Add to Address Book, and Set Nick Color. If the right-clicking user is a channel operator, additional items appear below a second separator: Kick, Ban, Give Voice (+v), Give Op (+o). Each menu item displays its keyboard shortcut (if any) right-aligned. Items unavailable in the current context appear grayed out and are not clickable.

**Why this priority**: Nicknames are the most frequently right-clicked element in any IRC client. This delivers the highest-value context menu since it enables the most common user actions (PM, whois, ignore) without typing commands. It also establishes the shared menu infrastructure (positioning, shortcuts display, disabled states) that all other menus build upon.

**Independent Test**: Can be fully tested by right-clicking any nickname in a chat message and verifying all menu items appear, shortcuts are displayed, disabled states work, and each action executes correctly.

**Acceptance Scenarios**:

1. **Given** a user is in a channel viewing chat messages, **When** they right-click a nickname in a message, **Then** a context menu appears at the cursor position with items: Private Message, Whois, Copy Nick, separator, Ignore, Add to Address Book, Set Nick Color.
2. **Given** a user is a channel operator, **When** they right-click a nickname in chat, **Then** operator actions (Kick, Ban, Give Voice, Give Op) appear below a separator in addition to the standard items.
3. **Given** a user is NOT a channel operator, **When** they right-click a nickname in chat, **Then** operator actions do NOT appear in the menu under any circumstance.
4. **Given** a context menu is open, **When** the user clicks a menu item that has a keyboard shortcut, **Then** the shortcut text is displayed right-aligned on that menu item row.
5. **Given** a menu item is unavailable (e.g., user already ignored), **When** the menu is displayed, **Then** that item appears grayed out and clicking it has no effect.
6. **Given** a user right-clicks their own nickname in chat, **When** the menu appears, **Then** self-targeting actions (Kick, Ban, Ignore) are grayed out or hidden.

---

### User Story 2 - URL Context Menu in Chat Area (Priority: P2)

A user right-clicks on a URL displayed in a chat message. A context menu appears with: Open Link (opens in new browser tab), Copy URL (copies to clipboard), and Save to URL List (adds to the user's saved URLs collection).

**Why this priority**: URLs are the second most commonly right-clicked element in chat. Providing quick access to open, copy, and save links eliminates manual selection and copying.

**Independent Test**: Can be fully tested by right-clicking a URL in a chat message and verifying each action (open, copy, save) works correctly.

**Acceptance Scenarios**:

1. **Given** a chat message contains a URL, **When** the user right-clicks on it, **Then** a context menu appears with Open Link, Copy URL, and Save to URL List.
2. **Given** the URL context menu is visible, **When** the user clicks "Open Link", **Then** the URL opens in a new browser tab.
3. **Given** the URL context menu is visible, **When** the user clicks "Copy URL", **Then** the full URL is copied to the clipboard.
4. **Given** the URL context menu is visible, **When** the user clicks "Save to URL List", **Then** the URL is added to the user's saved URL collection.

---

### User Story 3 - Channel Name Context Menu in Chat Area (Priority: P3)

A user right-clicks on a #channel name mentioned in a chat message. A context menu appears with: Join Channel, Add to Favorites, Copy Channel Name, and Channel Info.

**Why this priority**: Channel names in chat messages are a natural discovery point. Providing a context menu lets users quickly join or inspect channels without typing commands.

**Independent Test**: Can be fully tested by right-clicking a #channel reference in a chat message and verifying each action works correctly.

**Acceptance Scenarios**:

1. **Given** a chat message mentions a #channel name, **When** the user right-clicks on it, **Then** a context menu appears with Join Channel, Add to Favorites, Copy Channel Name, and Channel Info.
2. **Given** the user is already in the channel, **When** "Join Channel" is shown, **Then** it appears grayed out (since they are already joined).
3. **Given** the user clicks "Channel Info", **Then** the channel information dialog opens for that channel.
4. **Given** the user clicks "Copy Channel Name", **Then** the channel name (including the # prefix) is copied to the clipboard.

---

### User Story 4 - General Message Context Menu (Priority: P4)

A user right-clicks on the general chat area (not on a specific nick, URL, or channel reference). A context menu appears with: Copy Message (copies the full formatted message line including timestamp, nick prefix, and message body — e.g., `[14:32] <Alice> hello everyone`), Copy Selected Text (copies only the text selection, enabled only if text is selected), Quote/Reply (disabled until Message Interaction feature is implemented), and Ignore Sender (adds the message author to ignore list). If the message contains a URL, URL-specific items (Open Link, Copy URL) also appear in the menu.

**Why this priority**: Provides general-purpose actions for any message. Lower priority because it covers less frequent actions and depends on text selection state.

**Independent Test**: Can be fully tested by right-clicking in the chat area on a regular message and verifying menu items and their conditional states.

**Acceptance Scenarios**:

1. **Given** a user right-clicks on a regular chat message (not on a nick/URL/channel), **When** the context menu appears, **Then** it shows Copy Message, Copy Selected Text, Quote/Reply (disabled), and Ignore Sender.
2. **Given** text is selected in the chat area, **When** the user right-clicks, **Then** "Copy Selected Text" is enabled and copies the selection when clicked.
3. **Given** no text is selected, **When** the user right-clicks, **Then** "Copy Selected Text" appears grayed out.
4. **Given** the message contains a URL, **When** the user right-clicks on the message area (not directly on the URL), **Then** URL-related items (Open Link, Copy URL) also appear in the menu.
5. **Given** the message is a system message (join/part/quit), **When** the user right-clicks, **Then** the menu appears but "Ignore Sender" is NOT shown (no sender to ignore).
6. **Given** Quote/Reply functionality is not yet implemented, **When** the menu appears, **Then** "Quote/Reply" is shown but grayed out and not clickable.

---

### User Story 5 - Extended Treebar Context Menu (Priority: P5)

A user right-clicks on a channel in the treebar sidebar. The existing minimal menu (only "Add to Favorites") is replaced with an extended menu: Mark as Read, Mute Channel, Add to Favorites, Copy Name, a separator, Leave Channel, and Channel Settings.

**Why this priority**: Enhances an existing feature rather than creating a new interaction point. The treebar already has a basic context menu, so this is an incremental improvement.

**Independent Test**: Can be fully tested by right-clicking a channel in the treebar and verifying all extended menu items appear and function correctly.

**Acceptance Scenarios**:

1. **Given** a user right-clicks a channel in the treebar, **When** the context menu appears, **Then** it shows: Mark as Read, Mute Channel, Add to Favorites, Copy Name, separator, Leave Channel, Channel Settings.
2. **Given** a channel has unread messages, **When** the user clicks "Mark as Read", **Then** the unread indicator for that channel is cleared.
3. **Given** the user clicks "Mute Channel", **Then** the channel is muted (no notification sounds or visual alerts for new messages) and the menu item toggles to "Unmute Channel".
4. **Given** the user clicks "Leave Channel", **Then** the user leaves the channel (equivalent to /part command).
5. **Given** the user clicks "Channel Settings", **Then** the channel settings dialog opens for that channel.
6. **Given** the user clicks "Copy Name", **Then** the channel name is copied to the clipboard.

---

### Edge Cases

- **Viewport boundary**: When a context menu would appear partially outside the visible viewport, it repositions (flips up and/or left) to remain fully visible.
- **Menu overlap**: Right-clicking while another context menu is open closes the first menu and opens the new one at the new cursor position. Only one context menu can be visible at a time.
- **Input field preservation**: Right-clicking in the message input field does NOT show a custom context menu — the browser's default context menu is preserved for paste, spell-check, and other native input actions.
- **Element specificity**: If multiple interactive elements overlap (e.g., a nickname that is also part of a URL), the most specific element wins. Priority order: nick > URL > channel > general message.
- **Self-targeting**: Right-clicking your own nickname shows the menu but self-harmful actions (Kick, Ban, Ignore) are grayed out.
- **Keyboard navigation**: Once a context menu is open, arrow keys (Up/Down) move focus between items (skipping disabled items and separators), Enter selects the focused item, and Escape closes the menu without executing any action.
- **Click-away dismissal**: Clicking anywhere outside the context menu closes it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a context menu when the user right-clicks a nickname in the chat message area, with items: Private Message, Whois, Copy Nick, Ignore, Add to Address Book, Set Nick Color, and (for operators) Kick, Ban, Give Voice (+v), Give Op (+o).
- **FR-002**: System MUST display a context menu when the user right-clicks a URL in the chat message area, with items: Open Link, Copy URL, Save to URL List.
- **FR-003**: System MUST display a context menu when the user right-clicks a #channel name in the chat message area, with items: Join Channel, Add to Favorites, Copy Channel Name, Channel Info.
- **FR-004**: System MUST display a context menu when the user right-clicks the general chat message area, with items: Copy Message, Copy Selected Text, Quote/Reply, Ignore Sender, plus URL items if the message contains a URL.
- **FR-005**: System MUST extend the treebar channel context menu to include: Mark as Read, Mute Channel, Add to Favorites, Copy Name, Leave Channel, Channel Settings.
- **FR-006**: System MUST display keyboard shortcut hints right-aligned on menu items that have associated shortcuts.
- **FR-007**: System MUST gray out and disable menu items that are unavailable in the current context (e.g., operator actions for non-operators, Copy Selected Text when no text is selected, Quote/Reply until feature is implemented).
- **FR-008**: System MUST NOT display operator-only menu items (Kick, Ban, Give Voice, Give Op) to non-operator users under any circumstance.
- **FR-009**: System MUST NOT override the browser's default context menu on the message input field.
- **FR-010**: System MUST reposition context menus that would extend beyond the viewport boundary by flipping vertically and/or horizontally to remain fully visible.
- **FR-011**: System MUST close any open context menu when a new context menu is triggered, when the user clicks outside the menu, or when Escape is pressed.
- **FR-017**: System MUST support keyboard navigation within open context menus: Up/Down arrow keys move focus between enabled items (skipping disabled items and separators), Enter activates the focused item, and Escape closes the menu.
- **FR-012**: System MUST use the most specific element when right-clicking overlapping elements, with priority: nick > URL > channel > general message.
- **FR-013**: System MUST use visual separators between logical groups of menu items (standard actions, personal actions, operator actions).
- **FR-014**: System MUST NOT show "Ignore Sender" on system messages (join/part/quit notifications).
- **FR-015**: System MUST respect existing ignore lists and channel permissions when displaying and executing menu actions.
- **FR-016**: "Quote/Reply" MUST be displayed as disabled/grayed until the Message Interaction feature is implemented, and MUST NOT cause errors when clicked.

### Key Entities

- **Context Menu**: A floating menu anchored to cursor position, containing action items grouped by separators. Key attributes: menu type (nick/URL/channel/message/treebar), position (x, y), target element data (nick name, URL, channel name, message content), visibility state.
- **Menu Item**: An individual action within a context menu. Key attributes: label, action identifier, keyboard shortcut (optional), enabled/disabled state, visibility conditions (e.g., operator-only).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can perform common actions (PM, whois, ignore, copy) on any nickname in chat within 2 clicks (right-click + menu item click) instead of typing a command.
- **SC-002**: Users can open, copy, or save any URL in chat within 2 clicks instead of manually selecting and copying text.
- **SC-003**: Users can join or inspect any mentioned channel within 2 clicks from the chat area.
- **SC-004**: All context menus appear within 200ms of right-click and remain fully visible within the viewport regardless of click position.
- **SC-005**: 100% of operator-restricted actions are hidden from non-operator users with no exceptions.
- **SC-006**: The browser's native context menu remains fully functional in the message input field.
- **SC-007**: All five context menu types (nick, URL, channel, message, treebar) are accessible and functional for both guest and registered users.
- **SC-008**: Every menu item that has an associated keyboard shortcut displays that shortcut hint in the menu.

## Clarifications

### Session 2026-02-14

- Q: What does "Copy Message" copy — just body, or timestamp + nick + body? → A: Timestamp + nick + message (e.g., `[14:32] <Alice> hello everyone`), matching mIRC convention.
- Q: Should open context menus support keyboard navigation (arrow keys, Enter)? → A: Yes — full keyboard nav: Up/Down moves focus between enabled items (skipping disabled/separators), Enter selects, Escape closes.
- Q: Is the "Mute Channel" state persisted across sessions or session-only? → A: Persisted across sessions, stored in user preferences (survives reload/re-login).

## Assumptions

- The existing context menu infrastructure (retro styling, fixed positioning, phx-click event handling) will be reused and extended for new menu types.
- Chat messages already render nicknames, URLs, and channel references as distinct, identifiable elements (or can be enhanced to do so with data attributes).
- The "Save to URL List" action integrates with the existing URL catcher/list feature if present, or creates a simple saved URLs collection.
- "Channel Settings" opens the existing channel settings dialog. "Channel Info" opens the existing channel info/whois-style display.
- Keyboard shortcut hints are sourced from the keybinding system implemented in feature 025.
- The color picker for "Set Nick Color" reuses the existing color picker from the nicklist context menu.
- "Mark as Read" clears the unread indicator already tracked by the treebar/channel system.
- "Mute Channel" toggles a per-channel mute state that suppresses notification sounds and visual alerts but does not leave the channel. The mute state is persisted in user preferences and survives page reloads and re-logins.
