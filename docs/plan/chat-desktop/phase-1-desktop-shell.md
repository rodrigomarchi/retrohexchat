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

- [x] Add a `default_maximized` attr to `desktop_window/1` (`desktop.ex`) emitting
      `data-window-default-maximized`, honored by `registerWindow` in
      `window_manager_hook.js` when there is no persisted state for the window.
      Restoring from maximized must fall back to the `default_x/y/width/height`
      geometry, not to zeros.
- [x] Vitest coverage: fresh mount → maximized; persisted state wins over the
      default; restore-from-default-maximized yields sane geometry (+ late-arrival
      reconcile path honors the default).
- [x] Confirm lobby + showcase behavior unchanged (their tests stay green —
      full suite + all 40 pre-existing WM Vitest tests via `make ci.quick`).

### B. Desktop shell in the chat template

- [x] Restructure `chat_live.html.heex`: wrap the page in
      `<.desktop id="chat-desktop" persist_key="chat">` with the existing header
      (`chat_shell_header`: logo + menu bar + status bar) moved into the `:header`
      slot. Keep the modal dialogs block OUTSIDE the window, at desktop level
      (they overlay everything, unchanged).
- [x] Move sidebar + tab bar + topic bar + viewport islands + nicklist + composer
      into `<.desktop_window id="chat" pinned default_maximized ...>` with a
      sensible restored-size default (920×580, min 480×320). Preserved the flex
      chain via `body_class="flex flex-col min-h-0 p-0 overflow-hidden"`;
      `#app-container` (SoundHook + window keydown) kept as the outer wrapper.
- [x] Taskbar: `<.taskbar>` with the chat window button + `<.desktop_tray>` with
      the clock (ClockHook). Header status-bar clock was redundant — removed via a
      `show_clock` capability flag on `status_bar_app` (tray wins; showcase keeps
      its clock).
- [x] Start button + `<.start_menu>` skeleton with the four category groups
      (Tools / View / Admin / Help). Built as the design-system `StartMenuApp`
      component (`components/ui/shell/start_menu_app.ex`, mirroring `MenuBarApp`:
      semantic `toolbar_action` events, no Session). Admin group gated on the
      host's `admin?(@session)`.
- [x] Managed-window plumbing on ChatLive: `@managed_windows` (empty `MapSet` —
      runtime membership check avoids the dead-clause warning an empty guard list
      would raise), `open_windows` assign, `handle_event("window_open"/
      "window_closed")` above the dispatch catch-all, `handle_info({:open_window,
      id}/{:close_window, id})` above the catch-all. `window_open?/2` deferred to
      the first managed window (unused private fn would warn).

### C. Tests

- [x] LiveView tests: desktop + taskbar + start menu render; chat window is
      `pinned` (no close button) and `data-window-default-maximized`; persist key
      is `chat` with persistence enabled; start menu items dispatch the existing
      open events; `window_open` for an unknown/non-managed id is a no-op.
      (`chat_desktop_shell_test.exs` — 9 tests.)
- [x] Existing ChatLive test suite green (only `status_bar_feature_test.exs`
      needed updating: the clock moved from the status bar to the tray).

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
