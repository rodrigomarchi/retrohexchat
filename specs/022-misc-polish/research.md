# Research: Miscellaneous Polish (022)

**Date**: 2026-02-13
**Branch**: `022-misc-polish`

## Decision Log

### D1: Nick Column Alignment Strategy
- **Decision**: CSS grid layout on `.chat-message` elements for regular messages only
- **Rationale**: Currently messages use inline `<span>` elements with no width constraints. CSS Grid provides the cleanest column alignment without changing the stream/DOM structure. Grid template: `[timestamp] [nick-column: fixed 16ch + brackets + padding] [content: 1fr]`.
- **Alternatives considered**:
  - Flexbox with min-width on nick span — doesn't guarantee perfect alignment across messages
  - HTML table layout — semantic mismatch and breaks stream updates
  - `display: inline-block` with fixed width — fragile with font variations
- **Implementation**: Add CSS grid to `.chat-message--regular` class (3 columns). Action, notice, system, service, error messages keep full-width layout (no grid).

### D2: Character Counter Implementation
- **Decision**: Pure JavaScript in a new `CharCounterHook` — no server roundtrip
- **Rationale**: The counter must update on every keystroke with zero latency. The 1000-char limit matches `Chat.Policy.@max_content_length`. The hook updates a DOM element's text and class based on `input.value.length`.
- **Alternatives considered**:
  - LiveView `phx-change` on input — too much traffic for every keystroke
  - Inline script — against project's hook architecture pattern
- **Implementation**: Hook attached to input wrapper, listens to `input` events, updates counter span. Hard cap via `maxlength="1000"` attribute on the input element.

### D3: Multi-Line Paste Strategy
- **Decision**: JS hook intercepts `paste` event, LiveView handles confirmation dialog and message dispatch
- **Rationale**: Paste detection must happen client-side (clipboard API). The confirmation dialog should be a LiveView component (98.css style, consistent with existing dialogs). Message dispatch with 300ms pacing uses `Process.send_after` chain server-side.
- **Alternatives considered**:
  - Fully client-side dialog (JS prompt/confirm) — breaks 98.css aesthetic
  - TextArea instead of input — massive template change, breaks existing hooks
- **Implementation**: `PasteHook` captures paste, sends lines to LiveView via `push_event`. LiveView shows `PasteConfirmDialog` component. On confirm, dispatches lines with 300ms delay chain.

### D4: Right-Click Copy Strategy
- **Decision**: Custom 98.css context menu via JS hook on chat area, using `document.execCommand('copy')` / Clipboard API
- **Rationale**: The existing context menu pattern (nick right-click) is LiveView-driven, but clipboard operations require JS. A lightweight JS-only context menu on the chat area is cleaner since no server state is needed.
- **Alternatives considered**:
  - Browser native context menu — can't be styled with 98.css
  - LiveView-driven menu with push_event for copy — unnecessary roundtrip
- **Implementation**: `ChatCopyHook` on `.chat-messages` container. Right-click checks `window.getSelection()`, shows/hides 98.css styled menu, copies on click.

### D5: Double-Click Handler Strategy
- **Decision**: JS `dblclick` event listeners + LiveView events for server actions
- **Rationale**: Nicklist double-click needs server-side PM creation (LiveView event). URL double-click is pure JS (`window.open`). Channel name double-click needs server-side join (LiveView event).
- **Alternatives considered**:
  - All double-clicks via LiveView — URL opening can't be done server-side
  - All double-clicks via JS — PM/channel join need server state
- **Implementation**:
  - Nicklist: Change `phx-click` to include double-click detection (existing 300ms pattern in `context_menu_events.ex` already detects double-click → change action from whois to PM query)
  - URLs: Already have `<a>` tags with `target="_blank"` from URLDetector — double-click opens naturally via browser. Single click also opens. No change needed.
  - Channel names: Add `data-channel` attributes to channel name mentions in chat, handle `dblclick` in `ScrollHook` or new hook.

