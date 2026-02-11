# Category M: CTCP (Client-to-Client Protocol)

**Priority**: Green (Low impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| M1 | CTCP PING | New | Measure latency between you and another user |
| M2 | CTCP VERSION | New | Request the IRC client version of another user |
| M3 | CTCP TIME | New | Request the local time of another user |
| M4 | CTCP FINGER | New | Request profile info from another user |
| M5 | Customizable CTCP replies | New | Configure the responses your client gives to CTCP requests |

## Dependencies Detail

- M is independent and can be implemented standalone
- M must precede N2 (CTCP flood protection)
- M4 (FINGER) relates to W5 (customizable finger reply)
- M5 (custom replies) settings integrate into V (Options Dialog)
- In our web app, CTCP is simulated (not real IRC protocol)

## Technical Notes (IRC/mIRC Reference)

- CTCP uses SOH (\x01) delimiters in real IRC: \x01PING 1234567890\x01
- CTCP PING: client sends timestamp, target echoes it back, sender computes RTT
- CTCP VERSION: returns client name and version string
- CTCP TIME: returns local time in human-readable format
- CTCP FINGER: returns user's configured finger reply (name, idle time, etc.)
- CTCP replies should NOT trigger further auto-replies (same rule as NOTICE)
- In mIRC, CTCP responses are configurable via Tools > Options > IRC > CTCP

---

## Spec Command

```
/speckit.specify "CTCP (Client-to-Client Protocol) for RetroHexChat.

PROBLEM: Users have no way to query information about other users' clients or measure connection latency between themselves and others. In IRC culture, CTCP commands (PING, VERSION, TIME, FINGER) are fundamental social tools — users ping each other to check latency, query client versions out of curiosity, and share profile info. These commands are part of the expected IRC experience.

NOTE: Since RetroHexChat is a web-based client (not connected to real IRC servers), CTCP is simulated between users within the application rather than using the real IRC CTCP protocol.

USER JOURNEY: A user wants to check their latency to another user 'Alice'. They type '/ctcp Alice ping'. Alice's client automatically and invisibly echoes the ping back. The user sees a system message: '* CTCP PING reply from Alice: 45ms'. The entire exchange is invisible to Alice except for a brief system message noting the request.

A curious user types '/ctcp Alice version' and sees: '* CTCP VERSION reply from Alice: RetroHexChat v1.0'. They try '/ctcp Alice time' and see Alice's local time. '/ctcp Alice finger' returns Alice's configured profile text (or a default showing her nickname and idle time).

Users can customize their CTCP replies through a configuration dialog: what their VERSION string says, what their FINGER reply contains, and whether to respond to CTCP requests at all (some users prefer privacy).

ACTORS: Any connected user can send CTCP requests and receive automatic replies. Reply customization is per-user.

EDGE CASES: Sending a CTCP request to a non-existent user should show 'User not found'. If the target user has disabled CTCP responses, the sender should see 'No CTCP reply from Alice (timed out)' after a reasonable timeout (e.g., 10 seconds). Rapid CTCP requests to the same user should be rate-limited to prevent abuse. CTCP to yourself should work (useful for testing) and show instant response.

NEGATIVE REQUIREMENTS: CTCP replies must NOT trigger further automatic responses (same rule as NOTICE — prevents infinite loops). CTCP exchanges must NOT create PM windows or treebar entries. CTCP requests should NOT be visible to other users in the channel — they are private between sender and target.

SCOPE: In scope — /ctcp command for PING, VERSION, TIME, FINGER; automatic replies; customizable reply strings; reply configuration dialog. Out of scope — CTCP flood protection (that is Cat N), custom CTCP types beyond the four standard ones, CTCP ACTION (already implemented as /me)."
```
