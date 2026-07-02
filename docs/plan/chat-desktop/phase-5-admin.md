# Phase 5 — Admin Batch

## Objective

Apply the recipe to the two permission-gated admin mini-apps and finish the start
menu's Admin group.

## Prerequisite

Phase 4 complete.

## Windows to migrate

- [ ] AdminConsole (8 tabs: users, channels, MOTD, broadcast, settings, TURN,
      audit, danger zone). Danger-zone confirmations stay modal (locked decision
      #2), scoped to the console window.
- [ ] BotManagement (+ BotForm sub-dialogs — new/edit stay modal scoped to the
      window).

## Batch-specific watchpoints

- Both are admin-gated: the windows, their taskbar buttons, and the start menu
  Admin group must only render for admins — and the `managed` open events
  (`window_open`) must be authorized server-side, not just hidden client-side
  (a non-admin sending `window_open: admin-console` must be a no-op; add a test).
- These are strong `managed` candidates (heavy, rarely open, no state needed while
  closed) — confirm against the recipe rule.

## Completion criteria

- [ ] Both open as windows for admins from menu bar and start menu Admin group.
- [ ] Non-admins: no taskbar/start-menu traces, and server-side rejection test for
      forged `window_open`.
- [ ] All 18 planned windows are now windows; the modal-only survivors are exactly
      the locked-decision-#2 list.

## Verification

- `make ci` fully green.
- Manual smoke as admin AND as regular user (gating), broadcast tab opens, bot
  form sub-dialog scoping.
