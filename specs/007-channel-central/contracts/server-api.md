# Contract: Channel Server API Extensions

**Feature**: 007-channel-central
**Module**: `RetroHexChat.Channels.Server`

## New Public Functions

### add_ban_exception/3

```elixir
@spec add_ban_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
def add_ban_exception(channel_name, nickname, operator_nick)
```

**Preconditions**: Caller must be an operator of the channel.
**Postconditions**: Nickname added to ban exceptions MapSet. If registered channel, persisted to DB. Broadcast `{:ban_exception_added, %{channel: channel_name, nickname: nickname, added_by: operator_nick}}`.
**Idempotent**: Adding an existing exception is a no-op (returns `:ok`).

### remove_ban_exception/3

```elixir
@spec remove_ban_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
def remove_ban_exception(channel_name, nickname, operator_nick)
```

**Preconditions**: Caller must be an operator of the channel.
**Postconditions**: Nickname removed from ban exceptions MapSet. If registered channel, removed from DB. Broadcast `{:ban_exception_removed, %{channel: channel_name, nickname: nickname, removed_by: operator_nick}}`.
**Idempotent**: Removing a non-existent exception is a no-op (returns `:ok`).

### add_invite_exception/3

```elixir
@spec add_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
def add_invite_exception(channel_name, nickname, operator_nick)
```

**Preconditions**: Caller must be an operator of the channel.
**Postconditions**: Nickname added to invite exceptions MapSet. If registered channel, persisted to DB. Broadcast `{:invite_exception_added, %{channel: channel_name, nickname: nickname, added_by: operator_nick}}`.
**Idempotent**: Adding an existing exception is a no-op (returns `:ok`).

### remove_invite_exception/3

```elixir
@spec remove_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
def remove_invite_exception(channel_name, nickname, operator_nick)
```

**Preconditions**: Caller must be an operator of the channel.
**Postconditions**: Nickname removed from invite exceptions MapSet. If registered channel, removed from DB. Broadcast `{:invite_exception_removed, %{channel: channel_name, nickname: nickname, removed_by: operator_nick}}`.
**Idempotent**: Removing a non-existent exception is a no-op (returns `:ok`).

## Extended Functions

### get_state/1 (extended return)

```elixir
@spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
```

**New fields in return map**:
```elixir
%{
  # ... existing fields ...
  topic_set_by: String.t() | nil,
  topic_set_at: DateTime.t() | nil,
  modes_detail: %{
    moderated: boolean(),
    invite_only: boolean(),
    topic_lock: boolean(),
    key: String.t() | nil,
    limit: non_neg_integer() | nil
  },
  ban_exceptions: [String.t()],
  invite_exceptions: [String.t()]
}
```

### set_topic/3 (extended behavior)

Now stores `topic_set_by` and `topic_set_at` alongside the topic string.

**Broadcast payload extended**:
```elixir
{:topic_changed, %{
  channel: channel_name,
  nickname: nickname,
  topic: topic,
  set_at: DateTime.t()   # NEW
}}
```

## Broadcast Events (New)

| Event | Payload | Topic |
|-------|---------|-------|
| `{:ban_exception_added, payload}` | `%{channel: str, nickname: str, added_by: str}` | `"channel:#{name}"` |
| `{:ban_exception_removed, payload}` | `%{channel: str, nickname: str, removed_by: str}` | `"channel:#{name}"` |
| `{:invite_exception_added, payload}` | `%{channel: str, nickname: str, added_by: str}` | `"channel:#{name}"` |
| `{:invite_exception_removed, payload}` | `%{channel: str, nickname: str, removed_by: str}` | `"channel:#{name}"` |
