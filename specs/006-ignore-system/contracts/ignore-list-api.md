# IgnoreList API Contract

## Module: `RetroHexChat.Chat.IgnoreList`

### In-Memory CRUD

```elixir
@spec new() :: map()
# Returns %{entries: []}

@spec add_entry(map(), String.t(), atom(), DateTime.t() | nil) :: {:ok, map()} | {:error, atom()}
# add_entry(list, nickname, ignore_type, expires_at)
# Errors: :list_full, :invalid_type
# If nickname already exists: updates the entry (upsert behavior)

@spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
# Case-insensitive nickname matching

@spec ignored?(map(), String.t(), atom()) :: boolean()
# ignored?(list, nickname, message_type)
# message_type: :message | :pm | :action | :invite
# Returns true if nickname has an ignore entry matching the message_type
# Matching: :all matches everything; specific types match their own kind

@spec get_entry(map(), String.t()) :: IgnoreEntry.t() | nil
# Case-insensitive nickname lookup

@spec update_nickname(map(), String.t(), String.t()) :: map()
# Updates the nickname field for all entries matching old_nick (case-insensitive)

@spec sorted_entries(map()) :: [IgnoreEntry.t()]
# Returns entries sorted alphabetically by nickname (case-insensitive)

@spec count(map()) :: non_neg_integer()

@spec full?(map()) :: boolean()
# count >= @max_entries (100)

@spec remove_expired(map()) :: {map(), [String.t()]}
# Removes entries where expires_at < now
# Returns {updated_list, list_of_expired_nicknames}
```

### Persistence

```elixir
@spec save(String.t(), map()) :: :ok | {:error, term()}
# Bulk save in transaction: delete all for owner, reinsert current entries

@spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
# Load from DB, filter out expired entries, convert to in-memory format
```

### Type Matching Matrix

| IgnoreEntry.ignore_type | Matches :message | Matches :pm | Matches :action | Matches :invite |
|------------------------|-----------------|------------|-----------------|----------------|
| `:all` | Yes | Yes | Yes | Yes |
| `:messages` | Yes | No | No | No |
| `:pms` | No | Yes | No | No |
| `:actions` | No | No | Yes | No |
| `:invites` | No | No | No | Yes |

## Module: `RetroHexChat.Chat.IgnoreEntry`

```elixir
@type t :: %__MODULE__{
  nickname: String.t(),
  ignore_type: :all | :messages | :pms | :invites | :actions,
  expires_at: DateTime.t() | nil,
  created_at: DateTime.t()
}

@spec new(keyword() | map()) :: t()

@spec expired?(t()) :: boolean()
# true if expires_at is non-nil and < DateTime.utc_now()

@spec permanent?(t()) :: boolean()
# true if expires_at is nil

@spec remaining_seconds(t()) :: non_neg_integer()
# 0 if permanent or expired; otherwise DateTime.diff(expires_at, now)

@valid_types [:all, :messages, :pms, :invites, :actions]

@spec valid_type?(atom()) :: boolean()
```

## Module: `RetroHexChat.Chat.Schemas.IgnoreListEntry`

```elixir
# Ecto schema for ignore_list_entries table
# Fields: owner_nickname, ignored_nickname, ignore_type (string), expires_at

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```
