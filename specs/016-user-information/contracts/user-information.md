# Contracts: User Information

## Commands

### /whois (Enhanced)

**Handler**: `RetroHexChat.Commands.Handlers.Whois`
**Change**: Instead of returning `{:ok, :ui_action, :open_whois, ...}`, return `{:ok, :ui_action, :show_whois_info, %{nickname: target}}` which triggers the LiveView to generate and display formatted whois text in the chat stream.

**Input**: `/whois <nickname>`
**Output**: Multiple system messages in chat stream

```
----- Whois: Alice -----
Channels: #elixir, #lobby, #general
Shared channels: #elixir
Online for: 2 hours 15 minutes
Idle for: 15 minutes
Registered: Yes
Away: Gone to lunch
Bio: Elixir enthusiast from Brazil
-----------------------------
```

**Field Display Rules**:
- "Channels" always shown (list of all channels the target is in)
- "Shared channels" only shown if querying user shares at least one channel with target
- "Online for" always shown (computed from `connected_at`)
- "Idle for" always shown (computed from `last_activity_at`)
- "Registered" always shown ("Yes" or "No")
- "Away" only shown if user is away
- "Bio" only shown if user has a bio set

**Error Cases**:
- No arguments: `"Usage: /whois <nickname>"`
- Target not online: `"<nickname> is not online."` (fall through to existing behavior)

---

### /whowas (New)

**Handler**: `RetroHexChat.Commands.Handlers.Whowas`
**Behaviour**: `RetroHexChat.Commands.Handler`

**Input**: `/whowas <nickname>`
**Output**: System message in chat stream

**Success output**:
```
----- Whowas: Bob -----
Last seen: 10 minutes ago
Channels: #elixir, #lobby
Quit message: See you tomorrow!
-----------------------------
```

**Not found output**:
```
No whowas information available for Bob.
```

**Error Cases**:
- No arguments: `"Usage: /whowas <nickname>"`

---

### /bio (New)

**Handler**: `RetroHexChat.Commands.Handlers.Bio`
**Behaviour**: `RetroHexChat.Commands.Handler`

**Input variants**:
- `/bio <text>` — Set bio
- `/bio` — View current bio
- `/bio clear` — Clear bio

**Output**:

Set bio:
```
Bio set: Elixir enthusiast from Brazil
```

Set bio (truncated):
```
Bio truncated to 200 characters and set.
```

View bio (set):
```
Your bio: Elixir enthusiast from Brazil
```

View bio (not set):
```
No bio set. Use /bio <text> to set one.
```

Clear bio:
```
Bio cleared.
```

---

## Domain Modules

### RetroHexChat.Chat.UserBio

```elixir
@spec save(String.t(), String.t()) :: :ok | {:error, term()}
@spec load(String.t()) :: {:ok, String.t()} | {:error, :not_found}
@spec delete(String.t()) :: :ok
```

### RetroHexChat.Presence.WhowasCache

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
@spec record(String.t(), [String.t()], String.t() | nil) :: :ok
@spec lookup(String.t()) :: {:ok, map()} | {:error, :not_found}
@spec size() :: non_neg_integer()
@spec clear() :: :ok
```

### RetroHexChat.Chat.TimeFormatter

```elixir
@spec format_duration(non_neg_integer()) :: String.t()
@spec format_relative(DateTime.t()) :: String.t()
```

---

## LiveView Events

### New Events

| Event | Source | Params | Action |
|-------|--------|--------|--------|
| `nick_double_click` | Nicklist `phx-click` | `%{"nick" => nickname}` | Detect double-click (same nick within 300ms), trigger whois |
| `show_whois_info` | Command dispatch | `%{nickname: target}` | Generate whois output lines, insert as system messages |

### Modified Events

| Event | Change |
|-------|--------|
| `handle_event("send_message", ...)` | Reset `last_activity_at` in Presence meta |
| `handle_event("send_pm", ...)` | Reset `last_activity_at` in Presence meta |
| All command dispatches | Reset `last_activity_at` in Presence meta |

### Socket Assigns (New)

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `last_activity_at` | DateTime | `DateTime.utc_now()` | Last user activity timestamp |
| `last_nick_click` | map | `nil` | `%{nick: String.t(), at: DateTime.t()}` for double-click detection |

### Session Fields (New)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bio` | String.t() \| nil | nil | User's bio text |

---

## Supervision

### WhowasCache

- Started under `RetroHexChat.Application` supervision tree
- Named process: `RetroHexChat.Presence.WhowasCache`
- ETS table: `:whowas_cache` (set, public reads, named)
- Cleanup interval: 600_000ms (10 minutes)
- Inserted into existing children list in `application.ex`

---

## Help Topics

### New Topics

| ID | Title | Category |
|----|-------|----------|
| `cmd-whowas` | /whowas | Commands |
| `cmd-bio` | /bio | Commands |

### Updated Topics

| ID | Change |
|----|--------|
| `cmd-whois` | Add new fields documentation (shared channels, idle time, online time, registration, bio) |

---

## Command Registration

New commands must be added to the dispatcher's command map:
- `"whowas"` → `RetroHexChat.Commands.Handlers.Whowas`
- `"bio"` → `RetroHexChat.Commands.Handlers.Bio`
