# Data Model: Ignore System

**Feature**: 006-ignore-system
**Date**: 2026-02-11

## Entities

### IgnoreEntry (In-Memory Runtime Struct)

Lightweight struct for session state. No Ecto dependency.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `nickname` | `String.t()` | Yes | Case-preserved nickname of ignored user |
| `ignore_type` | `atom()` | Yes | One of: `:all`, `:messages`, `:pms`, `:invites`, `:actions` |
| `expires_at` | `DateTime.t() \| nil` | No | Expiry timestamp; `nil` = permanent |
| `created_at` | `DateTime.t()` | Yes | When the ignore was added |

**Enforce keys**: `[:nickname, :ignore_type, :created_at]`

**Constructor**: `IgnoreEntry.new/1` accepts keyword list or map.

**Derived functions**:
- `expired?/1` — true if `expires_at` is non-nil and in the past
- `permanent?/1` — true if `expires_at` is nil
- `remaining_seconds/1` — seconds until expiry (0 if permanent or expired)

### IgnoreList (In-Memory Collection)

Map-based container for ignore entries. Follows NotifyList pattern.

| Field | Type | Description |
|-------|------|-------------|
| `entries` | `[IgnoreEntry.t()]` | List of active ignore entries |

**Max entries**: 100

**API functions**:

| Function | Signature | Returns |
|----------|-----------|---------|
| `new/0` | `() -> map()` | `%{entries: []}` |
| `add_entry/4` | `(list, nickname, ignore_type, expires_at)` | `{:ok, list} \| {:error, atom}` |
| `remove_entry/2` | `(list, nickname)` | `{:ok, list} \| {:error, :not_found}` |
| `ignored?/3` | `(list, nickname, message_type)` | `boolean()` |
| `get_entry/2` | `(list, nickname)` | `IgnoreEntry.t() \| nil` |
| `update_nickname/3` | `(list, old_nick, new_nick)` | `list` |
| `sorted_entries/1` | `(list)` | `[IgnoreEntry.t()]` |
| `count/1` | `(list)` | `non_neg_integer()` |
| `full?/1` | `(list)` | `boolean()` |
| `remove_expired/1` | `(list)` | `{list, [String.t()]}` (updated list + expired nicknames) |

**Error atoms**: `:self_ignore`, `:list_full`, `:not_found`, `:invalid_type`, `:invalid_duration`

**Persistence functions** (same module, Ecto-dependent):

| Function | Signature | Returns |
|----------|-----------|---------|
| `save/2` | `(owner_nick, list)` | `:ok \| {:error, term}` |
| `load/1` | `(owner_nick)` | `{:ok, list} \| {:error, :not_found}` |

### IgnoreListEntry (Ecto Schema — Database Persistence)

Maps to `ignore_list_entries` PostgreSQL table.

| Column | DB Type | Elixir Type | Constraints |
|--------|---------|-------------|-------------|
| `id` | `bigint` (auto) | `integer()` | PK |
| `owner_nickname` | `varchar(16)` | `String.t()` | FK → `registered_nicks.nickname`, NOT NULL, ON DELETE CASCADE |
| `ignored_nickname` | `varchar(16)` | `String.t()` | NOT NULL |
| `ignore_type` | `varchar(10)` | `String.t()` | NOT NULL, one of: "all", "messages", "pms", "invites", "actions" |
| `expires_at` | `timestamptz` | `DateTime.t() \| nil` | Nullable; nil = permanent |
| `inserted_at` | `timestamptz` | `DateTime.t()` | Auto |
| `updated_at` | `timestamptz` | `DateTime.t()` | Auto |

**Indexes**:
- Unique: `lower(owner_nickname), lower(ignored_nickname)` — one ignore per target per owner
- Lookup: `owner_nickname` — fast load by owner

**Changeset validations**:
- `validate_required([:owner_nickname, :ignored_nickname, :ignore_type])`
- `validate_length(:owner_nickname, max: 16)`
- `validate_length(:ignored_nickname, max: 16)`
- `validate_inclusion(:ignore_type, ["all", "messages", "pms", "invites", "actions"])`

## Migration

```sql
CREATE TABLE ignore_list_entries (
  id BIGSERIAL PRIMARY KEY,
  owner_nickname VARCHAR(16) NOT NULL
    REFERENCES registered_nicks(nickname) ON DELETE CASCADE,
  ignored_nickname VARCHAR(16) NOT NULL,
  ignore_type VARCHAR(10) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE UNIQUE INDEX idx_ignore_list_entries_owner_ignored
  ON ignore_list_entries (LOWER(owner_nickname), LOWER(ignored_nickname));

CREATE INDEX idx_ignore_list_entries_owner
  ON ignore_list_entries (owner_nickname);
```

## State Diagram: Ignore Entry Lifecycle

```
                    /ignore nick
                        │
                        ▼
              ┌─────────────────┐
              │     Active      │
              │  (permanent or  │
              │    timed)       │
              └────────┬────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    /unignore     timer expires   /ignore nick
    (manual)      (auto-remove)   (update entry)
         │             │             │
         ▼             ▼             ▼
    ┌─────────┐  ┌──────────┐  ┌─────────────┐
    │ Removed │  │ Expired  │  │  Updated    │
    │         │  │ (removed │  │ (new type/  │
    │         │  │  + msg)  │  │  duration)  │
    └─────────┘  └──────────┘  └─────────────┘
```

## Session Extension

Add to `RetroHexChat.Accounts.Session`:

| Field | Type | Default | Getter/Setter |
|-------|------|---------|---------------|
| `ignore_list` | `map()` | `IgnoreList.new()` | `get_ignore_list/1`, `set_ignore_list/2` |

## Socket Assigns (ChatLive)

| Assign | Type | Description |
|--------|------|-------------|
| `ignore_timers` | `%{String.t() => reference()}` | Map of downcased nickname → timer ref |
| `show_ignore_dialog` | `boolean()` | Whether IgnoreListDialog is visible |
| `ignore_selected` | `String.t() \| nil` | Currently selected nickname in dialog |
| `show_ignore_add_dialog` | `boolean()` | Whether the Add sub-dialog is visible |
