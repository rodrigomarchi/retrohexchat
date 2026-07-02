# Phase 3 — Tools/Settings Batch

## Objective

Apply the Phase 2 recipe to the remaining Tools/Settings mini-apps. One dialog per
loop iteration, committed individually.

## Prerequisite

Phase 2 complete; recipe present in `PROGRESS.md`.

## Windows to migrate

- [x] AddressBook (managed + open-on-tab like Perform — the only island-targeted
      send_updates are the open/close/toggle directives themselves; contact/notify
      data lives on the session. 7 sub-forms window-scoped; showcase page now
      demos the panel directly)
- [x] NotifyList (managed, NOT always-mounted as guessed: buddy status updates
      mutate the parent's session, never the island — presence flows in as
      passthrough at mount; 2 sub-forms window-scoped)
- [x] Alias (managed — editor, close resets draft; `/alias` command opener rewired)
- [x] CustomMenus (managed — editor, close resets draft)
- [x] AutoRespond (managed — rules editor, close resets draft)
- [x] Perform (managed — open-on-tab via `send_update(open: tab)` AFTER `Windows.open` mounts the island; 4 sub-forms converted to `dialog scope={:window}`)
- [x] SoundSettings (managed — draft seeds from session at mount, discarded on close; OK/Apply/Cancel stay in the panel)
- [x] FloodProtection (managed — uncontrolled form, nothing survives closes)

Per dialog, follow the recipe exactly: mounting decision recorded → window frame →
icon → openers (menu bar + start menu + shortcut) → Escape-stack removal →
sub-form scoping → tests rewritten → help topic touched → commit.

## Completion criteria

- [x] All 8 open as windows from both menu bar and start menu (Tools group);
      shortcuts (`toggle_address_book`, etc.) focus/open the window — re-invoking
      focuses, never toggle-closes.
- [x] All sub-forms scoped to their parent windows (`dialog scope={:window}`).
- [x] Each mounting decision recorded (all 8 managed; the "receives updates while
      closed" rule refined: only island-targeted send_updates force
      always-mounted).
- [x] Zero entries for these dialogs remain in `dismiss_topmost`.

## Verification

✔ 2026-07-02 — full `make ci` 9/9 green (incl. dialyzer). T11 dialog-close E2E
now exercises the window contract in a real browser: X close, no backdrop
close, Escape ladder. Known pre-existing issues recorded in PROGRESS: the
channel-join race flake and the U12 whois-text spec (expects text mode,
default is card).

## Verification

- `make ci` fully green after the batch (and `make ci.quick` per dialog while
  iterating).
- Manual smoke: open 3+ of these windows simultaneously, drag/overlap/focus
  z-order, minimize-all + cascade from the taskbar desktop menu, reload persists.
