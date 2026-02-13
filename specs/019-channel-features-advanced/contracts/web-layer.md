# API Contracts: Web Layer

**Feature Branch**: `019-channel-features-advanced`
**Date**: 2026-02-13

## Nicklist Component Changes

### Modified Component: `RetroHexChatWeb.Components.Nicklist`

**New groups** (5 total, ordered top to bottom):
1. Owners (~) — CSS class: `nick-owner`
2. Operators (@) — CSS class: `nick-operator` (existing)
3. Half-Operators (%) — CSS class: `nick-halfop`
4. Voiced (+) — CSS class: `nick-voiced` (existing)
5. Regular — CSS class: `nick-regular` (existing)

**Modified function**:
```elixir
@spec group_users(list(map())) :: %{
  owners: list(map()),
  operators: list(map()),
  half_operators: list(map()),
  voiced: list(map()),
  regular: list(map())
}
```

## PubSub Handler Changes

### ChannelState Handler — Mode Change Handling

**Modified**: `apply_mode_to_users/3` must handle new mode strings:
```elixir
"+q" params → set matched users to role: :owner
"-q" params → set matched users to role: :regular
"+h" params → set matched users to role: :half_operator
"-h" params → set matched users to role: :regular
```

### New PubSub Handler — Knock Events

```elixir
def handle_info({:knock, %{nickname: nick, channel: channel, message: msg}}, socket)
# Display system message only if current user is :operator or :owner in the channel
# Message format: "* #{nick} has knocked on #{channel} (#{msg})"
```

## ChannelListLive Changes

### Modified: `list_active_channels/0` → `list_active_channels/1`

```elixir
@spec list_active_channels(viewer_channels :: [String.t()]) :: [channel_entry()]

@type channel_entry :: %{
  name: String.t(),
  topic: String.t() | nil,
  user_count: non_neg_integer()
}
```

**Filtering logic**:
- Channel with `:secret` mode AND viewer not a member → excluded entirely
- Channel with `:private` mode AND viewer not a member → shown as `%{name: "Prv", topic: nil, user_count: user_count}`
- Channel with `:private` mode AND viewer is a member → shown normally
- All other channels → shown normally

### Mount Change
```elixir
# Must receive viewer's channel list from session
def mount(_params, %{"viewer_channels" => viewer_channels}, socket)
```

## Whois Helper Changes

### Modified: `get_user_channels/1` → `get_user_channels/2`

```elixir
@spec get_user_channels(String.t(), [String.t()]) :: [String.t()]
# New parameter: requester_channels — list of channels the requester is in
# Filters out channels with :secret mode unless requester is also a member
```

## CommandDispatch Changes

### Modified: `channels_where_operator/1`

```elixir
# Returns channels where user is :operator OR :owner
# (Currently only checks :operator via state.operators)
```

### New: `channels_where_half_operator/1`

```elixir
@spec channels_where_half_operator(Session.t()) :: [String.t()]
# Returns channels where user role is :half_operator
```

## UI Action Handlers

### New: `:knock_channel` action

```elixir
def handle_ui_action(socket, :knock_channel, %{channel: channel, message: message})
# Calls Server.knock(channel, nickname, message)
# On :ok → display "Knock sent to #{channel}"
# On {:error, msg} → display error message
# Rate limit check: 60 seconds between knocks per channel (tracked in socket assigns)
```

### Modified: `:set_mode` action

No change to the action itself — `Server.set_mode/4` handles permission checks internally.

### Modified: `:kick_user` action

No change to the action itself — `Server.kick/4` handles rank-based permission checks internally.

### Modified: `:ban_user` action

No change to the action itself — `Server.ban/4` handles rank-based permission checks internally.
