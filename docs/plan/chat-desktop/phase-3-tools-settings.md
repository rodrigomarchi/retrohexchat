# Phase 3 — Tools/Settings Batch

## Objective

Apply the Phase 2 recipe to the remaining Tools/Settings mini-apps. One dialog per
loop iteration, committed individually.

## Prerequisite

Phase 2 complete; recipe present in `PROGRESS.md`.

## Windows to migrate

- [ ] AddressBook (4 tabs + 7 sub-forms — the heaviest; sub-forms scope to the
      window; watch send_update-while-closed for notify/contact updates when
      deciding managed vs always-mounted)
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

- [ ] All 8 open as windows from both menu bar and start menu (Tools group);
      shortcuts (`toggle_address_book`, etc.) focus/open the window.
- [ ] All sub-forms scoped to their parent windows.
- [ ] Each mounting decision recorded in PROGRESS.md.
- [ ] Zero entries for these dialogs remain in `dismiss_topmost`.

## Verification

- `make ci` fully green after the batch (and `make ci.quick` per dialog while
  iterating).
- Manual smoke: open 3+ of these windows simultaneously, drag/overlap/focus
  z-order, minimize-all + cascade from the taskbar desktop menu, reload persists.
