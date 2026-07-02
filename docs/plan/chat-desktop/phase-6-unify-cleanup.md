# Phase 6 — Unification, Help, Cleanup

## Objective

One open-state model, one Escape model, complete help docs, dead code removed,
learnings crystallized. After this phase the plan directory is deleted.

## Tasks

### A. State unification

- [ ] Remove every `show_*`/`*_visible` assign in ChatLive that belonged to a
      migrated window (sweep `assign_defaults/1`); open-state is now WM
      (localStorage) + `open_windows` for managed ones. The surviving `show_*`
      assigns are exactly the modal list (locked decision #2).
- [ ] `dismiss_topmost` in `keyboard_events.ex` shrinks to the modal survivors
      only; delete dead branches. Confirm ordering still matches real stacking.
- [ ] Sweep for orphaned events: `open_*`/`close_*`/`toggle_*` handlers that no
      longer have a caller, event-hook modules that became empty pass-throughs.

### B. Keyboard shortcuts

- [ ] All shortcuts that targeted migrated dialogs now toggle/focus windows;
      window-navigation shortcuts (`window_next/prev/1-9` — mIRC channel-tab
      semantics) still work and are NOT confused with desktop windows in code or
      docs (naming sweep: the chat's "window" terminology for channel tabs vs
      desktop windows must be unambiguous in module docs and help).

### C. Help documentation (mandatory, gates the phase)

- [ ] "Desktop & Windows" topic in `HelpTopics` (User Interface category): windows,
      taskbar, start menu, tray clock, minimize/maximize, persistence, taskbar
      context menus (cascade/tile), Escape behavior.
- [ ] Update "Keyboard Shortcuts" topic + Cheatsheet content for the new model.
- [ ] Sweep every existing topic that describes a migrated dialog ("dialog opens
      in the center…" style phrasing) and cross-references ("See Also").

### D. Cleanup & crystallization

- [ ] `UI.Dialog` stays (modals still use it) — but remove any dialog-layer code
      that only served migrated dialogs (unused UI wrappers, dead `show_modal`
      paths, unused testids).
- [ ] CSS audit: `mix audit.styles --strict` at 0 findings; no leftover
      modal-positioning CSS for migrated dialogs.
- [ ] Crystallize durable learnings from `PROGRESS.md` into `docs/AGENT-GUIDE.md`
      (§7 windowed desktop — extend with the chat-specific rules: pinned app
      window, default_maximized, Escape ladder, modal-scoped-to-window,
      persistence-on trade-offs).
- [ ] Update `docs/README.md` if any reference doc changed; delete
      `docs/plan/chat-desktop/` as the final commit of the migration.

### E. Full-system verification

- [ ] E2E pass over the desktop UX (existing Playwright specs updated in earlier
      phases must be green in the CI run; add a desktop smoke spec if none covers
      start-menu → window → taskbar → minimize → restore end-to-end).
- [ ] Lobby and showcase desktops still behave (their suites green — shared WM
      changed during this migration).

## Completion criteria

- [ ] `make ci` fully green.
- [ ] `make deploy` (full pipeline) executed and production verified — the
      migration ships.
- [ ] AGENT-GUIDE updated; plan directory deleted.

## Verification

- `make ci`, then `make deploy`.
- Manual production smoke: login, restore/move chat window, open Address Book +
  URL Catcher + Channel List simultaneously, reload persistence, admin console as
  admin, mobile width sanity (stacked mode).
