# Feature Specification: Interactive Chat Elements

**Feature Branch**: `027-interactive-chat-elements`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Interactive Elements in Chat for RetroHexChat — clickable URLs, channels, and nicks with hover tooltips and nick hover cards."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clickable URLs with Hover Tooltip (Priority: P1)

A user sees a URL in a chat message (e.g., "check https://hexdocs.pm/phoenix"). The URL is already visually distinct (existing feature). On hover, the cursor changes to a pointer and the URL becomes underlined. A tooltip appears showing the page title if available (e.g., "Phoenix Framework — Overview"). If no title is available, the tooltip shows the full URL. Clicking the URL opens it in a new browser tab.

**Why this priority**: URLs are the most common interactive element in chat. Making them obviously clickable with hover feedback is the foundation of interactive chat. This builds directly on the existing URL detection and linkification system, requiring minimal new infrastructure.

**Independent Test**: Can be fully tested by sending a message containing a URL and verifying hover tooltip appears and click opens a new tab.

**Acceptance Scenarios**:

1. **Given** a message containing "https://hexdocs.pm/phoenix" is displayed, **When** the user hovers over the URL, **Then** the cursor changes to pointer, the URL becomes underlined, and a tooltip shows the page title (if fetched) or the full URL
2. **Given** a message containing a URL is displayed, **When** the user clicks the URL, **Then** it opens in a new browser tab without affecting the chat
3. **Given** a message containing a long URL (over 100 characters) is displayed, **When** viewing the message, **Then** the display text is visually truncated but the link points to the full URL and the tooltip shows the full URL
4. **Given** a URL with special characters (query params, fragments, encoded chars), **When** displayed in chat, **Then** the URL is still clickable and opens correctly

---

### User Story 2 - Clickable Channel Names (Priority: P2)

A user sees a channel name mentioned in chat (e.g., "join us in #dev for the discussion"). The "#dev" text is visually distinct (colored). On hover, the cursor changes to a pointer, the text becomes underlined, and a tooltip shows channel info: "#dev — 5 users — Click to join". Clicking the channel name either joins the channel (if not already joined) or switches to it (if already joined).

**Why this priority**: Channel discovery and navigation is a core chat workflow. Clickable channels reduce friction — instead of typing "/join #dev", users simply click. This is the second most common interactive element after URLs.

**Independent Test**: Can be fully tested by sending a message mentioning a channel name and verifying hover tooltip shows user count and click joins/switches to the channel.

**Acceptance Scenarios**:

1. **Given** a message containing "#dev" is displayed and the user is NOT in #dev, **When** the user hovers over "#dev", **Then** a tooltip shows "#dev — N users — Click to join" with the current user count
2. **Given** the user hovers over "#dev" and clicks it, **When** the user is NOT in #dev, **Then** the user joins #dev and it becomes the active channel
3. **Given** the user hovers over "#general" and clicks it, **When** the user is already in #general, **Then** the view switches to #general without re-joining
4. **Given** a message containing "#dev." (channel followed by period), **When** displayed in chat, **Then** only "#dev" is interactive — the period is not included in the clickable element
5. **Given** a message containing a channel name, **When** the user hovers over it, **Then** the tooltip shows the real-time user count for that channel

---

### User Story 3 - Clickable Nicks with Hover Card (Priority: P3)

A user sees a message from "Mario" in chat. When they hover over Mario's nick in the message for 500ms without mouse movement, a mini-card appears showing: nick, hostname, online duration, and channels. The card includes subtle interaction hints: "Click: insert nick | Double-click: PM | Right-click: menu". Single-clicking the nick inserts "Mario: " into the input field. Double-clicking opens a PM conversation with Mario.

**Why this priority**: Nick interaction is the most complex story but delivers the richest value — it turns every nick mention into a gateway for user discovery and communication. It depends on existing whois infrastructure and builds on the context menu system's nick detection.

**Independent Test**: Can be fully tested by hovering over a nick in a message, verifying the hover card appears with correct user info, and testing click/double-click actions.

**Acceptance Scenarios**:

1. **Given** a message from "Mario" is displayed, **When** the user hovers over Mario's nick for 500ms without moving the mouse, **Then** a mini-card appears showing Mario's nick, hostname, online duration, and channels
2. **Given** the nick hover card is showing for Mario, **When** the user single-clicks Mario's nick, **Then** "Mario: " is inserted at the cursor position in the input field and the hover card dismisses
3. **Given** the nick hover card is showing for Mario, **When** the user double-clicks Mario's nick, **Then** a PM conversation with Mario opens and the hover card dismisses
4. **Given** the user is "Mario", **When** they hover over their own nick in their own messages, **Then** no hover card appears
5. **Given** the user is hovering over a nick, **When** they start selecting text (click and drag), **Then** no hover card appears — text selection takes priority
6. **Given** a hover card is showing for "Mario", **When** Mario changes their nick (to "Luigi"), **Then** the hover card dismisses automatically
7. **Given** whois data is not yet available for a nick, **When** the hover card appears, **Then** a loading state is shown briefly, followed by whatever info is available (at minimum, just the nick)
8. **Given** a context menu is currently open, **When** the user clicks or hovers on an interactive element, **Then** no additional interaction triggers — the context menu takes precedence

