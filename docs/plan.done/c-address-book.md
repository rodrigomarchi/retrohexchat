# Category C: Address Book

**Priority**: Green (Low impact)
**Dependencies**: B (Notify List), F (Ignore System), A1 (Nick Colors)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| C1 | Basic Address Book | New | Stores info about users: nickname, personal notes, date of first contact |
| C2 | Notify tab in Address Book | New | Manage the notify/buddy list within the address book UI |
| C3 | Nick Colors tab | New | Assign custom colors to specific nicknames (overrides hash-based color) |
| C4 | Control tab (ignore list) | New | Manage ignore list within the address book with ignore type controls |
| C5 | Access via Alt+B or toolbar | New | Keyboard shortcut and toolbar icon to open the address book |

## Dependencies Detail

- **Depends on B** (Notify List): C2 tab manages the notify list from Category B
- **Depends on F** (Ignore System): C4 tab manages the ignore list from Category F
- **Depends on A1** (existing): C3 provides overrides for the hash-based nick colors
- C is an aggregator — should be implemented after B and F are complete

## Technical Notes (IRC/mIRC Reference)

- In mIRC, the Address Book (Alt+B) is a tabbed dialog combining contacts, notify list, highlight settings, and control (ignore) lists
- It is the central place for managing per-user settings
- mIRC stores this data in its configuration files across sessions

---

## Spec Command

```
/speckit.specify "Address Book for RetroHexChat.

PROBLEM: Users currently manage friends, ignored users, and nick color preferences through separate mechanisms with no unified interface. In classic mIRC, the Address Book (Alt+B) is the single place to manage all per-user relationships — contacts, notifications, custom colors, and ignore rules. Without it, user management is fragmented and inconvenient.

EXISTING CONTEXT: Nick colors by hash (Cat A1) are already implemented. The Notify List (Cat B) and Ignore System (Cat F) must be implemented before this category, as the Address Book provides an alternative management UI for both.

USER JOURNEY: A user presses Alt+B (or clicks the Address Book toolbar icon) and a tabbed retro-style dialog opens with four tabs:

1. CONTACTS tab — Shows a list of saved contacts with columns: Nickname, Notes, First Contact Date. The user can add new contacts, edit notes, and remove entries. This is their personal rolodex of people they have interacted with.

2. NOTIFY tab — Provides full management of the buddy/notify list (from Cat B): add/remove buddies, edit notes per buddy, toggle notification preferences. This is an alternate UI for the same data managed by the Notify List window.

3. NICK COLORS tab — Shows a list of nickname-to-color mappings. The user can assign a custom color to any nickname, overriding the automatic hash-based color. Useful for making important people stand out or for accessibility preferences.

4. CONTROL tab — Manages the ignore list (from Cat F): shows ignored users with their ignore types (all messages, PMs only, invites only, actions only), allows add/remove/edit of ignore entries, and shows expiration time for temporary ignores.

ACTORS: Any connected user (guest or registered). Each user has their own private Address Book. Data persists across sessions for registered users.

EDGE CASES: Opening Address Book while another modal dialog is open should queue or focus the existing dialog. Editing a notify entry in the Address Book should be reflected in the Notify List window in real time (and vice versa). Removing an ignore in the Address Book should immediately stop filtering that user's messages. The Alt+B shortcut must not conflict with other key bindings.

SCOPE: In scope — tabbed Address Book dialog with four tabs (Contacts, Notify, Nick Colors, Control), Alt+B shortcut, toolbar icon. Out of scope — the underlying data management for notify and ignore (those are Cats B and F respectively); this category only provides the unified UI surface."
```
