# Data Model: Smart Input & Command Help

**Feature**: 024-smart-input-command-help
**Date**: 2026-02-13

## Entities

### 1. CommandSyntax (Domain — `RetroHexChat.Commands`)

Structured definition of a command's expected parameters, compiled at module load time from handler metadata.

| Field | Type | Description |
|-------|------|-------------|
| `command` | `String.t()` | Command name without slash (e.g., `"mode"`) |
| `syntax` | `String.t()` | Human-readable syntax (e.g., `"/mode <#canal> <+/-modos> [nick]"`) |
| `description` | `String.t()` | Brief description of the command |
| `category` | `atom()` | `:basics \| :channel \| :user \| :config \| :advanced` |
| `parameters` | `[Parameter.t()]` | Ordered list of parameter definitions |
| `examples` | `[String.t()]` | Example usages |
| `sub_options` | `[SubOption.t()] \| nil` | Enumerated options for complex commands (e.g., mode flags) |

**Relationships**: One CommandSyntax per registered command. Aggregated by Registry at compile time.

### 2. Parameter (Domain — `RetroHexChat.Commands`)

Single parameter within a command's syntax definition.

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String.t()` | Parameter name (e.g., `"nick"`, `"#canal"`) |
| `required` | `boolean()` | `true` for `<param>`, `false` for `[param]` |
| `type` | `atom()` | `:nick \| :channel \| :text \| :mode_flags \| :number \| :command` |
| `position` | `non_neg_integer()` | 0-indexed position in argument list |
| `description` | `String.t() \| nil` | Human-readable description (for Beginner level) |

### 3. SubOption (Domain — `RetroHexChat.Commands`)

Enumerated option within a command (e.g., mode flags for `/mode`).

| Field | Type | Description |
|-------|------|-------------|
| `flag` | `String.t()` | The flag value (e.g., `"+o"`, `"+v"`, `"+b"`) |
| `label` | `String.t()` | Brief label (e.g., `"Operador"`, `"Voz"`, `"Ban"`) |
| `description` | `String.t()` | Full description (e.g., `"Dar status de operador ao nick"`) |
| `requires_param` | `boolean()` | Whether this flag needs an additional argument |

### 4. UserPreferences — Display Category Extension

New key added to the existing `display` preferences map. No schema migration needed (JSON column).

| Key | Type | Default | Values |
|-----|------|---------|--------|
| `command_help_level` | `atom()` | `:beginner` | `:beginner \| :expert \| :off` |

### 5. HistoryEntry (Client-Side — JavaScript/localStorage)

Stored as a JSON array in localStorage under key `retro_hex_chat_history`.

| Field | Type | Description |
|-------|------|-------------|
| `text` | `string` | The full input text |
| `timestamp` | `number` | Unix timestamp in milliseconds |

**Constraints**:
- Maximum 100 entries (FIFO — oldest dropped when full)
- Sensitive commands filtered before persistence (not stored)
- Total localStorage key value must not exceed browser limits

### 6. HistoryDraft (Client-Side — JavaScript in-memory)

Ephemeral state held in the history hook during Ctrl+Up/Down navigation.

| Field | Type | Description |
|-------|------|-------------|
| `text` | `string` | The input text at the moment Ctrl+Up was first pressed |
| `cursorPosition` | `number` | Cursor position at time of draft save |

**Lifecycle**: Created on first Ctrl+Up. Restored on Ctrl+Down past newest entry. Discarded on message send or manual edit.

## State Transitions

### Syntax Tooltip State Machine

```
[Hidden] ---(input starts with "/" + space + recognized command)---> [Visible]
[Hidden] ---(autocomplete selects a command)---> [Visible]
[Visible] ---(user types arguments)---> [Visible] (parameter highlight updates)
[Visible] ---(Escape pressed)---> [Dismissed]
[Visible] ---(autocomplete opens)---> [Hidden]
[Visible] ---(input cleared or "/" removed)---> [Hidden]
[Visible] ---(message sent)---> [Hidden]
[Dismissed] ---(new command typed)---> [Visible]
[Dismissed] ---(input cleared)---> [Hidden]
```

### History Navigation State Machine

```
[Normal] ---(Ctrl+Up, has history)---> [Browsing] (draft saved)
[Browsing] ---(Ctrl+Up)---> [Browsing] (older entry shown)
[Browsing] ---(Ctrl+Down, not at newest)---> [Browsing] (newer entry shown)
[Browsing] ---(Ctrl+Down, at newest)---> [Normal] (draft restored)
[Browsing] ---(user types)---> [Normal] (exits browsing, draft discarded)
[Browsing] ---(Enter/send)---> [Normal] (draft discarded)
[Normal] ---(Ctrl+R)---> [Searching]
[Searching] ---(type term)---> [Searching] (results update)
[Searching] ---(Enter)---> [Normal] (selected entry placed in input)
[Searching] ---(Escape)---> [Normal] (search dismissed)
```

## Validation Rules

- **CommandSyntax.parameters**: Must have at least one entry for commands that take arguments. Commands with no arguments (e.g., `/clear`, `/quit`) have an empty parameters list.
- **Parameter.type**: Must be one of the defined atoms. Unknown types default to `:text`.
- **SubOption.flag**: Must start with `+` or `-`.
- **HistoryEntry.text**: Must be non-empty string. Maximum 1000 characters (matching input maxlength).
- **command_help_level**: Must be one of `:beginner`, `:expert`, `:off`. Invalid values default to `:beginner`.
- **History persistence**: Entries matching sensitive command prefixes (`/identify`, `/nickserv`, `/ns`) must be excluded before writing to localStorage.
