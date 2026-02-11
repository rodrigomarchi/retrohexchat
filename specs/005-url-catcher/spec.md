# Feature Specification: URL Catcher

**Feature Branch**: `005-url-catcher`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "URL Catcher for RetroHexChat — URL auto-detection and clickable rendering, URL Catcher window with filtering and search, inline link preview (page title only)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clickable URLs in Chat Messages (Priority: P1)

A user sends a message containing a URL (e.g., "check this out https://hexdocs.pm/phoenix"). The URL is automatically detected within the message text, rendered as a clickable link with a distinct visual style (underlined, different color from normal text), and opens in a new browser tab when clicked. The rest of the message text remains as normal chat text. URLs are detected in both channel messages and private messages.

**Why this priority**: This is the foundational capability — without clickable URLs, the URL Catcher window and link previews have nothing to build on. Every chat application needs clickable links as a basic usability feature. This single story delivers immediate value to every user who shares or receives a link.

**Independent Test**: Can be fully tested by sending a message with a URL and verifying it renders as a clickable link that opens in a new tab. Delivers the core value of making links usable.

**Acceptance Scenarios**:

1. **Given** a user is in a channel, **When** another user sends a message containing `https://hexdocs.pm/phoenix`, **Then** the URL portion renders as an underlined, distinctly colored clickable link while surrounding text renders normally.
2. **Given** a chat message contains a clickable URL, **When** the user clicks the link, **Then** the URL opens in a new browser tab.
3. **Given** a user sends "visit https://example.com.", **When** the message is rendered, **Then** the trailing period is NOT part of the clickable URL.
4. **Given** a message contains a URL with query parameters and fragments (e.g., `https://example.com/path?q=test&page=2#section`), **When** rendered, **Then** the full URL including query string and fragment is clickable.
5. **Given** a message contains a very long URL (over 100 characters), **When** rendered in chat, **Then** the link text is visually truncated with an ellipsis but the full URL is preserved in the link target.
6. **Given** a user is in a private message conversation, **When** a message containing a URL is sent, **Then** the URL is rendered as a clickable link identically to channel messages.
7. **Given** a message contains multiple URLs, **When** rendered, **Then** each URL is independently clickable with the correct target.

---

### User Story 2 - URL Catcher Window (Priority: P2)

A user opens the URL Catcher window (via the menu bar or a keyboard shortcut). The window displays a sortable list of all URLs that have been shared in channels and PMs the user is currently participating in, since the user connected. The list shows columns: URL, Channel/PM name, Posted By (nickname), and Time. The user can filter entries by channel name or search by URL text. Double-clicking an entry opens the URL in a new browser tab.

**Why this priority**: The URL Catcher window is the main differentiating feature — it solves the "I missed a link" problem. It depends on US1 for URL detection but adds significant standalone value as a URL aggregation and discovery tool.

**Independent Test**: Can be tested by sending messages with URLs in multiple channels, opening the URL Catcher window, and verifying all URLs appear with correct metadata. Filter and search can be tested independently.

**Acceptance Scenarios**:

1. **Given** a connected user has received messages containing URLs in channels #elixir and #general, **When** the user opens the URL Catcher window, **Then** the window displays all captured URLs in a table with columns: URL, Channel, Posted By, and Time.
2. **Given** the URL Catcher window is open showing multiple entries, **When** the user clicks a column header, **Then** the entries are sorted by that column (toggling ascending/descending on repeated clicks).
3. **Given** the URL Catcher has entries from multiple channels, **When** the user selects a channel from the filter dropdown, **Then** only URLs from that channel are displayed.
4. **Given** the URL Catcher has multiple entries, **When** the user types "github" in the search field, **Then** only entries whose URL contains "github" are shown.
5. **Given** the URL Catcher shows a list of entries, **When** the user double-clicks an entry, **Then** the URL opens in a new browser tab.
6. **Given** the user disconnects and reconnects, **When** the user opens the URL Catcher window, **Then** the list is empty (no URLs carried over from the previous session).
7. **Given** a URL is posted in a channel the user has not joined, **When** the user opens the URL Catcher, **Then** that URL does NOT appear in the list.
8. **Given** the URL Catcher window is open, **When** a new message with a URL arrives in a joined channel, **Then** the new URL appears in the URL Catcher list in real-time without requiring a manual refresh.

---

### User Story 3 - Inline Link Preview (Priority: P3)

When a message containing a URL is displayed, the system asynchronously fetches the page title from the linked URL and displays it as a small preview below or beside the link text. The preview shows only the page title as plain text. If the page cannot be reached or has no title, no preview is shown. The preview rendering does not block or delay the original message display.

