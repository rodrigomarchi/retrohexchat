# Data Model: Channel Features Advanced

**Feature Branch**: `019-channel-features-advanced`
**Date**: 2026-02-13

## Entity Changes

### 1. Channel Role (Modified — `Channels.Membership`)

**Current**:
```
role :: :operator | :voiced | :regular
```

**New**:
```
role :: :owner | :operator | :half_operator | :voiced | :regular

rank mapping:
  :owner         → 4
  :operator      → 3
  :half_operator → 2
  :voiced        → 1
  :regular       → 0
```

**Impact**: All code referencing `Membership.role()` type must handle new atoms. The `member_info` map structure (`%{role: role(), joined_at: DateTime.t()}`) is unchanged.

### 2. Channel Modes (Modified — `Channels.Modes`)

**Current struct**:
```
%Modes{
  flags: MapSet.t(),        # :moderated, :invite_only, :topic_lock
  key: String.t() | nil,
  limit: non_neg_integer() | nil
}
```

**New struct**:
```
%Modes{
  flags: MapSet.t(),        # :moderated, :invite_only, :topic_lock,
                            # :no_external, :secret, :private,
                            # :strip_colors, :registered_only, :no_knock
  key: String.t() | nil,
  limit: non_neg_integer() | nil,
  join_throttle: {pos_integer(), pos_integer()} | nil   # {count, seconds}
}
```

**New flag → character mapping**:
```
"n" → :no_external
"s" → :secret
"p" → :private
"c" → :strip_colors
"R" → :registered_only
"K" → :no_knock
"j" → (parameterized, stored in join_throttle)
```

**Validation rules**:
- `:secret` and `:private` are mutually exclusive — `apply_changes/3` returns `{:error, "+s and +p are mutually exclusive"}` if both would be active
- `join_throttle` format: `{count, seconds}` where both are positive integers, parsed from "count:seconds" parameter string
- Invalid `+j` parameter returns `{:error, "Invalid join throttle format. Use +j count:seconds (e.g., +j 5:10)"}`

### 3. Channel Server State (Modified — `Channels.Server`)

**Current state**:
```
%{
  name, topic, topic_set_by, topic_set_at,
  membership, modes, bans, ban_exceptions,
  invite_exceptions, registered, created_at
}
```

**New fields added**:
```
join_timestamps: [DateTime.t()]    # Sliding window for +j throttle
```

**Modified behavior**:
- `determine_join_role/2`: First joiner of unregistered channel → `:owner` (was `:operator`)
- `join/3` or `join/4`: Accepts `identified: boolean()` parameter for +R check
- `send_message/4`: Strips formatting codes when `:strip_colors` mode active
- `kick/4`: Rank-based permission check (not just operator?)
- `ban/4`: Rank-based permission check
- `set_mode/4`: Rank-based permission check with half-op restrictions

### 4. Channel Server State Map (Modified — `state_to_map/1`)

**New fields in returned map**:
```
%{
  ...existing fields...,
  owners: [String.t()],            # List of owner nicknames
  half_operators: [String.t()],    # List of half-op nicknames
  modes_detail: %{
    ...existing fields...,
    no_external: boolean(),
    secret: boolean(),
    private: boolean(),
    strip_colors: boolean(),
    registered_only: boolean(),
    no_knock: boolean(),
    join_throttle: {pos_integer(), pos_integer()} | nil
  }
}
```

### 5. Handler Context (Modified — `Commands.Handler`)

**Current**:
```
%{
  nickname, active_channel, channels,
  identified, operator_in
}
```

**New**:
```
%{
  nickname, active_channel, channels,
  identified,
  operator_in: [String.t()],        # Channels where user is operator OR owner
  half_operator_in: [String.t()]    # Channels where user is half-operator
}
```

### 6. User Mode Flags (Modified — `Server.apply_user_modes/3`)

**Current user mode characters**: `o`, `v`
**New user mode characters**: `q`, `h`

```
+q nick → set role to :owner    (requires actor to be :owner)
-q nick → set role to :regular  (requires actor to be :owner)
+h nick → set role to :half_operator (requires actor to be :operator or :owner)
-h nick → set role to :regular      (requires actor to be :operator or :owner)
+o nick → set role to :operator     (requires actor to be :operator or :owner)
-o nick → set role to :regular      (requires actor to be :operator or :owner)
+v nick → set role to :voiced       (requires actor to be :half_operator, :operator, or :owner)
-v nick → set role to :regular      (requires actor to be :half_operator, :operator, or :owner)
```

## Database Changes

### Migration: Alter `registered_channels` table

```sql
ALTER TABLE registered_channels
  ADD COLUMN mode_join_throttle VARCHAR(20);  -- stores "count:seconds" e.g. "5:10"
```

**No other table changes needed**. The `modes` varchar column already accommodates new flag characters (e.g., "+imnscRK"). The new flag characters are simply additional characters in the existing string.

## PubSub Events (New)

### Knock Event
```
Topic: "channel:#{channel_name}"
Event: {:knock, %{
  nickname: String.t(),
  channel: String.t(),
  message: String.t() | nil
}}
```

Delivered to all subscribers; PubSub handler in ChatLive filters display to operators and owners only.

## Knock Rate Limiting

Tracked in LiveView socket assigns (same pattern as CTCP rate limiting):
```
knock_timestamps: %{String.t() => DateTime.t()}   # channel_name → last_knock_at
```

One knock per 60 seconds per channel per user. Checked in the `/knock` command handler.
