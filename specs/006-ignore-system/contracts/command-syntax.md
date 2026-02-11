# Command Syntax Contracts: Ignore System

## /ignore Command

### Syntax

```
/ignore                          → List all ignored users
/ignore <nickname>               → Ignore user (type: all, permanent)
/ignore <nickname> <type>        → Ignore user with specific type (permanent)
/ignore <nickname> <type> <dur>  → Ignore user with specific type and duration
```

### Parameters

| Parameter | Required | Values | Default |
|-----------|----------|--------|---------|
| `nickname` | No (bare = list) | Any valid nickname (1-16 chars) | — |
| `type` | No | `all`, `messages`, `pms`, `invites`, `actions` | `all` |
| `duration` | No | `Nm` (minutes), `Nh` (hours), `Nd` (days) | permanent |

### Handler Returns

| Scenario | Return |
|----------|--------|
| Bare `/ignore` | `{:ok, :ui_action, :ignore_list, %{}}` |
| Valid ignore | `{:ok, :ui_action, :ignore_add, %{nickname: nick, type: type, duration: dur_or_nil}}` |
| Self-ignore | `{:error, "You cannot ignore yourself"}` |
| Invalid type | `{:error, "Invalid ignore type. Use: all, messages, pms, invites, actions"}` |
| Invalid duration | `{:error, "Invalid duration format. Use: 5m, 2h, 1d"}` |
| Zero duration | `{:error, "Duration must be greater than zero"}` |
| Missing nickname | `{:error, "Usage: /ignore <nickname> [type] [duration]"}` |

### Duration Parsing

| Input | Seconds |
|-------|---------|
| `5m` | 300 |
| `2h` | 7200 |
| `1d` | 86400 |
| `30m` | 1800 |
| `0m` | Error: zero |
| `xyz` | Error: invalid format |
| `-5m` | Error: invalid format |

## /unignore Command

### Syntax

```
/unignore <nickname>             → Remove ignore for user
```

### Parameters

| Parameter | Required | Values |
|-----------|----------|--------|
| `nickname` | Yes | Any valid nickname |

### Handler Returns

| Scenario | Return |
|----------|--------|
| Valid unignore | `{:ok, :ui_action, :ignore_remove, %{nickname: nick}}` |
| Missing nickname | `{:error, "Usage: /unignore <nickname>"}` |

## System Messages

| Event | Message Format |
|-------|---------------|
| Ignore added (permanent) | `* <nick> is now ignored` |
| Ignore added (timed) | `* <nick> is now ignored (expires in <duration>)` |
| Ignore updated | `* <nick> ignore updated to: <type>` |
| Ignore removed | `* <nick> is no longer ignored` |
| Timer expired | `* <nick> is no longer ignored (timer expired)` |
| Self-ignore | `* You cannot ignore yourself` |
| Not found | `* <nick> is not in your ignore list` |
| List empty | `* Your ignore list is empty` |
| List display | `* Ignore list: <nick1> (all), <nick2> (pms, 3m remaining), ...` |
