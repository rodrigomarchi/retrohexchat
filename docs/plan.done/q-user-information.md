# Category Q: User Information

**Priority**: Green (Low impact)
**Dependencies**: None
**Existing**: Q1 /whois dialog already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| Q1 | /whois dialog | Existing | Dialog showing user info (nickname, channels, away status) |
| Q2 | /whowas command | New | Show info about a nick that recently disconnected |
| Q3 | User Central dialog | New | Expanded dialog with more info: common channels, online time, away message, registration |
| Q4 | User profile/bio | New | Users can set a mini-bio/personal info accessible via /whois |
| Q5 | Idle time tracking | New | Show how long a user has been idle (no messages sent) |

## Dependencies Detail

- Q1 (existing) provides the /whois dialog foundation
- Q3 expands Q1 into a richer dialog
- Q4 adds user-editable data shown in Q1/Q3
- Q5 uses existing presence tracking infrastructure

## Technical Notes (IRC/mIRC Reference)

- IRC /whois shows: nickname, username, hostname, real name, channels, server, idle time, signon time
- IRC /whowas shows: info about recently disconnected users (server keeps a short buffer)
- Idle time in IRC is measured since last PRIVMSG sent by the user
- mIRC whois dialog shows all info in a formatted popup
- User profiles/bios are not standard IRC but common in modern clients (TheLounge, IRCCloud)

---

## Spec Command

```
/speckit.specify "User Information for RetroHexChat.

PROBLEM: The current /whois dialog shows basic user information, but users cannot see who was recently online (just missed someone), cannot view shared channels with another user, cannot see how long someone has been idle, and have no way to express their identity through a profile or bio. The user information experience is minimal compared to both classic mIRC and modern chat applications.

EXISTING CONTEXT: The /whois dialog is already implemented, showing basic user information (nickname, channels, away status) in a retro-style dialog.

USER JOURNEY: A user types '/whois Alice' and sees an expanded User Central dialog. Beyond the existing basic info, it now shows: channels they share with Alice, Alice's total online time for the current session, her away message (if set), whether she is registered with NickServ, her idle time ('idle for 15 minutes'), and her profile bio ('Elixir enthusiast from Brazil').

A user notices 'Bob' was online earlier but has since disconnected. They type '/whowas Bob' and see: 'Bob was last seen 10 minutes ago, was in channels #elixir and #lobby, quit with message: See you tomorrow!'. This information is cached for a limited time after disconnection.

Users can set their own profile bio: they type '/bio Elixir enthusiast, loves retro computing' or open a profile edit dialog. This short text (max 200 characters) appears in their /whois output for anyone who queries them.

The User Central dialog can also be opened by double-clicking a nickname in the nicklist.

ACTORS: Any connected user can view other users' information via /whois and /whowas. Any user (guest or registered) can set their own bio. Bios persist across sessions for registered users.

EDGE CASES: /whowas for a user who was never online should show 'No whowas information available for that nickname'. /whowas information should expire after a reasonable time (e.g., 1 hour) to avoid stale data accumulation. /whois on yourself should work and show your own profile. Setting a bio longer than 200 characters should be truncated with a warning. Idle time should reset on any message sent (not just channel messages — PMs and commands count too). If a user has no bio set, the bio field should simply not appear in /whois (not show empty).

SCOPE: In scope — /whowas command with cached recent disconnections, expanded User Central dialog (shared channels, online time, idle time, registration status, bio), /bio command and profile edit, idle time tracking. Out of scope — profile pictures/avatars, detailed activity history, user blocking (that is Cat F)."
```
