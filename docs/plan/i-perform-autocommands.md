# Category I: Perform / Auto-commands

**Priority**: Yellow (Medium impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| I1 | Perform on connect | New | List of commands executed automatically upon connecting |
| I2 | Auto-join channels | New | List of channels to join automatically on connect |
| I3 | Auto-identify NickServ | New | If nick registered and password saved, identify automatically |
| I4 | Auto-reconnect | New | Reconnect automatically if connection lost (with retry backoff) |
| I5 | Reconnect to channels | New | On reconnect, rejoin all channels user was in before |

## Dependencies Detail

- I is independent and can be implemented standalone
- I1 and I3 relate to Services context (NickServ)
- I2 relates to P (Favorites) — favorites can be auto-joined
- I4/I5 are infrastructure features that benefit all categories
- I settings integrate into V (Options Dialog)

## Technical Notes (IRC/mIRC Reference)

- In mIRC, Perform (Tools > Perform) is a list of commands executed on connect, with per-network support
- Auto-join is often implemented via Perform: /join #chan1, /join #chan2
- mIRC auto-reconnect tries 3 times with configurable delay
- NickServ identify is typically the first perform command
- Execution order in mIRC: connect → identify → wait for services → join channels → other commands

---

## Spec Command

```
/speckit.specify "Perform / Auto-commands for RetroHexChat.

PROBLEM: Every time a user connects, they must manually identify with NickServ, manually join their usual channels, and manually run any setup commands. This is tedious and error-prone, especially after disconnections. Classic mIRC solves this with Perform (auto-execute commands on connect) and auto-reconnect, making the connection experience seamless.

USER JOURNEY: A registered user configures their connection preferences once via a Perform dialog (accessible from menu). They add their usual commands:
- /ns identify mypassword (auto-identify with NickServ)
- /join #elixir
- /join #phoenix
- /join #project-secret secretkey

From then on, every time they connect, the system automatically runs these commands in order. The user sees system messages confirming each action: '* Identifying with NickServ...', '* Joining #elixir...', etc.

If the user's connection drops unexpectedly, the system automatically attempts to reconnect with increasing delays between attempts (starting at 1 second, doubling each time, up to 30 seconds maximum). A status indicator shows 'Reconnecting in Xs...' with an option to cancel. On successful reconnect, the system re-identifies with NickServ and rejoins all channels the user was in before the disconnection.

The user can also configure a dedicated auto-join channel list separately from the general perform commands, for convenience.

ACTORS: Any connected user (guest or registered). Auto-identify only applies to registered users with saved NickServ passwords. Perform commands and auto-join lists persist across sessions for registered users.

EDGE CASES: If NickServ identification fails, the system should still proceed with channel joins (some channels may not require it). If a channel requires a key (+k) and the saved key is wrong, the join fails gracefully with an error message. Auto-reconnect should give up after a configurable maximum number of attempts and notify the user. If the user manually disconnects (/quit), auto-reconnect should NOT trigger. If the server rejects the connection on reconnect (e.g., banned), auto-reconnect should stop and explain why.

NEGATIVE REQUIREMENTS: Auto-reconnect must NOT trigger on intentional disconnection (/quit or closing the browser). Perform commands must NOT execute if the user cancels the connection during reconnect. Saved NickServ passwords must NOT be displayed in plain text in the Perform dialog.

SCOPE: In scope — Perform dialog (command list editor), auto-join channel list, auto-identify NickServ, auto-reconnect with exponential backoff, rejoin channels on reconnect, execution order management. Out of scope — per-network perform lists (we have a single server), scripting/conditionals in perform commands (that is Cat S)."
```