**Why this priority**: Link previews add a nice-to-have enhancement on top of clickable URLs but are not essential. They require server-side HTTP fetching which adds complexity. The feature degrades gracefully (no preview shown on failure), so it can be added after the core link and catcher functionality is solid.

**Independent Test**: Can be tested by sending a URL for a page with a known title, verifying the title appears as preview text, and sending a URL to an unreachable page to verify graceful degradation.

**Acceptance Scenarios**:

1. **Given** a message with URL `https://hexdocs.pm/phoenix` is displayed, **When** the system fetches the page, **Then** the page title (e.g., "Phoenix Framework") appears as a small plain-text preview near the link.
2. **Given** a message with a URL is displayed, **When** the page title has not yet been fetched, **Then** the message renders immediately without waiting for the preview.
3. **Given** a message contains a URL to an unreachable page (e.g., returns 404 or times out), **When** the fetch completes or times out, **Then** no preview is shown and no error is displayed to the user.
4. **Given** a linked page has a title containing HTML tags or script content (e.g., `<script>alert('xss')</script>`), **When** the preview is rendered, **Then** the title is displayed as escaped plain text — no HTML is interpreted or scripts executed.
5. **Given** a message contains multiple URLs, **When** previews are fetched, **Then** each URL gets its own independent preview (or no preview if fetch fails).
6. **Given** the same URL appears in multiple messages, **When** previews are rendered, **Then** the system may cache the title to avoid redundant fetches.

---

### User Story 4 - URL Catcher Access via Menu and Keyboard (Priority: P4)

The user can open the URL Catcher window via the menu bar (under a "Tools" or similar menu) and via a keyboard shortcut. The window follows the 98.css MDI window style consistent with other windows in the application (Notify List, Address Book, etc.). The window can be closed, and reopening it preserves the current session's captured URLs.

**Why this priority**: This is an accessibility and polish story. The window must be reachable, but the access mechanism is straightforward once the window itself exists (US2).

**Independent Test**: Can be tested by verifying the menu item exists, the keyboard shortcut opens the window, and the window matches 98.css styling.

**Acceptance Scenarios**:

1. **Given** the user is on the chat screen, **When** the user selects "URL Catcher" from the menu bar, **Then** the URL Catcher window opens.
2. **Given** the user is on the chat screen, **When** the user presses the designated keyboard shortcut, **Then** the URL Catcher window opens.
3. **Given** the URL Catcher window is open, **When** the user closes it and reopens it, **Then** all previously captured URLs in the current session are still present.
4. **Given** the URL Catcher window is open, **Then** it follows the 98.css MDI window styling consistent with other application windows.

---

### Edge Cases

