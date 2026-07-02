# Phase 2 — Pilot Migrations + Recipe

## Objective

Migrate THREE representative dialogs to desktop windows, covering the three
architectural variants that exist in the chat, and crystallize a repeatable
per-dialog recipe in `PROGRESS.md`. Phases 3–5 are mechanical applications of
that recipe — do not start them until the recipe is written.

## Pilots (chosen to cover the variants)

1. **UrlCatcher** — open-state as ChatLive assign (`show_url_catcher`), data
   accumulated by the host while the dialog is closed. Exercises the
   managed-vs-always-mounted decision (URLs must keep accumulating while the
   window is closed).
2. **Timers** — open-state internal to the component via `send_update :action`.
   Exercises the send_update-driven lifecycle + `window_command` from `update/2`.
3. **Highlight** — has nested add/edit sub-forms. Exercises "sub-form modal scoped
   to the parent window" (locked decision #3).

## Tasks

### A. Generic WM extension: Escape closes the focused window

- [x] Design + implement Escape handling for dialog-windows. Shipped as opt-in:
      `escape_closes_windows` attr on `desktop/1` (chat=on, lobby untouched).
      Priority ladder in the hook: open WM menu (closed, press consumed) →
      open modal (`[phx-show-modal][data-state="open"]`) or visible
      `[data-escape-guard]` overlay (menu-bar dropdown, context menu, emoji
      picker — marker added to those components) → topmost unpinned window,
      mirroring the X-button semantics (a `phx-click` close is clicked, not
      client-closed) and consuming the press via stopPropagation so the server
      `dismiss_topmost` ladder never double-handles.
- [x] Vitest coverage (8 cases): menu wins, modal wins, guard-overlay
      visible/hidden, pinned skipped + press passes through, topmost-by-z,
      server-owned close mirrored, opt-out desktops inert.

### B. Sub-form scoping primitive

- [x] Added `scope` attr to `dialog/1` (`:viewport` default | `:window`). Window
      scope swaps `fixed`→`absolute` on overlay + centering container (anchoring
      to the nearest positioned ancestor — the `.desktop-window` root, since the
      dialog root drops `relative` in that scope) and the frame uses
      `min-h-0 max-h-full` instead of the mobile `100dvh` claim. Pure CSS — no
      hook assistance needed, so unit tests only (`dialog_test.exs`).
      Body `overflow-auto` does not clip it: the containing block (window root)
      sits outside the scrollable body.

### C. Migrate the three pilots

For each pilot (this becomes the recipe draft):

- [ ] Decide mounting: `managed` (server-mounted on demand — add to
      `@managed_windows`, render `:if` open) vs always-mounted (`open={false}`)
      per the state-survival rule in PROGRESS.md. Record the decision + reason.
- [ ] Replace the `UI.Dialog` frame with `<.desktop_window>` inside the chat
      desktop: stable window id, title, 16×16 title-bar icon (`icon_dialog_*` —
      add to the right `Icons` submodule by subject if missing), default
      geometry, `resizable`, `on_close` adapter event.
- [ ] Rewire openers: menu-bar `toolbar_action` handler + start-menu item + any
      keyboard shortcut now open/focus the window (`open_window` + `send_update`,
      or `data-window-open` for pure client opens). Toggle semantics: re-invoking
      focuses, not duplicates.
- [ ] Remove the dialog's entry from the Escape `dismiss_topmost` stack in
      `keyboard_events.ex` (the WM owns it now).
- [ ] Sub-forms (Highlight): keep modal, scoped to the parent window via the
      Task B primitive.
- [ ] Tests: rewrite the dialog's tests to the window contract
      (`render_hook("window_open")`, `assert_push_event(view, "window_command",
      ...)`, `data-window-id` presence/visibility, `:sys.get_state` for
      synchronous open-state). Keep `data-testid`s stable wherever possible so
      E2E churn stays low; update affected Playwright specs (targeted runs only).
- [ ] Help topic for the window updated (it moved from modal to window — mention
      taskbar/minimize behavior where the topic describes usage).

### D. Crystallize the recipe

- [ ] Write the final step-by-step per-dialog recipe into `PROGRESS.md`
      ("Per-dialog migration recipe" section), including the
      managed-vs-always-mounted decision rule, the test-rewrite pattern, and
      every gotcha hit during the pilots.

## Completion criteria

- [ ] UrlCatcher, Timers, Highlight open as draggable/resizable windows with
      taskbar buttons; URLs accumulate while the UrlCatcher window is closed;
      Highlight add/edit sub-forms center over the Highlight window.
- [ ] Escape behavior correct across: window focused, modal open, start menu open.
- [ ] Recipe written in PROGRESS.md and sufficient for a fresh session to migrate
      a dialog without re-deriving decisions.
- [ ] No regression in the 25 unmigrated dialogs.

## Verification

- `make ci` fully green.
- Manual smoke: open all three via menu bar AND start menu; minimize/restore via
  taskbar; persist across reload; Escape ladder (sub-form → window → nothing on
  pinned chat); taskbar right-click menu on a pilot window (cascade/tile still sane).
