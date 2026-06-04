# Feature Spec: Window & Display (Edit menu)

**Coverage today:** ❌ command-only · **Priority:** P1 · **Commands:** /clear

---

## 1. Overview

The current menu bar (`File | View | Tools | Help`) has no **Edit** menu. This is a meaningful usability gap: three text-editing primitives — clear the window, copy selected text, and find within the log — have no shared home in the UI, and the first two are entirely unreachable without typing a command.

Conventional desktop applications (mIRC included) place these operations under **Edit**. Establishing an Edit menu:

- Makes `/clear` discoverable to users who have never typed a slash command.
- Gives **Copy** a keyboard-accessible menu path (currently only reachable via the browser's default right-click context menu).
- Relocates **Find** out of View (where it is a structural oddity) into the semantically correct location.
- Completes the canonical `File | Edit | View | Tools | Help` ordering that users expect from any windowed application.

---

## 2. Commands (grounded in handler source)

### /clear

**Source:** `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/clear.ex`

- **Syntax:** `/clear` (no arguments; `validate/1` always returns `:ok`)
- **Return value:** `{:ok, :ui_action, :clear_chat, %{}}`
- **Behaviour:** Emits a UI action — the handler itself does no direct stream manipulation. The LiveView layer interprets `:clear_chat` to wipe all messages from the current chat window.
- **Reversibility:** Cannot be undone (stated explicitly in the handler's `description` string).
- **Category:** `:basics`

### Find / toggle_search

**Source:** `menu_bar_app.ex`, line 93 — `action="toggle_search"` under the View menu.

Find is **UI-only**: there is no `/find` or `/search` slash command. The action `toggle_search` shows/hides the in-window search bar. It currently lives under View as the fourth item.

### Copy

**Source:** No dedicated action string exists in `menu_bar_app.ex`. Copy is handled entirely by the browser's native selection + clipboard mechanism, optionally surfaced via the right-click context menu on the message log. There is no `copy` toolbar action today.

---

## 3. Current UI state

| Item | Location today | Reachable from menu bar? |
|---|---|---|
| Clear Window (`/clear`) | Command input only | No |
| Copy | Browser right-click / OS shortcut only | No |
| Find (`toggle_search`) | View menu, 4th item | Yes, but wrong category |

The menu bar defined in `menu_bar_app.ex` has exactly four top-level menus: **File**, **View**, **Tools**, **Help**. There is no Edit menu anywhere in the file. The `@moduledoc` string on line 6 explicitly names only those four menus.

---

## 4. UI specification — what to build

### 4.1 Entry points

Add a new top-level **Edit** menu inserted between **File** and **View**, yielding the final order:

```
File | Edit | View | Tools | Help
```

The Edit dropdown contains three items:

| Label | Action string | Source |
|---|---|---|
| Clear Window | `clear_window` | Fires `/clear` → `:clear_chat` ui_action |
| Copy | `copy_selection` | Copies current browser text selection to clipboard |
| Find | `toggle_search` | Same action as current View › Find |

**Find relocation:** Remove Find from the View menu and place it in Edit. To avoid breaking muscle memory, add a **disabled pointer item** in the View menu at the old Find position: `"Find → moved to Edit"` (or simply omit it — decision deferred to 7. Open Questions). The `toggle_search` action string is unchanged.

### 4.2 Layout

Edit dropdown, top to bottom:

```
┌──────────────────────────────┐
│ [✕] Clear Window             │
│ ─────────────────────────── │
│ [⎘] Copy                     │
│ ─────────────────────────── │
│ [🔍] Find            Ctrl+F  │
└──────────────────────────────┘
```

- Separator after Clear Window (destructive action separated from non-destructive).
- Separator before Find (Find is a navigation tool, not a clipboard operation).
- Icons follow the existing `icon_btn_*` pattern (`icon_btn_find` already exists for Find).
- Keyboard hint `Ctrl+F` shown on Find (matches existing shortcut cheatsheet).

### 4.3 Interactions & states

**Clear Window**

- **No confirmation dialog.** The existing `/clear` handler description explicitly states "Cannot be undone" — this is intentional and consistent with mIRC behaviour. Adding a confirmation dialog would slow a power-user action that has been intentionally destructive since day one. The menu label "Clear Window" (not "Clear All Messages…") already communicates permanence without softening it.
- Fires `clear_window` action → LiveView dispatches the existing `:clear_chat` ui_action path.

**Copy**

- Enabled only when the user has a non-empty text selection within the chat log.
- When no selection: item is visually disabled (greyed, non-interactive), consistent with the `disabled` state pattern used by `menu_trigger` in the existing component.
- When a selection exists: copies the selection to the clipboard via the Clipboard API (`navigator.clipboard.writeText`). Falls back to `document.execCommand('copy')` for browsers without Clipboard API support.
- The selection check must happen at dropdown-open time (not render time) because LiveView re-renders do not track browser selection state.

**Find**

- Toggles the search bar on/off (identical behaviour to current View › Find).
- Enabled when connected; disabled when disconnected (consistent with all other Edit items).
- No state indicator in the menu (the search bar's own visibility is the state indicator).

### 4.4 Control → command/action mapping

| User action | Menu action string | Handler / target |
|---|---|---|
| Edit › Clear Window | `clear_window` | LiveView `handle_event("toolbar_action", %{"action" => "clear_window"})` → dispatch `/clear` command |
| Edit › Copy | `copy_selection` | Client-side JS only; no server round-trip |
| Edit › Find | `toggle_search` | Existing LiveView handler for `toggle_search` (unchanged) |

Note: `clear_window` is a new action string. It must be added to the `toolbar_action` event handler in ChatLive (or its delegate). The string `clear_chat` remains an internal `:ui_action` atom — `clear_window` is the menu-bar-facing event name, keeping the naming layer clean.

---

## 5. Permissions & visibility

**Connected = false:** The Edit menu trigger is disabled (greyed, non-interactive), consistent with File, View, and Tools. This matches the existing `disabled={!@connected}` pattern on all non-Help menus.

**Connected = true:** All three items render. Copy is additionally gated by selection state (client-side, not connection-state).

**Admin vs. non-admin:** No difference. Clear, Copy, and Find are available to all connected users regardless of role.

**Guest users:** Same as authenticated users — both can clear their own window, copy, and search.

---

## 6. Help documentation (mandatory)

### Keyboard Shortcuts topic

Add entry:

- `Ctrl+F` — Open/close Find bar (was already present; confirm it is listed; move context note from "View menu" to "Edit menu").

No new keyboard shortcuts are introduced by Clear Window or Copy (both are menu-only additions; OS-native `Ctrl+C` covers copy without app registration).

### User Interface topic

Add a subsection for the Edit menu describing:

- **Clear Window** — clears all messages in the active chat tab; cannot be undone.
- **Copy** — copies the current text selection from the chat log to the clipboard; enabled only when text is selected.
- **Find** — opens the in-window search bar to search message history (also: `Ctrl+F`).

Update any existing "Find" references that say "found under the View menu" to say "Edit menu".

### Cross-references

- The `/clear` command help entry (from `clear.ex`) should gain a "See Also" note: "Clear Window in the Edit menu provides the same action without typing."
- The Find / search feature topic should update its menu path from View › Find to Edit › Find.

---

## 7. Out of scope / open questions

**Out of scope for this feature:**

- Undo/Redo — not applicable; the message log is append-only and `/clear` is intentionally irreversible.
- Select All — no use case in a read-only chat log; native OS `Ctrl+A` works if needed.
- Paste — input box already handles paste natively; no menu item needed.
- Edit menu in contexts other than ChatLive (ConnectLive, P2PSessionLive, etc.) — only the authenticated chat shell has a message log to clear or search.

**Open questions:**

1. **Find pointer in View menu after relocation:** Should a greyed-out "Find (moved to Edit)" stub remain in View to guide users who look there by habit, or is a clean removal preferred? Recommendation: clean removal (the cheatsheet and help docs cover discoverability).

2. **`clear_window` vs reusing `clear_chat` as the action string:** `clear_chat` is currently an internal `:ui_action` atom returned by the handler. Using a distinct `clear_window` string for the toolbar event maintains a clean separation between UI events and domain actions. Confirm this naming is consistent with existing toolbar action patterns before implementing.

3. **Copy selection detection:** Detecting a non-empty browser selection reliably across Firefox/Chrome/Safari at dropdown-open time requires a `selectionchange` listener or a check in the MenuBar JS hook. The implementation approach (hook-based vs. phx-click JS command) should be decided during implementation to avoid a needlessly complex LiveView round-trip.
