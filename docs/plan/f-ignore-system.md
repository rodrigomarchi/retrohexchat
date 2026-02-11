# Category F: Ignore System

**Priority**: Yellow (Medium impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| F1 | /ignore basic | New | Ignore all messages from a specific user |
| F2 | Ignore by type | New | Selectively ignore: channel messages, PMs, invites, actions (/me) |
| F3 | Temporary ignore | New | Ignore with automatic timer (e.g., ignore for 5 minutes) |
| F4 | Ignore list dialog | New | Dialog to view/add/remove ignores |
| F5 | /unignore command | New | Command to remove an ignore |

## Dependencies Detail

- F is independent and can be implemented standalone
- F feeds into C4 (Control tab in Address Book) — Address Book provides alternate UI
- F4 (ignore dialog) relates to N4 (auto-ignore flooders)

## Technical Notes (IRC/mIRC Reference)

- In mIRC, /ignore supports wildcards: /ignore *!*@*.spammer.com
- Ignore types in mIRC: msgs, ctcps, invites, notices, all
- mIRC ignore list is accessible via Tools > Address Book > Control tab
- Ignored users receive no feedback that they are being ignored
- NOTICE messages from ignored users may still be shown in some mIRC configurations

---

## Spec Command

```
/speckit.specify "Ignore System for RetroHexChat.

PROBLEM: Users have no way to block unwanted messages from annoying or abusive users. In any chat environment, the ability to locally silence someone without moderator intervention is essential for a comfortable experience. Classic mIRC provides a granular ignore system where users control exactly what they want to filter.

USER JOURNEY: A user is being spammed by 'SpamBot42' in #lobby. They type '/ignore SpamBot42' and immediately stop seeing any messages from that user — channel messages, PMs, and actions all disappear from their view. A system message confirms: '* SpamBot42 is now ignored'. SpamBot42 receives no indication that they are being ignored.

For more granular control, the user can ignore by type: '/ignore AnnoyingGuy pms' ignores only private messages from AnnoyingGuy while still showing their channel messages. Available types: all (default), messages, pms, invites, actions.

For temporary situations, the user can set a timer: '/ignore LoudPerson all 5m' ignores for 5 minutes. When the timer expires, a system message appears: '* LoudPerson is no longer ignored (timer expired)' and their messages become visible again.

The user can view and manage all ignores via a dialog (accessible from menu) showing: nickname, ignore type, expiration (permanent or countdown), with Add and Remove buttons. '/unignore SpamBot42' removes the ignore immediately.

ACTORS: Any connected user (guest or registered). Each user has their own private ignore list. Ignore preferences persist across sessions for registered users; for guests, they last for the current session.

EDGE CASES: Ignoring yourself should be rejected with a friendly error message. Ignoring a user who is already ignored should update the ignore type/duration rather than create a duplicate. If an ignored user sends a message that is quoted by a non-ignored user, the quoted text should still be visible. System messages (joins, parts, kicks) from ignored users should still be visible to maintain channel context. /unignore on a user who is not ignored should show 'User is not in your ignore list'.

NEGATIVE REQUIREMENTS: The system must NOT notify the ignored user in any way. The system must NOT filter server/system messages from ignored users — only user-authored content (messages, PMs, actions, invites).

SCOPE: In scope — /ignore and /unignore commands, per-type ignore (messages, pms, invites, actions, all), temporary ignore with timer, ignore list management dialog. Out of scope — wildcard/pattern-based ignoring (hostmasks), automatic flood-based ignoring (that is Cat N), ignore management within Address Book (that is Cat C)."
```
