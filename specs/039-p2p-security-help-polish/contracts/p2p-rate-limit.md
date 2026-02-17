# Contract: P2P Rate Limiting

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## Module: `RetroHexChat.P2P.RateLimiter`

New module implementing sliding-window rate limiting for P2P operations.

### Public API

```elixir
@spec check_session_rate(integer()) :: :ok | {:error, {:rate_limited, remaining_seconds :: pos_integer()}}
def check_session_rate(user_id)

@spec init_table() :: :ets.tid()
def init_table()
```

### Behaviour: `RetroHexChat.P2P.SignalingRateLimit` (Existing)

```elixir
# New implementation module: RetroHexChat.P2P.SignalingRateLimit.ETS
@behaviour RetroHexChat.P2P.SignalingRateLimit

@impl true
@spec check_signal_rate(String.t(), integer()) :: :ok | {:error, :rate_limited}
def check_signal_rate(session_token, user_id)
```

## Integration Points

### Session Creation (P2P.Service.create_session/3)

```elixir
# Before policy check:
with :ok <- RateLimiter.check_session_rate(creator_id),
     :ok <- Policy.can_create?(creator_id, peer_id),
     ...
```

### Signaling (P2PSessionLive.handle_event("p2p_signal", ...))

Already wired — just replace Noop with ETS implementation via application config.

## Rate Limits

| Operation | Limit | Window | On Exceed |
|-----------|-------|--------|-----------|
| Session creation | 5 | 10 minutes | Error with remaining time |
| Signaling messages | 100 | 1 minute | Silent drop |
