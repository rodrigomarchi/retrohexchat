# Data Model: Channel Central Dialog

**Feature Branch**: `007-channel-central`
**Date**: 2026-02-11

## New Entities

### BanException

Represents a user exempted from ban matching for a specific channel.

| Field        | Type     | Constraints                  | Notes                                |
|--------------|----------|------------------------------|--------------------------------------|
| channel_name | string   | required, max 50             | The channel this exception applies to |
| nickname     | string   | required, max 16             | The exempted user's nickname          |
| added_by     | string   | required, max 16             | Operator who added the exception      |
| inserted_at  | datetime | auto-set                     | When the exception was created        |

**Unique constraint**: `(channel_name, nickname)` — a user can only have one ban exception per channel.

**Index**: `channel_name` — for loading all exceptions for a channel.

**Cascade**: Delete all ban exceptions when the channel is dropped (ChanServ cleanup).

---

### InviteException

Represents a user allowed to bypass invite-only mode for a specific channel.

| Field        | Type     | Constraints                  | Notes                                |
|--------------|----------|------------------------------|--------------------------------------|
| channel_name | string   | required, max 50             | The channel this exception applies to |
| nickname     | string   | required, max 16             | The exempted user's nickname          |
| added_by     | string   | required, max 16             | Operator who added the exception      |
| inserted_at  | datetime | auto-set                     | When the exception was created        |

**Unique constraint**: `(channel_name, nickname)` — a user can only have one invite exception per channel.

**Index**: `channel_name` — for loading all exceptions for a channel.

**Cascade**: Delete all invite exceptions when the channel is dropped (ChanServ cleanup).

---

## Extended Entities

### Server State (in-memory GenServer)

Current state extended with new fields:

| Field             | Type                      | Default          | Notes                                |
|-------------------|---------------------------|------------------|--------------------------------------|
| name              | String.t()                | (required)       | Existing                             |
| topic             | String.t()                | ""               | Existing                             |
| **topic_set_by**  | **String.t() | nil**      | **nil**          | **NEW** — who set the current topic  |
| **topic_set_at**  | **DateTime.t() | nil**    | **nil**          | **NEW** — when the topic was set     |
| membership        | Membership.t()            | Membership.new() | Existing                             |
| modes             | Modes.t()                 | Modes.new()      | Existing                             |
| bans              | MapSet.t(String.t())      | MapSet.new()     | Existing                             |
| **ban_exceptions** | **MapSet.t(String.t())**  | **MapSet.new()** | **NEW** — nicknames exempt from bans |
| **invite_exceptions** | **MapSet.t(String.t())** | **MapSet.new()** | **NEW** — nicknames that bypass +i  |
| registered        | boolean()                 | false            | Existing                             |
| created_at        | DateTime.t()              | DateTime.utc_now | Existing                             |

### get_state/1 Return Map

Extended return value from `Server.get_state/1`:

| Field               | Type              | Notes                                     |
|---------------------|-------------------|-------------------------------------------|
| name                | String.t()        | Existing                                  |
| topic               | String.t()        | Existing                                  |
| **topic_set_by**    | **String.t() | nil** | **NEW**                              |
| **topic_set_at**    | **DateTime.t() | nil** | **NEW**                            |
| members             | list              | Existing                                  |
| member_count        | integer           | Existing                                  |
| operators           | list              | Existing                                  |
| modes               | String.t()        | Existing (string like "+im")              |
| **modes_detail**    | **map**           | **NEW** — `%{moderated: bool, invite_only: bool, topic_lock: bool, key: string|nil, limit: int|nil}` |
| bans                | list              | Existing (list of nicknames)              |
| **ban_exceptions**  | **list**          | **NEW** — list of exception nicknames     |
| **invite_exceptions** | **list**        | **NEW** — list of exception nicknames     |
| created_at          | DateTime.t()      | Existing                                  |

---

## Relationships

```
Channel Server (GenServer)
├── Membership (in-memory)
│   └── Members with roles (operator/voiced/regular)
├── Modes (in-memory struct)
│   └── Flags (m/i/t) + Key + Limit
├── Bans (in-memory MapSet ↔ DB bans table)
├── Ban Exceptions (in-memory MapSet ↔ DB ban_exceptions table)  [NEW]
└── Invite Exceptions (in-memory MapSet ↔ DB invite_exceptions table)  [NEW]
```

## State Transitions

### Ban Exception Lifecycle

```
Add Exception:
  operator calls add_ban_exception(channel, nickname, operator_nick)
  → MapSet.put(state.ban_exceptions, nickname)
  → Queries.add_ban_exception(channel, nickname, operator_nick)  [if registered]
  → broadcast {:ban_exception_added, %{...}}

Remove Exception:
  operator calls remove_ban_exception(channel, nickname, operator_nick)
  → MapSet.delete(state.ban_exceptions, nickname)
  → Queries.remove_ban_exception(channel, nickname)  [if registered]
  → broadcast {:ban_exception_removed, %{...}}

Join Check:
  user attempts to join channel
  → Policy.can_join? checks ban_exceptions MapSet
  → if user in ban_exceptions, skip ban check
```

### Invite Exception Lifecycle

```
Add Exception:
  operator calls add_invite_exception(channel, nickname, operator_nick)
  → MapSet.put(state.invite_exceptions, nickname)
  → Queries.add_invite_exception(channel, nickname, operator_nick)  [if registered]
  → broadcast {:invite_exception_added, %{...}}

Remove Exception:
  operator calls remove_invite_exception(channel, nickname, operator_nick)
  → MapSet.delete(state.invite_exceptions, nickname)
  → Queries.remove_invite_exception(channel, nickname)  [if registered]
  → broadcast {:invite_exception_removed, %{...}}

Join Check:
  user attempts to join invite-only channel
  → Policy.can_join? checks invite_exceptions MapSet
  → if user in invite_exceptions, skip invite-only check
```

## Validation Rules

- Nickname must be 1-16 characters (existing nick validation)
- Cannot add self to exception list (no practical purpose)
- Only operators can add/remove exceptions
- Duplicate additions are idempotent (no error, no duplicate entry)
- Removing a non-existent exception is idempotent (no error)