### D6: Quit Message Broadcast
- **Decision**: Broadcast quit message via PubSub to all joined channels during cleanup
- **Rationale**: `cleanup_channels/1` already iterates channels and calls `Server.part/3`. Add quit message broadcast before parting. The quit message type `:quit` is added to message types.
- **Alternatives considered**:
  - Modify `Server.part/3` to accept quit semantics — conflates two different operations
  - New `Server.quit/3` function — cleaner, broadcast quit to all members then part
- **Implementation**: Add `broadcast_quit/3` helper that broadcasts to each channel topic. Call before `cleanup_channels`. Store quit message in socket assign `quit_reason` set by `/quit` handler.

### D7: Away Auto-Reply Tracking
- **Decision**: `MapSet` in socket assigns (`away_replied_to`) tracking senders who received auto-reply
- **Rationale**: In-memory is sufficient — the tracking resets when away is cleared (same session). No persistence needed. The MapSet is checked in PM `handle_info` before sending auto-reply.
- **Alternatives considered**:
  - Session struct field — unnecessary persistence concern
  - ETS table — overkill for per-connection state
- **Implementation**: Add `away_replied_to: MapSet.new()` to socket assigns. On PM received while away: check MapSet, send auto-reply via PubSub if not already replied, add sender to MapSet. On clear_away: reset MapSet.

### D8: Timestamp Format for Main Chat
- **Decision**: Extend `UserPreferences` with `timestamp_format` field in `display_settings` JSONB column, reuse `DisplayPreferences` format atoms
- **Rationale**: The Log Viewer already defines `:hh_mm`, `:hh_mm_ss`, `:dd_mm_hh_mm` formats with formatting logic. Add `:none` for no timestamps. Extend the Options Dialog display panel with a format selector.
- **Alternatives considered**:
  - New migration/table — overkill, UserPreferences already has `display_settings` JSONB
  - Separate socket assign — redundant with preferences
- **Implementation**: Add `timestamp_format` key to `display_settings` map (default: `:hh_mm`). Modify `format_time/1` to accept format atom. Add format selector to Options Dialog display panel. Stream reset on format change.

### D9: Emoji Picker Architecture
- **Decision**: Static Elixir module with curated emoji dataset, LiveView component for picker, JS hook for insertion
- **Rationale**: Bundling ~300 common emojis as a static module avoids external dependencies. The picker is a 98.css popup component with category tabs and search. Unicode emojis already render correctly in modern browsers — no special rendering needed.
- **Alternatives considered**:
  - External emoji library/CDN — adds dependency, offline risk
  - Full Unicode emoji set (3000+) — too large, slow search
  - Client-side only picker — harder to test, breaks LiveView pattern
- **Implementation**: `Chat.EmojiData` module with categorized emoji list. `EmojiPickerComponent` with category tabs, search filter, grid display. `EmojiPickerHook` for cursor-position insertion. Toolbar button next to formatting toolbar.

### D10: About Dialog Enhancement
- **Decision**: Replace inline `<p>` tags with dedicated `AboutDialog` component featuring ASCII art logo
- **Rationale**: The existing about dialog uses the generic `Dialog` component with raw HTML. A dedicated component allows proper layout with logo, version, and credits sections styled like Windows 98 "About" boxes.
- **Alternatives considered**:
  - SVG/image logo — adds asset complexity
  - Keep generic Dialog with more HTML — less maintainable
- **Implementation**: New `AboutDialog` component with ASCII art rendered in `<pre>` tag, version info, credits, and OK button.

### D11: Help Menu Quick Access
- **Decision**: Add menu items that call `open_help_dialog` with a pre-selected topic
- **Rationale**: The help system already supports opening specific topics via `help_select_topic` event. Need a new event `open_help_at_topic` that opens the dialog AND selects the topic atomically.
- **Alternatives considered**:
  - Separate dialogs for commands/shortcuts — duplicates help system content
  - URL-based navigation — not applicable in LiveView
- **Implementation**: Add "IRC Commands" and "Keyboard Shortcuts" menu items to Help menu. New event handler `open_help_at_topic` that opens dialog + selects topic. Create a new commands overview topic that lists all commands.
