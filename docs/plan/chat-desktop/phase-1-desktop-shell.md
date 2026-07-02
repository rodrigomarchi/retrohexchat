# Phase 1 — Desktop Shell in ChatLive

## Objective

ChatLive renders a `<.desktop>`: the entire current chat layout lives inside one
pinned, maximized-by-default `desktop_window id="chat"`; taskbar + start menu +
tray clock exist; NO dialog is migrated yet (all keep working as modals over the
desktop). Visual result when the chat window is maximized must be indistinguishable
from today.

## Prerequisites

- None (first phase). Read `docs/AGENT-GUIDE.md` §7 and `universal_lobby.ex` first.

## Tasks

### A. Generic WM extension: maximized-by-default

- [ ] Add a `default_maximized` attr to `desktop_window/1` (`desktop.ex`) emitting
      `data-window-default-maximized`, honored by `registerWindow` in
      `window_manager_hook.js` when there is no persisted state for the window.
      Restoring from maximized must fall back to the `default_x/y/width/height`
      geometry, not to zeros.
- [ ] Vitest coverage: fresh mount → maximized; persisted state wins over the
      default; restore-from-default-maximized yields sane geometry.
- [ ] Confirm lobby + showcase behavior unchanged (their tests stay green).

### B. Desktop shell in the chat template

- [ ] Restructure `chat_live.html.heex`: wrap the page in
      `<.desktop id="chat-desktop" persist_key="chat">` with the existing header
      (`chat_shell_header`: logo + menu bar + status bar) moved into the `:header`
      slot. Keep the modal dialogs block OUTSIDE the window, at desktop level
      (they overlay everything, unchanged).
- [ ] Move sidebar + tab bar + topic bar + viewport islands + nicklist + composer
      into `<.desktop_window id="chat" pinned default_maximized ...>` with a
      sensible restored-size default. Preserve the `h-full`/flex chain inside
      `window_body` — the chat layout must fill the window at any size.
      Watch for: `#app-container` currently is `fixed inset-0` with
      `phx-hook="SoundHook"` and window-level keydown bindings — those semantics
      must survive the move (hook stays mounted, `phx-window-keydown` is
      window-scoped and unaffected by nesting).
- [ ] Taskbar: `<.taskbar>` with the chat window button + `<.desktop_tray>` with
      the clock (ClockHook, as in the showcase). Keep the existing header clock
      only if it isn't redundant — if the header status bar already shows a clock,
      remove the duplication (tray wins).
- [ ] Start button + `<.start_menu>` skeleton with the four category groups
      (Tools / View / Admin / Help). Until dialogs migrate, items trigger the
      SAME existing `toolbar_action` events via `phx-click` (no `data-window-open`
      yet). Admin group renders only for admins (same permission gate the menu
      bar uses).
- [ ] Managed-window plumbing on ChatLive (copied from `lobby_live.ex`):
      `@managed_windows` (empty for now), `open_windows` assign,
      `handle_event("window_open"/"window_closed")`, `handle_info({:open_window,
      id}/{:close_window, id})`, `open_window/close_window/window_open?` helpers.
      Place `handle_info` clauses above any catch-all.

### C. Tests

- [ ] LiveView tests: desktop + taskbar + start menu render; chat window is
      `pinned` (no close button) and `data-window-default-maximized`; persist key
      is `chat` with persistence enabled; start menu items dispatch the existing
      open events; `window_open` for an unknown/non-managed id is a no-op.
- [ ] Existing ChatLive test suite green (layout restructure must not break
      selectors — fix tests that asserted on the old top-level structure).

## Completion criteria

- [ ] Chat page loads as a desktop; chat window maximized by default; restore/drag/
      resize/minimize work; minimize → taskbar button restores it.
- [ ] All ~28 dialogs still open/close exactly as before (modals over the desktop).
- [ ] Window layout persists across reload (localStorage `rhc:desktop:chat`).
- [ ] Lobby and showcase desktops unaffected.
- [ ] Help: no new user-facing feature is fully shipped yet, but if the taskbar/
      start menu are visible to users at the end of this phase, add the
      "Desktop & Windows" HelpTopics entry now rather than deferring to Phase 6.

## Verification

- `make ci` fully green (all 9 checks — this is the gate).
- Manual smoke (dev server): load `/chat`, restore + move + resize + re-maximize
  the chat window, reload and confirm persistence, open 3 different dialogs from
  menu bar and start menu, check <720px stacked mode doesn't break the chat.
