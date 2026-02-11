# Data Model: Address Book (003)

**Date**: 2026-02-11
**Branch**: `003-address-book`

## New Entities

### Contact (in-memory runtime struct)

**Module**: `RetroHexChat.Accounts.Contact`
**Pattern**: Mirrors `RetroHexChat.Presence.NotifyEntry`

| Field              | Type               | Constraints            | Notes                        |
|--------------------|--------------------|------------------------|------------------------------|
| contact_nickname   | String.t()         | required, max 16 chars | Case-insensitive matching    |
| note               | String.t() \| nil  | max 200 chars          | Optional personal note       |
| first_contact_date | DateTime.t()       | required               | Set on creation, immutable   |

- `@enforce_keys [:contact_nickname, :first_contact_date]`
- `new/1` accepts keyword/map with defaults: `note: nil, first_contact_date: DateTime.utc_now()`

### ContactEntry (Ecto schema for persistence)

**Module**: `RetroHexChat.Accounts.ContactEntry`
**Table**: `contacts`

| Column           | DB Type              | Constraints                                      |
|------------------|----------------------|--------------------------------------------------|
| id               | bigserial            | PK (auto)                                        |
| owner_nickname   | varchar(16)          | FK → registered_nicks(nickname), ON DELETE CASCADE |
| contact_nickname | varchar(16)          | NOT NULL                                         |
| note             | varchar(200)         | nullable                                         |
| first_contact_date | utc_datetime_usec  | NOT NULL                                         |
| inserted_at      | utc_datetime_usec    | auto                                             |
| updated_at       | utc_datetime_usec    | auto                                             |

**Indexes**:
- `UNIQUE idx_contacts_owner_contact ON (lower(owner_nickname), lower(contact_nickname))`
- `idx_contacts_owner ON (owner_nickname)`

### NickColor (in-memory runtime struct)

**Module**: `RetroHexChat.Accounts.NickColor`

| Field            | Type               | Constraints                 | Notes                    |
|------------------|--------------------|-----------------------------|--------------------------|
| target_nickname  | String.t()         | required, max 16 chars      | Case-insensitive matching |
| color_index      | non_neg_integer()  | required, 0..15             | IRC color palette index   |

- `@enforce_keys [:target_nickname, :color_index]`
- `new/1` accepts keyword/map

### NickColorEntry (Ecto schema for persistence)

**Module**: `RetroHexChat.Accounts.NickColorEntry`
**Table**: `nick_color_overrides`

| Column          | DB Type              | Constraints                                      |
|-----------------|----------------------|--------------------------------------------------|
| id              | bigserial            | PK (auto)                                        |
| owner_nickname  | varchar(16)          | FK → registered_nicks(nickname), ON DELETE CASCADE |
| target_nickname | varchar(16)          | NOT NULL                                         |
| color_index     | integer              | NOT NULL, CHECK (0..15)                          |
| inserted_at     | utc_datetime_usec    | auto                                             |
| updated_at      | utc_datetime_usec    | auto                                             |

**Indexes**:
- `UNIQUE idx_nick_colors_owner_target ON (lower(owner_nickname), lower(target_nickname))`
- `idx_nick_colors_owner ON (owner_nickname)`

## Extended Entities

### Session (add fields)

| New Field    | Type   | Default              | Notes                                  |
|--------------|--------|----------------------|----------------------------------------|
| contacts     | map()  | `ContactList.new()`  | `%{entries: [Contact.t()]}`            |
| nick_colors  | map()  | `NickColors.new()`   | `%{entries: [NickColor.t()]}`          |

New accessors: `set_contacts/2`, `get_contacts/1`, `set_nick_colors/2`, `get_nick_colors/1`

## Entity Relationships

```text
registered_nicks
  ├── 1:N → contacts (owner_nickname)
  ├── 1:N → nick_color_overrides (owner_nickname)
  ├── 1:N → notify_list_entries (owner_nickname)  [existing]
  └── 1:1 → notify_list_settings (owner_nickname) [existing]
```

## Validation Rules

### ContactList
- Max 100 entries per owner
- No self-add (owner == contact)
- No duplicate contact_nickname per owner (case-insensitive)
- contact_nickname: 1-16 chars, required
- note: 0-200 chars, optional

### NickColors
- Max 50 entries per owner
- No duplicate target_nickname per owner (case-insensitive)
- target_nickname: 1-16 chars, required
- color_index: integer 0-15

## Migration

**File**: `YYYYMMDDHHMMSS_create_address_book_tables.exs`

Single migration creating both tables:
1. `contacts` table with FK, unique case-insensitive index, owner index
2. `nick_color_overrides` table with FK, unique case-insensitive index, owner index

Pattern follows `20260211082144_create_notify_list_tables.exs` exactly.
