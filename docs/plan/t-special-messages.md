# Category T: Special Messages

**Priority**: Green (Low impact)
**Dependencies**: R7 (Status Window) for U1/U3/U4
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| U1 | MOTD (Message of the Day) | New | Admin-configurable message displayed when users connect |
| U2 | Welcome message per channel | New | Automatic message displayed when joining a channel |
| U3 | /wallops (wall messages) | New | Broadcast message to all network operators |
| U4 | Global announcements | New | Admin message sent to ALL connected users |

## Dependencies Detail

- U1, U3, U4 depend on R7 (Status Window) as the display target
- U2 is per-channel and displays in the channel window
- U1 and U4 require admin/server-level permissions
- U3 requires operator status

## Technical Notes (IRC/mIRC Reference)

- MOTD in IRC: displayed on connect, stored server-side in a text file. RPL_MOTDSTART (375), RPL_MOTD (372), RPL_ENDOFMOTD (376)
- Welcome message: not standard IRC, but common as ChanServ feature (e.g., ChanServ ENTRYMSG)
- /wallops: IRC standard (RFC 2812 Section 3.7.3). Sends to all users with +w mode flag
- Global announcements: non-standard, typically implemented as WALLOPS from server or IRCop GLOBOPS

---

## Spec Command

```
/speckit.specify "Special Messages for RetroHexChat.

PROBLEM: There is no mechanism for server administrators to communicate with users (welcome messages, announcements, maintenance notices) and no way for channel operators to set automatic greeting messages for newcomers. Users connecting to the server see no orientation message. These communication channels are fundamental to any IRC server.

USER JOURNEY — MOTD: A user connects to RetroHexChat. In the Status Window (or active window if no Status Window), they see a bordered, distinctive system message: the Message of the Day. It contains server rules, announcements, and useful info set by the administrator. The MOTD is displayed once on connect and can be re-read with the /motd command.

USER JOURNEY — WELCOME: A user joins #elixir for the first time. Immediately after the join message, they see a system message: 'Welcome to #elixir! This channel is for Elixir language discussion. Please read the topic for guidelines.' This welcome message was set by the channel founder and appears for every user who joins.

USER JOURNEY — WALLOPS: A server operator needs to notify all other operators about upcoming maintenance. They type '/wallops Server restart in 15 minutes — please warn your channels'. All users who have opted into wallops notifications (via +w user mode) see the message in their Status Window: '[Wallops] OperatorNick: Server restart in 15 minutes...'.

USER JOURNEY — ANNOUNCEMENT: An administrator needs to reach every connected user urgently. They send a global announcement. Every user sees a prominent, unmissable message in their active window: '[ANNOUNCEMENT] Server maintenance at 22:00 UTC. All connections will be briefly interrupted.' with distinctive styling (bold, colored background).

ACTORS: Administrators can set MOTD and send global announcements. Channel operators/founders can set per-channel welcome messages. Server operators can send /wallops. Regular users receive and see all applicable messages.

EDGE CASES: MOTD that is not set should result in no MOTD display on connect (not an error). Very long MOTDs should be paginated or scrollable. Channel welcome messages should only display once per join (not on reconnect to the same channel within a session). /wallops with no users having +w mode should succeed silently (message sent to nobody). Global announcements should reach users in all states (including those with moderated channels, away status, etc.).

NEGATIVE REQUIREMENTS: Global announcements must NOT be ignorable — they bypass ignore lists. MOTD must NOT block the connection flow (display is informational). Channel welcome messages must NOT be sent to the user who set them (they already know). /wallops must NOT be usable by non-operators.

SCOPE: In scope — MOTD (admin-configurable, displayed on connect, /motd command), per-channel welcome message (set by operator/founder), /wallops to operators, global announcements from admin. Out of scope — MOTD editor GUI for admins (command-line or config only in this phase), scheduled announcements, welcome message templates."
```