- What happens when a URL contains parentheses (e.g., Wikipedia links like `https://en.wikipedia.org/wiki/Elixir_(programming_language)`)? The system must handle balanced parentheses within URLs correctly.
- What happens when a URL appears inside IRC formatting codes (bold, color)? The URL must still be detected and rendered as clickable, with formatting applied to the link.
- What happens when a message is only a URL with no surrounding text? The entire message becomes a single clickable link.
- How does the system handle URLs with internationalized domain names (IDN) or punycode? Standard `https://` prefixed URLs are detected; bare domains without protocol are not auto-linked.
- What happens when the URL Catcher has hundreds of entries? The list must remain responsive with no noticeable lag.
- What happens when the same URL is shared multiple times? Each occurrence appears as a separate entry in the URL Catcher (with its own channel, poster, and timestamp).
- How does the link preview handle redirects? The system follows up to 3 redirects and uses the final page's title.
- What happens with `http://` (non-HTTPS) URLs? They are detected and rendered as clickable links identically to HTTPS URLs.
- What happens when a user shares a URL in a message that also contains IRC formatting codes around the URL? The formatting is applied to the link element without breaking URL detection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST automatically detect URLs (http:// and https:// schemes) within chat message text and render them as clickable hyperlinks.
- **FR-002**: System MUST open clicked URLs in a new browser tab (target="_blank" behavior with appropriate security attributes).
- **FR-003**: System MUST correctly handle URL boundary detection — trailing punctuation (period, comma, exclamation mark, question mark, closing parenthesis when unbalanced) must not be included in the URL.
- **FR-004**: System MUST visually distinguish URLs from regular text with underline and a distinct link color that fits the 98.css/Windows 98 aesthetic.
- **FR-005**: System MUST visually truncate URLs longer than 100 characters in chat display while preserving the full URL as the link target.
- **FR-006**: System MUST detect and linkify URLs in both channel messages and private messages.
- **FR-007**: System MUST provide a URL Catcher window that lists all URLs captured from the user's joined channels and active PMs during the current session.
- **FR-008**: URL Catcher MUST display columns: URL, Channel/PM, Posted By, and Time.
- **FR-009**: URL Catcher MUST support sorting by any column (ascending and descending).
- **FR-010**: URL Catcher MUST support filtering by channel/PM name via a dropdown selector.
- **FR-011**: URL Catcher MUST support free-text search that filters entries by URL content.
- **FR-012**: URL Catcher MUST open the selected URL in a new browser tab when the user double-clicks an entry.
- **FR-013**: URL Catcher MUST update in real-time as new URLs arrive in messages.
- **FR-014**: URL Catcher data MUST NOT persist across sessions — it resets when the user disconnects and reconnects.
- **FR-015**: System MUST asynchronously fetch the page title for each detected URL and display it as a plain-text preview near the link in chat.
- **FR-016**: Link preview fetching MUST NOT block or delay message rendering — messages appear immediately, previews appear when ready.
- **FR-017**: Link preview MUST display only escaped plain text — no HTML rendering, no script execution from external page content.
- **FR-018**: Link preview MUST gracefully degrade — if the page is unreachable, returns an error, or has no title tag, no preview is shown.
- **FR-019**: Link preview fetch MUST time out after a reasonable period (assumption: 5 seconds) to avoid indefinite waiting.
- **FR-020**: System MUST support URLs containing query parameters, fragments, and special characters.
- **FR-021**: URL Catcher window MUST be accessible via the menu bar and a keyboard shortcut.
- **FR-022**: URL Catcher window MUST follow 98.css MDI window styling consistent with existing application windows.
- **FR-023**: System MUST handle multiple URLs in a single message, detecting and linkifying each independently.
- **FR-024**: URL detection MUST work correctly when URLs appear within or adjacent to IRC formatting codes (bold, italic, underline, color).

### Key Entities

- **CapturedURL**: Represents a single URL occurrence captured during the session. Attributes: URL string, source (channel name or PM identifier), poster nickname, timestamp, preview title (optional, populated asynchronously).
- **URLCatcherState**: Per-session collection of CapturedURL entries. Exists only in memory for the duration of the user's session. Supports filtering and sorting operations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of URLs using http:// or https:// schemes in chat messages are rendered as clickable links.
- **SC-002**: Users can find any URL shared in their joined channels during the current session within 10 seconds using the URL Catcher's search or filter.
- **SC-003**: Chat messages containing URLs render with no perceptible delay compared to messages without URLs.
- **SC-004**: Link preview titles appear within 5 seconds of message display for reachable pages.
- **SC-005**: Zero instances of external page content causing script execution or HTML injection in the chat interface (security requirement).
- **SC-006**: URL Catcher window remains responsive with up to 500 captured URL entries.
- **SC-007**: Trailing punctuation is correctly excluded from URLs in at least 99% of common sentence patterns (e.g., "visit https://example.com.", "see https://example.com, and also...").

## Assumptions

- Only URLs with explicit `http://` or `https://` schemes are auto-detected. Bare domains (e.g., `example.com`) are not auto-linked. This avoids false positives and keeps detection reliable.
- Link preview fetch timeout is 5 seconds. This balances user experience (not waiting too long) with allowing slow servers to respond.
- The URL Catcher captures URLs from the moment the user connects. Historical messages loaded before connect are not retroactively scanned.
- Link preview caching is per-session — the same URL fetched multiple times within a session may reuse a cached title to reduce external requests.
- The URL Catcher window uses the same MDI window pattern as the Notify List and Address Book windows.
- The keyboard shortcut for the URL Catcher follows the existing pattern (Alt+letter) — assumed Alt+U unless it conflicts with existing shortcuts.
- Very long URLs are truncated at 100 characters for display. This is a display-only truncation; the full URL is always available via the link and in the URL Catcher.
- Link preview follows up to 3 HTTP redirects before giving up.

## Scope

### In Scope

- URL auto-detection and clickable rendering in chat messages (channels and PMs)
- URL Catcher window with table view, sorting, filtering, and search
- Inline link preview showing page title only (plain text)
- 98.css-styled window and link rendering
- Real-time URL Catcher updates as new messages arrive

### Out of Scope

- Link preview thumbnails or rich embeds (images, videos, Open Graph cards)
- URL shortener resolution (e.g., expanding bit.ly links)
- Link safety or malware scanning
- URL persistence across sessions
- Auto-linking bare domains without protocol prefix
- Custom URL detection patterns or user-configurable URL rules
