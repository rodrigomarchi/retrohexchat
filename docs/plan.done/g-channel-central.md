# Category G: Channel Central Dialog

**Priority**: Yellow (Medium impact)
**Dependencies**: None (uses existing channel modes infrastructure)
**Existing**: Channel modes +m/+i/+t/+k/+l already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| G1 | Channel Central window | New | Dedicated dialog showing all channel info: topic, modes, ban list, creator |
| G2 | Topic editing in dialog | New | Editable field for the topic directly in the dialog |
| G3 | Visual ban list | New | Visual list of all channel bans with who banned and when, with add/remove buttons |
| G4 | Modes as checkboxes | New | Each channel mode as a visual checkbox in the dialog |
| G5 | Ban exceptions list (+e) | New | List of ban exceptions (users that can join even with an active ban) |
| G6 | Invite exceptions list (+I) | New | List of invite-only exceptions (users that can join without an invite) |

## Dependencies Detail

- G uses existing channel mode infrastructure (+m, +i, +t, +k, +l already work)
- G3 (ban list) uses existing ban system in Channels context
- G5 (+e) and G6 (+I) introduce new mode types
- T (Channel Advanced) adds more modes that would appear as additional checkboxes in G4

## Technical Notes (IRC/mIRC Reference)

- In mIRC, Channel Central (right-click channel > Channel Central, or double-click channel name) shows topic, modes, ban list
- Ban list entries show: mask, banned by, ban time
- +e (ban exceptions) is standard in RFC 2811 and most IRC networks
- +I (invite exceptions) is less standard but supported by most major networks (UnrealIRCd, InspIRCd)
- Modes are presented as checkboxes with associated fields for +k (key) and +l (limit)

---

## Spec Command

```
/speckit.specify "Channel Central Dialog for RetroHexChat.

PROBLEM: Channel operators currently manage channel settings only through slash commands (/mode, /topic, /ban), which is cumbersome and requires memorizing syntax. Users have no visual overview of a channel's current state — its topic, who set it, what modes are active, who is banned and why. Classic mIRC provides a Channel Central dialog as the single visual hub for all channel administration.

EXISTING CONTEXT: Channel modes +m (moderated), +i (invite-only), +t (topic lock), +k (key), +l (limit) are already fully implemented. The ban system is also in place. This feature provides a visual management surface for existing functionality, plus two new mode types.

USER JOURNEY: An operator double-clicks the channel name in the treebar (or right-clicks and selects 'Channel Central'). A retro-style dialog opens showing comprehensive channel information organized into sections:

INFO section — Channel name, creation date, creator nickname, current member count.

TOPIC section — The current topic text with who set it and when. Operators see an editable text field and a 'Set Topic' button. Non-operators see the topic as read-only.

MODES section — Each channel mode presented as a labeled checkbox: Moderated (+m), Invite Only (+i), Topic Lock (+t), etc. Key (+k) has an adjacent password field, Limit (+l) has a number input. Operators can check/uncheck modes; changes take effect when 'Apply' is clicked. Non-operators see disabled checkboxes showing current state.

BANS section — A list of all active bans showing: who is banned, who set the ban, when it was set. Operators see 'Add Ban' and 'Remove Ban' buttons. Below the ban list, a separate list for ban exceptions (+e) — users who are exempt from bans despite matching a ban mask.

INVITE EXCEPTIONS section — A list of users who can bypass invite-only (+i) mode without needing an explicit invite.

ACTORS: Any channel member can open Channel Central to view information. Only operators can edit topic, toggle modes, manage bans, and manage exception lists. Non-operators see a fully read-only view.

EDGE CASES: Opening Channel Central for a channel you are not a member of should be rejected. If another operator changes a mode while the dialog is open, the dialog should update in real time. Removing the last ban should clear the list cleanly. Setting +k with an empty key field should show a validation error. The dialog must reflect mode changes made via slash commands in other windows instantly.

NEGATIVE REQUIREMENTS: Non-operators must NOT see any editable controls — no accidental mode changes. The dialog must NOT allow setting mutually exclusive modes simultaneously (e.g., +s and +p in the future).

SCOPE: In scope — Channel Central dialog with all sections (info, topic, modes, bans, ban exceptions +e, invite exceptions +I), real-time updates, operator vs non-operator views. Out of scope — advanced channel modes not yet implemented (+s, +p, +c, +n from Cat T) — those will appear as additional checkboxes once implemented."
```
