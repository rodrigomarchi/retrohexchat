# Data Model: Favorites / Bookmarks

## Entities

### FavoriteEntry (in-memory struct)

Represents a single favorite channel in the user's favorites list.

| Field         | Type            | Required | Default | Description                                      |
|---------------|-----------------|----------|---------|--------------------------------------------------|
| channel_name  | string          | yes      | —       | Channel name including `#` prefix                |
| description   | string          | no       | `""`    | User-provided description of the channel         |
| password      | string          | no       | `nil`   | Channel key for +k channels (plain text in memory, encrypted at rest) |
| auto_join     | boolean         | yes      | `false` | Whether to auto-join this channel on connect     |
| position      | integer         | yes      | `0`     | Display order (0-based, ascending)               |

**Identity**: Unique by `channel_name` (case-insensitive) within a user's favorites list.

### Favorites (in-memory container)

Holds the user's complete favorites list.

| Field   | Type                | Description                          |
|---------|---------------------|--------------------------------------|
| entries | list(FavoriteEntry) | Ordered list of favorite entries     |

**API**:
- `new/0` — Returns empty favorites (`%{entries: []}`)
- `entries/1` — Returns the list of entries
- `add_entry/2` — Adds entry at end, returns `{:ok, favorites}` or `{:error, :duplicate}`
- `update_entry/3` — Updates entry by channel_name, returns `{:ok, favorites}` or `{:error, :not_found}`
- `remove_entry/2` — Removes entry by channel_name
- `move_up/2` — Moves entry up by channel_name
- `move_down/2` — Moves entry down by channel_name
- `find_entry/2` — Finds entry by channel_name (case-insensitive)
- `has_entry?/2` — Checks if channel_name exists in favorites
- `auto_join_entries/1` — Returns only entries with `auto_join: true`
- `save/2` — Persists to database for registered user
- `load/1` — Loads from database for registered user

## Database Schema

### Table: `favorites`

| Column         | Type                    | Nullable | Default | Notes                                            |
|----------------|-------------------------|----------|---------|--------------------------------------------------|
| id             | bigint (auto-increment) | no       | —       | Primary key                                      |
| owner_nickname | string(16)              | no       | —       | FK → registered_nicks.nickname, on_delete: delete_all |
| channel_name   | string(50)              | no       | —       | Channel name with `#` prefix                     |
| description    | string(200)             | yes      | `""`    | User description                                 |
| encrypted_password | text                | yes      | `nil`   | AES-GCM encrypted channel key (via Plug.Crypto.MessageEncryptor) |
| auto_join      | boolean                 | no       | `false` | Auto-join on connect flag                        |
| position       | integer                 | no       | `0`     | Display order                                    |
| inserted_at    | utc_datetime_usec       | no       | —       | Created timestamp                                |
| updated_at     | utc_datetime_usec       | no       | —       | Updated timestamp                                |

**Indexes**:
- `index(:favorites, [:owner_nickname])` — Fast lookup by user
- `unique_index(:favorites, ["lower(owner_nickname)", "lower(channel_name)"])` — Prevent duplicates (case-insensitive)

## Password Encryption

### Module: PasswordEncryption

Utility module for reversible encryption of channel passwords using AES-GCM.

**API**:
- `encrypt/1` — Encrypts a plain text password, returns encrypted string
- `decrypt/1` — Decrypts an encrypted password, returns `{:ok, plain}` or `:error`

**Implementation notes**:
- Uses `Plug.Crypto.MessageEncryptor` (already available as transitive dep)
- Derives encryption and signing keys from `secret_key_base` using `Plug.Crypto.KeyGenerator`
- Salt values: `"favorites_password_encryption"` (encrypt) and `"favorites_password_signing"` (sign)
- Key length: 32 bytes (AES-256)

## Session Integration

Add `favorites` field to `RetroHexChat.Accounts.Session`:

| Field     | Type | Default           | Description               |
|-----------|------|-------------------|---------------------------|
| favorites | map  | `Favorites.new()` | User's favorites list     |

Getter/setter: `get_favorites/1`, `set_favorites/2`

## State Transitions

```
Empty → Add entry → Non-empty
Non-empty → Add entry → Non-empty (reject if duplicate)
Non-empty → Remove entry → Empty or Non-empty
Non-empty → Reorder (move up/down) → Non-empty
Non-empty → Edit entry → Non-empty
Non-empty → Save → Persisted (registered users only)
Connect → Load → Favorites restored (registered users only)
Connect → Auto-join → Channels joined for auto_join entries
```
