# Phase 4 — View / Account / Channel Batch

## Objective

Apply the recipe to the informational and account/channel mini-apps.

## Prerequisite

Phase 3 complete (recipe battle-tested on the heavy Tools batch).

## Windows to migrate

- [ ] UrlCatcher — already done in Phase 2 (pilot); verify only.
- [x] ChannelList — ALWAYS-MOUNTED (`open={false}`): the search filter survives
      closes and the island receives targeted send_updates. Opener stays
      server-side everywhere (incl. start menu `app_item`): opening loads fresh
      /list rows, so a client-only `data-window-open` would show stale data.
- [ ] UserLookup (whois result card; opened programmatically from nick context
      menus and `/whois` — openers include non-menu paths, sweep for every
      `open_user_lookup` call site)
- [x] Cheatsheet — MANAGED: static content, no state to preserve.
      `toggle_cheatsheet` (menu + shortcut) routes through `Windows.open`
      (open/focus, never toggle-close); Escape is WM-owned. This emptied
      `topmost_dismissals` (Phase 6 cleanup candidate).
- [ ] Account (NickServ mini-app; 8 `update(%{action...})` entry points —
      register/identify/profile/presence/modes/ghost/drop must each open+focus the
      window and switch its internal mode; sweep all `open_account_*` actions)
- [ ] ChannelCentral (4 sub-forms; opened from channel context menus too — sweep
      openers)

Follow the Phase 2 recipe per dialog; record mounting decisions.

## Batch-specific watchpoints

- Account and ChannelCentral have many programmatic openers scattered across
  event modules (`account_events.ex`, `channel_central_events.ex`, context
  menus) — every entry point must route through the same open+focus adapter, no
  stragglers opening a ghost modal.
- Cheatsheet is in `topmost_dismissals` (highest Escape priority today) — after
  migration Escape is WM-owned for it.

## Completion criteria

- [ ] All 6 verified as windows; every programmatic opener (context menus, slash
      commands, menu bar, start menu View group, shortcuts) opens/focuses the
      window.
- [ ] Mounting decisions recorded.
- [ ] No entries for these remain in `dismiss_topmost`.

## Verification

- `make ci` fully green.
- Manual smoke: `/whois` from composer → UserLookup window; open Account via menu
  Register vs Identify (mode switches, single window); ChannelCentral from a
  channel context menu; Cheatsheet shortcut toggle.