---

### Edge Cases

- Clicking a channel the user is already in switches to it rather than re-joining
- Channel names at end of sentences with trailing punctuation (e.g., "#dev.", "#dev,", "#dev!") must not include the punctuation in the interactive element
- URLs with special characters (encoded chars, query strings, fragments) must remain fully clickable
- Long URLs are visually truncated in the message but the tooltip and link target use the full URL
- Nick hover cards must not appear while the user is actively selecting text — only on idle hover after 500ms without mouse movement
- Nick hover cards must not appear for the user's own nick in their own messages
- Clicking interactive elements must not trigger if the user dragged/selected text (distinguish click from text selection)
- Hover tooltips must not remain stuck if the mouse leaves the browser viewport
- If a context menu is currently open, no click/hover interactions on interactive elements should trigger
- The hover card must position itself to stay within the viewport (reposition if near edges)
- Multiple rapid hovers over different nicks should cancel pending hover cards — only the most recent hover triggers

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a pointer cursor and underline on hover for all URLs in chat messages
- **FR-002**: System MUST show a tooltip on URL hover displaying the page title (if available from link preview) or the full URL
- **FR-003**: System MUST open URLs in a new browser tab when clicked, without navigating away from the chat
- **FR-004**: System MUST display channel names in chat messages as interactive elements with distinct visual styling (color, pointer cursor, underline on hover)
- **FR-005**: System MUST show a tooltip on channel name hover displaying the channel name, current user count, and "Click to join" hint
- **FR-006**: System MUST join the referenced channel when a user clicks a channel name they have not yet joined
- **FR-007**: System MUST switch to the referenced channel when a user clicks a channel name they are already in
- **FR-008**: System MUST exclude trailing punctuation (period, comma, exclamation, question mark, semicolon, colon) from channel name interactive elements
- **FR-009**: System MUST display a nick hover card after 500ms of idle hover (no mouse movement) over a nick in chat messages
- **FR-010**: System MUST populate the nick hover card with: nickname, hostname, online duration, and list of channels the user is in
- **FR-011**: System MUST show a loading state in the nick hover card while whois data is being fetched
- **FR-012**: System MUST insert "Nick: " at the cursor position in the input field when a nick in a chat message is single-clicked (without text selection)
- **FR-013**: System MUST open a PM conversation when a nick in a chat message is double-clicked
- **FR-014**: System MUST NOT show the nick hover card for the current user's own nick in their own messages
- **FR-015**: System MUST NOT trigger hover cards while the user is actively selecting text
- **FR-016**: System MUST dismiss the nick hover card when the hovered nick changes their nickname
- **FR-017**: System MUST NOT trigger interactive element clicks or hovers when a context menu is open
- **FR-018**: System MUST cancel pending hover card timers when the mouse moves to a different element
- **FR-019**: System MUST dismiss hover tooltips and cards when the mouse leaves the browser viewport
- **FR-020**: System MUST distinguish between click and text-selection gestures — only trigger click actions when no text was selected during the mousedown-mouseup sequence
- **FR-021**: System MUST display interaction hints on the nick hover card: "Click: insert nick | Double-click: PM | Right-click: menu"

### Key Entities

- **Interactive Element**: A segment of chat message text that responds to hover and click. Types: URL, channel name, nick. Each has distinct hover behavior (tooltip vs. hover card) and click actions.
- **Nick Hover Card**: A transient overlay displaying user information (nick, host, online time, channels). Triggered by idle hover, dismissed on mouse leave, click action, or nick change.
- **Channel Tooltip**: A lightweight tooltip showing channel name, user count, and join hint. Appears on hover over channel names in messages.
- **URL Tooltip**: A lightweight tooltip showing page title or full URL. Appears on hover over links in messages.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open a URL from a chat message in one click, without needing to copy-paste
- **SC-002**: Users can join or switch to a channel mentioned in chat in one click, eliminating the need to type "/join #channel"
- **SC-003**: Users can view another user's basic info (nick, host, online time, channels) by hovering over their name for 500ms, without typing "/whois"
- **SC-004**: Users can start a PM conversation with another user by double-clicking their nick, eliminating the need to type "/msg nick"
- **SC-005**: Users can insert a nick into the input field by single-clicking it, eliminating manual typing
- **SC-006**: Interactive elements do not interfere with text selection — users can still select and copy text from chat messages without triggering click actions
- **SC-007**: All three interactive element types (URL, channel, nick) provide visual hover feedback (cursor change, underline or card) within 100ms of hover
- **SC-008**: Nick hover cards appear within 600ms of initiating hover (500ms delay + 100ms render) and dismiss instantly on mouse leave

### Assumptions

- The existing URL detection and linkification system (URL detector, formatter) will be extended rather than replaced
- The existing link preview system already fetches page titles — hover tooltips will reuse this data when available
- Channel user counts are available from the channel GenServer state and can be queried in real time
- Whois data for nick hover cards will use the same data gathering logic as the `/whois` command
- The context menu system's element detection logic (nick/URL/channel detection via data attributes) will be shared with the interactive elements system
- Nick hover cards show channels visible to the requesting user (secret channels filtered as in existing whois)
- The 500ms hover delay for nick cards is sufficient to prevent accidental triggers during normal mouse movement
