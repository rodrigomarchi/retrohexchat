# Category P: Favorites / Bookmarks

**Priority**: Yellow (Medium impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| P1 | Favorite channels | New | Save favorite channels with description and password |
| P2 | Favorites menu | New | "Favorites" menu in the menu bar with list of saved channels |
| P3 | Add to Favorites dialog | New | "Add to Favorites" option in channel context menu |
| P4 | Auto-join favorites | New | Option to automatically join all favorites on connect |
| P5 | Organize favorites | New | Dialog to manage, reorder, and edit favorites |

## Dependencies Detail

- P is independent and can be implemented standalone
- P4 (auto-join) relates to I2 (auto-join channels) — lists can merge
- P2 (menu) requires menu bar infrastructure in the UI

## Technical Notes (IRC/mIRC Reference)

- mIRC: Favorites menu (like browser bookmarks) with channels listed
- Each favorite stores: channel name, description, network, password (for +k channels)
- mIRC supports drag-and-drop reordering in the favorites organizer
- Auto-join favorites on connect is a checkbox per favorite entry

---

## Spec Command

```
/speckit.specify "Favorites / Bookmarks for RetroHexChat.

PROBLEM: Users who regularly visit the same channels must remember channel names and passwords and manually type /join every time they connect. There is no way to bookmark frequently visited channels for quick access. Classic mIRC provides a Favorites system (like browser bookmarks) that makes channel navigation effortless.

USER JOURNEY: A user is in #elixir and wants to bookmark it. They right-click the channel in the treebar and select 'Add to Favorites'. A small Windows 98-style dialog appears with pre-filled channel name, an optional description field ('Elixir language discussion'), an optional password field (for +k channels), and an 'Auto-join on connect' checkbox. They save it.

Now, the 'Favorites' menu in the menu bar shows #elixir in the list. Clicking it joins the channel instantly (or switches to it if already joined). The user adds several more favorites over time.

To manage their favorites, the user opens the Organize Favorites dialog (from the Favorites menu). This shows an ordered list of all favorites with Up/Down buttons for reordering, Edit to modify entries, and Remove to delete. The order in this dialog determines the display order in the Favorites menu.

Favorites marked as 'auto-join' are automatically joined when the user connects, saving them from typing /join commands every session.

ACTORS: Any connected user (guest or registered). Favorites persist across sessions for registered users.

EDGE CASES: Adding a favorite for a channel that is already in favorites should offer to update the existing entry rather than create a duplicate. If a favorited channel's password changes (+k), the saved password becomes stale — the join should fail gracefully with a 'Wrong channel key' message and offer to update. Clicking a favorite for a channel the user is already in should switch to that channel, not attempt to rejoin. The Favorites menu should indicate which favorited channels the user is currently in (e.g., with a checkmark).

NEGATIVE REQUIREMENTS: Favorite channel passwords must NOT be visible in plain text in the favorites list — show asterisks or a 'Password set' indicator. Favorites must NOT auto-join if the user explicitly chose not to auto-join (per-favorite setting).

SCOPE: In scope — favorites management (add/edit/remove/reorder), Favorites menu in menu bar, 'Add to Favorites' in context menu, auto-join favorites on connect, organize dialog. Out of scope — folder/group organization for favorites (keep it flat list), favorites sync between devices, favorites import/export."
```
