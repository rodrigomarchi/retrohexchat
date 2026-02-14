# Research: Interactive Chat Elements

**Feature**: 027-interactive-chat-elements
**Date**: 2026-02-14

## R1: Hover Card vs. Tooltip — Which Pattern for Each Element?

**Decision**: URLs and channels use lightweight CSS tooltips (no server round-trip). Nicks use a rich hover card (server-side data fetch via LiveView event).

**Rationale**: URLs already have `title` attributes and link preview data cached client-side. Channel user counts require a server query but the tooltip is simple enough to render via a LiveView component update. Nick hover cards need whois data (channels, online time, host) which requires server-side gathering across multiple sources (GenServer, Tracker, NickServ).

**Alternatives considered**:
- All-client-side tooltips: Rejected because nick whois data is only available server-side.
- All-server-side: Rejected because URL/channel tooltips would add unnecessary latency for data already available client-side or easily fetched with a single event.

## R2: Click-vs-Drag Detection Strategy

**Decision**: Track `mousedown` position and compare with `mouseup` position. If the mouse moved more than 3px or `window.getSelection().toString()` is non-empty, suppress the click action.

**Rationale**: The existing context menu system already checks `has_selection` in its payload. This approach is consistent and handles both small accidental movements and deliberate text selection.

**Alternatives considered**:
- Using `click` event only with `getSelection()` check: Misses small drag gestures that don't create a visible selection.
- Pointer events API: Overengineered for this use case.

## R3: Hover Debounce for Nick Cards (500ms Idle)

**Decision**: Use `mouseenter` to start a 500ms timer, `mousemove` to reset it, `mouseleave` to cancel it. The timer fires only after 500ms of no mouse movement within the nick element.

**Rationale**: This prevents accidental hover cards while scrolling or moving the mouse across the chat area. The 500ms threshold matches the spec requirement and is standard for hover intent detection.

**Alternatives considered**:
- Simple `mouseenter` with fixed delay (no reset on movement): Would trigger cards during fast mouse passes.
- Using `mouseover`/`mouseout` with debounce: Bubbling complications with nested elements.

## R4: URL Tooltip Data Source

**Decision**: Reuse the existing `link_previews` map from `socket.assigns` which is populated by the link preview system. The tooltip will show the page title if available in `link_previews[url]`, otherwise falls back to the full URL (already in the `title` attribute of the `<a>` tag).

**Rationale**: The link preview system already fetches page titles asynchronously and caches them in ETS. The `link_preview` push event already updates the DOM. For tooltips, we can either use the native `title` attribute (already set to the full URL) or enhance it with the fetched title. The simplest approach: update the `title` attribute when a link preview arrives, so native browser tooltips show the page title.

**Alternatives considered**:
- Custom tooltip component rendered server-side: Adds complexity for minimal gain — native `title` attribute provides the same information.
- Client-side tooltip library: Violates Constitution Principle I (no JS UI frameworks).

**Final approach**: Use native browser `title` attribute for URL tooltips. When link preview data arrives (via the existing `link_preview` push event), update the `title` attribute of matching `<a>` tags to show the page title. This is zero-cost — no new components or events needed.

## R5: Channel Tooltip Data Source

**Decision**: When the user hovers over a channel name, the JS hook pushes a `"channel_hover"` event to the server. The server queries `Server.get_state/1` to get the member count and responds with a `push_event("channel_tooltip", ...)` containing the channel name, user count, and whether the user is already joined. The JS side renders a positioned tooltip element.

**Rationale**: Channel member count is only available server-side (GenServer state). A lightweight round-trip is acceptable since the data is small and the response is fast (in-memory GenServer call).

**Alternatives considered**:
- Periodically pushing all channel counts to client: Wasteful — most channels are never hovered.
- Using a separate tooltip component in LiveView: Adds DOM overhead for every channel mention in every message. Client-side tooltip is simpler.

## R6: Nick Hover Card Positioning

**Decision**: Position the hover card absolutely relative to the viewport, using the mouse coordinates from the hover event. Apply boundary detection to keep the card within the viewport (same pattern as context menu positioning in `context_menu_hook.js`).

**Rationale**: The context menu system already solves the viewport boundary problem. Reusing the same positioning strategy ensures consistency.

## R7: Nick Change Detection for Hover Card Dismissal

**Decision**: When a `"nick_changed"` PubSub event is received for the nick currently shown in the hover card, push a `"dismiss_hover_card"` event to the client. The server tracks the currently displayed hover card nick in assigns.

**Rationale**: Nick changes are already broadcast via PubSub. The server knows which nick the hover card is showing (from the `hover_card` assign). A simple check in the existing nick change handler is sufficient.

## R8: Coexistence with Context Menu System

**Decision**: The JS code checks a global `contextMenuOpen` flag before triggering any hover or click interactions. The context menu hook sets this flag on open and clears it on close. Interactive element handlers check this flag and bail out if true.

**Rationale**: The context menu and interactive elements use the same target elements (nicks, URLs, channels). Right-click must always open the context menu without interference. A simple boolean flag is the cleanest coordination mechanism.

**Alternatives considered**:
- Event.stopPropagation: Doesn't work across different event types (right-click vs hover).
- Checking DOM for `.context-menu` visibility: Fragile and slower than a boolean check.

## R9: Help Documentation

**Decision**: Add one help topic in the "Features" category: "Interactive Chat Elements" covering all three element types (URLs, channels, nicks), their hover behaviors, and click actions. Update the "Keyboard Shortcuts" topic if any keyboard interactions are added. Add "See Also" cross-references to existing "Links" and "Context Menus" topics.

**Rationale**: Constitution Principle XI requires help documentation for all user-facing features. A single comprehensive topic is appropriate since the three element types share a common interaction model.
