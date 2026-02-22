# Research: Address Book (003)

**Date**: 2026-02-11
**Branch**: `003-address-book`

## R1: Where to place Contacts and NickColors in bounded contexts

**Decision**: Place both under `RetroHexChat.Accounts` — the existing context for user-scoped data (sessions, authentication, registration).

**Rationale**: Contacts and nick color overrides are per-user personal preferences, closely tied to the user's session. The Session struct is already in Accounts. NotifyList is in Presence because it's about online/offline tracking — contacts and color preferences are about personal data storage, not presence.

**Alternatives considered**:
- New `RetroHexChat.AddressBook` context — would create an 8th bounded context. Constitution II says 7 contexts "MUST exist" but doesn't prohibit more. However, the data is thin enough (two simple CRUD modules) that a dedicated context adds unnecessary structural overhead.
- `RetroHexChat.Presence` (alongside NotifyList) — contacts aren't presence-related; nick colors aren't either. Would muddy the Presence context boundary.

## R2: In-memory vs DB-only storage pattern

**Decision**: Follow the NotifyList pattern — in-memory structs in Session for runtime, async DB persistence for registered users.

**Rationale**: This is the established pattern in the codebase. Contacts and nick colors are accessed frequently (every message render for nick colors, every Address Book open for contacts). In-memory reads are sub-millisecond. Registered users get persistence via async `Task.start` DB writes.

**Alternatives considered**:
- DB-only with caching — more complex, introduces cache invalidation. Overkill for per-user data that fits comfortably in memory.
- ETS table — adds shared mutable state complexity. Session-embedded data is simpler and already proven.

## R3: Nick color storage format

**Decision**: Store as IRC color index (integer 0-15), mapping to the same 16-color palette used by the formatting toolbar.

**Rationale**: The 16 IRC colors are already defined in `FormattingToolbar.@color_palette` as `{name, hex}` tuples indexed 0-15. Storing the index is compact (single integer), unambiguous, and directly maps to the existing palette. The hex value can be derived at render time.

**Alternatives considered**:
- Store hex string — redundant with palette, fragile if palette hex values change.
- Store color name — requires name-to-hex lookup, names aren't unique identifiers in IRC color standard.

## R4: Nick color override propagation to all components

**Decision**: Pass a `nick_color_fn` (1-arity function) through assigns to all components that render nicknames. The function encapsulates "check override map, fall back to hash-based color."

**Rationale**: Components that render nicknames (ChatMessage, Nicklist, ContextMenu, NotifyListWindow, AddressBookDialog) need access to override resolution. A function assign avoids coupling components to Session internals. ChatLive builds the function once per render from `session.nick_colors` and passes it down.

**Alternatives considered**:
- Pass raw `nick_colors` map to every component — leaks domain structure into components, each component would need the resolution logic.
- Shared helper module imported by each component — works but the function approach is more LiveView-idiomatic (assigns drive rendering).

## R5: retro tab control implementation

**Decision**: Use native retro tab controls with `menu[role=tablist]` + `div[role=tabpanel]` semantic HTML.

**Rationale**: retro design system v0.1.21 natively supports tabbed interfaces via `<menu role="tablist">` with `<li aria-selected="true|false">` items. No custom CSS needed. Tab switching is managed by a LiveView assign (`address_book_tab`) and `phx-click` events.

**Alternatives considered**:
- Custom tab implementation — unnecessary; retro tabs are well-styled and semantically correct.
- JS-based tabs — violates constitution principle I (zero JS UI frameworks). LiveView event-driven tabs are the correct approach.

## R6: Alt+B keyboard shortcut implementation

**Decision**: Handle via existing `phx-window-keydown="window_keydown"` event on the app container. Add Alt+B detection to the `window_keydown` handler in ChatLive.

**Rationale**: The template already has `phx-window-keydown="window_keydown"` on the root div. This captures all key events at the window level, which is exactly where Alt+B needs to be caught (regardless of which element has focus). No new JS hook is needed.

**Alternatives considered**:
- New JS hook for Alt+B — adds unnecessary JS. The existing window keydown event is sufficient.
- KeyboardHook extension — that hook is scoped to the chat input element, not suitable for global shortcuts.

## R7: Context menu color picker for "Set Nick Color"

**Decision**: Trigger a small inline color picker dropdown anchored to the context menu position. Reuse the 16-color palette from FormattingToolbar. After selection, the context menu and picker close together.

**Rationale**: Opening the full Address Book dialog from a right-click action would be disruptive. A compact 4x4 color grid (same as formatting toolbar) provides quick selection. The pattern is already established in FormatToolbarHook.

**Alternatives considered**:
- Open Address Book → Nick Colors tab pre-filled — too many steps for a quick action.
- Sub-menu in context menu — retro design system doesn't natively support nested menus; a dropdown is simpler.

## R8: Address Book dialog as component vs inline template

**Decision**: Create a dedicated `AddressBookDialog` function component with embedded tab content. Sub-dialogs (add/edit contact, add/edit nick color) are rendered inline within the component using `:if` guards.

**Rationale**: Follows the NotifyListWindow pattern — a single component file managing its own visibility, sub-dialogs, and layout. Keeps ChatLive thin (principle VII). The component receives all needed data via assigns.

**Alternatives considered**:
- Separate component per tab — over-modularized for tabs that share styling and button patterns.
- Inline in ChatLive template — violates principle VII (lean LiveViews).
