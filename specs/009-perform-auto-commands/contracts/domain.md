# Domain Contracts: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12

## RetroHexChat.Chat.PerformEntry

```elixir
@type t :: %__MODULE__{
  command: String.t(),
  position: non_neg_integer()
}

@spec new(keyword() | map()) :: t()
```

---

## RetroHexChat.Chat.PerformList

```elixir
# In-memory CRUD
@spec new() :: map()
@spec add_entry(map(), String.t()) :: {:ok, map()} | {:error, atom() | String.t()}
@spec remove_entry(map(), non_neg_integer()) :: {:ok, map()} | {:error, :not_found}
@spec move_entry(map(), non_neg_integer(), non_neg_integer()) :: {:ok, map()} | {:error, atom()}
@spec clear(map()) :: {:ok, map()}
@spec entries(map()) :: [PerformEntry.t()]
@spec count(map()) :: non_neg_integer()
@spec full?(map()) :: boolean()
@spec enabled?(map()) :: boolean()
@spec set_enabled(map(), boolean()) :: map()

# Password masking
@spec mask_command(String.t()) :: String.t()

# Validation
@spec disallowed_command?(String.t()) :: boolean()
@spec valid_command?(String.t()) :: boolean()

# Persistence
@spec save(String.t(), map()) :: :ok | {:error, term()}
@spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
```

### Error atoms for `add_entry/2`
- `:list_full` — 50 entries maximum
- `:invalid_command` — does not start with `/`
- `:disallowed_command` — command is `/quit`, `/perform`, `/autojoin`, or `/disconnect`
- `:command_too_long` — exceeds 500 characters

### Error atoms for `move_entry/3`
- `:invalid_position` — from or to position out of range
- `:same_position` — from == to

---

## RetroHexChat.Chat.AutoJoinEntry

```elixir
@type t :: %__MODULE__{
  channel_name: String.t(),
  channel_key: String.t() | nil,
  position: non_neg_integer()
}

@spec new(keyword() | map()) :: t()
```

---

## RetroHexChat.Chat.AutoJoinList

```elixir
# In-memory CRUD
@spec new() :: map()
@spec add_entry(map(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, atom() | String.t()}
@spec remove_entry(map(), String.t()) :: {:ok, map()} | {:error, :not_found}
@spec update_entry(map(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, :not_found}
@spec clear(map()) :: {:ok, map()}
@spec entries(map()) :: [AutoJoinEntry.t()]
@spec count(map()) :: non_neg_integer()
@spec full?(map()) :: boolean()

# Persistence
@spec save(String.t(), map()) :: :ok | {:error, term()}
@spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
```

### Error atoms for `add_entry/3`
- `:list_full` — 20 entries maximum
- `:duplicate` — channel already in list (case-insensitive)
- `:invalid_channel` — does not start with `#` or contains spaces

---

## RetroHexChat.Accounts.Session (Extension)

New fields added to existing struct:

```elixir
# New fields
perform_list: map()    # PerformList data, default: PerformList.new()
autojoin_list: map()   # AutoJoinList data, default: AutoJoinList.new()

# New functions
@spec set_perform_list(t(), map()) :: t()
@spec set_autojoin_list(t(), map()) :: t()
```

---

## RetroHexChat.Commands.Handlers.Perform

```elixir
@behaviour RetroHexChat.Commands.Handler

# validate/1 patterns:
# ""                    → :ok (bare /perform opens dialog)
# "list"                → :ok
# "add <command>"       → :ok (validates command not empty)
# "add"                 → {:error, "Usage: /perform add <command>"}
# "remove <number>"     → :ok
# "remove"              → {:error, "Usage: /perform remove <number>"}
# "move <from> <to>"    → :ok
# "move"                → {:error, "Usage: /perform move <from> <to>"}
# "clear"               → :ok
# other                 → {:error, "Unknown subcommand..."}

# execute/2 results:
# []                    → {:ok, :ui_action, :open_perform_dialog, %{}}
# ["list"]              → {:ok, :ui_action, :perform_list_display, %{}}
# ["add" | command]     → {:ok, :ui_action, :perform_add, %{command: joined_command}}
# ["remove", n]         → {:ok, :ui_action, :perform_remove, %{position: parsed_int}}
# ["move", from, to]    → {:ok, :ui_action, :perform_move, %{from: int, to: int}}
# ["clear"]             → {:ok, :ui_action, :perform_clear, %{}}
```

---

## RetroHexChat.Commands.Handlers.AutoJoin

```elixir
@behaviour RetroHexChat.Commands.Handler

# validate/1 patterns:
# ""                           → :ok (bare /autojoin lists channels)
# "list"                       → :ok
# "add #channel [key]"         → :ok
# "add"                        → {:error, "Usage: /autojoin add #channel [key]"}
# "remove #channel"            → :ok
# "remove"                     → {:error, "Usage: /autojoin remove #channel"}
# "clear"                      → :ok
# other                        → {:error, "Unknown subcommand..."}

# execute/2 results:
# []                           → {:ok, :ui_action, :autojoin_list_display, %{}}
# ["list"]                     → {:ok, :ui_action, :autojoin_list_display, %{}}
# ["add", channel]             → {:ok, :ui_action, :autojoin_add, %{channel: ch, key: nil}}
# ["add", channel, key]        → {:ok, :ui_action, :autojoin_add, %{channel: ch, key: key}}
# ["remove", channel]          → {:ok, :ui_action, :autojoin_remove, %{channel: ch}}
# ["clear"]                    → {:ok, :ui_action, :autojoin_clear, %{}}
```

---

## RetroHexChat.Chat.Schemas.PerformListEntry (Ecto)

```elixir
schema "perform_entries" do
  field :owner_nickname, :string
  field :command, :string
  field :position, :integer
  timestamps(type: :utc_datetime_usec)
end

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```

---

## RetroHexChat.Chat.Schemas.AutoJoinListEntry (Ecto)

```elixir
schema "autojoin_entries" do
  field :owner_nickname, :string
  field :channel_name, :string
  field :channel_key, :string
  field :position, :integer
  timestamps(type: :utc_datetime_usec)
end

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```

---

## RetroHexChat.Chat.Schemas.PerformSettings (Ecto)

```elixir
@primary_key {:owner_nickname, :string, autogenerate: false}
schema "perform_settings" do
  field :enable_on_connect, :boolean, default: true
  timestamps(type: :utc_datetime_usec)
end

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```
