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

- [ ] Design + implement Escape handling for dialog-windows: when no start/taskbar
      menu is open AND no modal `UI.Dialog` is open (guard: presence of an open
      dialog overlay in the DOM), Escape closes the topmost visible unpinned
      window. Pinned windows (chat) are never closed by Escape.
      Transition safety: while unmigrated modals exist, an open modal must win —
      the hook must not double-handle. Verify against `keyboard_events.ex`
      `dismiss_topmost` order.
- [ ] Vitest coverage for the new Escape behavior (menu open wins, modal open
      wins, pinned skipped, topmost-by-z chosen).

### B. Sub-form scoping primitive

- [ ] Add a generic way to center a `UI.Dialog` over its parent window instead of
      the viewport (e.g. a `container`/`scope` attr on `dialog/1` that positions
      `absolute inset-0` within the window body). Component-first: extend
      `dialog.ex` generically, no per-dialog forks. Unit test + one Vitest/CSS
      check if positioning is hook-assisted.

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
