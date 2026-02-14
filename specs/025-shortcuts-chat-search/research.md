# Research: Keyboard Shortcuts & Chat Search

**Feature**: 025-shortcuts-chat-search
**Date**: 2026-02-13

## R1: Global Keyboard Dispatch Strategy

**Decision**: Bubble-up event pattern — global `document.addEventListener("keydown")` on the LiveView root element, with per-element handlers (AutocompleteHook) firing first via normal DOM propagation. Global dispatcher only acts on events not already handled.

**Rationale**: The existing `autocomplete_hook.js` handles Ctrl+Shift+B/Y/U/D/V/X for IRC formatting. A top-down dispatcher would break these. The bubble-up pattern lets focused-element handlers call `e.stopPropagation()` when they consume an event, so the global hook never sees it. This is the standard web pattern (VS Code, Slack, Discord all use it).

**Alternatives considered**:
- **Top-down dispatcher with skip-list**: Maintains explicit list of delegated shortcuts. Rejected — fragile, requires synchronizing two lists.
- **Move all shortcuts to global**: Remove formatting from AutocompleteHook. Rejected — formatting codes are input-context-specific (wrap selection, insert at cursor) and require access to the textarea.

**Implementation detail**: The `ShortcutDispatcherHook` attaches to the `#app-container` div (which already has `phx-window-keydown`). It listens at the document level and checks if the event was already handled by checking `e.defaultPrevented` or a custom `e._handled` flag set by element hooks.

## R2: Client-Side Search Highlighting Approach

**Decision**: JavaScript hook (`SearchHighlightHook`) that receives search parameters via `push_event` from the server and performs text matching + DOM manipulation on the client side.

**Rationale**: Search highlighting requires wrapping matched text in `<mark>` elements within the chat message DOM. LiveView streams render messages once and cannot retroactively modify rendered content. Client-side highlighting avoids re-rendering the entire message stream and provides instant visual feedback.

**Alternatives considered**:
- **Server-side rendering with highlight markup**: Rejected — would require re-rendering all messages on every search change, defeating stream efficiency.
- **CSS-only highlighting (::selection or CSS Custom Highlight API)**: The CSS Custom Highlight API is modern and performant but has limited browser support (no Firefox until v136+). Rejected for now due to compatibility concerns. Can be revisited as a progressive enhancement.
- **TreeWalker API for text scanning**: This IS the chosen sub-approach within the JS hook — use `TreeWalker` to find text nodes in message body elements, then wrap matches in `<mark>` tags.

**Implementation detail**:
1. Server sends `push_event("search_highlight", %{query: ..., flags: ...})` to client.
2. Hook scans all `.message-body` elements using `TreeWalker` for text nodes.
3. Matching text wrapped in `<mark class="search-highlight">` (all matches) or `<mark class="search-highlight-active">` (current match).
4. On close: `push_event("search_clear_highlights", %{})` removes all `<mark>` wrappers.
5. Navigation: server sends `push_event("search_scroll_to", %{index: N})` and hook scrolls the Nth match into view with `scrollIntoView({block: "center"})`.

## R3: Search Filter Architecture (Client vs Server)

**Decision**: Hybrid approach — client-side matching for visible/loaded messages, server-side for database history search.

**Rationale**: In-memory search on DOM content provides instant feedback (no round-trip). When "Search history" is toggled, the server queries PostgreSQL for historical matches. This gives the best of both worlds: instant feedback for visible content and comprehensive results for history.

**Alternatives considered**:
- **All server-side**: Every search keystroke → DB query. Rejected — too much latency for real-time highlighting of visible messages.
- **All client-side**: Load all messages into DOM for searching. Rejected — doesn't scale for channels with thousands of messages.

**Implementation detail**:
- **Case-sensitive**: JS uses regex flag `i` (default) or no flag.
- **Regex**: JS creates `new RegExp(query, flags)` wrapped in try/catch for invalid patterns.
- **My mentions**: JS filters matches to only those within message elements that contain the user's nick (checked via `data-nick` attribute or adjacent nick element).
- **History search**: Server-side uses `Search.search_messages/3` with new options `case_sensitive: bool`, `regex: bool`, `nick_filter: string`. Results pushed to client as message data for rendering in a history results panel.

## R4: Window Navigation Order

**Decision**: Window order follows the treebar DOM order: Status window (position 0, not numbered), then channels in rendered order, then PMs in rendered order. Ctrl+Shift+1 maps to the first channel, not Status.

**Rationale**: Users think of numbered windows starting with their first channel, not the system Status window. Status is always accessible but rarely the navigation target. This matches mIRC behavior where Alt+1 is the first channel.

**Alternatives considered**:
- **Status as position 1**: Wastes the most common shortcut on the least-used window. Rejected.
- **Insertion order instead of alpha order**: Unpredictable, hard to remember. Rejected — alphabetical is deterministic.

**Implementation detail**: The server maintains a `window_list` assign computed from `@channels` ++ `@pm_conversations` (in treebar render order). Navigation events (`window_next`, `window_prev`, `window_select`) index into this list. Status window is included in next/prev cycling but excluded from numbered shortcuts.

## R5: Cheatsheet Dialog Data Source

**Decision**: The cheatsheet reads from a centralized registry function `KeyBindings.registry/1` that returns all shortcuts with metadata (action, category, display label, description, current binding). This single function serves both the cheatsheet UI and the help system.

**Rationale**: A single source of truth prevents the cheatsheet and help topics from diverging. Categories and labels are defined in the domain module, not scattered across components.

**Alternatives considered**:
- **Hardcoded list in the component**: Rejected — would diverge from KeyBindings module and miss custom bindings.
- **Separate config file**: Rejected — adds indirection without benefit. The Elixir module IS the config.

**Implementation detail**: `KeyBindings.registry/1` accepts a bindings map (defaults or user-customized) and returns:
```elixir
[
  %{action: :toggle_search, category: :system, label: "Search",
    description: "Open/close search bar", binding: %{key: "f", modifiers: [:ctrl, :shift]}},
  ...
]
```
Categories: `:navigation`, `:chat`, `:formatting`, `:system`.

## R6: Existing `phx-window-keydown` Integration

**Decision**: Replace the current `phx-window-keydown="window_keydown"` on `#app-container` with the new `ShortcutDispatcherHook` that provides the same functionality plus dynamic binding lookup.

**Rationale**: The existing `window_keydown` handler in `keyboard_events.ex` already does what we need — it matches key events to actions via `KeyBindings.find_action/2`. The JS hook adds the bubble-up check and `preventDefault` for consumed events, which the current `phx-window-keydown` cannot do (LiveView's built-in keydown always sends to server, even for unregistered keys).

**Alternatives considered**:
- **Keep `phx-window-keydown` and add hook**: Dual listeners create race conditions. Rejected.
- **Only use `phx-window-keydown`**: Cannot prevent default or check if event was already handled. Rejected — would still send all keypresses to server.

**Implementation detail**: The hook sends a `shortcut_action` event to the server with the matched action atom. The server handler dispatches to the appropriate function. Unmatched keys are not sent to the server at all (reducing unnecessary traffic).
