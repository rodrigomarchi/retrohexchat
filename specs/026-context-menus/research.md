# Research: Context Menus

**Date**: 2026-02-14 | **Feature**: 026-context-menus

## R1: Chat Message HTML Structure & Element Detection

**Decision**: Right-click detection for nicknames targets the author prefix element (`<span class="chat-nick">`), not mentioned nicknames within message text. URLs target `<a class="chat-link">`, channels target `<span class="chat-channel-link" data-channel="...">`. General message fallback targets the `.chat-message` wrapper div.

**Rationale**: In mIRC, right-clicking a nickname means clicking the `<Nick>` prefix in the message line, not arbitrary mentions in text. The author prefix is already a distinct HTML element. Detecting mentioned nicks in plain text would require either a) server-side nick linkification (expensive, requires knowing all channel members at render time) or b) client-side word-under-cursor detection (complex, fragile). Both are out of scope — that's Category Y2 (Interactive Elements).

**Alternatives considered**:
- Nick linkification in formatter pipeline (rejected: requires channel member list at format time, breaks formatter purity)
- Client-side word detection on right-click (rejected: complex, edge-case prone, better suited to Y2)

**Required HTML changes**:
- Add `data-nick` attribute to `.chat-nick` spans for author identification
- Add `data-author`, `data-message-id`, and `data-system-message` attributes to `.chat-message` divs for message context menu
- Add `data-url` attribute to `.chat-link` elements (currently only href/title)

## R2: Existing Context Menu Infrastructure

**Decision**: Extend the existing context menu pattern (fixed positioning, retro `.window` class, `phx-click` events) with a unified chat area context menu component that handles all 4 menu types (nick, URL, channel, message). The existing scroll_hook.js copy menu will be replaced by the new system.

**Rationale**: The nicklist context menu (`context_menu.ex`) and treebar context menu (`treebar_context_menu.ex`) already establish the pattern. A new `chat_context_menu.ex` component handles the 4 chat area menu types as variants. The scroll_hook.js simple copy menu is superseded.

**Alternatives considered**:
- 4 separate components per menu type (rejected: too much duplication, shared positioning/keyboard nav/styling logic)
- One mega-component for all 6 menu types including nicklist and treebar (rejected: nicklist and treebar menus have different trigger mechanisms and data flows; better to keep them separate)

## R3: Viewport Repositioning Strategy

**Decision**: Implement viewport boundary detection in a JS hook attached to the context menu container. After the menu is rendered (mounted/updated), measure its dimensions and flip position if it would overflow the viewport.

**Rationale**: LiveView renders with fixed `left/top` from mouse coordinates. The JS hook runs post-render to adjust position. This is the same approach used by native retro context menus and avoids a two-render-cycle flash.

**Algorithm**:
```
menuRect = menu.getBoundingClientRect()
if (menuRect.right > viewport.width) → move left by menu width
if (menuRect.bottom > viewport.height) → move up by menu height
```

## R4: Keyboard Navigation in Context Menus

**Decision**: Implement keyboard navigation via a JS hook on the context menu container. The hook captures keydown events (ArrowUp, ArrowDown, Enter, Escape) and manages a `focused_index` state. Focus styling uses the existing `.context-menu li:hover` background (navy/white) applied via a `.focused` class.

**Rationale**: Keyboard navigation is a DOM concern (focus management, key capture) best handled in JS. The hook pushes the selected action's phx-click event when Enter is pressed.

## R5: Clipboard API Usage

**Decision**: Use `navigator.clipboard.writeText()` via `push_event` from LiveView to JS hook. The hook receives the text to copy and executes the clipboard write.

**Rationale**: The Clipboard API requires a user gesture context. The existing pattern in scroll_hook.js uses this API successfully. A dedicated `clipboard_copy` push_event keeps the pattern reusable across all copy actions.

## R6: Mute Channel Persistence

**Decision**: Store muted channels as a list in `user_preferences.message_settings.muted_channels` (array of channel name strings). Persisted via existing `UserPreferences.save/2`.

**Rationale**: The `message_settings` map in `UserPreference` schema is the natural home for notification preferences. Using the existing JSON column avoids a new migration. Guest users store mute state in their in-memory session (lost on disconnect, acceptable for guests).

**Alternatives considered**:
- New `display_settings.muted_channels` (rejected: muting is about message notification, not display)
- Separate database table (rejected: overkill for a simple list of channel names)
- localStorage only (rejected: wouldn't sync across devices for registered users)

## R7: Keyboard Shortcut Display in Menu Items

**Decision**: Use `KeyBindings.to_display_string/1` to format shortcut hints. Look up bindings from `session.user_preferences.key_bindings` at render time. Not all menu items have shortcuts — only those with registered keybinding actions.

**Rationale**: The keybinding system (feature 025) already has display string formatting. Menu items that correspond to keybinding actions (e.g., `:toggle_url_catcher`) show their shortcut. Items without keybindings show no shortcut text.

## R8: "Save to URL List" Integration

**Decision**: Reuse the existing URL catcher system. "Save to URL List" calls `CapturedURL.new/1` and prepends to `socket.assigns.url_catcher_entries`, identical to the automatic capture flow.

**Rationale**: The URL catcher (`captured_url.ex`, `url_catcher_events.ex`, `url_catcher_window.ex`) already provides URL collection, display, and management. Manual "Save" is just the manual equivalent of automatic capture.
