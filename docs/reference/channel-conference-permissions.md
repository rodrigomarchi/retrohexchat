# Channel conference — permissions matrix

> Authority contract for the channel conference. The conference inherits the
> channel hierarchy; there is no separate call host/moderator role.

## Roles

| Channel role | Rank | Description |
|---|---:|---|
| `owner` | 4 | Channel owner. Can moderate any participant below owner. |
| `operator` | 3 | Operator. Can moderate half-ops, voiced users and regular members. |
| `half_operator` | 2 | Half-op. Can moderate voiced users and regular members. |
| `voiced` | 1 | User with voice. Does not moderate the conference. |
| `regular` | 0 | Regular channel member. Does not moderate the conference. |
| `bot` | 0 | Bot in the channel. Same rank as `regular`; does not moderate the conference. |

The ranks are `Channels.Membership.rank/1`, the same scale the channel uses for
kick and ban. The matrix's `guest` column is not a role: it is anyone without a
registered nick, refused by `check_registered` before any role counts.

## Base rule

- Creating or joining the conference requires a registered user present in the channel.
- Closing the room requires `half_operator` or higher.
- Locking or unlocking the room requires `half_operator` or higher.
- Joining a locked conference is allowed for `half_operator` or higher,
  so moderators can unlock/moderate. Users below that
  stay in the channel, but do not join the locked call.
- Raising/lowering one's own hand is allowed for any conference
  participant.
- Granting the floor to another participant requires `half_operator` or higher and a rank
  above the target; the action unmutes the target and lowers their hand.
- Stopping/blocking or allowing another participant's screen share requires
  `half_operator` or higher and a rank above the target.
- Moderating another participant requires `half_operator` or higher and a rank above
  the target.
- The UI must hide actions the server would refuse by policy.
- The server policy remains the final authority:
  `RetroHexChat.GroupCall.Policy` (`can_create_channel_call?`, `can_join?`,
  `can_close?`, `can_kick_participant?`, `can_moderate_media?`). Kick and
  media moderation delegate to `Channels.Policy.can_kick?/3`.

## Action matrix

| Action | owner | operator | half-op | voiced | member | guest |
|---|---|---|---|---|---|---|
| Create conference in the channel | yes | yes | yes | yes | yes | no |
| Join open conference | yes | yes | yes | yes | yes | no |
| Join locked conference | yes | yes | yes | no | no | no |
| Close conference | yes | yes | yes | no | no | no |
| Lock/unlock conference | yes | yes | yes | no | no | no |
| Raise/lower own hand | yes | yes | yes | yes | yes | no |
| Grant the floor to another participant | lower rank only | lower rank only | lower rank only | no | no | no |
| Mute remote audio | lower rank only | lower rank only | lower rank only | no | no | no |
| Turn off remote camera | lower rank only | lower rank only | lower rank only | no | no | no |
| Stop/block remote screen share | lower rank only | lower rank only | lower rank only | no | no | no |
| Allow remote screen share | lower rank only | lower rank only | lower rank only | no | no | no |
| Remove/ban participant | lower rank only | lower rank only | lower rank only | no | no | no |

## Expected UI

- The close-room button appears only for `owner`, `operator` and
  `half_operator`.
- The lock/unlock-room button appears only for `owner`, `operator` and
  `half_operator`.
- The raise/lower-hand button appears for every local participant.
- The floor request queue appears when there are participants with a raised hand.
- The grant-floor button appears for moderators only on targets the policy
  allows them to moderate.
- The remote mute, remote camera-off and kick buttons appear per participant
  only when the current role can moderate that specific target.
- The camera-off button appears when the target's camera is on or blocked
  by a moderator; it does not turn on a camera the user turned off themselves.
- The screen moderation button appears when the target is sharing their screen or
  blocked by a moderator; allowing removes only the moderation block.
- No moderation action appears for `voiced`, `regular` or a user without
  `channel_role_snapshot`.
- No participant can moderate themselves.

## Coverage

- `RetroHexChat.GroupCall.PolicyTest` validates create/join/close/kick/remote mute
  per role.
- `RetroHexChat.GroupCall.RuntimeTest` validates audio, video and
  screen share blocks imposed by the server.
- `RetroHexChatWeb.ChatLive.GroupCallFlowTest` validates that the conference
  window hides the buttons according to the matrix.
