# API Contracts: Channels Domain

**Feature Branch**: `019-channel-features-advanced`
**Date**: 2026-02-13

## Channels.Membership API Changes

### New Types
```elixir
@type role :: :owner | :operator | :half_operator | :voiced | :regular
```

### New Functions
```elixir
@spec rank(role()) :: non_neg_integer()
# Returns: 4 (owner), 3 (operator), 2 (half_operator), 1 (voiced), 0 (regular)

@spec owners(t()) :: [String.t()]
# Returns sorted list of owner nicknames

@spec half_operators(t()) :: [String.t()]
# Returns sorted list of half-operator nicknames

@spec outranks?(t(), String.t(), String.t()) :: boolean()
# Returns true if first user's rank > second user's rank
```

## Channels.Modes API Changes

### New Struct Field
```elixir
defstruct flags: MapSet.new(), key: nil, limit: nil, join_throttle: nil
@type t :: %__MODULE__{
  flags: MapSet.t(),
  key: String.t() | nil,
  limit: non_neg_integer() | nil,
  join_throttle: {pos_integer(), pos_integer()} | nil
}
```

### New Predicate Functions
```elixir
@spec no_external?(t()) :: boolean()
@spec secret?(t()) :: boolean()
@spec private?(t()) :: boolean()
@spec strip_colors?(t()) :: boolean()
@spec registered_only?(t()) :: boolean()
@spec no_knock?(t()) :: boolean()
@spec has_join_throttle?(t()) :: boolean()
```

### Modified Functions
```elixir
@spec apply_changes(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
# Now handles: n, s, p, c, R, K (flags) and j (parameterized)
# Returns {:error, "+s and +p are mutually exclusive"} if both set
# Returns {:error, "Invalid join throttle format..."} if +j param invalid

@spec to_string(t()) :: String.t()
# Now includes new flag characters in output
```

## Channels.Policy API Changes

### Modified Functions
```elixir
@spec can_join?(Modes.t(), Membership.t(), String.t() | nil, String.t(), MapSet.t(), boolean()) ::
  :ok | {:error, String.t()}
# New parameter: identified :: boolean() — for +R check
# New error: "You must be registered to join this channel"
# New error: "Channel join throttle active, please try again shortly"

@spec can_speak?(Modes.t(), Membership.t(), String.t()) :: :ok | {:error, String.t()}
# New error: "Cannot send to channel (no external messages)" when +n and non-member

@spec can_kick?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
# New function. Checks: actor rank > target rank, actor rank >= half_operator
# Errors: "Cannot kick a higher-ranked user", "Insufficient privileges"

@spec can_ban?(Membership.t(), String.t()) :: :ok | {:error, String.t()}
# New function. Checks: actor rank >= operator
# Error: "Insufficient privileges"

@spec can_set_mode?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
# New function. Checks permission based on mode flag and actor role
# +q/-q: requires :owner
# +h/-h, +o/-o: requires :operator or :owner
# +v/-v: requires :half_operator, :operator, or :owner
# Channel flags: requires :operator or :owner
# Error: "Insufficient privileges to set channel modes"
```

## Channels.Server API Changes

### Modified Functions
```elixir
@spec join(String.t(), String.t(), String.t() | nil, keyword()) ::
  {:ok, map()} | {:error, String.t()}
# New keyword option: identified: boolean() (default: false)
# Passes identified flag through to Policy.can_join?
# Checks join throttle when +j is set

@spec set_mode(String.t(), String.t(), String.t(), [String.t()]) ::
  :ok | {:error, String.t()}
# Now validates per-flag permissions via Policy.can_set_mode?
# Handles +q, +h user modes in addition to +o, +v
# Handles +n, +s, +p, +c, +R, +K, +j channel modes

@spec kick(String.t(), String.t(), String.t(), String.t() | nil) ::
  :ok | {:error, String.t()}
# Now uses Policy.can_kick? with rank-based checks

@spec ban(String.t(), String.t(), String.t(), String.t() | nil) ::
  :ok | {:error, String.t()}
# Now uses Policy.can_ban? with rank-based checks

@spec send_message(String.t(), String.t(), String.t(), atom()) ::
  :ok | {:error, String.t()}
# When +c (strip_colors) is active: strips formatting from content before persist/broadcast
# When +n (no_external) is active: blocks non-member messages

@spec knock(String.t(), String.t(), String.t() | nil) ::
  :ok | {:error, String.t()}
# New function. Validates: channel is +i, not +K, user not banned, not already member
# Broadcasts {:knock, %{nickname, channel, message}} to channel topic
# Errors: "Channel is not invite-only", "Knocking is disabled for this channel",
#         "You are already in that channel", "You are banned from that channel"
```

### New State Field
```elixir
state :: %{
  ...existing...,
  join_timestamps: [DateTime.t()]
}
```

## Commands.Handler Context Changes

### Modified Type
```elixir
@type context :: %{
  nickname: String.t(),
  active_channel: String.t() | nil,
  channels: [String.t()],
  identified: boolean(),
  operator_in: [String.t()],          # Channels where :operator or :owner
  half_operator_in: [String.t()]      # Channels where :half_operator (NEW)
}
```

## New Command Handler: Commands.Handlers.Knock

```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: [channel_name | rest] where rest joined = message
# Returns: {:ok, :ui_action, :knock_channel, %{channel: String.t(), message: String.t() | nil}}
# Errors: "Usage: /knock #channel [message]", "Channel is not invite-only", etc.

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: %{name: String.t(), syntax: String.t(), description: String.t(), examples: [String.t()]}
```
