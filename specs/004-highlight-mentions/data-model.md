# Data Model: Highlight / Mentions

**Feature**: 004-highlight-mentions
**Date**: 2026-02-11

## Entities

### HighlightWord (runtime struct)

Pure Elixir struct used in-memory within Session state.

| Field | Type | Required | Default | Constraints |
|-------|------|----------|---------|-------------|
| `word` | `String.t()` | Yes | — | 1-50 chars, trimmed, case-preserved |
| `bg_color` | `integer() \| nil` | No | `nil` | 0-15 (IRC color index) or nil (default highlight color) |
| `position` | `integer()` | Yes | — | 0-based, determines priority order |

**Validation rules**:
- `word` must be 1-50 characters after trimming
- `word` must not be empty or whitespace-only
- `word` must be unique within the list (case-insensitive)
- `bg_color` must be nil or an integer in 0..15
- `position` is auto-assigned based on insertion order

### HighlightWordEntry (Ecto schema — persistence)

Maps to the `highlight_words` PostgreSQL table. Used only for save/load operations.

| Column | DB Type | Nullable | Constraints |
|--------|---------|----------|-------------|
| `id` | `bigint` (PK) | No | Auto-generated |
| `owner_nickname` | `varchar(16)` | No | FK → `registered_nicks.nickname`, ON DELETE CASCADE |
| `word` | `varchar(50)` | No | 1-50 chars |
| `bg_color` | `integer` | Yes | CHECK 0-15 |
| `position` | `integer` | No | 0-based |
| `inserted_at` | `utc_datetime_usec` | No | Auto-managed |
| `updated_at` | `utc_datetime_usec` | No | Auto-managed |

**Indexes**:
- Unique: `(lower(owner_nickname), lower(word))` — prevents duplicate words per user
- Non-unique: `(owner_nickname)` — fast load by owner

### HighlightWords (aggregate — in-memory state)

Container for the user's highlight word list, stored in `Session.highlight_words`.

```
%{
  entries: [%HighlightWord{}, ...]   # Ordered by position
}
```

### HighlightMatch (transient — return value)

Not persisted. Returned by `Chat.Highlight.check/4`.

| Field | Type | Description |
|-------|------|-------------|
| Result | `{:highlight, color} \| :no_highlight` | Tuple with CSS color string, or atom |

The `color` in `{:highlight, color}` is a CSS background-color string:
- Default highlight: `"#3a3500"` (dark-theme yellow)
- Custom word color: mapped from IRC color index via `NickColors.hex_for_index/1` adapted for backgrounds

## Relationships

```
registered_nicks (1) ──── (*) highlight_words
     │                           │
     │  owner_nickname ──────────┘
     │
     │  (also FK target for notify_list_entries,
     │   contacts, nick_color_overrides)
```

## State Transitions

### HighlightWords Lifecycle

```
Empty (%{entries: []})
  │
  ├─ add_entry(word) ──→ Has entries
  ├─ load(owner)     ──→ Has entries (from DB)
  │
Has entries (%{entries: [...]})
  │
  ├─ add_entry(word)     ──→ Has entries (appended)
  ├─ remove_entry(word)  ──→ Has entries or Empty
  ├─ update_entry(...)   ──→ Has entries (modified)
  ├─ save(owner, list)   ──→ Persisted to DB (async)
  └─ (session destroyed) ──→ Gone (guests lose data)
```

### Highlight Check Flow (per message)

```
Message received
  │
  ├─ type ∈ [:system, :service, :error] → :no_highlight
  ├─ sender == own_nick                 → :no_highlight
  │
  ├─ Strip formatting codes
  ├─ Mask URL spans
  │
  ├─ Check own_nick (whole-word, case-insensitive)
  │   └─ Match → {:highlight, default_color}
  │
  ├─ Check custom words (in position order)
  │   └─ First match → {:highlight, word_color || default_color}
  │
  └─ No matches → :no_highlight
```

## Migration SQL (conceptual)

```sql
CREATE TABLE highlight_words (
  id BIGSERIAL PRIMARY KEY,
  owner_nickname VARCHAR(16) NOT NULL
    REFERENCES registered_nicks(nickname) ON DELETE CASCADE,
  word VARCHAR(50) NOT NULL,
  bg_color INTEGER CHECK (bg_color >= 0 AND bg_color <= 15),
  position INTEGER NOT NULL DEFAULT 0,
  inserted_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE UNIQUE INDEX highlight_words_owner_word_index
  ON highlight_words (LOWER(owner_nickname), LOWER(word));

CREATE INDEX highlight_words_owner_index
  ON highlight_words (owner_nickname);
```
