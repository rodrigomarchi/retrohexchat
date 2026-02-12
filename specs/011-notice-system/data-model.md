# Data Model: Notice System

**Feature**: 011-notice-system
**Date**: 2026-02-12

## Entities

### Notice (transient — no database table)

A notice is a transient in-memory message that flows through PubSub and is never persisted. It exists only as a map/struct in the LiveView process.

| Field     | Type            | Description                                     |
| --------- | --------------- | ----------------------------------------------- |
| id        | String          | Unique ID: `"notice-#{System.unique_integer}"` |
| author    | String          | Sender's nickname                               |
| content   | String          | Notice message text                             |
| type      | atom (`:notice`) | Message type for rendering                     |
| timestamp | DateTime        | UTC timestamp of delivery                       |

**Lifecycle**: Created in ChatLive `handle_dispatch_result` (sender side) or `handle_info` (receiver side) → inserted into the appropriate stream → garbage collected when the LiveView stream evicts it.

**Validation rules**:
- `content` must not be empty
- `author` must be a valid connected nickname

---

### Notice Routing Setting (persisted — PostgreSQL)

Stores the notice routing preference for registered users. One row per user.

**Table**: `notice_routing_settings`

| Column         | Type      | Constraints                        | Default    |
| -------------- | --------- | ---------------------------------- | ---------- |
| owner_nickname | string(16) | PK, FK → registered_nicks, NOT NULL | —          |
| routing        | string    | NOT NULL, CHECK (valid values)     | `"active"` |
| inserted_at    | utc_datetime_usec | NOT NULL                    | —          |
| updated_at     | utc_datetime_usec | NOT NULL                    | —          |

**Valid routing values**: `"active"`, `"status"`, `"sender"`

**Relationships**:
- `owner_nickname` → `registered_nicks.nickname` (ON DELETE CASCADE)

**Indexes**:
- Primary key on `owner_nickname` (single row per user)

---

### Session Struct Extension (in-memory)

Add `notice_routing` field to the existing `RetroHexChat.Accounts.Session` struct.

| Field          | Type | Default   | Description                         |
| -------------- | ---- | --------- | ----------------------------------- |
| notice_routing | atom | `:active` | `:active`, `:status`, or `:sender` |

**State transitions**: The `notice_routing` field has no lifecycle transitions — it is a simple preference that can be set to any valid value at any time via `/notice_routing <value>`.

---

### IgnoreEntry Type Extension (in-memory)

Extend the existing `@valid_types` list in `RetroHexChat.Chat.IgnoreEntry`.

| Current types | Added type | Matching message_type |
| ------------- | ---------- | --------------------- |
| `:all`, `:messages`, `:pms`, `:invites`, `:actions` | `:notices` | `:notice` |

**Behavior**: When `ignore_type` is `:notices`, only notices from the ignored user are dropped. When `ignore_type` is `:all`, notices (along with all other message types) are dropped.

## Entity Relationships

```text
registered_nicks
  └── notice_routing_settings (1:0..1, ON DELETE CASCADE)

Session (in-memory)
  ├── notice_routing (atom field)
  └── ignore_list
       └── entries[] → IgnoreEntry (now includes :notices type)
```

## PubSub Event Shapes

### User Notice Event

```text
Topic: "user:#{recipient_nickname}"
Event: {:new_notice, %{sender: String, content: String, timestamp: DateTime}}
```

### Channel Notice Event

```text
Topic: "channel:#{channel_name}"
Event: %{event: "new_notice", payload: %{author: String, content: String, channel: String, timestamp: DateTime}}
```
