# Contract: Policy Module Extensions

**Feature**: 007-channel-central
**Module**: `RetroHexChat.Channels.Policy`

## Extended Functions

### can_join?/6 (extended signature)

```elixir
@spec can_join?(
  Modes.t(),
  Membership.t(),
  String.t() | nil,
  non_neg_integer(),
  MapSet.t(String.t()),
  MapSet.t(String.t())
) :: :ok | {:error, String.t()}
def can_join?(modes, membership, password \\ nil, _max_channels \\ 10,
              ban_exceptions \\ MapSet.new(), invite_exceptions \\ MapSet.new())
```

**Check order** (updated):
1. **Limit** (+l): If set and member count >= limit → reject "Channel is full (+l)". No exception bypass.
2. **Ban check**: If user is in bans MapSet AND NOT in ban_exceptions → reject "You are banned from this channel". Exception overrides ban.
3. **Invite-only** (+i): If set AND user NOT in invite_exceptions → reject "Channel is invite-only (+i)". Exception allows bypass.
4. **Key** (+k): If set and password doesn't match → reject "Bad channel key (+k)". No exception bypass.
5. All checks pass → return `:ok`.

**Note**: The current ban check lives in Server.join handler (`check_not_banned/2`), not in Policy. This refactoring moves it to Policy for consistency with other join validations.

## New Functions

### can_manage_exceptions?/2

```elixir
@spec can_manage_exceptions?(Membership.t(), String.t()) :: :ok | {:error, String.t()}
def can_manage_exceptions?(membership, nickname)
```

**Behavior**: Returns `:ok` if the user is an operator, `{:error, "You must be a channel operator to manage exceptions"}` otherwise. Delegates to `operator?/2`.
