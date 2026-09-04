# Mobile & touch

Read when changing viewport behaviour, touch handling, or a dialog on mobile.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§18). Section numbers there are stable — `§18` still means this file.

---

Mobile is not shrunk desktop, and desktop is not a separate interface — it's the same mobile-first
interface using more room. When layout changes with width, the concepts, components and hierarchy
must stay the same. Never build two visual systems inside one surface.

### 18.1 The viewport contract

- **One breakpoint, 768px**, agreed between `WindowManagerHook` and the LiveView. Below it the
  window manager drops MDI and shows one fullscreen window at a time; the LiveView sets/clears
  `mobile_viewport` and restores sidebars on the way back to desktop.
- **`ViewportDetectHook` owns visual-viewport truth.** It observes `visualViewport` `resize`/`scroll`
  plus `focusin`/`focusout`, and publishes height, width, `offsetTop`, `offsetLeft` and
  `keyboardInset` as `:root` CSS variables. `chat-app-root` follows those variables, which is what
  keeps the composer off the keyboard and the layout from drifting sideways.
- **`rhc-keyboard-open` requires both signals**: a mobile viewport *and* an editable element focused
  *and* a bottom inset over 80px. Inset alone is a browser chrome resize, not a keyboard. With the
  class on, the stacked taskbar and Start menu hide to give the chat its height back.
- **Mobile overlays start below the header, they do not out-z-index it.** A `fixed inset-0` backdrop
  swallowing a header button is not fixed by raising the header — that just moves the interception
  onto the sidebar's own close button and menu items. Keep the natural layers and offset the overlay.
- **Long-press opens the same context menu as right-click** — one menu definition, two gestures,
  for messages, nicklist and conversations.
- `overflow-hidden` on the root can still accumulate programmatic `scrollLeft` in stacked mode:
  when a window looks offset, inspect ancestor `scrollLeft` and rects, not just the window's own CSS.

### 18.2 Dialog patterns (established across every dialog in `components/ui/dialogs/`)

- **Tabs:** a horizontal `overflow-x` strip with a fade + chevron affordance on whichever side has
  more content — never wrap to multiple rows. Don't change `Tabs`' global roles without running the
  full dialog suite; helpers still rely on `getByRole("button")`.
- **Lists and tabular data:** one mobile-first representation that also reads well on desktop. Use a
  table only when the data is genuinely matrix-like and comparative; for list editors, actionable
  rows beat a table on both. Primary field on the first line, short-labelled metadata below
  (`Set By`, `Set At`). Preserve existing per-row test ids, and when a row becomes a `button`, set
  `aria-label` so its accessible name is the entry — not its whole inner text.
- **Reference content** (help, shortcuts, cheatsheet): the item is the visual unit, not a row in a
  table. Strong categories, scannable entries, key badges with `max-width: 100%` and safe wrapping.
- **Forms:** inputs need `min-width: 0`; long operational text goes in a textarea even when the
  stored value stays a plain string; user/server/timestamp values need `overflow-wrap: anywhere`;
  numeric inputs in flex/grid need a stable `flex-basis` + `min-width` or they collapse to just the
  spinner. Treat a label/input/unit setting as a responsive block, not a rigid column table.
- **Small confirms are not fullscreen.** A one- or two-sentence decision is a compact message box:
  icon, question, consequence on its own line, actions right-aligned. Use an opt-in local class to
  compact it rather than changing the global `Dialog`. The titlebar X must map to Cancel's semantics
  — and when the dialog fronts a server-owned queue, to a real domain action, not a client-side hide.
- **Subdialogs** inside a desktop window use `scope={:window}`; the inner form is a flex column
  (`min-h-0`, `flex-1`) so titlebar and footer survive and only the body scrolls.
- **Shared adjustments only land in global components once the other dialogs' tests are ready for
  them.** And a functional test never substitutes for a screenshot — validate behavior *and* pixels.
