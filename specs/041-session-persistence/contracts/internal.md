# Internal API Contracts: Session Persistence

This feature has no external APIs. All contracts are internal Elixir module functions.

## Domain Layer (retro_hex_chat)

### Chat.Queries

```elixir
@spec list_pm_partners(String.t(), keyword()) :: [%{nickname: String.t(), last_message_at: DateTime.t()}]
def list_pm_partners(nickname, opts \\ [])
```

Returns distinct PM conversation partners for the given nickname, ordered by most recent message timestamp descending. Excludes self-PMs and soft-deleted messages.

**Options**:
- `:limit` — max partners to return (default: 50)

**Returns**: List of maps with `:nickname` and `:last_message_at` keys.

## Domain Layer — Session Modifications

### Accounts.Session

```elixir
@spec add_pm_conversation(t(), String.t()) :: t()
def add_pm_conversation(session, nickname)
```

**Changed behavior**: Prepends `nickname` to head of `pm_conversations` list. If already present, moves to head. Previously appended to end.

```elixir
@spec move_pm_to_front(t(), String.t()) :: t()
def move_pm_to_front(session, nickname)
```

**New function**: Moves `nickname` to head of `pm_conversations` if present. No-op if not found.

## Web Layer (retro_hex_chat_web)

### Helpers.Persistence

```elixir
@spec restore_pm_conversations(Session.t(), String.t()) :: Session.t()
def restore_pm_conversations(session, nickname)
```

**New function**: Queries `Queries.list_pm_partners/2`, filters out self-nick, sets `pm_conversations` on session. Called from `load_persisted_data/2`.

### PubsubHandlers.Messages — apply_new_pm/3

**Changed behavior**: Before processing unread/sound/notification, checks if the sender nick is in `pm_conversations`. If not, and if not ignored (`:pm` type), calls `Session.add_pm_conversation/2` to auto-add. This makes the conversation appear in the treebar instantly.

### CommandDispatch — handle_dispatch_result/2

**Changed behavior for `:join`**: After successful join, if the user is identified and the channel is not `#lobby`, calls `AutoJoinList.add_entry/3` on the session's auto-join list. If the list is full, emits a system message. Persists async.

**Changed behavior for `:part`**: After successful part, if the user is identified, calls `AutoJoinList.remove_entry/2` on the session's auto-join list. Persists async.

## PubSub Topics

No new PubSub topics. Existing topics used:
- `"pm:#{sorted(nick_a, nick_b)}"` — PM message delivery (existing)
- `"user:#{nickname}"` — User-scoped events (existing)
