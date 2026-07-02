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

- [x] Chat page loads as a desktop; chat window maximized by default; restore/drag/
      resize/minimize work; minimize → taskbar button restores it. (Verified live
      in Chrome on the dev server.)
- [x] All ~28 dialogs still open/close exactly as before (modals over the desktop).
      (Full suite green + Address Book/Alias Editor verified live.)
- [x] Window layout persists across reload (localStorage `rhc:desktop:chat` —
      verified live: restored geometry survived a reload and beat the
      default-maximized flag).
- [x] Lobby and showcase desktops unaffected (their suites green; WM Vitest 45/45).
- [x] Help: "Desktop & Windows" topic added (`ui-desktop`) with content template
      and See Also cross-refs from ui-overview and ui-toolbar; ui-overview's
      stale status-bar-clock mention fixed.

## Verification

- `make ci` fully green (all 9 checks — this is the gate). ✔ 2026-07-02
- Manual smoke (dev server): ✔ 2026-07-02 via browser automation — restore, drag,
  resize (SE grip), re-maximize (control button), minimize → taskbar restore,
  reload persistence, Address Book via menu bar + Alias Editor via start menu,
  admin group correctly absent for a guest, zero console errors.
  ⚠ Not verified: <720px stacked mode (Chrome window was fullscreen and refused
  programmatic resize). Stacked mode is untouched generic WM code the lobby
  already ships, but give it one quick look in devtools responsive mode.
