# API Contract: Presence.NotifyList Context

**Feature**: 002-notify-list
**Date**: 2026-02-11

## Module: `RetroHexChat.Presence.NotifyList`

Pure domain module. Zero Phoenix/web dependencies. All functions are @spec annotated.

### Types

```elixir
@type entry :: %{
  tracked_nickname: String.t(),
  note: String.t() | nil,
  last_seen_at: DateTime.t() | nil,
  online: boolean()
}

@type settings :: %{
  auto_whois: boolean()
}

@type notify_list :: %{
  entries: [entry()],
  settings: settings()
}
```

### CRUD Operations (in-memory)

```elixir
@spec new() :: notify_list()
# Returns empty notify list with default settings.

@spec add_entry(notify_list(), String.t(), String.t(), String.t() | nil) ::
  {:ok, notify_list()} | {:error, :self_add | :duplicate | :list_full}
# Adds a buddy. owner_nickname is the caller's nick (for self-add check).
# nickname is case-insensitive matched against existing entries.
# Returns :self_add if nickname matches owner_nickname (case-insensitive).
# Returns :duplicate if already in list (case-insensitive).
# Returns :list_full if 50 entries reached.

@spec remove_entry(notify_list(), String.t()) ::
  {:ok, notify_list()} | {:error, :not_found}
# Removes a buddy by nickname (case-insensitive).

@spec update_note(notify_list(), String.t(), String.t()) ::
  {:ok, notify_list()} | {:error, :not_found}
# Updates the note for an existing entry. Note max 200 chars (truncated).

@spec update_nickname(notify_list(), String.t(), String.t()) :: notify_list()
# Renames a tracked buddy in the list. If old_nick not found, returns unchanged.

@spec set_online(notify_list(), String.t(), boolean()) :: notify_list()
# Sets the online status for a buddy. Updates last_seen_at when going offline.

@spec set_auto_whois(notify_list(), boolean()) :: notify_list()
# Toggles the global auto-whois setting.

@spec tracking?(notify_list(), String.t()) :: boolean()
# Returns true if nickname is in the list (case-insensitive).

@spec online_buddies(notify_list()) :: [entry()]
# Returns entries where online == true, sorted alphabetically.

@spec offline_buddies(notify_list()) :: [entry()]
# Returns entries where online == false, sorted alphabetically.

@spec sorted_entries(notify_list()) :: [entry()]
# Returns all entries sorted: online first (alphabetical), then offline (alphabetical).

@spec count(notify_list()) :: non_neg_integer()
# Returns total number of entries.

@spec full?(notify_list()) :: boolean()
# Returns true if count >= 50.
```

### Persistence Operations (database)

```elixir
@spec save(String.t(), notify_list()) :: :ok | {:error, term()}
# Persists the entire notify list for a registered user (owner_nickname).
# Upserts entries + settings. Deletes entries removed from the list.

@spec load(String.t()) :: {:ok, notify_list()} | {:error, :not_found}
# Loads the notify list for a registered user from the database.
# Returns entries with online: false (status computed at runtime).

@spec save_entry(String.t(), entry()) :: :ok | {:error, term()}
# Persists a single entry change (add/update). For incremental saves.

@spec delete_entry(String.t(), String.t()) :: :ok
# Deletes a single entry by owner + tracked_nickname.

@spec save_settings(String.t(), settings()) :: :ok | {:error, term()}
# Persists settings for a registered user.
```

### Whois Data (read-only aggregation)

```elixir
@spec whois_info(String.t()) :: {:ok, map()} | {:error, :not_found}
# Gathers whois information for a nickname.
# Returns: %{
#   nickname: String.t(),
#   registered: boolean(),
#   identified: boolean(),
#   channels: [String.t()],
#   away: boolean(),
#   away_message: String.t() | nil,
#   idle_seconds: non_neg_integer() | nil
# }
```

## Module: `RetroHexChat.Commands.Handlers.Notify`

Implements `RetroHexChat.Commands.Handler` behaviour.

### Commands

| Command | validate/1 input | execute/2 result |
|---------|-----------------|------------------|
| `/notify` | `""` | `{:ok, :ui_action, :open_notify_list, %{}}` |
| `/notify add <nick> [note]` | `"add <nick> [note]"` | `{:ok, :system, %{content: "Added..."}}` or `{:error, msg}` |
| `/notify remove <nick>` | `"remove <nick>"` | `{:ok, :system, %{content: "Removed..."}}` or `{:error, msg}` |
| `/notify edit <nick> <note>` | `"edit <nick> <note>"` | `{:ok, :system, %{content: "Updated..."}}` or `{:error, msg}` |
| `/notify list` | `"list"` | `{:ok, :ui_action, :notify_list_display, %{}}` |

### Validation Rules

- `add`: requires at least 1 arg (nickname). Note is optional, rest of args joined.
- `remove`: requires exactly 1 arg (nickname).
- `edit`: requires at least 2 args (nickname + note). Rest of args joined as note.
- `list`: no args.
- Unknown subcommand: `{:error, "Unknown /notify subcommand. Use: add, remove, edit, list"}`.

## PubSub Events

### New Topic: `"presence:global"`

| Event | Payload | Emitted by | Consumed by |
|-------|---------|-----------|-------------|
| `{:user_connected, %{nickname: String.t()}}` | Nickname of connecting user | ChatLive on mount | ChatLive (notify list filter) |
| `{:user_disconnected, %{nickname: String.t()}}` | Nickname of disconnecting user | ChatLive on terminate | ChatLive (notify list filter) |

### Existing Topic: `"user:#{nickname}"`

| Event | Payload | Emitted by | Consumed by |
|-------|---------|-----------|-------------|
| `{:nickserv_identified, %{nickname: String.t()}}` | NEW | NickServ on identify | ChatLive (load notify list) |

### Existing Channel Topics (no changes)

| Event | Payload | Notes |
|-------|---------|-------|
| `{:nick_changed, %{old: String.t(), new: String.t()}}` | Already exists | ChatLive extends handler to update notify list entries |
