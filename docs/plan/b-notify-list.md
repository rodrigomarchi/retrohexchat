# Category B: Notify List / Buddy List

**Priority**: Yellow (Medium impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| B1 | Notify list (buddy list) | New | Persistent list of "friend" nicknames — notifies on connect/disconnect |
| B2 | Custom sounds per notify event | New | Different sound when a buddy comes online vs goes offline |
| B3 | Notes per nickname | New | Personal annotation field per nickname in the notify list |
| B4 | Auto-whois on notify | New | When someone from notify list comes online, auto-show their /whois info |
| B5 | Notify list window | New | Dedicated window showing online/offline status of each buddy |

## Dependencies Detail

- B feeds into C2 (Notify tab in Address Book) — Address Book aggregates notify management
- B2 (sounds) relates to O (Sounds & Notifications) for sound infrastructure
- B is independent and can be implemented standalone

## Technical Notes (IRC/mIRC Reference)

- In mIRC, the Notify List (Alt+W) shows a list of nicknames with online/offline indicators
- Notifications fire on sign-on and sign-off events
- The list persists across sessions in mIRC's config files
- mIRC shows a popup notification and plays a configurable sound per event

---

## Spec Command

```
/speckit.specify "Notify List (Buddy List) for RetroHexChat.

PROBLEM: Users have no way to know when their friends come online or go offline. In a busy chat environment, it is easy to miss when someone you care about connects. Classic mIRC solved this with a Notify List — a persistent buddy list that alerts you to friends' presence changes.

USER JOURNEY: A user wants to track when their friend 'Alice' is online. They open the Notify List window (via menu or toolbar) and add 'Alice' to the list with an optional personal note ('Works on Elixir projects'). Later, when Alice connects, the user receives a system notification: '* Alice is now online' with a distinct sound. The Notify List window updates to show Alice's status as online. When Alice disconnects, the user sees '* Alice has gone offline' with a different sound.

The Notify List window is a dedicated Windows 98-style window showing all buddies in a list with columns: Nickname, Status (online/offline icon), Notes, Last Seen. The user can add, remove, and edit entries. Double-clicking an online buddy opens a PM conversation.

Optionally, when a buddy comes online, the system can automatically fetch and display their /whois information as a system message, so the user sees what channels they are in.

ACTORS: Any connected user (guest or registered). Each user has their own private notify list. The notify list persists across sessions for registered users; for guests it lasts for the current session only.

EDGE CASES: Adding a nickname that doesn't exist yet should still be allowed (they may connect later). Adding your own nickname should be rejected with a friendly message. The list should have a reasonable maximum (e.g., 50 entries). If a buddy rapidly connects/disconnects, notifications should be debounced to avoid spam. Removing a buddy from the list while they are online should not generate an offline notification.

SCOPE: In scope — buddy list management (add/remove/edit/notes), online/offline notifications with distinct sounds, notify window, auto-whois option. Out of scope — notify list management within Address Book (that is Cat C), sound file selection UI (that is Cat O)."
```
