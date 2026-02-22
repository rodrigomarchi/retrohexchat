# Category J: Invite System

**Priority**: Yellow (Medium impact)
**Dependencies**: None (uses existing +i invite-only mode)
**Existing**: +i invite-only channel mode already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| J1 | /invite command | New | Invite a user to an invite-only (+i) channel |
| J2 | Invite notification | New | Visual notification when someone invites you to a channel |
| J3 | Auto-join on invite | New | Option to automatically join when invited (configurable) |
| J4 | Invite dialog | New | Dialog popup when receiving an invite: Join / Ignore |

## Dependencies Detail

- J builds on existing +i channel mode infrastructure
- J relates to G6 (invite exceptions +I in Channel Central)
- J3 (auto-join) setting integrates into V (Options Dialog)
- T1 (/knock) is the complement — knock requests entry, invite grants entry

## Technical Notes (IRC/mIRC Reference)

- In IRC, INVITE is a standard protocol command (RFC 2812 Section 3.2.7)
- Only channel operators can invite users to +i channels
- The invited user receives a server notice with the channel name and inviter
- mIRC shows a popup dialog with Join/Ignore options
- Invites have no built-in expiration in IRC protocol, but many servers implement timeouts

---

## Spec Command

```
/speckit.specify "Invite System for RetroHexChat.

PROBLEM: When a channel is set to invite-only (+i), there is currently no way for operators to invite specific users to join. Users who want to enter a private channel have no mechanism to request or receive access. Classic IRC solves this with the /invite command and invitation notifications.

EXISTING CONTEXT: The +i (invite-only) channel mode is already implemented — channels with +i reject all join attempts. This feature adds the ability for operators to grant individual users permission to bypass that restriction.

USER JOURNEY: An operator in the invite-only channel #private wants to bring in their colleague 'Alice'. They type '/invite Alice #private'. Alice, wherever she is, receives a notification: '* Operator has invited you to #private'. A retro-style dialog popup appears asking: 'OperatorNick has invited you to join #private — Join / Ignore'. If Alice clicks Join, she enters the channel. If she clicks Ignore, the invitation is dismissed.

Users can optionally enable 'Auto-join on invite' in their preferences, which skips the dialog and joins immediately when invited. This is off by default for security.

The operator who sent the invite receives confirmation: '* Inviting Alice to #private'.

ACTORS: Channel operators can send invites to +i channels they operate. Any connected user can receive invites. The auto-join preference is per-user.

EDGE CASES: Inviting a user who is already in the channel should show an informational message, not an error. Inviting a user who does not exist (not connected) should show 'User not found'. Only operators of the channel should be able to invite — non-operators get 'You are not a channel operator'. Invites should expire after a reasonable timeout (e.g., 5 minutes) — if the user does not respond, the invite becomes invalid and joining the +i channel is rejected again. If the channel mode is changed from +i to open while an invite is pending, the invite becomes irrelevant (anyone can join).

NEGATIVE REQUIREMENTS: The /invite command must NOT work on non-invite-only channels (unnecessary). Auto-join on invite must NOT be enabled by default (security consideration — could be abused).

SCOPE: In scope — /invite command for operators, invite notification dialog (Join/Ignore), auto-join on invite preference, invite expiration. Out of scope — invite exceptions list (+I mode, that is Cat G), /knock command to request entry (that is Cat T)."
```
