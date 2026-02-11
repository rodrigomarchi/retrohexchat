# Category T: Channel Features Advanced

**Priority**: Green (Low impact)
**Dependencies**: None for most; A for T7
**Existing**: +m (moderated), +i (invite-only), +t (topic lock), +k (key), +l (limit) already implemented

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| T1 | /knock command | New | "Knock on the door" of an invite-only channel |
| T2 | Half-operator (+h) | New | Intermediate level between voice and op |
| T3 | Channel owner (+q) | New | Level above op, super-power over the channel |
| T4 | +n mode (no external) | New | Block messages from outside the channel |
| T5 | +s mode (secret channel) | New | Channel hidden from /list and /whois |
| T6 | +p mode (private channel) | New | Similar to secret but with subtle differences |
| T7 | +c mode (strip colors) | New | Automatically removes color codes from messages |
| T8 | +R mode (registered only) | New | Only NickServ-registered users can join |
| T9 | Channel flood protection modes | New | Modes like +j (joins/time) for automatic protection |

## Dependencies Detail

- Existing modes provide the mode infrastructure
- T2 (+h) and T3 (+q) extend the user access level hierarchy
- T5/T6 (+s/+p) affect /list and /whois behavior — mutually exclusive
- T7 (+c) depends on A (text formatting) — strips the color codes A introduces
- T8 (+R) depends on NickServ registration (Services context)

## Technical Notes (IRC/mIRC Reference)

- /knock: standard on many networks (InspIRCd, UnrealIRCd). Sends a notice to channel ops. Can be disabled with +K
- +h (half-op): prefix %, RFC-adjacent. Can kick, set topic, set +v, but cannot ban or set other modes
- +q (owner): prefix ~, non-standard but common (UnrealIRCd, InspIRCd). Above +o in hierarchy
- +s vs +p: mutually exclusive per RFC 2811. +s hides from /list AND /whois. +p shows "Prv" in /list but hides name
- +n (no external messages): extremely common, default on most networks. RFC 2811 standard
- +c: strips mIRC color codes (^C, ^B, ^], ^_, etc.) before delivery. Common on UnrealIRCd
- +R: requires NickServ identification to join. Common on Freenode/Libera
- +j X:Y: join throttle — max X joins per Y seconds. Common on UnrealIRCd

---

## Spec Command

```
/speckit.specify "Channel Features Advanced for RetroHexChat.

PROBLEM: The current channel mode system supports the basics (+m, +i, +t, +k, +l) but lacks the full spectrum of modes that IRC users expect. There is no way for users to 'knock' on invite-only channels, no half-operator or owner roles for nuanced permission hierarchies, and no protection modes like 'no external messages', 'secret', or 'registered only'. These advanced features complete the IRC channel experience.

EXISTING CONTEXT: Channel modes +m (moderated), +i (invite-only), +t (topic lock), +k (key/password), +l (user limit) are already fully implemented with OTP process management. The user hierarchy currently has: operator (@) and voice (+).

USER JOURNEY — KNOCK: A user wants to join #private (which is +i invite-only) but has no contact with the operators. They type '/knock #private Hey, can I join? I was referred by Alice.' The channel operators see a system message: '* UserNick has knocked on #private (Hey, can I join? I was referred by Alice.)' and can decide to /invite the user. Channel ops can disable knock with mode +K.

USER JOURNEY — HIERARCHY: A channel founder sets up a team channel with fine-grained permissions. They are the owner (+q, prefix ~) with full control. They promote trusted users to operator (+o, prefix @) who can manage the channel. Semi-trusted helpers get half-operator (+h, prefix %) who can kick disruptive users and voice others but cannot set channel modes or ban. New members get voice (+v, prefix +) to speak in moderated mode. The hierarchy is: owner > operator > half-op > voice > regular.

USER JOURNEY — CHANNEL MODES: An operator sets +n (no external messages) so only members can send to the channel. They set +s (secret) to hide the channel from /list and from members' /whois output. Another operator prefers +p (private) which still shows the channel in /list but as 'Prv' without revealing the name. For a professional channel, +c (strip colors) is set to force plain text only. For a trusted community, +R (registered only) ensures all members are NickServ-identified. To prevent join-flooding, +j 5:10 limits joins to 5 per 10 seconds.

ACTORS: Channel operators can set all modes. Channel owners (+q) have elevated permissions above operators. Half-operators (+h) have limited permissions. Regular users are affected by mode restrictions.

EDGE CASES: Setting +s and +p simultaneously should be rejected (mutually exclusive). +c should strip colors from all messages including /me actions. +R should allow existing unregistered members to stay but block new unregistered joins. /knock on a non-invite-only channel should respond 'Channel is not invite-only'. /knock when +K is set should respond 'Knocking is disabled'. Half-ops must not be able to kick operators or owners. Owners must not be kickable by operators.

NEGATIVE REQUIREMENTS: +s channels must NOT appear in /list results or in members' /whois under any circumstances. +p channel names must NOT be revealed in /list (show 'Prv' only). +n must NOT block service messages (NickServ, ChanServ). +j must NOT prevent operators from joining.

SCOPE: In scope — /knock command, +K mode (disable knock), +h half-operator, +q channel owner, +n no external, +s secret, +p private, +c strip colors, +R registered only, +j join throttle. Out of scope — +S SSL-only mode, +f per-message flood protection (complex), channel mode parameters on ban-type modes."
```
