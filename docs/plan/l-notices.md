# Category L: Notices

**Priority**: Yellow (Medium impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| L1 | /notice command | New | Send a notice to a user (special message that doesn't open a query window) |
| L2 | Notice rendering | New | Notices appear with distinct formatting (prefix, color, or dedicated area) |
| L3 | Notice to channel | New | /notice #channel message — sends notice to all channel members |
| L4 | Notice routing | New | Option to display notices in: active window, status window, or sender's window |

## Dependencies Detail

- L is independent and can be implemented standalone
- L4 (notice routing) configuration integrates into V3 (IRC messages options)
- R7 (Status Window) is a possible routing target for notices
- Per IRC spec, NOTICE must NOT generate automatic replies (prevents bot loops)

## Technical Notes (IRC/mIRC Reference)

- IRC NOTICE (RFC 2812 Section 3.3.2): "The NOTICE message is used similarly to PRIVMSG. The difference is automatic replies must never be sent in response to a NOTICE message."
- In mIRC, notices are displayed with -nickname- prefix instead of <nickname>
- mIRC can route notices to: active window, status window, sender's query window, or a dedicated notices window
- Channel notices show as: -nickname:#channel- message
- Services (NickServ, ChanServ) typically communicate via NOTICE

---

## Spec Command

```
/speckit.specify "Notices for RetroHexChat.

PROBLEM: Users currently have only regular messages and PMs for communication. There is no way to send a lightweight notification-style message that doesn't create a PM conversation window. In IRC, NOTICE is a distinct message type used for announcements, service messages, and bot responses — it is essential for protocol correctness and user experience.

USER JOURNEY: A user wants to quietly inform 'Alice' about something without opening a full PM conversation. They type '/notice Alice hey, check #project when you have a moment'. Alice sees the notice displayed with distinctive formatting — a -UserNick- prefix (instead of the usual <UserNick> for regular messages) and a unique color to distinguish it from normal chat.

For channel-wide announcements, an operator types '/notice #elixir Server maintenance in 30 minutes'. All channel members see the notice in the channel window with the distinct notice formatting.

Users can configure where notices appear: in the currently active window (default), in the Status Window (if available), or in the sender's PM window (if one is open). This routing preference is configurable per user.

ACTORS: Any connected user can send and receive notices. Channel notices can be sent by any channel member. Notice routing preference is per-user.

EDGE CASES: Sending a notice to a non-existent user should show 'User not found'. Sending a notice to a channel you are not a member of should be rejected. If notice routing is set to 'status window' but no Status Window exists yet, fall back to the active window. Notices from service bots (NickServ, ChanServ) should always use notice formatting regardless of routing preferences.

NEGATIVE REQUIREMENTS: The system must NEVER send automatic replies to notices — this is a fundamental IRC protocol rule to prevent infinite loops between bots. Notices must NOT create PM/query windows or treebar entries. Notices must NOT trigger notification sounds or highlights (they are intentionally lightweight).

SCOPE: In scope — /notice command for users and channels, distinct visual rendering, configurable routing (active/status/sender window). Out of scope — notice-specific sound configuration (that is Cat O), routing settings UI in Options Dialog (that is Cat V)."
```
