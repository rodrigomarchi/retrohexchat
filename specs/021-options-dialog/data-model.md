# Data Model: Options Dialog (021)

**Date**: 2026-02-13
**Branch**: `021-options-dialog`

## New Table: `user_preferences`

Single row per registered user. Stores all centralized preference categories as JSONB columns.

| Column             | Type                  | Nullable | Default | Notes                                                     |
| ------------------ | --------------------- | -------- | ------- | --------------------------------------------------------- |
| `owner_nickname`   | `string(16)`, PK      | NOT NULL | —       | FK → `registered_nicks.nickname`, `on_delete: :delete_all` |
| `display_settings` | `map` (JSONB)         | NOT NULL | `{}`    | See Display Settings shape below                          |
| `font_settings`    | `map` (JSONB)         | NOT NULL | `{}`    | See Font Settings shape below                             |
| `color_settings`   | `map` (JSONB)         | NOT NULL | `{}`    | See Color Settings shape below                            |
| `connect_settings` | `map` (JSONB)         | NOT NULL | `{}`    | See Connect Settings shape below                          |
| `message_settings` | `map` (JSONB)         | NOT NULL | `{}`    | See Message Settings shape below                          |
| `key_bindings`     | `map` (JSONB)         | NOT NULL | `{}`    | See Key Bindings shape below                              |
| `inserted_at`      | `utc_datetime_usec`   | NOT NULL | —       | Ecto timestamps                                           |
| `updated_at`       | `utc_datetime_usec`   | NOT NULL | —       | Ecto timestamps                                           |

## JSONB Column Shapes

### Display Settings

```json
{
  "show_toolbar": true,
  "show_treebar": true,
  "show_switchbar": true,
  "show_statusbar": true,
  "compact_mode": false,
  "line_shading": false
}
```

### Font Settings

```json
{
  "chat_messages": {"family": "Fixedsys, \"Courier New\", monospace", "size": 13},
  "input_box":     {"family": "Fixedsys, \"Courier New\", monospace", "size": 13},
  "nicklist":      {"family": "Fixedsys, \"Courier New\", monospace", "size": 12},
  "treebar":       {"family": "\"MS Sans Serif\", Tahoma, sans-serif", "size": 12}
}
```

**Valid font families**: `Fixedsys, "Courier New", monospace` | `Consolas, monospace` | `"Lucida Console", monospace` | `"Courier New", monospace` | `monospace`

**Valid font sizes**: 8–24 px (integer)

### Color Settings

```json
{
  "chat_background": "#ffffff",
  "default_text": "#000000",
  "own_messages": "#000000",
  "system_messages": "#808080",
  "timestamps": "#808080",
  "error_messages": "#cc0000",
  "nick_palette": ["#ffffff", "#000000", "#00007f", "#009300", "#ff0000", "#7f0000", "#9c009c", "#fc7f00", "#ffff00", "#00fc00", "#009393", "#00ffff", "#0000fc", "#ff00ff", "#7f7f7f", "#d2d2d2"]
}
```

### Connect Settings

```json
{
  "auto_reconnect_enabled": true,
  "retry_interval": 5,
  "max_retries": 10,
  "connection_timeout": 30
}
```

**Validation**: `retry_interval` 1–60, `max_retries` 1–100, `connection_timeout` 5–120.

### Message Settings

```json
{
  "whois_routing": "active",
  "notice_routing": "active",
  "pm_routing": "new_tab"
}
```

**Valid values**:
- `whois_routing`: `"active"` | `"dialog"`
- `notice_routing`: `"active"` | `"status"` | `"sender"` (mirrors existing Session.notice_routing)
- `pm_routing`: `"new_tab"` | `"active"`

### Key Bindings

```json
{
  "toggle_search":          {"key": "f", "modifiers": ["ctrl"]},
  "toggle_address_book":    {"key": "b", "modifiers": ["alt"]},
  "toggle_ignore_dialog":   {"key": "i", "modifiers": ["alt"]},
  "toggle_highlight_dialog": {"key": "h", "modifiers": ["alt"]},
  "toggle_url_catcher":     {"key": "u", "modifiers": ["alt"]},
  "toggle_log_viewer":      {"key": "l", "modifiers": ["alt"]},
  "toggle_perform_dialog":  {"key": "p", "modifiers": ["alt"]},
  "toggle_options_dialog":  {"key": "o", "modifiers": ["alt"]},
  "open_help":              {"key": "F1", "modifiers": []}
}
```

**Constraints**:
- No two actions may share the same key+modifiers combination.
- Browser-reserved combos are rejected: Ctrl+W, Ctrl+T, Ctrl+N, Ctrl+L, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+H (history), Ctrl+J (downloads), Ctrl+D (bookmark).

## In-Memory Domain Structs

### UserPreferences (new module: `RetroHexChat.Chat.UserPreferences`)

```
%{
  display: %{show_toolbar: bool, show_treebar: bool, show_switchbar: bool,
             show_statusbar: bool, compact_mode: bool, line_shading: bool},
  fonts: %{chat_messages: %{family: String, size: int}, input_box: %{...},
           nicklist: %{...}, treebar: %{...}},
  colors: %{chat_background: String, default_text: String, own_messages: String,
            system_messages: String, timestamps: String, error_messages: String,
            nick_palette: [String]},
  connect: %{auto_reconnect_enabled: bool, retry_interval: int,
             max_retries: int, connection_timeout: int},
  messages: %{whois_routing: atom, notice_routing: atom, pm_routing: atom},
  key_bindings: %{action_id => %{key: String, modifiers: [atom]}}
}
```

### KeyBindings (new module: `RetroHexChat.Chat.KeyBindings`)

Provides `defaults/0`, `validate/1`, `find_action/2` (lookup by key+modifiers), `conflict?/3`, `reserved?/1`, and `to_display_string/1`.

## Existing Entities (read/write interactions)

| Entity                  | Interaction                                                                |
| ----------------------- | -------------------------------------------------------------------------- |
| `Session`               | Extended with `user_preferences` field. Options dialog reads/writes here.  |
| `notice_routing_settings` | When notice_routing changes in Options, synced to existing table too.     |
| `registered_nicks`      | FK target for `user_preferences.owner_nickname`.                           |

## Entity Relationships

```
registered_nicks (1) ──── (0..1) user_preferences
                   └──── (0..1) notice_routing_settings  [existing, synced]
```

## State Transitions

The Options dialog uses a **draft state pattern** (matching SoundSettingsDialog):

```
CLOSED ──[Alt+O/menu]──► OPEN (draft = copy of live settings)
OPEN ──[edit panel]──► OPEN (draft updated, live unchanged)
OPEN ──[Apply]──► OPEN (draft → live, persist if identified)
OPEN ──[OK]──► CLOSED (draft → live, persist if identified)
OPEN ──[Cancel]──► CLOSED (draft discarded, live unchanged)
OPEN ──[Alt+O]──► FOCUSED (no duplicate)
```
